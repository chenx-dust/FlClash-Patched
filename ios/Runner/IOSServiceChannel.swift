import Flutter
import Foundation
import NetworkExtension

final class IOSServiceChannel {
  private static var instance: IOSServiceChannel?

  private let channel: FlutterMethodChannel
  private let providerBundleIdentifier = "site.yinmo.clash.NECore"
  private let appGroupIdentifier = "group.site.yinmo.clash"
  private let sharedStateKey = "sharedState"
  private let localizedDescription = "FlClash"
  private let appCoreMethods: Set<String> = [
    "validateConfig",
    "asyncTestDelay",
    "getConfig",
    "generateAgeKeyPair",
    "convertAgeSecretKeyToPublicKey",
    "deleteFile",
  ]

  private func log(_ message: String) {
    NSLog("[IOSServiceChannel] %@", message)
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    instance = IOSServiceChannel(messenger: messenger)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.follow.clash/service",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("handle method=\(call.method)")
    switch call.method {
    case "invokeAction":
      guard let message = call.arguments as? String,
            let data = message.data(using: .utf8) else {
        result(actionResult(data: nil, message: "invalid action"))
        return
      }
      routeAction(data, result: result)
    case "start":
      startTunnel(result: result)
    case "stop":
      stopTunnel(result: result)
    case "init":
      result("")
    case "syncState":
      syncState(call, result: result)
    case "shutdown":
      stopTunnel(result: result)
    case "getRunTime":
      result(0)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadManager(
    createIfNeeded: Bool = true,
    completion: @escaping (NETunnelProviderManager?, Error?) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error = error {
        self.log("loadManager failed: \(error.localizedDescription)")
        completion(nil, error)
        return
      }

      if let manager = managers?.first(where: { manager in
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return proto.providerBundleIdentifier == self.providerBundleIdentifier
      }) {
        self.log("loadManager found existing manager status=\(self.statusDescription(manager.connection.status))")
        completion(manager, nil)
        return
      }

      if !createIfNeeded {
        self.log("loadManager manager not found")
        completion(nil, nil)
        return
      }

      self.log("loadManager create manager")
      let manager = NETunnelProviderManager()
      let proto = NETunnelProviderProtocol()
      proto.providerBundleIdentifier = self.providerBundleIdentifier
      proto.serverAddress = self.localizedDescription
      manager.protocolConfiguration = proto
      manager.localizedDescription = self.localizedDescription
      manager.isEnabled = true
      completion(manager, nil)
    }
  }

  private func startTunnel(result: @escaping FlutterResult) {
    startTunnelWithCompletion { isStarted in
      result(isStarted)
    }
  }

  private func startTunnelWithCompletion(completion: @escaping (Bool) -> Void) {
    log("startTunnelWithCompletion begin")
    stopAppCoreListener {
      self.log("app core listener stopped, start NECore")
      self.startTunnelAfterStoppingAppCore(completion: completion)
    }
  }

  private func startTunnelAfterStoppingAppCore(completion: @escaping (Bool) -> Void) {
    loadManager { manager, error in
      guard let manager = manager else {
        self.log("startTunnel failed: manager missing")
        completion(false)
        return
      }
      if let error = error {
        self.log("startTunnel failed: \(error.localizedDescription)")
        completion(false)
        return
      }

      manager.isEnabled = true
      self.log("startTunnel save preferences")
      manager.saveToPreferences { error in
        if let error = error {
          self.log("startTunnel save preferences failed: \(error.localizedDescription)")
          completion(false)
          return
        }
        self.log("startTunnel reload preferences")
        manager.loadFromPreferences { error in
          if let error = error {
            self.log("startTunnel reload preferences failed: \(error.localizedDescription)")
            completion(false)
            return
          }
          do {
            self.log("startTunnel startVPNTunnel currentStatus=\(self.statusDescription(manager.connection.status))")
            try manager.connection.startVPNTunnel()
            self.log("startTunnel startVPNTunnel requested")
            completion(true)
          } catch {
            self.log("startTunnel startVPNTunnel failed: \(error.localizedDescription)")
            completion(false)
          }
        }
      }
    }
  }

  private func stopAppCoreListener(completion: @escaping () -> Void) {
    log("stopAppCoreListener begin")
    let action: [String: Any] = [
      "id": "stopListener#ios",
      "method": "stopListener",
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: action),
          let message = String(data: data, encoding: .utf8) else {
      log("stopAppCoreListener serialize action failed")
      completion()
      return
    }
    IOSCoreBridge.invokeAction(message) { _ in
      self.log("stopAppCoreListener completed")
      completion()
    }
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    log("stopTunnel requested")
    loadManager { manager, _ in
      self.log("stopTunnel currentStatus=\(self.statusDescription(manager?.connection.status ?? .invalid))")
      manager?.connection.stopVPNTunnel()
      result(true)
    }
  }

  private func syncState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let message = call.arguments as? String,
          let data = message.data(using: .utf8),
          let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
      log("syncState failed")
      result("failed to sync shared state")
      return
    }
    userDefaults.set(data, forKey: sharedStateKey)
    userDefaults.synchronize()
    log("syncState saved bytes=\(data.count)")
    result("")
  }

  private func routeAction(_ data: Data, result: @escaping FlutterResult) {
    guard let action = actionInfo(data) else {
      log("routeAction invalid action")
      result(actionResult(data: data, message: "invalid action"))
      return
    }
    log("routeAction method=\(action.method) id=\(action.id ?? "")")

    if action.method == "startTun" {
      startTunnelWithCompletion { isStarted in
        result(self.actionResult(data: data, payload: isStarted, code: 0))
      }
      return
    }
    if action.method == "stopTun" {
      stopTunnel { _ in
        result(self.actionResult(data: data, payload: true, code: 0))
      }
      return
    }

    loadManager(createIfNeeded: false) { manager, error in
      if let error = error {
        result(self.actionResult(data: data, message: error.localizedDescription))
        return
      }

      let status = manager?.connection.status ?? .invalid
      self.log("routeAction status=\(self.statusDescription(status)) method=\(action.method)")
      if self.canSendProviderMessage(status: status) && !self.appCoreMethods.contains(action.method) {
        self.sendProviderMessage(data, result: result)
        return
      }

      self.invokeAppCore(data, status: status, result: result)
    }
  }

  private func sendProviderMessage(_ data: Data, result: @escaping FlutterResult) {
    loadManager(createIfNeeded: false) { manager, error in
      if let error = error {
        self.log("sendProviderMessage failed load manager: \(error.localizedDescription)")
        result(self.actionResult(data: data, message: error.localizedDescription))
        return
      }
      guard let session = manager?.connection as? NETunnelProviderSession else {
        self.log("sendProviderMessage failed: session not found")
        result(self.actionResult(data: data, message: "network extension session not found"))
        return
      }
      do {
        self.log("sendProviderMessage to NECore")
        try session.sendProviderMessage(data) { response in
          guard let response = response,
                let message = String(data: response, encoding: .utf8) else {
            self.log("sendProviderMessage empty response")
            result(self.actionResult(data: data, message: "empty network extension response"))
            return
          }
          self.log("sendProviderMessage response bytes=\(response.count)")
          result(message)
        }
      } catch {
        self.log("sendProviderMessage failed: \(error.localizedDescription)")
        result(self.actionResult(data: data, message: error.localizedDescription))
      }
    }
  }

  private func invokeAppCore(
    _ data: Data,
    status: NEVPNStatus,
    result: @escaping FlutterResult
  ) {
    guard let action = String(data: data, encoding: .utf8) else {
      log("invokeAppCore invalid action")
      result(actionResult(data: data, message: "invalid action"))
      return
    }
    log("invokeAppCore status=\(statusDescription(status))")
    IOSCoreBridge.invokeAction(action) { response in
      guard let response = response else {
        self.log("invokeAppCore empty response")
        result(self.actionResult(data: data, message: "empty app core response"))
        return
      }
      self.log("invokeAppCore response received")
      result(response)
    }
  }

  private func canSendProviderMessage(status: NEVPNStatus) -> Bool {
    switch status {
    case .connected, .reasserting:
      return true
    case .connecting, .disconnecting, .disconnected, .invalid:
      return false
    @unknown default:
      return false
    }
  }

  private func statusDescription(_ status: NEVPNStatus) -> String {
    switch status {
    case .invalid:
      return "invalid"
    case .disconnected:
      return "disconnected"
    case .connecting:
      return "connecting"
    case .connected:
      return "connected"
    case .reasserting:
      return "reasserting"
    case .disconnecting:
      return "disconnecting"
    @unknown default:
      return "unknown"
    }
  }

  private func actionInfo(_ data: Data) -> (method: String, id: String?)? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return (
      object["method"] as? String ?? "message",
      object["id"] as? String
    )
  }

  private func actionResult(data: Data?, message: String) -> String {
    return actionResult(data: data, payload: message, code: -1)
  }

  private func actionResult(data: Data?, payload resultPayload: Any, code: Int) -> String {
    var method = "message"
    var id: String?

    if let data = data,
       let action = actionInfo(data) {
      method = action.method
      id = action.id
    }

    var payload: [String: Any] = [
      "method": method,
      "data": resultPayload,
      "code": code,
    ]
    if let id = id {
      payload["id"] = id
    }

    guard let resultData = try? JSONSerialization.data(withJSONObject: payload),
          let result = String(data: resultData, encoding: .utf8) else {
      return #"{"method":"message","data":"serialization failed","code":-1}"#
    }
    return result
  }
}
