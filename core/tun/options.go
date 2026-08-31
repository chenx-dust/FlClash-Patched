package tun

type Options struct {
	Stack                  string `json:"stack"`
	Address                string `json:"address"`
	DNS                    string `json:"dns"`
	MTU                    uint32 `json:"mtu"`
	DisableICMPForwarding  bool   `json:"disableIcmpForwarding"`
	EndpointIndependentNAT bool   `json:"endpointIndependentNat"`
}
