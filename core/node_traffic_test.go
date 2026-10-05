package main

import (
	"io"
	"net"
	"runtime"
	"testing"
	"weak"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	N "github.com/metacubex/mihomo/common/net"
	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

type trafficPacketConn struct{ net.PacketConn }

func (*trafficPacketConn) Close() error { return nil }

type trafficProvider struct {
	P.ProxyProvider
	nodes []C.Proxy
}

func (p *trafficProvider) Proxies() []C.Proxy { return p.nodes }

func setupNodeTraffic(t *testing.T) {
	t.Helper()
	previous := statistic.DefaultManager
	previousNotify := statistic.DefaultRequestNotify
	previousProxies := tunnel.Proxies()
	previousProviders := tunnel.ProvidersSnapshot()
	statistic.DefaultManager = &statistic.Manager{}
	statistic.DefaultRequestNotify = nil
	tunnel.UpdateProxies(nil, nil)
	t.Cleanup(func() {
		tunnel.UpdateProxies(previousProxies, previousProviders)
		statistic.DefaultManager = previous
		statistic.DefaultRequestNotify = previousNotify
	})
}

func trafficNode(name, provider string) C.Proxy {
	return adapter.NewProxy(outbound.NewBase(outbound.BaseOption{
		Name: name, ProviderName: provider, Addr: "example.com:443", Type: C.Socks5,
	}))
}

type trafficTrackedConn interface {
	C.Conn
	UnwrapWriter() (io.Writer, []N.CountFunc)
}

func trafficTCP(t *testing.T, node C.Proxy, up, down int64) trafficTrackedConn {
	t.Helper()
	local, remote := net.Pipe()
	t.Cleanup(func() { local.Close(); remote.Close() })
	conn := outbound.NewConn(local, node)
	conn.AppendToChains(trafficNode("selector", ""))
	return statistic.NewTCPTracker(conn, statistic.DefaultManager, &C.Metadata{}, nil, up, down, true)
}

func trafficUDP(node C.Proxy, up, down int64) C.PacketConn {
	conn := outbound.NewPacketConn(&trafficPacketConn{}, node.Adapter().(outbound.ProxyAdapter))
	conn.AppendToChains(trafficNode("selector", ""))
	return statistic.NewUDPTracker(conn, statistic.DefaultManager, &C.Metadata{}, nil, up, down, true)
}

func TestNodeTrafficConfigReplacementSeparatesLiveOldConnections(t *testing.T) {
	setupNodeTraffic(t)
	oldNode := trafficNode("same", "provider")
	tunnel.UpdateProxies(map[string]C.Proxy{"same": oldNode}, nil)
	oldTCP := trafficTCP(t, oldNode, 3, 4)
	oldUDP := trafficUDP(oldNode, 5, 6)
	if oldTCP.TrafficCounter() != oldUDP.TrafficCounter() {
		t.Fatal("TCP and UDP do not share the node counter")
	}
	newNode := trafficNode("same", "provider")
	tunnel.UpdateProxies(map[string]C.Proxy{"same": newNode}, nil)
	if got := handleGetNodeTraffic(); len(got) != 0 {
		t.Fatalf("old traffic carried across replacement: %+v", got)
	}
	newConn := trafficTCP(t, newNode, 1, 2)
	_, writers := oldTCP.UnwrapWriter()
	writers[0](7)
	got := handleGetNodeTraffic()
	if len(got) != 1 || got[0].Up != 1 || got[0].Down != 2 {
		t.Fatalf("old connection contaminated new node: %+v", got)
	}
	if up, down := oldNode.TrafficCounter().Total(); up != 15 || down != 10 {
		t.Fatalf("old connection stopped counting: %d/%d", up, down)
	}
	handleResetTraffic()
	for _, counter := range []*C.TrafficCounter{oldTCP.TrafficCounter(), newConn.TrafficCounter()} {
		if up, down := counter.Total(); up != 0 || down != 0 {
			t.Fatalf("reset missed a current or retired node: %d/%d", up, down)
		}
	}
	oldTCP.Close()
	oldUDP.Close()
	newConn.Close()
}

func TestNodeTrafficProviderReplacementAndDuplicateReferences(t *testing.T) {
	setupNodeTraffic(t)
	first := trafficNode("same", "a")
	second := trafficNode("same", "b")
	provider := &trafficProvider{nodes: []C.Proxy{first, second}}
	tunnel.UpdateProxies(map[string]C.Proxy{"same": first}, map[string]P.ProxyProvider{"provider": provider})
	firstConn := trafficTCP(t, first, 1, 2)
	secondConn := trafficUDP(second, 3, 4)
	firstConn.Close()
	secondConn.Close()
	if got := handleGetNodeTraffic(); len(got) != 2 {
		t.Fatalf("duplicate references counted twice or same names merged: %+v", got)
	}
	replacement := trafficNode("same", "b")
	provider.nodes = []C.Proxy{replacement}
	conn := trafficUDP(replacement, 5, 6)
	conn.Close()
	got := handleGetNodeTraffic()
	if len(got) != 2 {
		t.Fatalf("stale provider nodes retained: %+v", got)
	}
	for _, item := range got {
		if item.Provider == "b" && (item.Up != 5 || item.Down != 6) {
			t.Fatalf("replaced provider counter retained: %+v", item)
		}
	}
	tunnel.UpdateProxies(nil, nil)
	if got := handleGetNodeTraffic(); len(got) != 0 {
		t.Fatalf("removed nodes retained: %+v", got)
	}
}

func TestNodeTrafficReleasesRemovedNodes(t *testing.T) {
	setupNodeTraffic(t)
	counter := func() weak.Pointer[C.TrafficCounter] {
		node := trafficNode("retired", "provider")
		tunnel.UpdateProxies(map[string]C.Proxy{"retired": node}, nil)
		conn := trafficTCP(t, node, 1, 2)
		reference := weak.Make(node.TrafficCounter())
		tunnel.UpdateProxies(nil, nil)
		runtime.GC()
		if reference.Value() == nil {
			t.Fatal("counter reclaimed while connection is alive")
		}
		_, writers := conn.UnwrapWriter()
		writers[0](3)
		if up, down := conn.TrafficCounter().Total(); up != 4 || down != 2 {
			t.Fatalf("retired connection lost counter: %d/%d", up, down)
		}
		if err := conn.Close(); err != nil {
			t.Fatal(err)
		}
		return reference
	}()
	for i := 0; i < 10 && counter.Value() != nil; i++ {
		runtime.GC()
	}
	if counter.Value() != nil {
		t.Fatal("removed node counter remains reachable after connection closes")
	}
}

func TestNodeTrafficDirectCountsTCPAndUDPAndResets(t *testing.T) {
	setupNodeTraffic(t)
	node := adapter.NewProxy(outbound.NewBase(outbound.BaseOption{Name: "DIRECT", Type: C.Direct}))
	tunnel.UpdateProxies(map[string]C.Proxy{"DIRECT": node}, nil)
	tcp := trafficTCP(t, node, 12, 34)
	udp := trafficUDP(node, 5, 6)
	_, writers := tcp.UnwrapWriter()
	writers[0](7)
	tcp.Close()
	udp.Close()
	got := handleGetNodeTraffic()
	if len(got) != 1 || got[0].Name != "DIRECT" || got[0].Up != 24 || got[0].Down != 40 {
		t.Fatalf("direct traffic missing or incorrect: %+v", got)
	}
	handleResetTraffic()
	if got := handleGetNodeTraffic(); len(got) != 0 {
		t.Fatalf("direct traffic survived reset: %+v", got)
	}
}
