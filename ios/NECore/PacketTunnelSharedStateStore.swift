import Foundation

enum PacketTunnelEnvironment {
  static let extensionBundleIdentifier = Bundle.main.bundleIdentifier!
  static let baseBundleIdentifier = String(
    extensionBundleIdentifier.dropLast(".NECore".count)
  )
  static let appGroupIdentifier = "group.\(baseBundleIdentifier)"
  static let widgetIdentifier = "\(baseBundleIdentifier).Widget"
  static let eventNotificationName =
    "\(extensionBundleIdentifier).event"
}

final class PacketTunnelSharedStateStore {
  private static let emptySetupParams = Data("{}".utf8)

  private let sharedStateKey = "sharedState"
  private let setupParamsKey = "setupParams"
  private let runTimeKey = "runTime"
  private let activeVpnOptionsKey = "activeVpnOptions"

  func loadVPNOptionsSnapshot() -> (options: PacketTunnelVPNOptions, data: Data)? {
    guard let sharedData = userDefaults?.data(forKey: sharedStateKey),
      let shared = try? JSONSerialization.jsonObject(with: sharedData) as? [String: Any],
      let rawOptions = shared["vpnOptions"] as? [String: Any],
      let data = try? JSONSerialization.data(withJSONObject: rawOptions),
      let options = try? JSONDecoder().decode(PacketTunnelVPNOptions.self, from: data)
    else {
      return nil
    }
    return (options, data)
  }

  func loadSetupParams() -> Data {
    guard let userDefaults else {
      return Self.emptySetupParams
    }
    if let data = userDefaults.data(forKey: setupParamsKey) {
      return data
    }
    guard let sharedStateData = userDefaults.data(forKey: sharedStateKey),
      let json = try? JSONSerialization.jsonObject(with: sharedStateData)
        as? [String: Any],
      let setupParams = json[setupParamsKey],
      !(setupParams is NSNull),
      JSONSerialization.isValidJSONObject(setupParams),
      let data = try? JSONSerialization.data(withJSONObject: setupParams)
    else {
      return Self.emptySetupParams
    }
    userDefaults.set(data, forKey: setupParamsKey)
    return data
  }

  func makeInitParams() -> String {
    let homeDirectory = appGroupDirectory()?.path ?? ""
    return "{\"home-dir\":\"\(homeDirectory)\",\"version\":0}"
  }

  func appGroupDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier:
        PacketTunnelEnvironment.appGroupIdentifier
    )
  }

  func saveRunTime(vpnOptions: Data) {
    let milliseconds = Int(Date().timeIntervalSince1970 * 1000)
    userDefaults?.set(vpnOptions, forKey: activeVpnOptionsKey)
    userDefaults?.set(milliseconds, forKey: runTimeKey)
  }

  func clearRunTime() {
    userDefaults?.removeObject(forKey: runTimeKey)
    userDefaults?.removeObject(forKey: activeVpnOptionsKey)
  }

  private var userDefaults: UserDefaults? {
    UserDefaults(
      suiteName: PacketTunnelEnvironment.appGroupIdentifier
    )
  }
}

struct PacketTunnelVPNOptions: Decodable {
  let port: Int
  let ipv6: Bool
  let captureDns: Bool
  let systemProxy: Bool
  let bypassDomain: [String]
  let stack: String
  let mtu: Int
  let routeAddress: [String]
  let disableIcmpForwarding: Bool
  let endpointIndependentNat: Bool
  let congestionController: String
  let recvMsgX: Bool
  let sendMsgX: Bool
  let includeAllNetworks: Bool
  let excludeLocalNetworks: Bool
  let excludeAPNs: Bool
  let excludeCellularServices: Bool
  let enforceRoutes: Bool
  let excludeDeviceCommunication: Bool

  private enum CodingKeys: String, CodingKey {
    case port
    case ipv6
    case captureDns
    case systemProxy
    case bypassDomain
    case stack
    case mtu
    case routeAddress
    case disableIcmpForwarding
    case endpointIndependentNat
    case congestionController
    case recvMsgX
    case sendMsgX
    case includeAllNetworks
    case excludeLocalNetworks
    case excludeAPNs
    case excludeCellularServices
    case enforceRoutes
    case excludeDeviceCommunication
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    port = try container.decode(Int.self, forKey: .port)
    ipv6 = try container.decode(Bool.self, forKey: .ipv6)
    captureDns = try container.decode(Bool.self, forKey: .captureDns)
    systemProxy = try container.decode(Bool.self, forKey: .systemProxy)
    bypassDomain = try container.decodeIfPresent(
      [String].self,
      forKey: .bypassDomain
    ) ?? []
    stack = try container.decode(String.self, forKey: .stack)
    mtu = try container.decodeIfPresent(Int.self, forKey: .mtu) ?? 9000
    routeAddress = try container.decodeIfPresent(
      [String].self,
      forKey: .routeAddress
    ) ?? []
    disableIcmpForwarding = try container.decodeIfPresent(
      Bool.self,
      forKey: .disableIcmpForwarding
    ) ?? false
    endpointIndependentNat = try container.decodeIfPresent(
      Bool.self,
      forKey: .endpointIndependentNat
    ) ?? false
    congestionController = try container.decodeIfPresent(
      String.self,
      forKey: .congestionController
    ) ?? ""
    recvMsgX = try container.decodeIfPresent(Bool.self, forKey: .recvMsgX) ?? true
    sendMsgX = try container.decodeIfPresent(Bool.self, forKey: .sendMsgX) ?? false
    includeAllNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .includeAllNetworks
    ) ?? false
    excludeLocalNetworks = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeLocalNetworks
    ) ?? true
    excludeAPNs = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeAPNs
    ) ?? true
    excludeCellularServices = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeCellularServices
    ) ?? true
    enforceRoutes = try container.decodeIfPresent(
      Bool.self,
      forKey: .enforceRoutes
    ) ?? false
    excludeDeviceCommunication = try container.decodeIfPresent(
      Bool.self,
      forKey: .excludeDeviceCommunication
    ) ?? true
  }
}
