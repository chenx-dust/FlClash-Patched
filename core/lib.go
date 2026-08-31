//go:build (android || ios) && cgo

package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"core/platform"
	t "core/tun"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"syscall"
	"unsafe"

	"github.com/metacubex/mihomo/component/dialer"
	"github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
)

var (
	eventListenerLock sync.RWMutex
	eventListener     unsafe.Pointer
)

type TunHandler struct {
	listener *sing_tun.Listener
	callback unsafe.Pointer

	mu sync.RWMutex
}

func (th *TunHandler) start(fd int, options t.Options) bool {
	configMu.Lock()
	defer configMu.Unlock()

	th.mu.Lock()
	th.initHook()
	th.mu.Unlock()

	// t.Start runs outside th.mu on purpose. The hook is live from initHook
	// onwards, and a socket opened anywhere inside Start reaches handleProtect
	// on this very goroutine — an RLock taken while this one holds the write
	// lock deadlocks the start outright. Nothing is lost by dropping it: both
	// hooks return early until th.listener is set, which is below.
	tunListener := t.Start(fd, options)

	th.mu.Lock()
	defer th.mu.Unlock()
	if tunListener != nil {
		log.Infoln("TUN address: %v", tunListener.Address())
		th.listener = tunListener
		return true
	}
	th.clear()
	return false
}

func (th *TunHandler) close() {
	th.mu.Lock()
	defer th.mu.Unlock()
	th.clear()
}

func (th *TunHandler) clear() {
	th.removeHook()
	if th.listener != nil {
		_ = th.listener.Close()
	}
	if th.callback != nil {
		releaseObject(th.callback)
	}
	th.callback = nil
	th.listener = nil
}

// protectFailing tracks whether the last protect call was refused, so a stuck
// VpnService produces one log line rather than one per connection.
var protectFailing atomic.Bool

func (th *TunHandler) handleProtect(fd int) error {
	th.mu.RLock()
	defer th.mu.RUnlock()

	if th.listener == nil || (th.callback == nil && platform.RequiresProtectCallback()) {
		// The tun routes are already live at this point (Android establishes
		// them before it hands the fd over), so an unprotected socket would be
		// routed straight back into the tunnel and hang until it times out.
		// Failing it here costs nothing and is at least visible.
		return errTunNotReady
	}

	if !protect(th.callback, fd) {
		if protectFailing.CompareAndSwap(false, true) {
			logError("VpnService.protect refused a socket; connections would loop back into the tunnel")
		}
		return errProtectRefused
	}

	if protectFailing.CompareAndSwap(true, false) {
		log.Infoln("[TUN] VpnService.protect recovered")
	}
	return nil
}

func (th *TunHandler) handleResolveProcess(source, target net.Addr) (int, string) {
	th.mu.RLock()
	defer th.mu.RUnlock()

	// A released callback is a null jobject, and JNI aborts on a call through one.
	if th.listener == nil || th.callback == nil {
		return -1, ""
	}
	var protocol int
	switch source.Network() {
	case "udp", "udp4", "udp6":
		protocol = syscall.IPPROTO_UDP
	case "tcp", "tcp4", "tcp6":
		protocol = syscall.IPPROTO_TCP
	}
	var uid int
	if sdkVersion.Load() < 29 {
		uid = platform.QuerySocketUidFromProcFs(source, target)
	} else {
		uid = resolveUid(th.callback, protocol, source.String(), target.String())
	}
	if uid < 0 {
		return -1, ""
	}
	return uid, resolvePackage(th.callback, uid)
}

var (
	installHooksOnce sync.Once
	activeTunHandler atomic.Pointer[TunHandler]
)

func installHooks() {
	installHooksOnce.Do(func() {
		dialer.DefaultSocketHook = func(network, address string, conn syscall.RawConn) error {
			if platform.ShouldBlockConnection() {
				return errBlocked
			}
			th := activeTunHandler.Load()
			if th == nil {
				return nil
			}
			var protectErr error
			if err := conn.Control(func(fd uintptr) {
				protectErr = th.handleProtect(int(fd))
			}); err != nil {
				return err
			}
			return protectErr
		}
		process.DefaultPackageNameResolver = func(metadata *constant.Metadata) (string, error) {
			th := activeTunHandler.Load()
			if th == nil {
				return "", process.ErrInvalidNetwork
			}
			src, dst := metadata.RawSrcAddr, metadata.RawDstAddr
			if src == nil || dst == nil {
				return "", process.ErrInvalidNetwork
			}
			// Everywhere else mihomo fills Uid from its own procfs lookup, the one Android took away.
			uid, packageName := th.handleResolveProcess(src, dst)
			if uid >= 0 {
				metadata.Uid = uint32(uid)
			}
			return packageName, nil
		}
	})
}

func (th *TunHandler) initHook() {
	installHooks()
	activeTunHandler.Store(th)
}

// Swap the handler, never the hook: mihomo nil-checks DefaultSocketHook once and
// dereferences it again when the socket is created, so clearing it mid-dial
// calls a nil func value.
func (th *TunHandler) removeHook() {
	activeTunHandler.CompareAndSwap(th, nil)
}

var (
	tunLock           sync.Mutex
	errBlocked        = errors.New("blocked: the process is out of file descriptors")
	errTunNotReady    = errors.New("blocked: the tun listener is not ready")
	errProtectRefused = errors.New("blocked: VpnService.protect refused the socket")
	tunHandler        *TunHandler
)

