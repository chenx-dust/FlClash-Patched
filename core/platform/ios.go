//go:build ios && cgo

package platform

import (
	"net"
)

func ShouldBlockConnection() bool {
	return false
}

func QuerySocketUidFromProcFs(source, target net.Addr) int {
	return -1
}
