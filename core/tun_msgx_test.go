package main

import (
	"encoding/json"
	"testing"

	LC "github.com/metacubex/mihomo/listener/config"
)

func TestPatchTunMsgX(t *testing.T) {
	target := LC.Tun{RecvMsgX: true}
	var params tunSchema
	if err := json.Unmarshal([]byte(`{"recvmsgx":false,"sendmsgx":true}`), &params); err != nil {
		t.Fatal(err)
	}
	patchTun(&target, &params)
	if target.RecvMsgX || !target.SendMsgX {
		t.Fatalf("explicit switches were not applied: %+v", target)
	}
	patchTun(&target, &tunSchema{})
	if target.RecvMsgX || !target.SendMsgX {
		t.Fatal("omitted switches changed existing values")
	}
}

func TestPatchTunCongestionController(t *testing.T) {
	target := LC.Tun{CongestionController: "cubic"}
	var params tunSchema
	if err := json.Unmarshal([]byte(`{"congestion-controller":"bbr"}`), &params); err != nil {
		t.Fatal(err)
	}
	patchTun(&target, &params)
	if target.CongestionController != "bbr" {
		t.Fatalf("congestion controller was not applied: %q", target.CongestionController)
	}
	patchTun(&target, &tunSchema{})
	if target.CongestionController != "bbr" {
		t.Fatal("omitted congestion controller changed the existing value")
	}
}
