//go:build ios

package platform

import "net"

func ShouldBlockConnection() bool {
	return false
}

func QuerySocketUidFromProcFs(_, _ net.Addr) int {
	return -1
}
