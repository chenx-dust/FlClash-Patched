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

func Start(fd int, config Options) *sing_tun.Listener {
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
	for _, address := range strings.Split(config.Address, ",") {
		address = strings.TrimSpace(address)
		if address == "" {
			continue
		}
		prefix, parseErr := netip.ParsePrefix(address)
		if parseErr != nil {
			_ = syscall.Close(tunFd)
			log.Errorln("TUN: %v", parseErr)
			return nil
		}
		if prefix.Addr().Is4() {
			prefix4 = append(prefix4, prefix)
		} else {
			prefix6 = append(prefix6, prefix)
		}
	}

	var dnsHijack []string
	for _, address := range strings.Split(config.DNS, ",") {
		address = strings.TrimSpace(address)
		if address == "" {
			continue
		}
		dnsHijack = append(dnsHijack, net.JoinHostPort(address, "53"))
	}

	options := LC.Tun{
		Enable:                 true,
		Device:                 "FlClash",
		Stack:                  constant.TunGvisor,
		DNSHijack:              dnsHijack,
		AutoRoute:              false,
		AutoDetectInterface:    false,
		Inet4Address:           prefix4,
		Inet6Address:           prefix6,
		MTU:                    config.MTU,
		FileDescriptor:         tunFd,
		DisableICMPForwarding:  config.DisableICMPForwarding,
		EndpointIndependentNat: config.EndpointIndependentNAT,
		LoopbackAddress: []netip.Addr{
			netip.MustParseAddr("10.7.0.1"),
		},
		RecvMsgX: true,
		SendMsgX: true,
	}

	listener, err := sing_tun.New(options, tunnel.Tunnel)
	if err != nil {
		_ = syscall.Close(tunFd)
		log.Errorln("TUN: %v", err)
		return nil
	}
	return listener
}
