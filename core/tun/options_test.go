package tun

import (
	"encoding/json"
	"testing"
)

func TestOptionsJSON(t *testing.T) {
	data := []byte(`{"stack":"mixed","address":"172.19.0.1/30","dns":"172.19.0.2","mtu":9000,"disableIcmpForwarding":true,"endpointIndependentNat":true}`)
	options := Options{}
	if err := json.Unmarshal(data, &options); err != nil {
		t.Fatal(err)
	}
	if options.Stack != "mixed" || options.Address != "172.19.0.1/30" || options.DNS != "172.19.0.2" || options.MTU != 9000 || !options.DisableICMPForwarding || !options.EndpointIndependentNAT {
		t.Fatalf("unexpected options: %+v", options)
	}
}
