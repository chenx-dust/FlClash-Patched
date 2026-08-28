package main

import (
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"slices"
	"strconv"
	"sync"
	"sync/atomic"
	"time"

	"github.com/metacubex/mihomo/adapter"
	"github.com/metacubex/mihomo/adapter/outboundgroup"
	"github.com/metacubex/mihomo/common/observable"
	"github.com/metacubex/mihomo/common/utils"
	"github.com/metacubex/mihomo/component/age"
	"github.com/metacubex/mihomo/component/resolver"
	"github.com/metacubex/mihomo/component/updater"
	"github.com/metacubex/mihomo/config"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/constant/features"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/mihomo/listener"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/tunnel"
	"github.com/metacubex/mihomo/tunnel/statistic"
)

var (
	logMu         sync.Mutex
	logSubscriber observable.Subscription[log.Event]
	logCancel     context.CancelFunc
)

var (
	logNotifyMu      sync.Mutex
	logNotifyEnabled bool
	logNotifyCache   [maxCachedLogNotify]StampedLogEvent
	logNotifyStart   int
	logNotifyLen     int
)

var (
	requestNotifyMu      sync.Mutex
	requestNotifyEnabled bool
	requestNotifyCache   [maxCachedRequestNotify]*statistic.TrackerInfo
	requestNotifyStart   int
	requestNotifyLen     int
)

const (
	maxCachedLogNotify     = 100
	maxCachedRequestNotify = 100
)

type StampedLogEvent struct {
	LogLevel log.LogLevel
	Payload  string
	Time     int64
}

func handleInitClash(params *InitParams) bool {
	configMu.Lock()
	defer configMu.Unlock()
	sdkVersion.Store(int32(params.Version))
	constant.SetHomeDir(params.HomeDir)
	constant.Path.MMDB()
	constant.Path.ASN()
	constant.Path.GeoIP()
	constant.Path.GeoSite()
	initOwnership(params.HomeDir)
	isInit.Store(true)
	return true
}

func handleStartListener() bool {
	configMu.Lock()
	defer configMu.Unlock()
	isRunning.Store(true)
	updateListeners(currentConfig)
	resolver.ResetConnection()
	return true
}

func handleStopListener() bool {
	configMu.Lock()
	defer configMu.Unlock()
	isRunning.Store(false)
	listener.StopListener()
	resolver.ResetConnection()
	return true
}

func handleGetIsInit() bool {
	return isInit.Load()
}

func handleForceGC() {
	log.Infoln("[APP] request force GC")
	tunnel.InvalidateAllProxies()
	runtime.GC()
	if features.Android {
		debug.FreeOSMemory()
	}
}

func handleShutdown() bool {
	handleStopLog()

	configMu.Lock()
	isRunning.Store(false)
	listener.StopListener()
	updater.StopGeoUpdater()
	executor.Shutdown()
	currentConfig = nil
	isInit.Store(false)
	configMu.Unlock()

	handleForceGC()
	return true
}

func handleValidateConfig(data string) string {
	if _, err := config.UnmarshalRawConfig([]byte(data)); err != nil {
		return err.Error()
	}
	return ""
}

func handleDecryptAgeConfig(params *DecryptAgeConfigParams) (string, error) {
	decrypted, err := age.DecryptBytes([]byte(params.Data), params.AgeSecretKey)
	if err != nil {
		return "", err
	}
	return string(decrypted), nil
}

const globalProxyName = "GLOBAL"

func isProxyGroupType(adapterType constant.AdapterType) bool {
	switch adapterType {
	case constant.Selector, constant.URLTest, constant.Fallback, constant.Relay, constant.LoadBalance:
		return true
	default:
		return false
	}
}

func proxyGroupNames(
	nameList []string,
	typeOf func(name string) (constant.AdapterType, bool),
) []string {
	hasGlobal := false
	names := make([]string, 0, len(nameList)+1)

	for _, name := range nameList {
		if name == globalProxyName {
			hasGlobal = true
		}
		adapterType, ok := typeOf(name)
		if !ok || !isProxyGroupType(adapterType) {
			continue
		}
		names = append(names, name)
	}

	if !hasGlobal {
		if adapterType, ok := typeOf(globalProxyName); ok && isProxyGroupType(adapterType) {
			names = append([]string{globalProxyName}, names...)
		}
	}

	return names
}

