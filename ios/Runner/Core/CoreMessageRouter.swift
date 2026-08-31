import Foundation
import os

private enum AppCoreMethod: String {
  case initClash
  case getIsInit
  case validateConfig
  case getProfileConfig
  case decryptAgeConfig
  case generateAgeKeyPair
  case convertAgeSecretKeyToPublicKey
  case deleteManagedPath
  case updateGeoData
  case getCountryCode
}

private enum ConfigurationCoreMethod: String {
  case setupConfig
  case updateConfig
}

private struct CoreRoutingError: LocalizedError {
  let code: String
  let message: String

  var errorDescription: String? {
    message
  }
}

@MainActor
final class CoreMessageRouter {
  private let tunnelController: TunnelController
  private var currentRoute = CoreRoute.app
  private lazy var notificationCoordinator = CoreNotificationCoordinator(
    sendMessage: { [weak self] data, route in
      guard let self else {
        throw CoreRoutingError(
          code: "core_router_unavailable",
          message: "core router is unavailable"
        )
      }
      return try await self.sendCoreMessage(data, route: route)
    }
  )
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.follow.clash",
    category: "CoreMessageRouter"
  )

  init(tunnelController: TunnelController) {
    self.tunnelController = tunnelController
  }

  func updateTunnelState(_ state: TunnelTarget) {
    currentRoute = state == .running ? .networkExtension : .app
    notificationCoordinator.setDesiredRoute(currentRoute)
  }

  func invoke(_ data: Data) async -> String {
    let method = methodCallName(data)
    let action = notificationCoordinator.action(for: data)
    await notificationCoordinator.prepare(for: action)
    defer {
      notificationCoordinator.finish(action)
    }

    let selectedRoute = currentRoute
    let networkExtensionActive = selectedRoute == .networkExtension

    do {
      if case .stop(let kind) = action {
        return try await sendNotificationStop(
          data,
          kind: kind,
          defaultRoute: selectedRoute
        )
      }

      let routedResult: (response: String, route: CoreRoute)
      if let method,
        let configurationMethod = ConfigurationCoreMethod(rawValue: method)
      {
        let response = try await sendConfigurationMessage(
          data,
          method: configurationMethod,
          networkExtensionActive: networkExtensionActive
        )
        routedResult = (
          response,
          networkExtensionActive ? .networkExtension : .app
        )
      } else {
        routedResult = try await sendRoutedCoreMessage(
          data,
          selectedRoute: route(
            method: method,
            defaultRoute: selectedRoute
          )
        )
      }
      if case .start(let kind) = action,
        methodResponseSucceeded(routedResult.response)
      {
        notificationCoordinator.recordSuccessfulStart(
          kind,
          data: data,
          route: routedResult.route
        )
      }
      return routedResult.response
    } catch let error as CoreRoutingError {
      return methodErrorResponse(
        data: data,
        code: error.code,
        message: error.message
      )
    } catch let error as ProviderMessageError {
      return methodErrorResponse(
        data: data,
        code: error.code,
        message: error.message
      )
    } catch {
      return methodErrorResponse(
        data: data,
        code: "core_routing_error",
        message: error.localizedDescription
      )
    }
  }

  func shutdownAppCore() async -> Bool {
    let methodCall = #"{"method":"shutdown","arguments":null}"#
    return await withCheckedContinuation { continuation in
      IOSCoreBridge.invokeMethod(methodCall) { [weak self] response in
        guard let response,
          let data = response.data(using: .utf8),
          let payload = try? JSONSerialization.jsonObject(with: data)
            as? [String: Any],
          let success = payload["result"] as? Bool
        else {
          self?.log("shutdownAppCore invalid response")
          continuation.resume(returning: false)
          return
        }
        self?.log("shutdownAppCore result=\(success)")
        continuation.resume(returning: success)
      }
    }
  }

  private func sendRoutedCoreMessage(
    _ data: Data,
    selectedRoute: CoreRoute
  ) async throws -> (response: String, route: CoreRoute) {
    do {
      let response = try await sendCoreMessage(data, route: selectedRoute)
      return (response, selectedRoute)
    } catch {
      guard selectedRoute == .networkExtension else {
        throw error
      }
      log(
        "route fallback networkExtension -> app: \(error.localizedDescription)"
      )
      let response = try await sendCoreMessage(data, route: .app)
      return (response, .app)
    }
  }

  private func sendNotificationStop(
    _ data: Data,
    kind: CoreNotificationKind,
    defaultRoute: CoreRoute
  ) async throws -> String {
    let routes = notificationCoordinator.beginStop(
      kind,
      data: data,
      defaultRoute: defaultRoute
    )
    var successfulResponse: String?
    var failedResponse: String?
    var firstError: Error?

    for route in routes {
      do {
        let response = try await sendCoreMessage(data, route: route)
        guard methodResponseSucceeded(response) else {
          if failedResponse == nil {
            failedResponse = response
          }
          continue
        }
        notificationCoordinator.recordSuccessfulStop(
          kind,
          route: route
        )
        if successfulResponse == nil {
          successfulResponse = response
        }
      } catch {
        if firstError == nil {
          firstError = error
        }
      }
    }

    if let failedResponse {
      return failedResponse
    }
    if let firstError {
      throw firstError
    }
    guard let successfulResponse else {
      throw CoreRoutingError(
        code: "notification_stop_failed",
        message: "failed to stop Core notifications"
      )
    }
    return successfulResponse
  }

  private func sendConfigurationMessage(
    _ data: Data,
    method: ConfigurationCoreMethod,
    networkExtensionActive: Bool
  ) async throws -> String {
    let appData: Data
    if networkExtensionActive && method == .updateConfig {
      appData = try replacingArgument(
        in: data,
        key: "external-controller",
        with: ""
      )
    } else {
      appData = data
    }

    let appResponse = try await sendCoreMessage(appData, route: .app)
    guard networkExtensionActive,
      currentRoute == .networkExtension,
      methodResponseHasEmptyStringResult(appResponse)
    else {
      return appResponse
    }

    let networkExtensionData = method == .updateConfig
      ? try replacingArgument(
        in: data,
        key: "geo-auto-update",
        with: false
      )
      : data
    return try await sendCoreMessage(
      networkExtensionData,
      route: .networkExtension
    )
  }

  private func sendCoreMessage(
    _ data: Data,
    route: CoreRoute
  ) async throws -> String {
    switch route {
    case .app:
      guard let methodCall = String(data: data, encoding: .utf8) else {
        throw CoreRoutingError(
          code: "invalid_method_call",
          message: "invalid method call"
        )
      }
      let response: String? = await withCheckedContinuation {
        (continuation: CheckedContinuation<String?, Never>) in
        IOSCoreBridge.invokeMethod(methodCall) { value in
          continuation.resume(returning: value)
        }
      }
      guard let response else {
        throw CoreRoutingError(
          code: "empty_response",
          message: "empty app core response"
        )
      }
      return response
    case .networkExtension:
      return try await tunnelController.sendProviderMessage(data)
    }
  }

  private func route(
    method: String?,
    defaultRoute: CoreRoute
  ) -> CoreRoute {
    guard let method,
      AppCoreMethod(rawValue: method) != nil
    else {
      return defaultRoute
    }
    return .app
  }

  private func replacingArgument(
    in data: Data,
    key: String,
    with value: Any
  ) throws -> Data {
    guard var object = methodCallObject(data),
      var arguments = object["arguments"] as? [String: Any]
    else {
      throw CoreRoutingError(
        code: "invalid_arguments",
        message: "invalid configuration arguments"
      )
    }
    arguments[key] = value
    object["arguments"] = arguments
    do {
      return try JSONSerialization.data(withJSONObject: object)
    } catch {
      throw CoreRoutingError(
        code: "invalid_arguments",
        message: error.localizedDescription
      )
    }
  }

  private func methodResponseHasEmptyStringResult(
    _ response: String
  ) -> Bool {
    guard let data = response.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data)
        as? [String: Any],
      methodResponseSucceeded(object)
    else {
      return false
    }
    return object["result"] as? String == ""
  }

  private func methodResponseSucceeded(_ response: String) -> Bool {
    guard let data = response.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data)
        as? [String: Any]
    else {
      return false
    }
    return methodResponseSucceeded(object)
  }

  private func methodResponseSucceeded(
    _ object: [String: Any]
  ) -> Bool {
    object["error"] == nil || object["error"] is NSNull
  }

  private func methodCallObject(_ data: Data) -> [String: Any]? {
    try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  }

  private func methodCallName(_ data: Data) -> String? {
    methodCallObject(data)?["method"] as? String
  }

  private func methodCallID(_ data: Data?) -> String? {
    guard let data,
      let object = methodCallObject(data)
    else {
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
      let response = String(data: responseData, encoding: .utf8)
    else {
      return #"{"result":null,"error":{"code":"serialization_error","message":"failed to serialize method response","details":null}}"#
    }
    return response
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
