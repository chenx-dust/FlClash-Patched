import Flutter
import Foundation

final class ServiceChannel {
  private static var instance: ServiceChannel?

  private let packageName = "com.follow.clash"
  private let channel: FlutterMethodChannel
  private let tileChannel: FlutterMethodChannel
  private let sharedStateStore = SharedStateStore()

  private lazy var tunnelController = TunnelController(
    sharedStateStore: sharedStateStore,
    onExternalStart: { [weak self] in
      self?.tileChannel.invokeMethod("start", arguments: nil)
    },
    onExternalStop: { [weak self] in
      self?.tileChannel.invokeMethod("stop", arguments: nil)
    }
  )

  private lazy var coreEventRelay = CoreEventRelay(
    sharedStateStore: sharedStateStore,
    sendEvent: { [weak self] event, completion in
      guard let self else {
        completion(false)
        return
      }
      self.channel.invokeMethod("event", arguments: event) { callbackResult in
        completion(callbackResult == nil)
      }
    }
  )

  private func log(_ message: String) {
    NSLog("[ServiceChannel] %@", message)
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    instance = ServiceChannel(messenger: messenger)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "\(packageName)/service",
      binaryMessenger: messenger
    )
    tileChannel = FlutterMethodChannel(
      name: "\(packageName)/tile",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler(handle)
    coreEventRelay.start()
    tunnelController.startObserving()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("handle method=\(call.method)")
    switch call.method {
    case "invokeMethod", "invokeAppCore":
      guard let data = methodCallData(call) else {
        result(methodErrorResponse(
          data: nil,
          code: "invalid_method_call",
          message: "invalid method call"
        ))
        return
      }
      invokeAppCore(data, result: result)
    case "invokeNetworkExtensionCore":
      guard let data = methodCallData(call) else {
        result(methodErrorResponse(
          data: nil,
          code: "invalid_method_call",
          message: "invalid method call"
        ))
        return
      }
      invokeNetworkExtensionCore(data, result: result)
    case "start":
      tunnelController.start { success in
        result(success)
      }
    case "stop":
      tunnelController.stop { success in
        result(success)
      }
    case "init":
      coreEventRelay.drainEventQueue()
      result("")
    case "syncState":
      syncState(call, result: result)
    case "shutdown":
      tunnelController.stop { success in
        result(success)
      }
    case "getAppGroupDir":
      result(sharedStateStore.appGroupDirectory()?.path ?? "")
    case "getRunTime":
      tunnelController.getRunTime { runTime in
        result(runTime)
      }
    case "isNetworkExtensionCoreActive":
      tunnelController.isCoreActive { active in
        result(active)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func methodCallData(_ call: FlutterMethodCall) -> Data? {
    guard let message = call.arguments as? String else {
      return nil
    }
    return message.data(using: .utf8)
  }

  private func syncState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let data = methodCallData(call),
          sharedStateStore.saveSharedState(data) else {
      log("syncState failed")
      result("failed to sync shared state")
      return
    }
    log("syncState saved bytes=\(data.count)")
    tunnelController.reloadOnDemandRules()
    result("")
  }

  private func invokeAppCore(
    _ data: Data,
    result: @escaping FlutterResult
  ) {
    guard let methodCall = String(data: data, encoding: .utf8) else {
      log("invokeAppCore invalid method call")
      result(methodErrorResponse(
        data: data,
        code: "invalid_method_call",
        message: "invalid method call"
      ))
      return
    }
    log("invokeAppCore")
    coreEventRelay.invokeAppCore(methodCall) { response in
      guard let response else {
        self.log("invokeAppCore empty response")
        result(self.methodErrorResponse(
          data: data,
          code: "empty_response",
          message: "empty app core response"
        ))
        return
      }
      self.log("invokeAppCore response received")
      result(response)
    }
  }

  private func invokeNetworkExtensionCore(
    _ data: Data,
    result: @escaping FlutterResult
  ) {
    tunnelController.sendProviderMessage(data) { response, error in
      if let error {
        result(self.methodErrorResponse(
          data: data,
          code: error.code,
          message: error.message
        ))
        return
      }
      guard let response else {
        result(self.methodErrorResponse(
          data: data,
          code: "empty_response",
          message: "empty network extension response"
        ))
        return
      }
      result(response)
    }
  }

  private func methodCallID(_ data: Data?) -> String? {
    guard let data,
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return object["id"] as? String
  }

  private func methodErrorResponse(
    data: Data?,
    code: String,
    message: String
  ) -> String {
    var payload: [String: Any] = [
      "result": NSNull(),
      "error": [
        "code": code,
        "message": message,
        "details": NSNull(),
      ],
    ]
    if let id = methodCallID(data) {
      payload["id"] = id
    }

    guard let responseData = try? JSONSerialization.data(withJSONObject: payload),
          let response = String(data: responseData, encoding: .utf8) else {
      return #"{"result":null,"error":{"code":"serialization_error","message":"failed to serialize method response","details":null}}"#
    }
    return response
  }
}