func handleGetProxies() ProxiesData {
	proxies := tunnel.AllProxies()

	allNames := proxyGroupNames(config.GetProxyNameList(), func(name string) (constant.AdapterType, bool) {
		p, ok := proxies[name]
		if !ok || p == nil {
			return 0, false
		}
		return p.Type(), true
	})

	return ProxiesData{
		All:     allNames,
		Proxies: proxies,
	}
}

var (
	errGroupNotFound    = errors.New("Not found group")
	errGroupInvalidType = errors.New("Group has invalid proxy type")
	errGroupNotSelect   = errors.New("Group is not selectable")
)

func lookupProxy(name string) constant.Proxy {
	return tunnel.AllProxies()[name]
}

func selectableGroup(groupName string) (outboundgroup.SelectAble, error) {
	group := lookupProxy(groupName)
	if group == nil {
		return nil, errGroupNotFound
	}
	adapterProxy, ok := group.(*adapter.Proxy)
	if !ok {
		return nil, errGroupInvalidType
	}
	selector, ok := adapterProxy.ProxyAdapter.(outboundgroup.SelectAble)
	if !ok {
		return nil, errGroupNotSelect
	}
	return selector, nil
}

func handleChangeProxy(params *ChangeProxyParams) string {
	selectMu.Lock()
	defer selectMu.Unlock()

	selector, err := selectableGroup(params.GroupName)
	if err != nil {
		return err.Error()
	}
	if params.ProxyName == "" {
		selector.ForceSet(params.ProxyName)
		return ""
	}
	if err := selector.Set(params.ProxyName); err != nil {
		return err.Error()
	}
	return ""
}

func handleGetTraffic(onlyStatisticsProxy bool) Traffic {
	up, down := statistic.DefaultManager.NowTraffic(onlyStatisticsProxy)
	return Traffic{
		Up:   up,
		Down: down,
	}
}

func handleGetTotalTraffic(onlyStatisticsProxy bool) Traffic {
	up, down := statistic.DefaultManager.TotalTraffic(onlyStatisticsProxy)
	return Traffic{
		Up:   up,
		Down: down,
	}
}

func handleResetTraffic() {
	statistic.DefaultManager.ResetStatistic()
}

func delayValue(delay uint16) int32 {
	if delay == 0 {
		return -1
	}
	return int32(delay)
}

var anyDelayTestStatus utils.IntRanges[uint16]

func delayTestTimeout(milliseconds int64) time.Duration {
	if milliseconds <= 0 {
		return defaultDelayTestTimeout
	}
	return time.Duration(milliseconds) * time.Millisecond
}

var missingDelayTestProxyAt atomic.Int64

// A delay test against a name the tunnel does not know is what an apply that
// fell back to the default config looks like from the outside: the profile
// still lists every node and every one of them reports Timeout. Say so, once a
// second rather than once per node, so the log names the real failure.
func reportMissingDelayTestProxy(name string) {
	now := time.Now().UnixNano()
	last := missingDelayTestProxyAt.Load()
	if last != 0 && now-last < int64(time.Second) {
		return
	}
	if !missingDelayTestProxyAt.CompareAndSwap(last, now) {
		return
	}
	logError("delay test: %q is not part of the applied config", name)
}

func handleTestDelay(params *TestDelayParams) *Delay {
	url := params.TestUrl
	if url == "" {
		url = currentTestURL()
	}
	delayData := &Delay{
		Name:  params.ProxyName,
		Url:   url,
		Value: -1,
	}

	proxy := lookupProxy(params.ProxyName)
	if proxy == nil {
		reportMissingDelayTestProxy(params.ProxyName)
		return delayData
	}

	timeout := delayTestTimeout(params.Timeout)

	// Queueing for a slot and probing the node each get the full timeout.
	// Sharing one deadline meant a node that waited four seconds behind a
	// saturated semaphore had one second left to connect, so a bulk test of a
	// large subscription reported Timeout for whatever happened to be at the
	// back of the queue.
	queueCtx, cancelQueue := context.WithTimeout(context.Background(), timeout)
	granted := acquireDelayTestSlot(queueCtx)
	cancelQueue()
	if !granted {
		return nil
	}
	defer releaseDelayTestSlot()

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	delay, err := proxy.URLTest(ctx, url, anyDelayTestStatus)
	if err != nil {
		return delayData
	}

	delayData.Value = delayValue(delay)
	return delayData
}

