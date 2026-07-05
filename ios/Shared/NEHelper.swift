import NetworkExtension
import WidgetKit

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

  static let runTimeKey = "runTime"

  public static func loadManager() async throws -> NETunnelProviderManager? {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    return managers.first
  }

  public static func loadManager(completionHandler: @escaping @Sendable (NETunnelProviderManager?, (any Error)?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences() { managers, error in
      completionHandler(managers?.first, error)
    }
  }

  public static func isRunning(_ status: NEVPNStatus) -> Bool {
    [.connecting, .connected, .reasserting].contains(status)
  }

  public static func start(manager: NETunnelProviderManager) async throws {
    if isRunning(manager.connection.status) {
      return
    }
    manager.isEnabled = true
    try await manager.saveToPreferences()
    try await manager.loadFromPreferences()
    try manager.connection.startVPNTunnel()
    let ms = Int(Date().timeIntervalSince1970 * 1000)
    UserDefaults(suiteName: appGroupIdentifier)?.set(ms, forKey: runTimeKey)
  }

  public static func stop(manager: NETunnelProviderManager) {
    if !isRunning(manager.connection.status) {
      return
    }
    manager.connection.stopVPNTunnel()
    UserDefaults(suiteName: appGroupIdentifier)?.removeObject(
      forKey: runTimeKey
    )
  }
  
  public static func toggle(manager: NETunnelProviderManager) async throws {
    if isRunning(manager.connection.status) {
      stop(manager: manager)
    } else {
      try await start(manager: manager)
    }
  }
}
