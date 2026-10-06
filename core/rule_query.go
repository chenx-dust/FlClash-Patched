package main

import (
	"errors"
	"fmt"
	"net/netip"
	"strings"
	"time"

	C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/tunnel"
	D "github.com/miekg/dns"
)

type RuleQueryParams struct {
	Target        string `json:"target"`
	Port          uint16 `json:"port"`
	Network       string `json:"network"`
	SourceIP      string `json:"sourceIP"`
	SourcePort    uint16 `json:"sourcePort"`
	DestinationIP string `json:"destinationIP"`
	Process       string `json:"process"`
	ProcessPath   string `json:"processPath"`
	UID           uint32 `json:"uid"`
	InboundName   string `json:"inboundName"`
	InboundUser   string `json:"inboundUser"`
	SniffHost     string `json:"sniffHost"`
	DSCP          uint8  `json:"dscp"`
}

type RuleQuery struct {
	Target      string `json:"target"`
	Port        uint16 `json:"port"`
	Network     string `json:"network"`
	Mode        string `json:"mode"`
	Rule        string `json:"rule"`
	RulePayload string `json:"rulePayload"`
	Proxy       string `json:"proxy"`
	IP          string `json:"ip"`
	Delay       int64  `json:"delay"`
}

func ruleQueryMetadata(params *RuleQueryParams) (*C.Metadata, error) {
	target := strings.TrimSuffix(strings.TrimSpace(params.Target), ".")
	if target == "" {
		return nil, errors.New("target is empty")
	}
	metadata := &C.Metadata{Type: C.INNER, DstPort: params.Port}
	if metadata.DstPort == 0 {
		return nil, errors.New("port must be between 1 and 65535")
	}
	switch strings.ToLower(strings.TrimSpace(params.Network)) {
	case "tcp":
		metadata.NetWork = C.TCP
	case "udp":
		metadata.NetWork = C.UDP
	default:
		return nil, fmt.Errorf("invalid network: %s", params.Network)
	}
	if ip, err := netip.ParseAddr(target); err == nil && ip.Zone() == "" {
		metadata.DstIP = ip.Unmap()
	} else {
		if _, valid := D.IsDomainName(target); !valid || strings.ContainsAny(target, "/:@[]\\ \t\r\n") {
			return nil, errors.New("target must be a domain or IP address")
		}
		metadata.Host = strings.ToLower(target)
	}
	for _, field := range []struct {
		name        string
		value       string
		destination *netip.Addr
	}{
		{"sourceIP", params.SourceIP, &metadata.SrcIP},
		{"destinationIP", params.DestinationIP, &metadata.DstIP},
	} {
		value := strings.TrimSpace(field.value)
		if value == "" {
			continue
		}
		ip, err := netip.ParseAddr(value)
		if err != nil || ip.Zone() != "" {
			return nil, fmt.Errorf("invalid %s: %s", field.name, value)
		}
		if field.name == "destinationIP" && metadata.Host == "" && metadata.DstIP != ip.Unmap() {
			return nil, errors.New("destinationIP conflicts with target IP")
		}
		*field.destination = ip.Unmap()
	}
	if params.DSCP > 63 {
		return nil, errors.New("DSCP must be between 0 and 63")
	}
	metadata.SrcPort = params.SourcePort
	metadata.Process = strings.TrimSpace(params.Process)
	metadata.ProcessPath = strings.TrimSpace(params.ProcessPath)
	metadata.Uid = params.UID
	metadata.InName = strings.TrimSpace(params.InboundName)
	metadata.InUser = strings.TrimSpace(params.InboundUser)
	metadata.SniffHost = strings.TrimSuffix(strings.ToLower(strings.TrimSpace(params.SniffHost)), ".")
	if metadata.SniffHost != "" {
		if _, valid := D.IsDomainName(metadata.SniffHost); !valid || strings.ContainsAny(metadata.SniffHost, "/:@[]\\ \t\r\n") {
			return nil, errors.New("invalid sniffHost")
		}
	}
	metadata.DSCP = params.DSCP
	return metadata, nil
}

func handleQueryRule(params *RuleQueryParams) (RuleQuery, error) {
	metadata, err := ruleQueryMetadata(params)
	if err != nil {
		return RuleQuery{}, err
	}
	query := RuleQuery{
		Target: metadata.String(), Port: metadata.DstPort,
		Network: metadata.NetWork.String(), Mode: tunnel.Mode().String(),
	}
	start := time.Now()
	proxy, rule, err := tunnel.ResolveMetadata(metadata)
	if err != nil {
		return RuleQuery{}, err
	}
	if proxy == nil {
		return RuleQuery{}, errors.New("no routing configuration is loaded")
	}
	query.Proxy = proxy.Name()
	if rule != nil {
		query.Rule = rule.RuleType().String()
		query.RulePayload = rule.Payload()
	}
	if metadata.DstIP.IsValid() {
		query.IP = metadata.DstIP.String()
	}
	query.Delay = time.Since(start).Milliseconds()
	return query, nil
}