func handleGetConnections() *statistic.Snapshot {
	return statistic.DefaultManager.Snapshot()
}

func handleCloseConnections() bool {
	statistic.DefaultManager.Range(func(c statistic.Tracker) bool {
		_ = c.Close()
		return true
	})
	return true
}

func handleResetConnections() bool {
	resolver.ResetConnection()
	return true
}

func handleCloseConnection(connectionId string) bool {
	c := statistic.DefaultManager.Get(connectionId)
	if c == nil {
		return false
	}
	_ = c.Close()
	return true
}

func handleGetExternalProviders() []ExternalProvider {
	providers := externalProviders()
	eps := make([]ExternalProvider, 0, len(providers))
	for _, p := range providers {
		externalProvider, err := toExternalProvider(p)
		if err != nil {
			continue
		}
		eps = append(eps, *externalProvider)
	}
	slices.SortFunc(eps, func(a, b ExternalProvider) int {
		return cmp.Compare(a.Name, b.Name)
	})
	return eps
}

func handleGetExternalProvider(externalProviderName string) *ExternalProvider {
	p, exist := lookupExternalProvider(externalProviderName)
	if !exist {
		return nil
	}
	externalProvider, err := toExternalProvider(p)
	if err != nil {
		return nil
	}
	return externalProvider
}

var geoResourceUpdaters = map[string]func() error{
	"MMDB":    updater.UpdateMMDB,
	"ASN":     updater.UpdateASN,
	"GEOIP":   updater.UpdateGeoIp,
	"GEOSITE": updater.UpdateGeoSite,
}

const (
	geoUpdateScope      = "geo:"
	providerUpdateScope = "provider:"
)

var (
	updateMu       sync.Mutex
	updateInFlight = map[string]bool{}
	geoHookClaims  = map[string]bool{}
)

func claimUpdate(key string) bool {
	updateMu.Lock()
	defer updateMu.Unlock()
	if updateInFlight[key] {
		return false
	}
	updateInFlight[key] = true
	return true
}

func releaseUpdate(key string) {
	updateMu.Lock()
	defer updateMu.Unlock()
	delete(updateInFlight, key)
	delete(geoHookClaims, key)
}

func claimGeoUpdate(geoType string) bool {
	return claimUpdate(geoUpdateScope + geoType)
}

func releaseGeoUpdate(geoType string) {
	releaseUpdate(geoUpdateScope + geoType)
}

func claimGeoUpdateFromHook(geoType string) {
	key := geoUpdateScope + geoType
	updateMu.Lock()
	defer updateMu.Unlock()
	if updateInFlight[key] {
		return
	}
	updateInFlight[key] = true
	geoHookClaims[key] = true
}

func releaseGeoUpdateFromHook(geoType string) {
	key := geoUpdateScope + geoType
	updateMu.Lock()
	defer updateMu.Unlock()
	if !geoHookClaims[key] {
		return
	}
	delete(geoHookClaims, key)
	delete(updateInFlight, key)
}

func handleUpdateGeoData(geoType string) string {
	update, exist := geoResourceUpdaters[geoType]
	if !exist {
		logError("updateGeoData: unknown geo resource %q", geoType)
		return "unknown geo resource: " + geoType
	}
	if !claimGeoUpdate(geoType) {
		return ""
	}
	safeGoDetached("updateGeoData("+geoType+")", func() {
		defer releaseGeoUpdate(geoType)
		if err := update(); err != nil {
			logError("updateGeoData(%s) error: %v", geoType, err)
		}
	})
	return ""
}

func providerRequestErrorCode(err error) string {
	message := err.Error()
	if len(message) >= 4 && message[3] == ' ' {
		status, parseErr := strconv.Atoi(message[:3])
		if parseErr == nil && status >= 100 && status <= 599 {
			return "request_bad_response"
		}
	}
	var urlError *url.Error
	var networkError net.Error
	if errors.Is(err, context.DeadlineExceeded) ||
		errors.As(err, &urlError) ||
		errors.As(err, &networkError) {
		return "request_error"
	}
	return ""
}

func providerMethodError(code, providerName string, err error) *MethodError {
	return &MethodError{
		Code:    code,
		Message: err.Error(),
		Details: map[string]any{"providerName": providerName},
	}
}

