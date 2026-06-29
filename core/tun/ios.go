//go:build ios && cgo

package tun

import "github.com/metacubex/mihomo/listener/sing_tun"

func Start(fd int, stack string, address, dns string) *sing_tun.Listener {
	return nil
}
