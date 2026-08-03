import AppIntents

@available(iOS 16.0, *)
public struct StartVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "startVPNTitle"
  public static let description: IntentDescription = "startVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    return .result(value: try await NEHelper.start())
  }
}

@available(iOS 16.0, *)
public struct StopVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "stopVPNTitle"
  public static let description: IntentDescription = "stopVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
    return .result(value: try await NEHelper.stop())
  }
}

@available(iOS 16.0, *)
public struct ToggleVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "toggleVPNTitle"
  public static let description: IntentDescription = "toggleVPNDescription"

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await NEHelper.toggle()
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
    try await NEHelper.setRunning(value)
    return .result()
  }
}