func handleUpdateExternalProvider(providerName string) *MethodError {
	p, exist := lookupExternalProvider(providerName)
	if !exist {
		return providerMethodError(
			"provider_not_found",
			providerName,
			errors.New("external provider does not exist"),
		)
	}
	key := providerUpdateScope + providerName
	if !claimUpdate(key) {
		return providerMethodError(
			"provider_updating",
			providerName,
			errors.New("external provider is updating"),
		)
	}
	defer releaseUpdate(key)
	if err := p.Update(); err != nil {
		code := providerRequestErrorCode(err)
		if code == "" {
			code = "provider_update_error"
		}
		return providerMethodError(code, providerName, err)
	}
	return nil
}

func handleSideLoadExternalProvider(providerName string, data []byte) *MethodError {
	p, exist := lookupExternalProvider(providerName)
	if !exist {
		return providerMethodError(
			"provider_not_found",
			providerName,
			errors.New("external provider does not exist"),
		)
	}
	key := providerUpdateScope + providerName
	if !claimUpdate(key) {
		return providerMethodError(
			"provider_updating",
			providerName,
			errors.New("external provider is updating"),
		)
	}
	defer releaseUpdate(key)
	if err := sideUpdateExternalProvider(p, data); err != nil {
		return providerMethodError("provider_update_error", providerName, err)
	}
	return nil
}

// defaultRefreshHealthChecks re-probes every proxy provider off the calling
// thread. Providers coalesce concurrent checks internally, so an extra call
// costs nothing when one is already running.
func defaultRefreshHealthChecks() {
	safeGoDetached("refreshHealthChecks", func() {
		for name, p := range tunnel.ProvidersSnapshot() {
			log.Debugln("[APP] re-checking provider %s after resume", name)
			p.HealthCheck()
		}
	})
}

var refreshHealthChecks = defaultRefreshHealthChecks

func handleSuspend(suspended bool) bool {
	wasSuspended := isSuspended.Swap(suspended)
	if suspended {
		tunnel.OnSuspend()
		return true
	}

	tunnel.OnRunning()
	// Provider health checks keep ticking through Doze, where the app has no
	// network at all, so coming back means every proxy is marked dead and every
	// delay reads Timeout. A lazy provider then skips its next tick because
	// nothing touched it in the meantime, and the whole list stays wrong until
	// the user tests by hand. Re-check now instead - but not while the
	// listeners are stopped, since the service also resumes the core on its way
	// down.
	if wasSuspended && isRunning.Load() {
		refreshHealthChecks()
	}
	return true
}

// shouldPublishDelay reports whether a probe result is worth showing.
//
// A failure measured while the device is dozing says nothing about the node -
// the app had no network at all - and publishing it repaints the entire list as
// Timeout for a user who is not even looking. Successes still are worth having,
// whenever they happen.
func shouldPublishDelay(delay uint16) bool {
	return delay != 0 || !isSuspended.Load()
}

func startLogLocked() {
	ctx, cancel := context.WithCancel(context.Background())
	subscriber := log.Subscribe()
	logSubscriber = subscriber
	logCancel = cancel

	go func() {
		defer func() {
			logMu.Lock()
			if logSubscriber == subscriber {
				log.UnSubscribe(subscriber)
				logSubscriber = nil
				logCancel = nil
			}
			logMu.Unlock()
		}()
		for {
			select {
			case <-ctx.Done():
				return
			case logData, ok := <-subscriber:
				if !ok {
					return
				}
				if logData.LogLevel < log.Level() {
					continue
				}
				stampedLog := StampedLogEvent{
					LogLevel: logData.LogLevel,
					Payload:  logData.Payload,
					Time:     time.Now().UnixMilli(),
				}
				logNotifyMu.Lock()
				if !logNotifyEnabled {
					cacheLog(stampedLog)
					logNotifyMu.Unlock()
					continue
				}
				logNotifyMu.Unlock()
				sendMessage(Message{
					Type: LogMessage,
					Data: stampedLog,
				})
			}
		}
	}()
}

func handleStartLog() {
	logMu.Lock()
	if logCancel != nil {
		logCancel()
		logCancel = nil
	}
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
	startLogLocked()
	logMu.Unlock()
}

