package main

import (
	"encoding/json"
	"fmt"
	"runtime"
	"sync/atomic"
	"unsafe"

	"github.com/metacubex/mihomo/component/age"
)

type MethodCall struct {
	ID        string          `json:"id,omitempty"`
	Method    CoreMethod      `json:"method"`
	Arguments json.RawMessage `json:"arguments"`
}

func (call MethodCall) decodeArguments(target any) error {
	if len(call.Arguments) == 0 || string(call.Arguments) == "null" {
		return fmt.Errorf("missing arguments")
	}
	return json.Unmarshal(call.Arguments, target)
}

func decodeMethodArguments(call *MethodCall, response MethodResponse, target any) bool {
	if err := call.decodeArguments(target); err != nil {
		response.failure(
			"invalid_arguments",
			fmt.Sprintf("invalid arguments for %s: %v", call.Method, err),
			nil,
		)
		return false
	}
	return true
}

type MethodError struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Details any    `json:"details"`
}

type MethodResponse struct {
	ID       string       `json:"id,omitempty"`
	Result   any          `json:"result"`
	Error    *MethodError `json:"error,omitempty"`
	callback unsafe.Pointer
	sent     *atomic.Bool
}

func newMethodResponse(id string, callback unsafe.Pointer) MethodResponse {
	return MethodResponse{
		ID:       id,
		callback: callback,
		sent:     &atomic.Bool{},
	}
}

func (response MethodResponse) JSON() ([]byte, error) {
	return json.Marshal(response)
}

func (response MethodResponse) claim() bool {
	if response.sent == nil {
		return true
	}
	return response.sent.CompareAndSwap(false, true)
}

func (response MethodResponse) success(result any) {
	if !response.claim() {
		return
	}
	response.Result = result
	response.Error = nil
	response.send()
}

func (response MethodResponse) failure(code, message string, details any) {
	if !response.claim() {
		return
	}
	response.Result = nil
	response.Error = &MethodError{
		Code:    code,
		Message: message,
		Details: details,
	}
	response.send()
}

func (response MethodResponse) notImplemented(method CoreMethod) {
	response.failure(
		"not_implemented",
		fmt.Sprintf("unknown method: %s", method),
		nil,
	)
}

func stackTrace() []byte {
	buf := make([]byte, 4096)
	return buf[:runtime.Stack(buf, false)]
}

func safeGo(response MethodResponse, run func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logError("panic in async handler: %v\n%s", r, stackTrace())
				response.failure("internal_error", fmt.Sprintf("internal panic: %v", r), nil)
			}
		}()
		run()
	}()
}

func safeGoDetached(name string, run func()) {
	go func() {
		defer func() {
			if r := recover(); r != nil {
				logError("panic in %s: %v\n%s", name, r, stackTrace())
			}
		}()
		run()
	}()
}

type methodHandler func(call *MethodCall, response MethodResponse)

func withArguments[T any](handle func(params *T, response MethodResponse)) methodHandler {
	return func(call *MethodCall, response MethodResponse) {
		var params T
		if !decodeMethodArguments(call, response, &params) {
			return
		}
		handle(&params, response)
	}
}

func withDefaults[T any](
	defaults func() *T,
	handle func(params *T, response MethodResponse),
) methodHandler {
	return func(call *MethodCall, response MethodResponse) {
		params := defaults()
		if !decodeMethodArguments(call, response, params) {
			return
		}
		handle(params, response)
	}
}

func withoutArguments(handle func(response MethodResponse)) methodHandler {
	return func(_ *MethodCall, response MethodResponse) {
		handle(response)
	}
}

