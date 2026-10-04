//go:build !cgo

package main

import (
	"encoding/json"
	"testing"

	C "github.com/metacubex/mihomo/constant"
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
	handleResetTraffic()
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