func ensureLogStarted() {
	logMu.Lock()
	defer logMu.Unlock()
	if logSubscriber != nil {
		return
	}
	startLogLocked()
}

func handleStopLog() {
	logMu.Lock()
	defer logMu.Unlock()
	if logCancel != nil {
		logCancel()
		logCancel = nil
	}
	if logSubscriber != nil {
		log.UnSubscribe(logSubscriber)
		logSubscriber = nil
	}
}

func handleStartLogNotify() []StampedLogEvent {
	ensureLogStarted()
	logNotifyMu.Lock()
	defer logNotifyMu.Unlock()
	logs := make([]StampedLogEvent, logNotifyLen)
	for i := 0; i < logNotifyLen; i++ {
		index := (logNotifyStart + i) % maxCachedLogNotify
		logs[i] = logNotifyCache[index]
	}
	logNotifyStart = 0
	logNotifyLen = 0
	logNotifyEnabled = true
	return logs
}

func handleStopLogNotify() {
	logNotifyMu.Lock()
	defer logNotifyMu.Unlock()
	logNotifyEnabled = false
}

func cacheLog(logData StampedLogEvent) {
	if logNotifyLen < maxCachedLogNotify {
		index := (logNotifyStart + logNotifyLen) % maxCachedLogNotify
		logNotifyCache[index] = logData
		logNotifyLen++
		return
	}
	logNotifyCache[logNotifyStart] = logData
	logNotifyStart = (logNotifyStart + 1) % maxCachedLogNotify
}

func handleStartRequestNotify() []*statistic.TrackerInfo {
	requestNotifyMu.Lock()
	defer requestNotifyMu.Unlock()
	requests := make([]*statistic.TrackerInfo, requestNotifyLen)
	for i := 0; i < requestNotifyLen; i++ {
		index := (requestNotifyStart + i) % maxCachedRequestNotify
		requests[i] = requestNotifyCache[index]
		requestNotifyCache[index] = nil
	}
	requestNotifyStart = 0
	requestNotifyLen = 0
	requestNotifyEnabled = true
	return requests
}

func handleStopRequestNotify() {
	requestNotifyMu.Lock()
	defer requestNotifyMu.Unlock()
	requestNotifyEnabled = false
}

func handleGetMemory() uint64 {
	var memStats runtime.MemStats
	runtime.ReadMemStats(&memStats)
	return memStats.StackInuse + memStats.HeapInuse + memStats.HeapIdle - memStats.HeapReleased
}

func handleGetGoroutineCount() int {
	return runtime.NumGoroutine()
}

func managedPathComponents(scope ManagedPathScope) ([]string, error) {
	switch scope {
	case profilesPathScope:
		return []string{"profiles"}, nil
	case providersPathScope:
		return []string{"profiles", "providers"}, nil
	case scriptsPathScope:
		return []string{"scripts"}, nil
	default:
		return nil, fmt.Errorf("invalid managed path scope: %s", scope)
	}
}

func resolveManagedPath(relativePath string) (string, error) {
	if relativePath == "" || relativePath == "." || !filepath.IsLocal(relativePath) {
		return "", fmt.Errorf("invalid managed relative path: %s", relativePath)
	}
	cleanPath := filepath.Clean(relativePath)
	if cleanPath == "." || !filepath.IsLocal(cleanPath) {
		return "", fmt.Errorf("invalid managed relative path: %s", relativePath)
	}
	return cleanPath, nil
}

func openManagedRoot(scope ManagedPathScope) (*os.Root, error) {
	components, err := managedPathComponents(scope)
	if err != nil {
		return nil, err
	}
	root, err := os.OpenRoot(constant.Path.HomeDir())
	if err != nil {
		return nil, err
	}
	for _, component := range components {
		nextRoot, err := root.OpenRoot(component)
		if err != nil {
			_ = root.Close()
			return nil, err
		}
		openedInfo, err := nextRoot.Stat(".")
		if err != nil {
			_ = nextRoot.Close()
			_ = root.Close()
			return nil, err
		}
		pathInfo, err := root.Lstat(component)
		if err != nil {
			_ = nextRoot.Close()
			_ = root.Close()
			return nil, err
		}
		if !pathInfo.IsDir() || pathInfo.Mode()&os.ModeSymlink != 0 || !os.SameFile(openedInfo, pathInfo) {
			_ = nextRoot.Close()
			_ = root.Close()
			return nil, fmt.Errorf("managed path scope is not a stable directory: %s", scope)
		}
		_ = root.Close()
		root = nextRoot
	}
	return root, nil
}