var methodHandlers = map[CoreMethod]methodHandler{
	initClashMethod: withArguments(func(params *InitParams, response MethodResponse) {
		response.success(handleInitClash(params))
	}),
	getIsInitMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetIsInit())
	}),
	forceGcMethod: withoutArguments(func(response MethodResponse) {
		handleForceGC()
		response.success(true)
	}),
	shutdownMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleShutdown())
	}),
	validateConfigMethod: withArguments(func(data *string, response MethodResponse) {
		response.success(handleValidateConfig(*data))
	}),
	decryptAgeConfigMethod: withArguments(func(params *DecryptAgeConfigParams, response MethodResponse) {
		response.success(handleDecryptAgeConfig(params))
	}),
	updateConfigMethod: withArguments(func(params *UpdateParams, response MethodResponse) {
		response.success(handleUpdateConfig(params))
	}),
	setupConfigMethod: withDefaults(defaultSetupParams, func(params *SetupParams, response MethodResponse) {
		response.success(handleSetupConfig(params))
	}),
	getProfileConfigMethod: withArguments(func(profileID *int64, response MethodResponse) {
		rawConfig, err := handleGetProfileConfig(*profileID)
		if err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		response.success(rawConfig)
	}),
	getProxiesMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetProxies())
	}),
	changeProxyMethod: withArguments(func(params *ChangeProxyParams, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleChangeProxy(params))
		})
	}),
	getTrafficMethod: withArguments(func(onlyStatisticsProxy *bool, response MethodResponse) {
		response.success(handleGetTraffic(*onlyStatisticsProxy))
	}),
	getTotalTrafficMethod: withArguments(func(onlyStatisticsProxy *bool, response MethodResponse) {
		response.success(handleGetTotalTraffic(*onlyStatisticsProxy))
	}),
	resetTrafficMethod: withoutArguments(func(response MethodResponse) {
		handleResetTraffic()
		response.success(true)
	}),
	asyncTestDelayMethod: withArguments(func(params *TestDelayParams, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleTestDelay(params))
		})
	}),
	getConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetConnections())
	}),
	closeConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleCloseConnections())
	}),
	resetConnectionsMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleResetConnections())
	}),
	closeConnectionMethod: withArguments(func(id *string, response MethodResponse) {
		response.success(handleCloseConnection(*id))
	}),
	getExternalProvidersMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetExternalProviders())
	}),
	getExternalProviderMethod: withArguments(func(name *string, response MethodResponse) {
		response.success(handleGetExternalProvider(*name))
	}),
	getOverlayNetworkStatusMethod: withArguments(func(params *GetOverlayNetworkStatusParams, response MethodResponse) {
		response.success(handleGetOverlayNetworkStatus(params))
	}),
	activateOverlayNetworkMethod: withArguments(func(params *ActivateOverlayNetworkParams, response MethodResponse) {
		response.success(handleActivateOverlayNetwork(params))
	}),
	pingTailscaleNodeMethod: withArguments(func(params *TailscalePingParams, response MethodResponse) {
		result, err := handlePingTailscaleNode(params)
		if err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		response.success(result)
	}),
	logoutTailscaleMethod: withArguments(func(params *TailscaleLogoutParams, response MethodResponse) {
		if err := handleLogoutTailscale(params); err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		response.success(true)
	}),
	updateExternalProviderMethod: withArguments(func(name *string, response MethodResponse) {
		safeGo(response, func() {
			if err := handleUpdateExternalProvider(*name); err != nil {
				response.failure(err.Code, err.Message, err.Details)
				return
			}
			response.success("")
		})
	}),
	sideLoadExternalProviderMethod: withArguments(func(params *SideLoadParams, response MethodResponse) {
		safeGo(response, func() {
			if err := handleSideLoadExternalProvider(params.ProviderName, []byte(params.Data)); err != nil {
				response.failure(err.Code, err.Message, err.Details)
				return
			}
			response.success("")
		})
	}),
	updateGeoDataMethod: withArguments(func(geoType *string, response MethodResponse) {
		response.success(handleUpdateGeoData(*geoType))
	}),
	startLogNotifyMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStartLogNotify())
	}),
	stopLogNotifyMethod: withoutArguments(func(response MethodResponse) {
		handleStopLogNotify()
		response.success(true)
	}),
	startRequestNotifyMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStartRequestNotify())
	}),
	stopRequestNotifyMethod: withoutArguments(func(response MethodResponse) {
		handleStopRequestNotify()
		response.success(true)
	}),
	startListenerMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStartListener())
	}),
	stopListenerMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleStopListener())
	}),
	getMemoryMethod: withoutArguments(func(response MethodResponse) {
		safeGo(response, func() {
			response.success(handleGetMemory())
		})
	}),
	getGoroutineCountMethod: withoutArguments(func(response MethodResponse) {
		response.success(handleGetGoroutineCount())
	}),
	clearEffectMethod: withArguments(func(profileId *int64, response MethodResponse) {
		safeGo(response, func() {
			response.success(handleClearEffect(*profileId))
		})
	}),
	deleteManagedPathMethod: withArguments(func(params *DeleteManagedPathParams, response MethodResponse) {
		response.success(handleDeleteManagedPath(params))
	}),
	generateAgeKeyPairMethod: withoutArguments(func(response MethodResponse) {
		secretKey, publicKey, err := age.GenX25519KeyPair()
		if err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		response.success(map[string]string{
			"secret-key": secretKey,
			"public-key": publicKey,
		})
	}),
	convertAgeSecretKeyToPublicKeyMethod: withArguments(func(secretKey *string, response MethodResponse) {
		publicKeys, err := age.ToPublicKeys(*secretKey)
		if err != nil {
			response.failure("core_error", err.Error(), nil)
			return
		}
		if len(publicKeys) == 0 {
			response.failure("core_error", "no public keys found", nil)
			return
		}
		response.success(publicKeys[0])
	}),
}

func registerMethod(method CoreMethod, handler methodHandler) {
	if _, exists := methodHandlers[method]; exists {
		panic(fmt.Sprintf("duplicate handler for method %s", method))
	}
	methodHandlers[method] = handler
}

func handleMethodCall(call *MethodCall, response MethodResponse) {
	// The crash method is a developer-only fatal-path test. It must bypass the
	// recovery below so the core process terminates; on Android this also
	// terminates the in-process application.
	if call.Method == crashMethod {
		handleCrash()
		return
	}
	defer func() {
		if r := recover(); r != nil {
			logError("panic in handleMethodCall(%s): %v\n%s", call.Method, r, stackTrace())
			response.failure("internal_error", fmt.Sprintf("internal panic: %v", r), nil)
		}
	}()

	handler, exists := methodHandlers[call.Method]
	if !exists {
		response.notImplemented(call.Method)
		return
	}
	handler(call, response)
}
