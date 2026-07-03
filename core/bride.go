//go:build android && cgo

package main

//#include "bride.h"
import "C"
import (
	"strings"
	"unsafe"

	"github.com/metacubex/mihomo/dns"
	"github.com/metacubex/mihomo/log"
)

func init() {
	sub := log.Subscribe()
	go func() {
		for logData := range sub {
			if logData.LogLevel < log.Level() {
				continue
			}
			writeSystemLog(logData.LogLevel.String(), logData.Payload)
		}
	}()
}

func protect(callback unsafe.Pointer, fd int) {
	C.protect(callback, C.int(fd))
}

func resolveProcess(callback unsafe.Pointer, protocol int, source, target string, uid int) string {
	s := C.CString(source)
	defer C.free(unsafe.Pointer(s))
	t := C.CString(target)
	defer C.free(unsafe.Pointer(t))
	res := C.resolve_process(callback, C.int(protocol), s, t, C.int(uid))
	return takeCString(res)
}

func invokeResult(callback unsafe.Pointer, data string) {
	s := C.CString(data)
	defer C.free(unsafe.Pointer(s))
	C.result(callback, s)
}

func releaseObject(callback unsafe.Pointer) {
	C.release_object(callback)
}

func takeCString(s *C.char) string {
	defer C.free_string(s)
	return C.GoString(s)
}

func handleUpdateDns(value string) {
	go func() {
		log.Infoln("[DNS] updateDns %s", value)
		dns.UpdateSystemDNS(strings.Split(value, ","))
		dns.FlushCacheWithDefaultResolver()
	}()
}

func writeSystemLog(level, message string) {
	l := C.CString(level)
	defer C.free(unsafe.Pointer(l))
	m := C.CString(message)
	defer C.free(unsafe.Pointer(m))
	C.system_log(l, m)
}
