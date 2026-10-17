package tun

import "net/netip"

// The system stack answers its own NAT on this address; iOS gives the tunnel no
// loopback of its own to fall back to.
var loopbackAddress = []netip.Addr{netip.MustParseAddr("10.7.0.1")}
