import ClashCore
import Foundation
import NetworkExtension
import os

/// While the tunnel runs the Network Extension holds the live Core, so runtime
/// calls go there; the app's own Core serves everything that only reads files
/// and keeps the configuration for when the tunnel goes down again.
final class CoreMessageRouter: @unchecked Sendable {
  private enum Route {
    case app
    case networkExtension(NETunnelProviderSession)
  }

  private static let appMethods: Set<String> = [
    "initClash",
    "getIsInit",
    "shutdown",
    "startListener",
    "stopListener",
    "validateConfig",
    "decryptConfig",
    "getConfig",
    "getProfileBase",
    "getProfileOutbounds",
    "buildProfile",
    "validateProxies",
    "validateFilters",
    "convertProxies",
    "encodeShareLinks",
    "decodeShareLinks",
    "dumpRuleSet",
    "compileRuleSet",
    "clearEffect",
    "updateGeoData",
  ]

  private static let configurationMethods: Set<String> = [
    "setupConfig",
    "updateConfig",
  ]

  private static let invalidCallResponse =
    #"{"result":null,"error":{"code":"invalid_method_call","message":"invalid method call","details":null}}"#

  var onEvent: ((Data) -> Void)?

  private let lock = NSLock()
  private var route = Route.app
  private var logRunning = false
  private var routeWatch: Data?
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "",
    category: "CoreMessageRouter"
  )

  /// Called in the order Flutter sent the calls: each one leaves for its Core
  /// before this returns, which is the order `watchRoute` depends on.
  func invoke(_ data: Data, reply: @escaping (Data) -> Void) {
    guard let call = MethodCall(data) else {
      reply(Data(Self.invalidCallResponse.utf8))
      return
    }
    let route = lock.withLock {
      record(call)
      return self.route
    }
    if Self.configurationMethods.contains(call.method),
      case .networkExtension(let session) = route
    {
      configureBoth(call, session: session, reply: reply)
      return
    }
    if Self.appMethods.contains(call.method) {
      sendToApp(call.data, reply: reply)
      return
    }
    send(call, route: route, reply: reply)
  }

  func useNetworkExtension(_ session: NETunnelProviderSession?) {
    let moved: (from: Route, to: Route, calls: [Data])? = lock.withLock {
      switch (route, session) {
      case (.app, nil):
        return nil
      case (.networkExtension(let current), let session?) where current === session:
        return nil
      default:
        break
      }
      let from = route
      route = session.map(Route.networkExtension) ?? .app
      return (from, route, subscriptionCalls())
    }
    guard let moved else {
      return
    }
    log("route \(session == nil ? "app" : "networkExtension")")
    // The extension's Core ends with the tunnel; the app's stays and would
    // keep publishing beside it.
    if case .app = moved.from {
      for data in moved.calls {
        if let call = MethodCall(data)?.cancelled {
          send(call, route: .app) { _ in }
        }
      }
    }
    for data in moved.calls {
      guard let call = MethodCall(data) else {
        continue
      }
      send(call, route: moved.to) { [weak self] response in
        if call.method == "watchRoute" {
          self?.publishRouteState(response)
        }
      }
    }
  }

  // The new Core counts its epochs from its own start, and Flutter takes only
  // a newer epoch than the one it holds for a sign it is behind.
  private func publishRouteState(_ response: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: response)
        as? [String: Any],
      let state = object["result"] as? [String: Any],
      let event = try? JSONSerialization.data(withJSONObject: [
        "method": "message",
        "arguments": [["type": "routeChanged", "data": state]],
      ])
    else {
      return
    }
    onEvent?(event)
  }

  // A Core the route moves to never heard the subscriptions made on the other.
  private func record(_ call: MethodCall) {
    switch call.method {
    case "startLog":
      logRunning = true
    case "stopLog":
      logRunning = false
    case "watchRoute":
      routeWatch = call.data
    default:
      break
    }
  }

  private func subscriptionCalls() -> [Data] {
    var calls: [Data] = []
    if logRunning {
      calls.append(Data(#"{"method":"startLog"}"#.utf8))
    }
    if let routeWatch {
      calls.append(routeWatch)
    }
    return calls
  }

  // The app's Core keeps the profile for when the tunnel stops; its external
  // controller would take the port the extension's Core already listens on.
  private func configureBoth(
    _ call: MethodCall,
    session: NETunnelProviderSession,
    reply: @escaping (Data) -> Void
  ) {
    var appCall = call
    if call.method == "updateConfig" {
      appCall = call.replacingArgument("external-controller", with: "")
    }
    sendToApp(appCall.data) { [weak self] response in
      guard let self, Self.isEmptySuccess(response) else {
        reply(response)
        return
      }
      var extensionCall = call
      if call.method == "updateConfig" {
        extensionCall = call.replacingArgument("geo-auto-update", with: false)
      }
      self.sendToExtension(extensionCall, session: session, reply: reply) {
        reply(response)
      }
    }
  }

  private func send(
    _ call: MethodCall,
    route: Route,
    reply: @escaping (Data) -> Void
  ) {
    switch route {
    case .app:
      sendToApp(call.data, reply: reply)
    case .networkExtension(let session):
      sendToExtension(call, session: session, reply: reply) { [weak self] in
        self?.sendToApp(call.data, reply: reply)
      }
    }
  }

  private func sendToApp(_ data: Data, reply: @escaping (Data) -> Void) {
    MobileInvokeMethod(
      String(data: data, encoding: .utf8),
      CoreResultHandler(reply)
    )
  }

  // A tunnel going down takes its Core with it before the route hears of it.
  private func sendToExtension(
    _ call: MethodCall,
    session: NETunnelProviderSession,
    reply: @escaping (Data) -> Void,
    unavailable: @escaping () -> Void
  ) {
    do {
      try session.sendProviderMessage(call.data) { response in
        guard let response, !response.isEmpty else {
          unavailable()
          return
        }
        reply(response)
      }
    } catch {
      unavailable()
    }
  }

  private static func isEmptySuccess(_ response: Data) -> Bool {
    guard
      let object = try? JSONSerialization.jsonObject(with: response)
        as? [String: Any]
    else {
      return false
    }
    let error = object["error"]
    return (error == nil || error is NSNull) && object["result"] as? String == ""
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}

private struct MethodCall {
  let data: Data
  let method: String
  private let object: [String: Any]

  init?(_ data: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: data)
        as? [String: Any],
      let method = object["method"] as? String
    else {
      return nil
    }
    self.data = data
    self.object = object
    self.method = method
  }

  var cancelled: MethodCall? {
    switch method {
    case "startLog":
      return MethodCall(Data(#"{"method":"stopLog"}"#.utf8))
    case "watchRoute":
      return MethodCall(Data(#"{"method":"watchRoute","arguments":false}"#.utf8))
    default:
      return nil
    }
  }

  func replacingArgument(_ key: String, with value: Any) -> MethodCall {
    guard var arguments = object["arguments"] as? [String: Any] else {
      return self
    }
    arguments[key] = value
    var object = object
    object["arguments"] = arguments
    guard let data = try? JSONSerialization.data(withJSONObject: object),
      let call = MethodCall(data)
    else {
      return self
    }
    return call
  }
}
