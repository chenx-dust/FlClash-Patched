import Foundation
import NetworkExtension
import os

private struct ManagerLoadRequest {
  let createIfNeeded: Bool
  let continuation: CheckedContinuation<NETunnelProviderManager?, Error>
}

private enum ManagerCacheState {
  case unloaded
  case loading(
    id: UInt64,
    generation: UInt64,
    reloadCount: Int,
    requests: [ManagerLoadRequest]
  )
  case timedOut(id: UInt64, generation: UInt64)
  case loaded(NETunnelProviderManager?)
}

private enum ManagerLoadError: LocalizedError {
  case invalidatedRepeatedly
  case timedOut

  var errorDescription: String? {
    switch self {
    case .invalidatedRepeatedly:
      return "Network Extension manager changed repeatedly while loading"
    case .timedOut:
      return "Timed out while loading Network Extension preferences"
    }
  }
}

@MainActor
final class TunnelManagerStore {
  private let sharedStateStore: SharedStateStore
  private let networkExtensionIdentifier: String
  private let localizedDescription: String
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.follow.clash",
    category: "TunnelManagerStore"
  )
  private let loadTimeout: TimeInterval = 5
  private let maxInvalidationReloadCount = 1

  private var cacheGeneration: UInt64 = 0
  private var cacheState = ManagerCacheState.unloaded
  private var nextLoadID: UInt64 = 0
  private var loadTimeoutWork: DispatchWorkItem?

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
      let request = ManagerLoadRequest(
        createIfNeeded: createIfNeeded,
        continuation: continuation
      )
      switch cacheState {
      case .unloaded:
        startManagerLoad(requests: [request], reloadCount: 0)
      case .loading(
        let id,
        let generation,
        let reloadCount,
        var requests
      ):
        requests.append(request)
        cacheState = .loading(
          id: id,
          generation: generation,
          reloadCount: reloadCount,
          requests: requests
        )
      case .timedOut:
        // The system load cannot be cancelled. Its late callback must retire
        // before another load is allowed onto ne_session queue.
        continuation.resume(throwing: ManagerLoadError.timedOut)
      case .loaded(let cachedManager):
        if let cachedManager {
          continuation.resume(returning: cachedManager)
        } else if createIfNeeded {
          let manager = makeManager()
          cacheState = .loaded(manager)
          continuation.resume(returning: manager)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  @discardableResult
  func invalidateCachedManager(forPreferenceError error: Error) -> Bool {
    guard isRetryablePreferenceError(error) else {
      return false
    }
    cacheGeneration &+= 1
    if case .loaded = cacheState {
      cacheState = .unloaded
    }
    log("invalidate manager generation=\(cacheGeneration)")
    return true
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

  func isCachedConnection(_ connection: NEVPNConnection) -> Bool {
    guard case .loaded(let manager) = cacheState,
      let manager
    else {
      return false
    }
    return manager.connection === connection
  }

  private func isRetryablePreferenceError(_ error: Error) -> Bool {
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

  private func startManagerLoad(
    requests: [ManagerLoadRequest],
    reloadCount: Int
  ) {
    nextLoadID &+= 1
    let loadID = nextLoadID
    let generation = cacheGeneration
    cacheState = .loading(
      id: loadID,
      generation: generation,
      reloadCount: reloadCount,
      requests: requests
    )

    let timeoutWork = DispatchWorkItem { [weak self] in
      self?.handleManagerLoadTimeout(loadID: loadID)
    }
    loadTimeoutWork?.cancel()
    loadTimeoutWork = timeoutWork
    DispatchQueue.main.asyncAfter(
      deadline: .now() + loadTimeout,
      execute: timeoutWork
    )
    log(
      "loadManager begin id=\(loadID) generation=\(generation) reload=\(reloadCount) requests=\(requests.count)"
    )

    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      DispatchQueue.main.async {
        self.finishManagerLoad(
          loadID: loadID,
          managers: managers,
          error: error
        )
      }
    }
  }

  private func finishManagerLoad(
    loadID: UInt64,
    managers: [NETunnelProviderManager]?,
    error: Error?
  ) {
    if case .timedOut(
      let activeLoadID,
      let generation
    ) = cacheState,
      activeLoadID == loadID
    {
      finishTimedOutManagerLoad(
        generation: generation,
        managers: managers,
        error: error
      )
      return
    }

    guard case .loading(
      let activeLoadID,
      let generation,
      let reloadCount,
      let requests
    ) = cacheState,
      activeLoadID == loadID
    else {
      return
    }
    loadTimeoutWork?.cancel()
    loadTimeoutWork = nil

    if let error {
      cacheState = .unloaded
      log("loadManager failed: \(error.localizedDescription)")
      resume(requests, throwing: error)
      return
    }

    guard generation == cacheGeneration else {
      guard reloadCount < maxInvalidationReloadCount else {
        cacheState = .unloaded
        let error = ManagerLoadError.invalidatedRepeatedly
        log("loadManager stopped after repeated invalidation")
        resume(requests, throwing: error)
        return
      }
      log(
        "loadManager reload invalidated generation=\(generation)->\(cacheGeneration)"
      )
      startManagerLoad(
        requests: requests,
        reloadCount: reloadCount + 1
      )
      return
    }

    let loadedManager = managers?.first(where: isManagedManager)
    let needsManager = requests.contains { $0.createIfNeeded }
    let createdManager = loadedManager == nil && needsManager
      ? makeManager()
      : nil
    let manager = loadedManager ?? createdManager
    cacheState = .loaded(manager)

    if manager == nil {
      log("loadManager manager not found")
    }

    for request in requests {
      let requestManager = loadedManager ??
        (request.createIfNeeded ? createdManager : nil)
      request.continuation.resume(returning: requestManager)
    }
  }

  private func handleManagerLoadTimeout(loadID: UInt64) {
    guard case .loading(
      let activeLoadID,
      let generation,
      _,
      let requests
    ) = cacheState,
      activeLoadID == loadID
    else {
      return
    }
    loadTimeoutWork = nil
    cacheState = .timedOut(
      id: loadID,
      generation: generation
    )
    let error = ManagerLoadError.timedOut
    log("loadManager timeout id=\(loadID) requests=\(requests.count)")
    resume(requests, throwing: error)
  }

  private func finishTimedOutManagerLoad(
    generation: UInt64,
    managers: [NETunnelProviderManager]?,
    error: Error?
  ) {
    guard error == nil,
      generation == cacheGeneration
    else {
      cacheState = .unloaded
      log("loadManager late result discarded")
      return
    }
    let manager = managers?.first(where: isManagedManager)
    cacheState = .loaded(manager)
    log("loadManager late result adopted manager=\(manager != nil)")
  }

  private func resume(
    _ requests: [ManagerLoadRequest],
    throwing error: Error
  ) {
    for request in requests {
      request.continuation.resume(throwing: error)
    }
  }

  private func isManagedManager(_ manager: NETunnelProviderManager) -> Bool {
    guard
      let proto = manager.protocolConfiguration
        as? NETunnelProviderProtocol
    else {
      return false
    }
    return proto.providerBundleIdentifier == networkExtensionIdentifier
  }

  private func makeManager() -> NETunnelProviderManager {
    log("loadManager create manager")
    let manager = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = networkExtensionIdentifier
    proto.serverAddress = localizedDescription
    manager.protocolConfiguration = proto
    manager.localizedDescription = localizedDescription
    manager.isEnabled = true
    return manager
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
