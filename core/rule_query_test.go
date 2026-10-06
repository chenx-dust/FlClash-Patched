package main

import (
	"testing"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outbound"
	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
)

func TestRuleQueryMetadata(t *testing.T) {
	for _, target := range []string{" Example.COM. ", "192.0.2.1", "2001:db8::1"} {
		metadata, err := ruleQueryMetadata(&RuleQueryParams{Target: target, Port: 53, Network: "UDP"})
		if err != nil || metadata.DstPort != 53 || metadata.NetWork != C.UDP {
			t.Fatalf("%s: metadata=%+v err=%v", target, metadata, err)
		}
		if target == " Example.COM. " && metadata.Host != "example.com" {
			t.Fatalf("host = %s", metadata.Host)
		}
	}
	for _, params := range []RuleQueryParams{
		{Target: "", Port: 443, Network: "tcp"},
		{Target: "https://example.com", Port: 443, Network: "tcp"},
		{Target: "example.com:443", Port: 443, Network: "tcp"},
		{Target: "example.com", Port: 0, Network: "tcp"},
		{Target: "example.com", Port: 443, Network: "invalid"},
	} {
		if _, err := ruleQueryMetadata(&params); err == nil {
			t.Errorf("accepted invalid params: %+v", params)
		}
	}
}

func TestQueryRuleUsesRoutingAndUpdatesStatistics(t *testing.T) {
	oldRules, oldProxies, oldProviders := tunnel.Rules(), tunnel.Proxies(), tunnel.Providers()
	oldRuleProviders, oldMode := tunnel.RuleProviders(), tunnel.Mode()
	t.Cleanup(func() {
		tunnel.UpdateRules(oldRules, nil, oldRuleProviders)
		tunnel.UpdateProxies(oldProxies, oldProviders)
		tunnel.SetMode(oldMode)
	})
	tunnel.UpdateProxies(map[string]C.Proxy{
		"DIRECT": adapter.NewProxy(outbound.NewDirect()),
		"GLOBAL": adapter.NewProxy(outbound.NewDirectWithOption(outbound.DirectOption{Name: "GLOBAL"})),
		"PASS":   adapter.NewProxy(outbound.NewPass()),
		"REJECT": adapter.NewProxy(outbound.NewReject()),
	}, nil)
	rule := parseTestRule(t, "DOMAIN-SUFFIX", "example.com", "DIRECT", true).(C.RuleWrapper)
	tunnel.UpdateRules([]C.Rule{rule}, nil, nil)
	tunnel.SetMode(tunnel.Rule)
	params := &RuleQueryParams{Target: "www.example.com", Port: 443, Network: "tcp"}
	query, err := handleQueryRule(params)
	if err != nil || query.Rule != "DomainSuffix" || query.RulePayload != "example.com" || query.Proxy != "DIRECT" {
		t.Fatalf("query=%+v err=%v", query, err)
	}
	if rule.HitCount() != 1 || rule.MissCount() != 0 {
		t.Fatal("manual query did not record the rule hit")
	}
	rule.SetDisabled(true)
	query, err = handleQueryRule(params)
	if err != nil || query.Rule != "" || query.Proxy != "DIRECT" {
		t.Fatalf("disabled query=%+v err=%v", query, err)
	}
	tunnel.SetMode(tunnel.Global)
	query, err = handleQueryRule(params)
	if err != nil || query.Rule != "" || query.Proxy != "GLOBAL" || query.Mode != "global" {
		t.Fatalf("global query=%+v err=%v", query, err)
	}
	tunnel.SetMode(tunnel.Direct)
	query, err = handleQueryRule(params)
	if err != nil || query.Rule != "" || query.Proxy != "DIRECT" || query.Mode != "direct" {
		t.Fatalf("direct query=%+v err=%v", query, err)
	}
	tunnel.SetMode(tunnel.Rule)
	pass := parseTestRule(t, "MATCH", "", "PASS", true).(C.RuleWrapper)
	ipRule := parseTestRule(t, "IP-CIDR", "192.0.2.0/24", "REJECT", true).(C.RuleWrapper)
	tunnel.UpdateRules([]C.Rule{pass, ipRule}, nil, nil)
	params.Target, params.Network = "192.0.2.1", "udp"
	query, err = handleQueryRule(params)
	if err != nil || query.Rule != "IPCIDR" || query.Proxy != "REJECT" || query.IP != "192.0.2.1" {
		t.Fatalf("IP query after PASS=%+v err=%v", query, err)
	}
	params.Target = "198.51.100.1"
	query, err = handleQueryRule(params)
	if err != nil || query.Rule != "" || query.Proxy != "DIRECT" {
		t.Fatalf("unmatched IP query=%+v err=%v", query, err)
	}
	if pass.HitCount() != 2 || ipRule.HitCount() != 1 || ipRule.MissCount() != 1 {
		t.Fatal("query did not record hit and miss statistics")
	}
	tunnel.UpdateRules([]C.Rule{parseTestRule(t, "PROCESS-NAME", "browser", "REJECT", true)}, nil, nil)
	params.Process = "browser"
	query, err = handleQueryRule(params)
	if err != nil || query.Proxy != "REJECT" || query.Rule != "ProcessName" {
		t.Fatalf("process query=%+v err=%v", query, err)
	}
}

func TestRuleQueryAdvancedMetadata(t *testing.T) {
	params := RuleQueryParams{
		Target: "example.com", Port: 443, Network: "tcp",
		SourceIP: "2001:db8::1", SourcePort: 12345, DestinationIP: "192.0.2.1",
		Process: "browser", ProcessPath: "/usr/bin/browser", UID: 123,
		InboundName: "mixed-in", InboundUser: "alice", SniffHost: " Sniff.Example. ", DSCP: 63,
	}
	metadata, err := ruleQueryMetadata(&params)
	if err != nil {
		t.Fatal(err)
	}
	if metadata.Type != C.INNER || metadata.Host != "example.com" || metadata.DstIP.String() != "192.0.2.1" ||
		metadata.SrcIP.String() != "2001:db8::1" || metadata.SrcPort != 12345 ||
		metadata.Process != "browser" || metadata.ProcessPath != "/usr/bin/browser" || metadata.Uid != 123 ||
		metadata.InName != "mixed-in" || metadata.InUser != "alice" || metadata.SniffHost != "sniff.example" || metadata.DSCP != 63 {
		t.Fatalf("metadata=%+v", metadata)
	}
	for _, mutate := range []func(*RuleQueryParams){
		func(p *RuleQueryParams) { p.SourceIP = "invalid" },
		func(p *RuleQueryParams) { p.DestinationIP = "example.com" },
		func(p *RuleQueryParams) { p.Target = "192.0.2.2" },
		func(p *RuleQueryParams) { p.DSCP = 64 },
		func(p *RuleQueryParams) { p.SniffHost = "https://example.com" },
	} {
		invalid := params
		mutate(&invalid)
		if _, err := ruleQueryMetadata(&invalid); err == nil {
			t.Errorf("accepted invalid params=%+v", invalid)
		}
	}
}
