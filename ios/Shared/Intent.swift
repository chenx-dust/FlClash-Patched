import AppIntents

@available(iOS 16.0, *)
public struct StartVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "startVPNTitle"
  public static let description: IntentDescription = "startVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    guard let manager = try await NEHelper.loadManager() else {
      return .result(value: false)
    }
    try await NEHelper.start(manager: manager)
    return .result(value: true)
  }
}

@available(iOS 16.0, *)
public struct StopVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "stopVPNTitle"
  public static let description: IntentDescription = "stopVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    guard let manager = try await NEHelper.loadManager() else {
      return .result(value: false)
    }
    NEHelper.stop(manager: manager)
    return .result(value: true)
  }
}

@available(iOS 16.0, *)
public struct ToggleVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "toggleVPNTitle"
  public static let description: IntentDescription = "toggleVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult {
    guard let manager = try await NEHelper.loadManager() else {
      return .result()
    }
    try await NEHelper.toggle(manager: manager)
    return .result()
  }
}

@available(iOS 16.0, *)
public struct SetVPNIntent: SetValueIntent {
  public static let title: LocalizedStringResource = "setVPNTitle"

  @Parameter(title: "vpnIsRunning")
  public var value: Bool

  public init() {}

  public func perform() async throws -> some IntentResult {
    guard let manager = try await NEHelper.loadManager() else {
      return .result()
    }
    if value {
      try await NEHelper.start(manager: manager)
    } else {
      NEHelper.stop(manager: manager)
    }
    return .result()
  }
}
