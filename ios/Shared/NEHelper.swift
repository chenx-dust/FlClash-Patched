import Foundation
import NetworkExtension

public enum NEHelper {
  private static var appBundleId: String {
    let bundleId = Bundle.main.bundleIdentifier!
    for suffix in [".NECore", ".Widget"] where bundleId.hasSuffix(suffix) {
      return String(bundleId.dropLast(suffix.count))
    }
    return bundleId
  }

  public static var appGroupIdentifier: String { "group.\(appBundleId)" }
  public static var widgetIdentifier: String { "\(appBundleId).Widget" }
  public static var providerBundleIdentifier: String {
    "\(appBundleId).NECore"
  }

  @MainActor
  public static func loadManager() async throws -> NETunnelProviderManager? {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    return managers.first(where: isManagedManager)
  }

  public static func isRunning(_ status: NEVPNStatus) -> Bool {
    [.connecting, .connected, .reasserting].contains(status)
  }

  @MainActor
  @discardableResult
  public static func start() async throws -> Bool {
    try await startWithPreferenceRetry(initialManager: nil)
  }

  @MainActor
  private static func startWithPreferenceRetry(
    initialManager: NETunnelProviderManager?
  ) async throws -> Bool {
    var manager = initialManager
    var allowPreferenceRetry = true
    while true {
      if manager == nil {
        manager = try await loadManager()
      }
      guard let currentManager = manager else {
        return false
      }
      do {
        return try await start(manager: currentManager)
      } catch {
        guard allowPreferenceRetry,
          isRetryablePreferenceError(error)
        else {
          throw error
        }
        allowPreferenceRetry = false
        manager = nil
      }
    }
  }

  @MainActor
  @discardableResult
  public static func stop() async throws -> Bool {
    guard let manager = try await loadManager() else {
      return false
    }
    stop(manager: manager)
    return true
  }

  @MainActor
  public static func toggle() async throws {
    guard let manager = try await loadManager() else {
      return
    }
    if isRunning(manager.connection.status) {
      stop(manager: manager)
    } else {
      _ = try await startWithPreferenceRetry(initialManager: manager)
    }
  }

  @MainActor
  public static func setRunning(_ running: Bool) async throws {
    if running {
      _ = try await start()
    } else {
      _ = try await stop()
    }
  }

  @MainActor
  private static func start(
    manager: NETunnelProviderManager
  ) async throws -> Bool {
    var status = manager.connection.status
    if status == .disconnecting {
      status = try await waitForStableStatus(manager: manager)
    }
    if isRunning(status) {
      return true
    }

    manager.isEnabled = true
    if let rules = manager.onDemandRules, !rules.isEmpty {
      manager.isOnDemandEnabled = true
    }
    try await manager.saveToPreferences()
    try await manager.loadFromPreferences()

    status = manager.connection.status
    if status == .disconnecting {
      status = try await waitForStableStatus(manager: manager)
    }
    if isRunning(status) {
      return true
    }
    try manager.connection.startVPNTunnel()
    return true
  }

  @MainActor
  private static func stop(manager: NETunnelProviderManager) {
    guard isRunning(manager.connection.status) else {
      return
    }
    manager.connection.stopVPNTunnel()
  }

  @MainActor
  private static func waitForStableStatus(
    manager: NETunnelProviderManager
  ) async throws -> NEVPNStatus {
    let deadline = Date().addingTimeInterval(5)
    var status = manager.connection.status
    while status == .disconnecting && Date() < deadline {
      try await Task.sleep(nanoseconds: 100_000_000)
      status = manager.connection.status
    }
    guard status != .disconnecting else {
      throw NEHelperError.transitionTimedOut
    }
    return status
  }

  private static func isManagedManager(
    _ manager: NETunnelProviderManager
  ) -> Bool {
    guard
      let proto = manager.protocolConfiguration
        as? NETunnelProviderProtocol
    else {
      return false
    }
    return proto.providerBundleIdentifier == providerBundleIdentifier
  }

  private static func isRetryablePreferenceError(_ error: Error) -> Bool {
    let error = error as NSError
    guard error.domain == NEVPNErrorDomain,
      let code = NEVPNError.Code(rawValue: error.code)
    else {
      return false
    }
    switch code {
    case .configurationInvalid, .configurationStale:
      return true
    default:
      return false
    }
  }
}

private enum NEHelperError: LocalizedError {
  case transitionTimedOut

  var errorDescription: String? {
    "Network Extension transition timed out"
  }
}
