//go:build android && cgo

package main

//#include "bride.h"
import "C"
import (
	"strings"
	"sync"
	"sync/atomic"
	"unsafe"

	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/log"
)

var (
	dnsUpdateMu  sync.Mutex
	dnsUpdateSeq atomic.Uint64
)

func protect(callback unsafe.Pointer, fd int) bool {
	return C.protect(callback, C.int(fd)) != 0
}

func resolveUid(callback unsafe.Pointer, protocol int, source, target string) int {
	s := C.CString(source)
	defer C.free(unsafe.Pointer(s))
	t := C.CString(target)
	defer C.free(unsafe.Pointer(t))
	return int(C.resolve_uid(callback, C.int(protocol), s, t))
}

func resolvePackage(callback unsafe.Pointer, uid int) string {
	return takeCString(C.resolve_package(callback, C.int(uid)))
}

func invokeResult(callback unsafe.Pointer, data string) {
	s := C.CString(data)
	defer C.free(unsafe.Pointer(s))
	C.result(callback, s)
}

func releaseObject(callback unsafe.Pointer) {
	C.release_object(callback)
}

func retainObject(callback unsafe.Pointer) unsafe.Pointer {
	return C.retain_object(callback)
}

func writeSystemLog(level, message string) {
}

func handleUpdateDns(value string) {
	seq := dnsUpdateSeq.Add(1)
	safeGoDetached("updateDns", func() {
		dnsUpdateMu.Lock()
		defer dnsUpdateMu.Unlock()
		if seq != dnsUpdateSeq.Load() {
			return
		}
		log.Infoln("[DNS] updateDns %s", value)
		dns.UpdateSystemDNS(strings.Split(value, ","))
		dns.FlushCacheWithDefaultResolver()
	})
}

func takeCString(s *C.char) string {
	defer C.free_string(s)
	return C.GoString(s)
}
