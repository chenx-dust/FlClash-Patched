import Foundation
import NetworkExtension
import UIKit

final class TunnelController {
  private let sharedStateStore: SharedStateStore
  private let onExternalStart: () -> Void
  private let onExternalStop: () -> Void
  private let networkExtensionIdentifier = "\(Bundle.main.bundleIdentifier!).NECore"
  private let localizedDescription = "FlClash"
  private let connectTimeout: TimeInterval = 5

  private var tunnelStatusObserver: NSObjectProtocol?
  private var appActiveObserver: NSObjectProtocol?
  private var lastTunnelStatus: NEVPNStatus?
  private var isTunnelStopExpected = false
  private var isTunnelStartExpected = false

  init(
    sharedStateStore: SharedStateStore,
    onExternalStart: @escaping () -> Void,
    onExternalStop: @escaping () -> Void
  ) {
    self.sharedStateStore = sharedStateStore
    self.onExternalStart = onExternalStart
    self.onExternalStop = onExternalStop
  }

  deinit {
    if let tunnelStatusObserver {
      NotificationCenter.default.removeObserver(tunnelStatusObserver)
    }
    if let appActiveObserver {
      NotificationCenter.default.removeObserver(appActiveObserver)
    }
  }

  func startObserving() {
    registerTunnelStatusObserver()
    appActiveObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.handleTunnelStatusDidChange()
    }
  }

  func start(completion: @escaping (Bool) -> Void) {
    log("start begin")
    loadManager { manager, error in
      guard let manager else {
        self.log("start failed: manager missing")
        completion(false)
        return
      }
      if let error {
        self.log("start failed: \(error.localizedDescription)")
        completion(false)
        return
      }

      manager.isEnabled = true
      self.applyNetworkExtensionOptions(to: manager)
      self.log("start save preferences")
      manager.saveToPreferences { error in
        if let error {
          self.log("start save preferences failed: \(error.localizedDescription)")
          completion(false)
          return
        }
        self.log("start reload preferences")
        manager.loadFromPreferences { error in
          if let error {
            self.log("start reload preferences failed: \(error.localizedDescription)")
            completion(false)
            return
          }
          do {
            self.log("start currentStatus=\(self.statusDescription(manager.connection.status))")
            if self.isActiveTunnelStatus(manager.connection.status) {
              self.log("start already connected")
              self.isTunnelStopExpected = false
              self.lastTunnelStatus = manager.connection.status
              self.sharedStateStore.saveRunTime()
              completion(true)
              return
            }
            self.isTunnelStopExpected = false
            self.isTunnelStartExpected = true
            try manager.connection.startVPNTunnel()
            self.log("start requested")
            self.waitForConnected(manager: manager) { connected in
              self.log("start connected result=\(connected)")
              if connected {
                self.sharedStateStore.saveRunTime()
              }
              completion(connected)
            }
          } catch {
            self.log("start failed: \(error.localizedDescription)")
            completion(false)
          }
        }
      }
    }
  }

  func stop(completion: @escaping (Bool) -> Void) {
    log("stop requested")
    loadManager { manager, _ in
      let status = manager?.connection.status ?? .invalid
      self.log("stop currentStatus=\(self.statusDescription(status))")
      self.isTunnelStopExpected = self.isActiveTunnelStatus(status)
      manager?.connection.stopVPNTunnel()
      if !self.isTunnelStopExpected {
        self.isTunnelStopExpected = false
      }
      self.sharedStateStore.clearRunTime()
      completion(true)
    }
  }

  func reloadOnDemandRules() {
    loadManager(createIfNeeded: false) { manager, _ in
      guard let manager else {
        return
      }
      self.applyNetworkExtensionOptions(to: manager)
      manager.saveToPreferences { error in
        if let error {
          self.log("reloadOnDemandRules save failed: \(error.localizedDescription)")
        }
      }
    }
  }

  func sendProviderMessage(
    _ data: Data,
    completion: @escaping (String?, ProviderMessageError?) -> Void
  ) {
    loadManager(createIfNeeded: false) { manager, error in
      if let error {
        self.log("sendProviderMessage failed load manager: \(error.localizedDescription)")
        completion(nil, ProviderMessageError(
          code: "network_extension_error",
          message: error.localizedDescription
        ))
        return
      }
      guard let session = manager?.connection as? NETunnelProviderSession else {
        self.log("sendProviderMessage failed: session not found")
        completion(nil, ProviderMessageError(
          code: "network_extension_unavailable",
          message: "network extension session not found"
        ))
        return
      }
      do {
        self.log("sendProviderMessage to NECore")
        try session.sendProviderMessage(data) { response in
          guard let response,
                let message = String(data: response, encoding: .utf8) else {
            self.log("sendProviderMessage empty response")
            completion(nil, nil)
            return
          }
          self.log("sendProviderMessage response bytes=\(response.count)")
          completion(message, nil)
        }
      } catch {
        self.log("sendProviderMessage failed: \(error.localizedDescription)")
        completion(nil, ProviderMessageError(
          code: "network_extension_error",
          message: error.localizedDescription
        ))
      }
    }
  }

  func isCoreActive(completion: @escaping (Bool) -> Void) {
    loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      completion(self.isConnectedTunnelStatus(status))
    }
  }

  func getRunTime(completion: @escaping (Int) -> Void) {
    loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      guard self.isConnectedTunnelStatus(status) else {
        completion(0)
        return
      }
      completion(self.sharedStateStore.runTime())
    }
  }

  private func loadManager(
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
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return proto.providerBundleIdentifier == self.networkExtensionIdentifier
      }) {
        self.log("loadManager found status=\(self.statusDescription(manager.connection.status))")
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

  private func waitForConnected(
    manager: NETunnelProviderManager,
    completion: @escaping (Bool) -> Void
  ) {
    let status = manager.connection.status
    if isConnectedTunnelStatus(status) {
      completion(true)
      return
    }

    var observer: NSObjectProtocol?
    var timeoutWork: DispatchWorkItem?

    let cleanup: () -> Void = {
      if let observer {
        NotificationCenter.default.removeObserver(observer)
      }
      timeoutWork?.cancel()
    }

    observer = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: manager.connection,
      queue: .main
    ) { _ in
      let current = manager.connection.status
      if self.isConnectedTunnelStatus(current) {
        cleanup()
        completion(true)
      } else if self.isTerminalTunnelStatus(current) {
        self.log("waitForConnected failed status=\(self.statusDescription(current))")
        cleanup()
        completion(false)
      }
    }

    timeoutWork = DispatchWorkItem { [weak self] in
      let current = manager.connection.status
      self?.log("waitForConnected timeout status=\(self?.statusDescription(current) ?? "unknown")")
      cleanup()
      completion(self?.isConnectedTunnelStatus(current) ?? false)
    }
    DispatchQueue.main.asyncAfter(
      deadline: .now() + connectTimeout,
      execute: timeoutWork!
    )
  }

  private func applyNetworkExtensionOptions(to manager: NETunnelProviderManager) {
    let configuration = sharedStateStore.loadTunnelConfiguration()
    let options = configuration.options
    guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
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
    log("applyNEOptions includeAll=\(options.includeAllNetworks) excludeLocal=\(options.excludeLocalNetworks) excludeAPNs=\(options.excludeAPNs) excludeCellular=\(options.excludeCellularServices) enforceRoutes=\(options.enforceRoutes) excludeDeviceComm=\(options.excludeDeviceCommunication)")

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
    log("applyOnDemandRules excludeSSIDs=\(configuration.excludeSSIDs) enabled=\(manager.isOnDemandEnabled)")
  }

  private func registerTunnelStatusObserver() {
    loadManager(createIfNeeded: false) { manager, _ in
      guard let manager else {
        return
      }
      DispatchQueue.main.async {
        self.tunnelStatusObserver = NotificationCenter.default.addObserver(
          forName: .NEVPNStatusDidChange,
          object: manager.connection,
          queue: .main
        ) { [weak self] _ in
          self?.handleTunnelStatusDidChange()
        }
        self.lastTunnelStatus = manager.connection.status
      }
    }
  }

  private func handleTunnelStatusDidChange() {
    loadManager(createIfNeeded: false) { manager, _ in
      DispatchQueue.main.async {
        let status = manager?.connection.status ?? .invalid
        if self.lastTunnelStatus != status {
          self.handleTunnelStatus(status)
        }
      }
    }
  }

  private func handleTunnelStatus(_ status: NEVPNStatus) {
    let previousStatus = lastTunnelStatus
    lastTunnelStatus = status
    log("status changed \(statusDescription(previousStatus ?? .invalid)) -> \(statusDescription(status)) expectedStart=\(isTunnelStartExpected) expectedStop=\(isTunnelStopExpected)")

    if isConnectedTunnelStatus(status) {
      if !isTunnelStartExpected {
        log("tunnel started externally")
        sharedStateStore.saveRunTime()
        onExternalStart()
      }
      isTunnelStartExpected = false
      isTunnelStopExpected = false
      return
    }

    guard isTerminalTunnelStatus(status) else {
      return
    }

    if isTunnelStopExpected {
      isTunnelStopExpected = false
      isTunnelStartExpected = false
      return
    }

    guard let previousStatus,
          isActiveTunnelStatus(previousStatus) else {
      isTunnelStartExpected = false
      return
    }
    isTunnelStopExpected = false
    isTunnelStartExpected = false
    log("tunnel stopped externally")
    sharedStateStore.clearRunTime()
    onExternalStop()
  }

  private func isActiveTunnelStatus(_ status: NEVPNStatus) -> Bool {
    switch status {
    case .connecting, .connected, .reasserting, .disconnecting:
      return true
    case .disconnected, .invalid:
      return false
    @unknown default:
      return false
    }
  }

  private func isConnectedTunnelStatus(_ status: NEVPNStatus) -> Bool {
    switch status {
    case .connected, .reasserting:
      return true
    case .connecting, .disconnecting, .disconnected, .invalid:
      return false
    @unknown default:
      return false
    }
  }

  private func isTerminalTunnelStatus(_ status: NEVPNStatus) -> Bool {
    switch status {
    case .disconnected, .invalid:
      return true
    case .connecting, .connected, .reasserting, .disconnecting:
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

  private func log(_ message: String) {
    NSLog("[TunnelController] %@", message)
  }
}

struct ProviderMessageError {
  let code: String
  let message: String
}
