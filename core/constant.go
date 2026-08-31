package main

import (
	"github.com/metacubex/mihomo/adapter/provider"
	P "github.com/metacubex/mihomo/component/process"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"net/netip"
	"time"
)

type InitParams struct {
	HomeDir string `json:"home-dir"`
	Version int    `json:"version"`
}

type DecryptAgeConfigParams struct {
	Data         string `json:"data"`
	AgeSecretKey string `json:"age-secret-key"`
}

type ManagedPathScope string

const (
	profilesPathScope  ManagedPathScope = "profiles"
	providersPathScope ManagedPathScope = "providers"
	scriptsPathScope   ManagedPathScope = "scripts"
)

type DeleteManagedPathParams struct {
	Scope        ManagedPathScope `json:"scope"`
	RelativePath string           `json:"relative-path"`
}

type SetupParams struct {
	SelectedMap map[string]string `json:"selected-map"`
	TestURL     string            `json:"test-url"`
}

type UpdateParams struct {
	Tun                *tunSchema         `json:"tun"`
	AllowLan           *bool              `json:"allow-lan"`
	MixedPort          *int               `json:"mixed-port"`
	FindProcessMode    *P.FindProcessMode `json:"find-process-mode"`
	Mode               *tunnel.TunnelMode `json:"mode"`
	LogLevel           *log.LogLevel      `json:"log-level"`
	IPv6               *bool              `json:"ipv6"`
	TCPConcurrent      *bool              `json:"tcp-concurrent"`
	ExternalController *string            `json:"external-controller"`
	UnifiedDelay       *bool              `json:"unified-delay"`
	GeoAutoUpdate      *bool              `json:"geo-auto-update"`
	GeoUpdateInterval  *int               `json:"geo-update-interval"`
}

type tunSchema struct {
	Enable       bool               `yaml:"enable" json:"enable"`
	Device       *string            `yaml:"device" json:"device"`
	Stack        *constant.TUNStack `yaml:"stack" json:"stack"`
	DNSHijack    *[]string          `yaml:"dns-hijack" json:"dns-hijack"`
	AutoRoute    *bool              `yaml:"auto-route" json:"auto-route"`
	RouteAddress *[]netip.Prefix    `yaml:"route-address" json:"route-address,omitempty"`
}

type SideLoadParams struct {
	ProviderName string `json:"providerName"`
	Data         string `json:"data"`
}

type ChangeProxyParams struct {
	GroupName        string `json:"group-name"`
	ProxyName        string `json:"proxy-name"`
	CloseConnections bool   `json:"close-connections"`
}

type TestDelayParams struct {
	ProxyName string `json:"proxy-name"`
	TestUrl   string `json:"test-url"`
	Timeout   int64  `json:"timeout"`
}

type Traffic struct {
	Up   int64 `json:"up"`
	Down int64 `json:"down"`
}

type ExternalProvider struct {
	Name             string                     `json:"name"`
	Type             string                     `json:"type"`
	Format           string                     `json:"format,omitempty"`
	VehicleType      string                     `json:"vehicle-type"`
	Count            int                        `json:"count"`
	Path             string                     `json:"path"`
	UpdateAt         time.Time                  `json:"update-at"`
	SubscriptionInfo *provider.SubscriptionInfo `json:"subscription-info"`
}

type ProxiesData struct {
	Proxies map[string]constant.Proxy `json:"proxies"`
	All     []string                  `json:"all"`
}

