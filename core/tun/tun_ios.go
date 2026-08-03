//go:build ios && cgo

package tun

import (
	"net"
	"net/netip"
	"strings"
	"syscall"

	"github.com/metacubex/mihomo/constant"
	LC "github.com/metacubex/mihomo/listener/config"
	"github.com/metacubex/mihomo/listener/sing_tun"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
)

func Start(fd int, stack string, address, dns string, mtu uint32) *sing_tun.Listener {
	if fd <= 0 {
		return nil
	}
	tunFd, err := syscall.Dup(fd)
	if err != nil {
		log.Errorln("TUN: dup fd: %v", err)
		return nil
	}

	var prefix4 []netip.Prefix
	var prefix6 []netip.Prefix
	for _, a := range strings.Split(address, ",") {
		a = strings.TrimSpace(a)
		if len(a) == 0 {
			continue
		}
		prefix, err := netip.ParsePrefix(a)
		if err != nil {
			_ = syscall.Close(tunFd)
			log.Errorln("TUN:", err)
			return nil
		}
		if prefix.Addr().Is4() {
			prefix4 = append(prefix4, prefix)
		} else {
			prefix6 = append(prefix6, prefix)
		}
	}

	var dnsHijack []string
	for _, d := range strings.Split(dns, ",") {
		d = strings.TrimSpace(d)
		if len(d) == 0 {
			continue
		}
		dnsHijack = append(dnsHijack, net.JoinHostPort(d, "53"))
	}

	options := LC.Tun{
		Enable:              true,
		Device:              "FlClash",
		Stack:               constant.TunGvisor,
		DNSHijack:           dnsHijack,
		AutoRoute:           false,
		AutoDetectInterface: false,
		Inet4Address:        prefix4,
		Inet6Address:        prefix6,
		MTU:                 mtu,
		FileDescriptor:      tunFd,
		LoopbackAddress: []netip.Addr{
			netip.MustParseAddr("10.7.0.1"),
		},
		RecvMsgX: true,
		SendMsgX: true,
	}

	listener, err := sing_tun.New(options, tunnel.Tunnel)
	if err != nil {
		_ = syscall.Close(tunFd)
		log.Errorln("TUN:", err)
		return nil
	}

	return listener
}
