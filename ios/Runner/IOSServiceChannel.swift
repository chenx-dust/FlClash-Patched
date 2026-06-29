import Flutter
import Foundation
import NetworkExtension

final class IOSServiceChannel {
  private static var instance: IOSServiceChannel?

  private let channel: FlutterMethodChannel
  private let providerBundleIdentifier = "site.yinmo.clash.NECore"
  private let localizedDescription = "FlClash"
  private let appCoreMethods: Set<String> = [
    "validateConfig",
    "asyncTestDelay",
    "getConfig",
    "generateAgeKeyPair",
    "convertAgeSecretKeyToPublicKey",
    "deleteFile",
  ]

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
    case "init", "syncState":
      result("")
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
        completion(nil, error)
        return
      }

      if let manager = managers?.first(where: { manager in
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return proto.providerBundleIdentifier == self.providerBundleIdentifier
      }) {
        completion(manager, nil)
        return
      }

      if !createIfNeeded {
        completion(nil, nil)
        return
      }

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
    loadManager { manager, error in
      guard let manager = manager else {
        completion(false)
        return
      }
      if error != nil {
        completion(false)
        return
      }

      manager.isEnabled = true
      manager.saveToPreferences { error in
        if error != nil {
          completion(false)
          return
        }
        manager.loadFromPreferences { error in
          if error != nil {
            completion(false)
            return
          }
          do {
            try manager.connection.startVPNTunnel()
            completion(true)
          } catch {
            completion(false)
          }
        }
      }
    }
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    loadManager { manager, _ in
      manager?.connection.stopVPNTunnel()
      result(true)
    }
  }

  private func routeAction(_ data: Data, result: @escaping FlutterResult) {
    guard let action = actionInfo(data) else {
      result(actionResult(data: data, message: "invalid action"))
      return
    }

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
        result(self.actionResult(data: data, message: error.localizedDescription))
        return
      }
      guard let session = manager?.connection as? NETunnelProviderSession else {
        result(self.actionResult(data: data, message: "network extension session not found"))
        return
      }
      do {
        try session.sendProviderMessage(data) { response in
          guard let response = response,
                let message = String(data: response, encoding: .utf8) else {
            result(self.actionResult(data: data, message: "empty network extension response"))
            return
          }
          result(message)
        }
      } catch {
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
      result(actionResult(data: data, message: "invalid action"))
      return
    }
    IOSCoreBridge.invokeAction(action) { response in
      guard let response = response else {
        result(self.actionResult(data: data, message: "empty app core response"))
        return
      }
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
