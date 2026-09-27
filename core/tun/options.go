package tun

type Options struct {
	RecvMsgX               bool   `json:"recvMsgX"`
	SendMsgX               bool   `json:"sendMsgX"`
	Stack                  string `json:"stack"`
	Address                string `json:"address"`
	DNS                    string `json:"dns"`
	MTU                    uint32 `json:"mtu"`
	DisableICMPForwarding  bool   `json:"disableIcmpForwarding"`
	EndpointIndependentNAT bool   `json:"endpointIndependentNat"`
	CongestionController   string `json:"congestionController"`
}
