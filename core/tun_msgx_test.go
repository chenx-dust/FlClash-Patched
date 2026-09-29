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

func TestPatchTunRoutingOptions(t *testing.T) {
	target := LC.Tun{}
	var params tunSchema
	if err := json.Unmarshal([]byte(`{"mtu":1500,"strict-route":true,"disable-icmp-forwarding":true,"endpoint-independent-nat":true}`), &params); err != nil {
		t.Fatal(err)
	}
	patchTun(&target, &params)
	if target.MTU != 1500 || !target.StrictRoute || !target.DisableICMPForwarding || !target.EndpointIndependentNat {
		t.Fatalf("routing options were not applied: %+v", target)
	}
	patchTun(&target, &tunSchema{})
	if target.MTU != 1500 || !target.StrictRoute || !target.DisableICMPForwarding || !target.EndpointIndependentNat {
		t.Fatalf("omitted routing options changed existing values: %+v", target)
	}
	if err := json.Unmarshal([]byte(`{"mtu":9000,"strict-route":false,"disable-icmp-forwarding":false,"endpoint-independent-nat":false}`), &params); err != nil {
		t.Fatal(err)
	}
	patchTun(&target, &params)
	if target.MTU != 9000 || target.StrictRoute || target.DisableICMPForwarding || target.EndpointIndependentNat {
		t.Fatalf("routing options could not be reset: %+v", target)
	}
}
