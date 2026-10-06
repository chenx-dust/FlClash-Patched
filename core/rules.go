package main

import (
	"time"

	"github.com/metacubex/mihomo/constant"
	P "github.com/metacubex/mihomo/constant/provider"
	"github.com/metacubex/mihomo/tunnel"
)

type CoreRule struct {
	Index     int        `json:"index"`
	Type      string     `json:"type"`
	Payload   string     `json:"payload"`
	Proxy     string     `json:"proxy"`
	Size      int        `json:"size"`
	Disabled  bool       `json:"disabled"`
	HitCount  uint64     `json:"hitCount"`
	HitAt     *time.Time `json:"hitAt,omitempty"`
	MissCount uint64     `json:"missCount"`
	MissAt    *time.Time `json:"missAt,omitempty"`
}

type SetRuleDisabledParams struct {
	Index    int    `json:"index"`
	Type     string `json:"type"`
	Payload  string `json:"payload"`
	Disabled bool   `json:"disabled"`
}

func handleGetRules() []CoreRule {
	return newCoreRules(tunnel.Rules(), tunnel.RuleProvidersSnapshot())
}

// The index alone may name a different rule once a config apply has replaced
// the list, so the caller's type and payload must still match.
func handleSetRuleDisabled(params *SetRuleDisabledParams) bool {
	return setRuleDisabled(tunnel.Rules(), params)
}

func newCoreRules(rules []constant.Rule, providers map[string]P.RuleProvider) []CoreRule {
	result := make([]CoreRule, 0, len(rules))
	for index, rule := range rules {
		item := CoreRule{
			Index:   index,
			Type:    rule.RuleType().String(),
			Payload: rule.Payload(),
			Proxy:   rule.Adapter(),
			Size:    -1,
		}
		if wrapper, ok := rule.(constant.RuleWrapper); ok {
			item.Disabled = wrapper.IsDisabled()
			item.HitCount = wrapper.HitCount()
			item.HitAt = optionalTime(wrapper.HitAt())
			item.MissCount = wrapper.MissCount()
			item.MissAt = optionalTime(wrapper.MissAt())
			rule = wrapper.Unwrap()
		}
		item.Size = ruleSize(rule, providers)
		result = append(result, item)
	}
	return result
}

func ruleSize(rule constant.Rule, providers map[string]P.RuleProvider) int {
	switch rule.RuleType() {
	case constant.GEOIP, constant.GEOSITE:
		if group, ok := rule.(constant.RuleGroup); ok {
			return group.GetRecodeSize()
		}
	case constant.RuleSet:
		if provider, ok := providers[rule.Payload()]; ok {
			return provider.Count()
		}
	}
	return -1
}

// RuleWrapper stores times as Unix nanoseconds, so a rule that never matched
// reports the epoch rather than the zero time.
func optionalTime(value time.Time) *time.Time {
	if value.UnixNano() <= 0 {
		return nil
	}
	return &value
}

func setRuleDisabled(rules []constant.Rule, params *SetRuleDisabledParams) bool {
	if params.Index < 0 || params.Index >= len(rules) {
		return false
	}
	wrapper, ok := rules[params.Index].(constant.RuleWrapper)
	if !ok {
		return false
	}
	if wrapper.RuleType().String() != params.Type || wrapper.Payload() != params.Payload {
		return false
	}
	wrapper.SetDisabled(params.Disabled)
	return true
}