func readManagedConfig(root *os.Root, path string) ([]byte, error) {
	file, err := root.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	fileInfo, err := file.Stat()
	if err != nil {
		return nil, err
	}
	if !fileInfo.Mode().IsRegular() {
		return nil, fmt.Errorf("config is not a regular file")
	}
	return io.ReadAll(file)
}

func handleGetProfileConfig(profileID int64) (*config.RawConfig, error) {
	if !isInit.Load() {
		return nil, fmt.Errorf("not initialized")
	}
	if profileID <= 0 {
		return nil, fmt.Errorf("invalid profile id: %d", profileID)
	}
	path, err := resolveManagedPath(strconv.FormatInt(profileID, 10) + ".yaml")
	if err != nil {
		return nil, err
	}
	root, err := openManagedRoot(profilesPathScope)
	if err != nil {
		return nil, err
	}
	defer root.Close()
	data, err := readManagedConfig(root, path)
	if err != nil {
		return nil, err
	}
	return config.UnmarshalRawConfig(data)
}

func handleCrash() {
	panic("handle invoke crash")
}

func handleUpdateConfig(params *UpdateParams) string {
	if err := updateConfig(params); err != nil {
		return err.Error()
	}
	return ""
}

func handleClearEffect(profileId int64) string {
	if profileId <= 0 {
		return "invalid profile id"
	}
	return handleDeleteManagedPath(&DeleteManagedPathParams{
		Scope:        providersPathScope,
		RelativePath: strconv.FormatInt(profileId, 10),
	})
}

func handleDeleteManagedPath(params *DeleteManagedPathParams) string {
	if !isInit.Load() {
		return "not initialized"
	}
	path, err := resolveManagedPath(params.RelativePath)
	if err != nil {
		return err.Error()
	}
	root, err := openManagedRoot(params.Scope)
	if err != nil {
		if os.IsNotExist(err) {
			return ""
		}
		return err.Error()
	}
	defer root.Close()
	if err := root.RemoveAll(path); err != nil {
		return err.Error()
	}
	return ""
}

var setupConfig = applyConfig

func handleSetupConfig(params *SetupParams) string {
	if !isInit.Load() {
		return "not initialized"
	}
	if err := setupConfig(params); err != nil {
		return err.Error()
	}
	return ""
}

func init() {
	adapter.UrlTestHook = func(url string, name string, delay uint16) {
		if !shouldPublishDelay(delay) {
			return
		}
		sendMessage(Message{
			Type: DelayMessage,
			Data: &Delay{
				Url:   url,
				Name:  name,
				Value: delayValue(delay),
			},
		})
	}
	statistic.DefaultRequestNotify = func(c statistic.Tracker) {
		requestNotifyMu.Lock()
		if !requestNotifyEnabled {
			request := c.Info()
			if requestNotifyLen < maxCachedRequestNotify {
				index := (requestNotifyStart + requestNotifyLen) % maxCachedRequestNotify
				requestNotifyCache[index] = request
				requestNotifyLen++
			} else {
				requestNotifyCache[requestNotifyStart] = request
				requestNotifyStart = (requestNotifyStart + 1) % maxCachedRequestNotify
			}
			requestNotifyMu.Unlock()
			return
		}
		requestNotifyMu.Unlock()
		sendMessage(Message{
			Type: RequestMessage,
			Data: c,
		})
	}
	executor.DefaultProviderLoadedHook = func(providerName string) {
		scheduleReclaimOwnership()
		sendMessage(Message{
			Type: LoadedMessage,
			Data: providerName,
		})
	}
	updater.GeoUpdateHook = func(geoType string, updating bool, skipped bool, updateErr error) {
		if updating {
			claimGeoUpdateFromHook(geoType)
		} else {
			releaseGeoUpdateFromHook(geoType)
			scheduleReclaimOwnership()
		}
		status := GeoUpdateStatus{
			Type:     geoType,
			Updating: updating,
			Skipped:  skipped,
		}
		if updateErr != nil {
			status.Error = updateErr.Error()
		}
		sendMessage(Message{
			Type: GeoUpdateMessage,
			Data: status,
		})
	}
}
