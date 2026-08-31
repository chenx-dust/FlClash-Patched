package main

import (
	"encoding/json"
	"testing"

	"github.com/metacubex/tailscale/ipn/ipnstate"
)

func TestOverlayNetworkRequestProtocol(t *testing.T) {
	payload := []byte(`{"targets":[{"name":"tailnet","kind":"tailscale","level":"summary"},{"name":"zerotier","kind":"zerotier","level":"details"}]}`)
	var params GetOverlayNetworkStatusParams
	if err := json.Unmarshal(payload, &params); err != nil {
		t.Fatalf("unmarshal overlay network request: %v", err)
	}
	if len(params.Targets) != 2 {
		t.Fatalf("unexpected params: %+v", params)
	}
	if params.Targets[0].Kind != overlayNetworkTailscale || params.Targets[0].Level != overlayNetworkSummary {
		t.Fatalf("unexpected summary target: %+v", params.Targets[0])
	}
	if params.Targets[1].Kind != overlayNetworkZeroTier || params.Targets[1].Level != overlayNetworkDetails {
		t.Fatalf("unexpected details target: %+v", params.Targets[1])
	}
}

func TestOverlayNetworkActivationRequestProtocol(t *testing.T) {
	payload := []byte(`{"name":"tailnet","kind":"tailscale"}`)
	var params ActivateOverlayNetworkParams
	if err := json.Unmarshal(payload, &params); err != nil {
		t.Fatalf("unmarshal overlay network activation request: %v", err)
	}
	if params.Name != "tailnet" || params.Kind != overlayNetworkTailscale {
		t.Fatalf("unexpected activation params: %+v", params)
	}
}

func TestTailscalePingRequestProtocol(t *testing.T) {
	payload := []byte(`{"name":"tailnet","ip":"100.64.0.1"}`)
	var params TailscalePingParams
	if err := json.Unmarshal(payload, &params); err != nil {
		t.Fatalf("unmarshal Tailscale ping request: %v", err)
	}
	if params.Name != "tailnet" || params.IP != "100.64.0.1" {
		t.Fatalf("unexpected params: %+v", params)
	}

	resultJSON, err := json.Marshal(TailscalePingResult{LatencyMS: 23})
	if err != nil {
		t.Fatalf("marshal Tailscale ping result: %v", err)
	}
	if string(resultJSON) != `{"latency-ms":23}` {
		t.Fatalf("unexpected result: %s", resultJSON)
	}
}

func TestTailscaleLogoutRequestProtocol(t *testing.T) {
	payload := []byte(`{"name":"tailnet"}`)
	var params TailscaleLogoutParams
	if err := json.Unmarshal(payload, &params); err != nil {
		t.Fatalf("unmarshal Tailscale logout request: %v", err)
	}
	if params.Name != "tailnet" {
		t.Fatalf("unexpected Tailscale logout params: %+v", params)
	}
}

func TestTailscaleNodePreservesHostAndDNSNames(t *testing.T) {
	node := toTailscaleNode(&ipnstate.PeerStatus{
		HostName: "device",
		DNSName:  "device.example.com.",
	}, false)
	if node.HostName != "device" {
		t.Fatalf("unexpected host name: %q", node.HostName)
	}
	if node.DNSName != "device.example.com." {
		t.Fatalf("unexpected DNS name: %q", node.DNSName)
	}
}

func TestTailscaleDetailsIncludeMagicDNSSuffix(t *testing.T) {
	status := &ipnstate.Status{
		CurrentTailnet: &ipnstate.TailnetStatus{
			Name:           "example",
			MagicDNSSuffix: "example.ts.net",
		},
	}
	result := toTailscaleOverlayNetworkStatus(OverlayNetworkTarget{
		Name:  "tailnet",
		Kind:  overlayNetworkTailscale,
		Level: overlayNetworkDetails,
	}, status, true)
	details, ok := result.Details.(TailscaleNetworkDetails)
	if !ok {
		t.Fatalf("unexpected details: %#v", result.Details)
	}
	if details.MagicDNSSuffix != "example.ts.net" {
		t.Fatalf("unexpected MagicDNS suffix: %q", details.MagicDNSSuffix)
	}
	if !details.AuthKeyConfigured {
		t.Fatal("expected configured auth key")
	}
}

func TestOverlayNetworkResponseDistinguishesSummaryAndDetails(t *testing.T) {
	summary := OverlayNetworkStatus{
		Name:  "tailnet",
		Kind:  overlayNetworkTailscale,
		State: overlayNetworkStopped,
	}
	summaryJSON, err := json.Marshal(summary)
	if err != nil {
		t.Fatalf("marshal summary: %v", err)
	}
	var summaryMap map[string]any
	if err = json.Unmarshal(summaryJSON, &summaryMap); err != nil {
		t.Fatalf("unmarshal summary: %v", err)
	}
	if _, exists := summaryMap["details"]; exists {
		t.Fatalf("summary unexpectedly contains details: %s", summaryJSON)
	}

	details := summary
	details.Details = TailscaleNetworkDetails{
		Health: []string{},
		Nodes:  []TailscaleNode{},
	}
	detailsJSON, err := json.Marshal(details)
	if err != nil {
		t.Fatalf("marshal details: %v", err)
	}
	var detailsMap map[string]any
	if err = json.Unmarshal(detailsJSON, &detailsMap); err != nil {
		t.Fatalf("unmarshal details: %v", err)
	}
	if _, exists := detailsMap["details"]; !exists {
		t.Fatalf("details response omitted requested details: %s", detailsJSON)
	}
}

func TestOverlayNetworkStateNormalization(t *testing.T) {
	if got := tailscaleOverlayNetworkState("NoState"); got != overlayNetworkUninitialized {
		t.Fatalf("Tailscale NoState mapped to %q", got)
	}
	if got := tailscaleOverlayNetworkState(""); got != overlayNetworkUninitialized {
		t.Fatalf("empty Tailscale state mapped to %q", got)
	}
	if got := tailscaleOverlayNetworkState("Stopped"); got != overlayNetworkStopped {
		t.Fatalf("Tailscale Stopped mapped to %q", got)
	}
	if got := tailscaleOverlayNetworkState("NeedsLogin"); got != overlayNetworkNeedsLogin {
		t.Fatalf("Tailscale NeedsLogin mapped to %q", got)
	}
	if got := tailscaleOverlayNetworkState("NeedsMachineAuth"); got != overlayNetworkNeedsApproval {
		t.Fatalf("Tailscale NeedsMachineAuth mapped to %q", got)
	}
	if got := zeroTierOverlayNetworkState("ok", ""); got != overlayNetworkConnected {
		t.Fatalf("ZeroTier ok mapped to %q", got)
	}
	if got := zeroTierOverlayNetworkState("", ""); got != overlayNetworkUninitialized {
		t.Fatalf("empty ZeroTier state mapped to %q", got)
	}
	if got := zeroTierOverlayNetworkState("stopped", ""); got != overlayNetworkStopped {
		t.Fatalf("ZeroTier stopped mapped to %q", got)
	}
	if got := zeroTierOverlayNetworkState("ok", "failure"); got != overlayNetworkError {
		t.Fatalf("ZeroTier error mapped to %q", got)
	}
}
