//go:build !cgo

package main

import (
	"encoding/json"
	"testing"

	C "github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

func TestNodeTrafficMethodReturnsStructuredTotalsAndResets(t *testing.T) {
	setupNodeTraffic(t)
	node := trafficNode("node", "provider")
	tunnel.UpdateProxies(map[string]C.Proxy{"node": node}, nil)
	read := func() []statistic.NodeTraffic {
		t.Helper()
		frame := captureSingleFrame(t, func() {
			handleMethodCall(&MethodCall{ID: "node-traffic", Method: getNodeTrafficMethod}, MethodResponse{ID: "node-traffic"})
		})
		var response struct {
			Result []statistic.NodeTraffic `json:"result"`
			Error  *MethodError            `json:"error"`
		}
		if err := json.Unmarshal(frame, &response); err != nil {
			t.Fatal(err)
		}
		if response.Error != nil || response.Result == nil {
			t.Fatalf("invalid node traffic response: %s", frame)
		}
		return response.Result
	}
	if got := read(); len(got) != 0 {
		t.Fatalf("empty traffic = %+v", got)
	}
	conn := trafficTCP(t, node, 12, 34)
	want := statistic.NodeTraffic{Name: "node", Provider: "provider", Up: 12, Down: 34}
	if got := read(); len(got) != 1 || got[0] != want {
		t.Fatalf("traffic = %+v, want %+v", got, want)
	}
	providerNode := trafficNode("node", "other-provider")
	provider := &trafficProvider{nodes: []C.Proxy{providerNode}}
	tunnel.UpdateProxies(map[string]C.Proxy{"node": node}, map[string]P.ProxyProvider{"other-provider": provider})
	udp := trafficUDP(providerNode, 56, 78)
	if got := read(); len(got) != 2 {
		t.Fatalf("per-proxy traffic missing before reset: %+v", got)
	}
	frame := captureSingleFrame(t, func() {
		handleMethodCall(&MethodCall{ID: "reset-traffic", Method: resetTrafficMethod}, MethodResponse{ID: "reset-traffic"})
	})
	var response struct {
		Result bool         `json:"result"`
		Error  *MethodError `json:"error"`
	}
	if err := json.Unmarshal(frame, &response); err != nil {
		t.Fatal(err)
	}
	if response.Error != nil || !response.Result {
		t.Fatalf("invalid reset traffic response: %s", frame)
	}
	if got := read(); len(got) != 0 {
		t.Fatalf("per-proxy traffic survived reset: %+v", got)
	}
	for _, proxy := range []C.Proxy{node, providerNode} {
		if up, down := proxy.TrafficCounter().Total(); up != 0 || down != 0 {
			t.Fatalf("proxy %s/%s survived reset: %d/%d", proxy.ProxyInfo().ProviderName, proxy.Name(), up, down)
		}
	}
	if err := udp.Close(); err != nil {
		t.Fatal(err)
	}
	_, writers := conn.UnwrapWriter()
	writers[0](7)
	if err := conn.Close(); err != nil {
		t.Fatal(err)
	}
	want.Up, want.Down = 7, 0
	if got := read(); len(got) != 1 || got[0] != want {
		t.Fatalf("traffic after reset and close = %+v, want %+v", got, want)
	}
}
