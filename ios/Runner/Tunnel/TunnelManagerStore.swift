import Foundation
import NetworkExtension

final class TunnelManagerStore {
  private let sharedStateStore: SharedStateStore
  private let networkExtensionIdentifier: String
  private let localizedDescription: String

  init(
    sharedStateStore: SharedStateStore,
    networkExtensionIdentifier: String,
    localizedDescription: String
  ) {
    self.sharedStateStore = sharedStateStore
    self.networkExtensionIdentifier = networkExtensionIdentifier
    self.localizedDescription = localizedDescription
  }

  func loadManager(
    createIfNeeded: Bool = true
  ) async throws -> NETunnelProviderManager? {
    try await withCheckedThrowingContinuation { continuation in
      loadManager(createIfNeeded: createIfNeeded) { manager, error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: manager)
        }
      }
    }
  }

  func loadManager(
    createIfNeeded: Bool = true,
    completion: @escaping (NETunnelProviderManager?, Error?) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        self.log("loadManager failed: \(error.localizedDescription)")
        completion(nil, error)
        return
      }

      if let manager = managers?.first(where: { manager in
        guard
          let proto = manager.protocolConfiguration
            as? NETunnelProviderProtocol
        else {
          return false
        }
        return proto.providerBundleIdentifier == self.networkExtensionIdentifier
      }) {
        self.log(
          "loadManager found status=\(self.statusDescription(manager.connection.status))"
        )
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
      proto.providerBundleIdentifier = self.networkExtensionIdentifier
      proto.serverAddress = self.localizedDescription
      manager.protocolConfiguration = proto
      manager.localizedDescription = self.localizedDescription
      manager.isEnabled = true
      completion(manager, nil)
    }
  }

  func applyNetworkExtensionOptions(to manager: NETunnelProviderManager) {
    let configuration = sharedStateStore.loadTunnelConfiguration()
    let options = configuration.options
    guard
      let proto = manager.protocolConfiguration
        as? NETunnelProviderProtocol
    else {
      return
    }
    if #available(iOS 14.0, *) {
      proto.includeAllNetworks = options.includeAllNetworks
    }
    if #available(iOS 14.2, *) {
      proto.excludeLocalNetworks = options.excludeLocalNetworks
      proto.enforceRoutes = options.enforceRoutes
    }
    if #available(iOS 16.4, *) {
      proto.excludeAPNs = options.excludeAPNs
      proto.excludeCellularServices = options.excludeCellularServices
    }
    if #available(iOS 17.4, *) {
      proto.excludeDeviceCommunication = options.excludeDeviceCommunication
    }
    log(
      "applyNEOptions includeAll=\(options.includeAllNetworks) excludeLocal=\(options.excludeLocalNetworks) excludeAPNs=\(options.excludeAPNs) excludeCellular=\(options.excludeCellularServices) enforceRoutes=\(options.enforceRoutes) excludeDeviceComm=\(options.excludeDeviceCommunication)"
    )

    var rules: [NEOnDemandRule] = []
    if !configuration.excludeSSIDs.isEmpty {
      let disconnectRule = NEOnDemandRuleDisconnect()
      disconnectRule.ssidMatch = configuration.excludeSSIDs
      disconnectRule.interfaceTypeMatch = .wiFi
      rules.append(disconnectRule)
    }

    if configuration.alwaysOn {
      let connectWifi = NEOnDemandRuleConnect()
      connectWifi.interfaceTypeMatch = .wiFi
      rules.append(connectWifi)

      let connectCellular = NEOnDemandRuleConnect()
      connectCellular.interfaceTypeMatch = .cellular
      rules.append(connectCellular)
    }

    manager.onDemandRules = rules.isEmpty ? nil : rules
    manager.isOnDemandEnabled = !rules.isEmpty
    log(
      "applyOnDemandRules excludeSSIDs=\(configuration.excludeSSIDs) enabled=\(manager.isOnDemandEnabled)"
    )
  }

  func isManagedConnection(_ connection: NEVPNConnection) -> Bool {
    guard
      let proto = connection.manager.protocolConfiguration
        as? NETunnelProviderProtocol
    else {
      return false
    }
    return proto.providerBundleIdentifier == networkExtensionIdentifier
  }

  func isRetryablePreferenceError(_ error: Error) -> Bool {
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

  private func log(_ message: String) {
    NSLog("[TunnelController] %@", message)
  }
}