type TailscaleNode struct {
	ID              string     `json:"id"`
	PublicKey       string     `json:"public-key,omitempty"`
	HostName        string     `json:"hostname"`
	DNSName         string     `json:"dns-name"`
	OS              string     `json:"os"`
	IPs             []string   `json:"ips"`
	Tags            []string   `json:"tags,omitempty"`
	PrimaryRoutes   []string   `json:"primary-routes,omitempty"`
	Endpoints       []string   `json:"endpoints,omitempty"`
	CurrentEndpoint string     `json:"current-endpoint,omitempty"`
	Relay           string     `json:"relay,omitempty"`
	RxBytes         int64      `json:"rx-bytes,omitempty"`
	TxBytes         int64      `json:"tx-bytes,omitempty"`
	Online          bool       `json:"online"`
	Active          bool       `json:"active"`
	Self            bool       `json:"self"`
	ExitNode        bool       `json:"exit-node"`
	ExitNodeOption  bool       `json:"exit-node-option"`
	Expired         bool       `json:"expired"`
	LastSeen        *time.Time `json:"last-seen,omitempty"`
	LastHandshake   *time.Time `json:"last-handshake,omitempty"`
	KeyExpiry       *time.Time `json:"key-expiry,omitempty"`
}

type TailscaleNetworkDetails struct {
	MagicDNSSuffix    string          `json:"magic-dns-suffix,omitempty"`
	AuthKeyConfigured bool            `json:"auth-key-configured"`
	Health            []string        `json:"health"`
	Nodes             []TailscaleNode `json:"nodes"`
}

type ZeroTierPeer struct {
	Address   string   `json:"address"`
	Role      string   `json:"role"`
	Version   string   `json:"version"`
	Direct    bool     `json:"direct"`
	Endpoints []string `json:"endpoints"`
	LatencyMS int64    `json:"latency-ms"`
}

type ZeroTierNetworkDetails struct {
	NetworkID string         `json:"network-id"`
	Node      string         `json:"node"`
	Online    bool           `json:"online"`
	Addresses []string       `json:"addresses"`
	Routes    []string       `json:"routes"`
	DNS       []string       `json:"dns"`
	MTU       uint32         `json:"mtu"`
	Peers     []ZeroTierPeer `json:"peers"`
}

type OverlayNetworkTarget struct {
	Name  string                    `json:"name"`
	Kind  OverlayNetworkKind        `json:"kind"`
	Level OverlayNetworkDetailLevel `json:"level"`
}

type GetOverlayNetworkStatusParams struct {
	Targets []OverlayNetworkTarget `json:"targets"`
}

type ActivateOverlayNetworkParams struct {
	Name string             `json:"name"`
	Kind OverlayNetworkKind `json:"kind"`
}

type TailscalePingParams struct {
	Name string `json:"name"`
	IP   string `json:"ip"`
}

type TailscalePingResult struct {
	LatencyMS int64 `json:"latency-ms"`
}

type TailscaleLogoutParams struct {
	Name string `json:"name"`
}

type OverlayNetworkStatus struct {
	Name        string              `json:"name"`
	Kind        OverlayNetworkKind  `json:"kind"`
	State       OverlayNetworkState `json:"state"`
	RawState    string              `json:"raw-state,omitempty"`
	NetworkName string              `json:"network-name,omitempty"`
	AuthURL     string              `json:"auth-url,omitempty"`
	Error       string              `json:"error,omitempty"`
	Details     any                 `json:"details,omitempty"`
}