func handleStopTun() {
	tunLock.Lock()
	defer tunLock.Unlock()
	stopTunLocked()
}

func stopTunLocked() {
	if tunHandler == nil {
		return
	}
	tunHandler.close()
	tunHandler = nil
}

func handleStartTun(callback unsafe.Pointer, fd int, options t.Options) bool {
	tunLock.Lock()
	defer tunLock.Unlock()
	stopTunLocked()
	if fd == 0 {
		if callback != nil {
			releaseObject(callback)
		}
		logError("startTun was handed no tun descriptor")
		return false
	}
	tunHandler = &TunHandler{
		callback: callback,
	}
	if tunHandler.start(fd, options) {
		return true
	}
	// start() already cleared the handler, so nothing protects sockets from
	// here on. Android has the routes up regardless, so the caller has to tear
	// the VPN down rather than leave the device pointed at a black hole.
	tunHandler = nil
	return false
}

func (response MethodResponse) send() {
	if response.callback != nil {
		defer releaseObject(response.callback)
	}
	data, err := response.JSON()
	if err != nil {
		logError("MethodResponse marshal error: id=%s err=%v", response.ID, err)
		data, err = (&MethodResponse{
			ID: response.ID,
			Error: &MethodError{
				Code:    "serialization_error",
				Message: "failed to serialize method response",
				Details: err.Error(),
			},
		}).JSON()
		if err != nil {
			logError("Fallback MethodResponse marshal error: id=%s err=%v", response.ID, err)
			return
		}
	}
	invokeResult(response.callback, string(data))
}

func init() {
	registerMethod(updateDnsMethod, withArguments(func(value *string, response MethodResponse) {
		handleUpdateDns(*value)
		response.success(true)
	}))
}

//export invokeMethod
func invokeMethod(callback unsafe.Pointer, paramsChar *C.char) {
	params := takeCString(paramsChar)
	call := &MethodCall{}
	if err := json.Unmarshal([]byte(params), call); err != nil {
		newMethodResponse("", callback).failure("invalid_method_call", err.Error(), nil)
		return
	}
	go handleMethodCall(call, newMethodResponse(call.ID, callback))
}

//export startTUN
func startTUN(callback unsafe.Pointer, fd C.int, optionsChar *C.char) bool {
	options := t.Options{}
	if err := json.Unmarshal([]byte(takeCString(optionsChar)), &options); err != nil {
		logError("invalid TUN options: %v", err)
		if callback != nil {
			releaseObject(callback)
		}
		platform.CloseRejectedTunDescriptor(int(fd))
		return false
	}
	started := handleStartTun(callback, int(fd), options)
	if !started {
		return false
	}
	if !isRunning.Load() {
		handleStartListener()
	} else {
		handleResetConnections()
	}
	return true
}

//export quickSetup
func quickSetup(callback unsafe.Pointer, initParamsChar *C.char, setupParamsChar *C.char) {
	go func() {
		defer releaseObject(callback)
		defer func() {
			if r := recover(); r != nil {
				logError("panic in quickSetup: %v\n%s", r, stackTrace())
				invokeResult(callback, fmt.Sprintf("internal panic: %v", r))
			}
		}()
		initParamsString := takeCString(initParamsChar)
		setupParamsString := takeCString(setupParamsChar)
		initParams := InitParams{}
		if err := json.Unmarshal([]byte(initParamsString), &initParams); err != nil || !handleInitClash(&initParams) {
			invokeResult(callback, "init failed")
			return
		}
		setupParams := defaultSetupParams()
		if err := UnmarshalJson([]byte(setupParamsString), setupParams); err != nil {
			invokeResult(callback, err.Error())
			return
		}
		isRunning.Store(true)
		invokeResult(callback, handleSetupConfig(setupParams))
	}()
}

//export setEventListener
func setEventListener(listener unsafe.Pointer) {
	eventListenerLock.Lock()
	defer eventListenerLock.Unlock()
	if eventListener != nil {
		releaseObject(eventListener)
	}
	eventListener = listener
}

//export getTotalTraffic
func getTotalTraffic(onlyStatisticsProxy bool) *C.char {
	return C.CString(marshalResult(handleGetTotalTraffic(onlyStatisticsProxy)))
}

//export getTraffic
func getTraffic(onlyStatisticsProxy bool) *C.char {
	return C.CString(marshalResult(handleGetTraffic(onlyStatisticsProxy)))
}

func marshalResult(value any) string {
	data, err := json.Marshal(value)
	if err != nil {
		logError("Result marshal error: %v", err)
		return ""
	}
	return string(data)
}

func deliverEvent(data []byte) {
	eventListenerLock.RLock()
	if eventListener == nil {
		eventListenerLock.RUnlock()
		return
	}
	listener := retainObject(eventListener)
	eventListenerLock.RUnlock()
	if listener == nil {
		return
	}
	defer releaseObject(listener)
	invokeResult(listener, string(data))
}

//export stopTun
func stopTun() {
	handleStopTun()
	if isRunning.Load() {
		handleStopListener()
	}
}

//export suspend
func suspend(suspended bool) {
	handleSuspend(suspended)
}

//export forceGC
func forceGC() {
	handleForceGC()
}

//export updateDns
func updateDns(s *C.char) {
	handleUpdateDns(takeCString(s))
}