const (
	messageMethod                        CoreMethod = "message"
	initClashMethod                      CoreMethod = "initClash"
	getIsInitMethod                      CoreMethod = "getIsInit"
	forceGcMethod                        CoreMethod = "forceGc"
	shutdownMethod                       CoreMethod = "shutdown"
	validateConfigMethod                 CoreMethod = "validateConfig"
	updateConfigMethod                   CoreMethod = "updateConfig"
	getProxiesMethod                     CoreMethod = "getProxies"
	changeProxyMethod                    CoreMethod = "changeProxy"
	getTrafficMethod                     CoreMethod = "getTraffic"
	getTotalTrafficMethod                CoreMethod = "getTotalTraffic"
	resetTrafficMethod                   CoreMethod = "resetTraffic"
	asyncTestDelayMethod                 CoreMethod = "asyncTestDelay"
	getConnectionsMethod                 CoreMethod = "getConnections"
	closeConnectionsMethod               CoreMethod = "closeConnections"
	resetConnectionsMethod               CoreMethod = "resetConnections"
	closeConnectionMethod                CoreMethod = "closeConnection"
	getExternalProvidersMethod           CoreMethod = "getExternalProviders"
	getExternalProviderMethod            CoreMethod = "getExternalProvider"
	getOverlayNetworkStatusMethod        CoreMethod = "getOverlayNetworkStatus"
	activateOverlayNetworkMethod         CoreMethod = "activateOverlayNetwork"
	pingTailscaleNodeMethod              CoreMethod = "pingTailscaleNode"
	logoutTailscaleMethod                CoreMethod = "logoutTailscale"
	getMemoryMethod                      CoreMethod = "getMemory"
	getGoroutineCountMethod              CoreMethod = "getGoroutineCount"
	updateGeoDataMethod                  CoreMethod = "updateGeoData"
	updateExternalProviderMethod         CoreMethod = "updateExternalProvider"
	sideLoadExternalProviderMethod       CoreMethod = "sideLoadExternalProvider"
	startLogNotifyMethod                 CoreMethod = "startLogNotify"
	stopLogNotifyMethod                  CoreMethod = "stopLogNotify"
	startRequestNotifyMethod             CoreMethod = "startRequestNotify"
	stopRequestNotifyMethod              CoreMethod = "stopRequestNotify"
	startListenerMethod                  CoreMethod = "startListener"
	stopListenerMethod                   CoreMethod = "stopListener"
	updateDnsMethod                      CoreMethod = "updateDns"
	crashMethod                          CoreMethod = "crash"
	setupConfigMethod                    CoreMethod = "setupConfig"
	getProfileConfigMethod               CoreMethod = "getProfileConfig"
	clearEffectMethod                    CoreMethod = "clearEffect"
	deleteManagedPathMethod              CoreMethod = "deleteManagedPath"
	generateAgeKeyPairMethod             CoreMethod = "generateAgeKeyPair"
	convertAgeSecretKeyToPublicKeyMethod CoreMethod = "convertAgeSecretKeyToPublicKey"
	decryptAgeConfigMethod               CoreMethod = "decryptAgeConfig"
)

type CoreMethod string

type OverlayNetworkKind string

const (
	overlayNetworkTailscale OverlayNetworkKind = "tailscale"
	overlayNetworkZeroTier  OverlayNetworkKind = "zerotier"
)

type OverlayNetworkDetailLevel string

const (
	overlayNetworkSummary OverlayNetworkDetailLevel = "summary"
	overlayNetworkDetails OverlayNetworkDetailLevel = "details"
)

type OverlayNetworkState string

const (
	overlayNetworkUninitialized OverlayNetworkState = "uninitialized"
	overlayNetworkStarting      OverlayNetworkState = "starting"
	overlayNetworkConnected     OverlayNetworkState = "connected"
	overlayNetworkNeedsLogin    OverlayNetworkState = "needs-login"
	overlayNetworkNeedsApproval OverlayNetworkState = "needs-approval"
	overlayNetworkStopped       OverlayNetworkState = "stopped"
	overlayNetworkError         OverlayNetworkState = "error"
	overlayNetworkUnknown       OverlayNetworkState = "unknown"
)

type MessageType string

type Delay struct {
	Url   string `json:"url"`
	Name  string `json:"name"`
	Value int32  `json:"value"`
}

type Message struct {
	Type MessageType `json:"type"`
	Data any         `json:"data"`
}

const (
	LogMessage       MessageType = "log"
	DelayMessage     MessageType = "delay"
	RequestMessage   MessageType = "request"
	LoadedMessage    MessageType = "loaded"
	GeoUpdateMessage MessageType = "geoUpdate"
)

type GeoUpdateStatus struct {
	Type     string `json:"type"`
	Updating bool   `json:"updating"`
	Skipped  bool   `json:"skipped,omitempty"`
	Error    string `json:"error,omitempty"`
}
