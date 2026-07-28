import Foundation
import NetworkExtension

final class TunnelCoordinator {
  private let sharedStateStore: SharedStateStore
  private let managerStore: TunnelManagerStore
  private let onExternalStart: () -> Void
  private let onExternalStop: () -> Void
  private let connectTimeout: TimeInterval = 5

  private var observedTunnelStatus: NEVPNStatus?
  private var publishedTunnelState: TunnelTarget?

  private var requestGeneration: UInt64 = 0
  private var tunnelRequest: TunnelRequest?
  private var tunnelWait: TunnelWait?
  private var isCoordinatorRunning = false

  private var configurationCompletions: [(Error?) -> Void] = []
  private var needsStatusRefresh = false
  private var statusRefreshShouldNotify = false

  init(
    sharedStateStore: SharedStateStore,
    managerStore: TunnelManagerStore,
    onExternalStart: @escaping () -> Void,
    onExternalStop: @escaping () -> Void
  ) {
    self.sharedStateStore = sharedStateStore
    self.managerStore = managerStore
    self.onExternalStart = onExternalStart
    self.onExternalStop = onExternalStop
  }

  deinit {
    tunnelWait?.timeoutWork?.cancel()
  }

  func submitTunnelRequest(
    target: TunnelTarget,
    completion: @escaping (Bool) -> Void
  ) {
    onMain {
      if let request = self.tunnelRequest,
        request.target == target
      {
        self.log("merge \(target.description) request")
        request.completions.append(completion)
        return
      }

      let supersededCompletions = self.tunnelRequest?.completions ?? []
      self.requestGeneration &+= 1
      let request = TunnelRequest(
        generation: self.requestGeneration,
        target: target,
        completion: completion
      )
      self.tunnelRequest = request
      self.publishedTunnelState = target
      self.cancelTunnelWait()
      self.log(
        "request target=\(target.description) generation=\(request.generation)"
      )

      for supersededCompletion in supersededCompletions {
        supersededCompletion(false)
      }
      self.driveCoordinator()
    }
  }

  func reloadOnDemandRules(completion: @escaping (Error?) -> Void) {
    onMain {
      self.configurationCompletions.append(completion)
      self.driveCoordinator()
    }
  }

  func requestStatusRefresh(notifyExternal: Bool) {
    needsStatusRefresh = true
    statusRefreshShouldNotify =
      statusRefreshShouldNotify || notifyExternal
    driveCoordinator()
  }

  func handleTunnelStatusNotification(_ notification: Notification) {
    guard let connection = notification.object as? NEVPNConnection,
      managerStore.isManagedConnection(connection)
    else {
      return
    }

    if let wait = tunnelWait,
      wait.manager.connection === connection
    {
      recordObservedTunnelStatus(
        connection.status,
        notifyExternal: false
      )
      return
    }
    requestStatusRefresh(notifyExternal: true)
  }

  private func driveCoordinator() {
    guard !isCoordinatorRunning else {
      return
    }
    isCoordinatorRunning = true
    Task { @MainActor [weak self] in
      await self?.runCoordinator()
    }
  }

  @MainActor
  private func runCoordinator() async {
    while true {
      if let request = tunnelRequest {
        await reconcileTunnel(request)
        continue
      }

      if !configurationCompletions.isEmpty {
        let completions = configurationCompletions
        configurationCompletions.removeAll()
        let error = await performOnDemandRulesReload()
        for completion in completions {
          completion(error)
        }
        continue
      }

      if needsStatusRefresh {
        let notifyExternal = statusRefreshShouldNotify
        needsStatusRefresh = false
        statusRefreshShouldNotify = false
        await performStatusRefresh(notifyExternal: notifyExternal)
        continue
      }

      isCoordinatorRunning = false
      return
    }
  }

  @MainActor
  private func reconcileTunnel(_ request: TunnelRequest) async {
    while isCurrent(request) {
      do {
        switch request.target {
        case .running:
          try await reconcileRunningTunnel(request)
        case .stopped:
          try await reconcileStoppedTunnel(request)
        }
        return
      } catch {
        guard isCurrent(request) else {
          return
        }
        let status = observedTunnelStatus
        if request.preferenceRetryCount == 0,
          managerStore.isRetryablePreferenceError(error)
        {
          request.preferenceRetryCount += 1
          log(
            "\(request.target.description) retry preferences: \(error.localizedDescription)"
          )
          continue
        }
        log(
          "\(request.target.description) failed: \(error.localizedDescription)"
        )
        finishTunnelRequest(
          request,
          actualState: inferredFailureState(
            for: request.target,
            status: status
          ),
          success: false
        )
        return
      }
    }
  }

  @MainActor
  private func reconcileRunningTunnel(
    _ request: TunnelRequest
  ) async throws {
    while isCurrent(request) {
      let loadedManager = try await managerStore.loadManager()
      guard isCurrent(request) else {
        return
      }
      guard let manager = loadedManager else {
        finishTunnelRequest(request, actualState: .stopped, success: false)
        return
      }

      let status = manager.connection.status
      recordObservedTunnelStatus(status, notifyExternal: false)
      if status.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return
      }
      if status.tunnelState == nil {
        guard await settleBeforeStart(manager: manager, request: request) else {
          return
        }
        continue
      }

      manager.isEnabled = true
      managerStore.applyNetworkExtensionOptions(to: manager)
      log("start save preferences")
      do {
        try await awaitPreferenceResult { completion in
          manager.saveToPreferences(completionHandler: completion)
        }
      } catch {
        guard isCurrent(request) else {
          return
        }
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }
      guard isCurrent(request) else {
        return
      }

      log("start reload preferences")
      do {
        try await awaitPreferenceResult { completion in
          manager.loadFromPreferences(completionHandler: completion)
        }
      } catch {
        guard isCurrent(request) else {
          return
        }
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }
      guard isCurrent(request) else {
        return
      }

      let preparedStatus = manager.connection.status
      recordObservedTunnelStatus(preparedStatus, notifyExternal: false)
      if preparedStatus.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return
      }
      if preparedStatus.tunnelState == nil {
        guard await settleBeforeStart(manager: manager, request: request) else {
          return
        }
        continue
      }

      sharedStateStore.clearRunTime()
      do {
        try manager.connection.startVPNTunnel()
        log("start requested")
      } catch {
        if finishRunningRequestIfSatisfied(request, manager: manager) {
          return
        }
        throw error
      }

      let result = await waitForTunnelStatus(
        manager: manager,
        request: request,
        purpose: .starting
      )
      guard isCurrent(request) else {
        return
      }
      switch result {
      case .status(let status):
        finishTunnelRequest(
          request,
          actualState: status.tunnelState ?? .stopped,
          success: status.tunnelState == .running
        )
      case .timeout(let status):
        cleanUpFailedStart(manager: manager, status: status)
        finishTunnelRequest(request, actualState: .stopped, success: false)
      case .superseded:
        return
      }
      return
    }
  }

  @MainActor
  private func settleBeforeStart(
    manager: NETunnelProviderManager,
    request: TunnelRequest
  ) async -> Bool {
    let result = await waitForTunnelStatus(
      manager: manager,
      request: request,
      purpose: .settleThenStart
    )
    guard isCurrent(request) else {
      return false
    }
    switch result {
    case .status(let status):
      if status.tunnelState == .running {
        finishTunnelRequest(request, actualState: .running)
        return false
      }
      return true
    case .timeout(let status):
      cleanUpFailedStart(manager: manager, status: status)
      finishTunnelRequest(request, actualState: .stopped, success: false)
      return false
    case .superseded:
      return false
    }
  }

  @MainActor
  private func reconcileStoppedTunnel(
    _ request: TunnelRequest
  ) async throws {
    guard
      let manager = try await managerStore.loadManager(
        createIfNeeded: false
      )
    else {
      finishTunnelRequest(request, actualState: .stopped)
      return
    }
    guard isCurrent(request) else {
      return
    }

    let status = manager.connection.status
    recordObservedTunnelStatus(status, notifyExternal: false)
    if status.tunnelState == .stopped {
      finishTunnelRequest(request, actualState: .stopped)
      return
    }

    if status != .disconnecting {
      manager.connection.stopVPNTunnel()
      log("stop requested from Network Extension")
    }
    let result = await waitForTunnelStatus(
      manager: manager,
      request: request,
      purpose: .stopping
    )
    guard isCurrent(request) else {
      return
    }
    switch result {
    case .status(let status):
      finishTunnelRequest(
        request,
        actualState: status.tunnelState ?? .running,
        success: status.tunnelState == .stopped
      )
    case .timeout(let status):
      finishTunnelRequest(
        request,
        actualState: inferredFailureState(for: .stopped, status: status),
        success: false
      )
    case .superseded:
      return
    }
  }

  @MainActor
  private func waitForTunnelStatus(
    manager: NETunnelProviderManager,
    request: TunnelRequest,
    purpose: TunnelWaitPurpose
  ) async -> TunnelWaitResult {
    await withCheckedContinuation { continuation in
      let wait = TunnelWait(
        request: request,
        purpose: purpose,
        manager: manager,
        continuation: continuation
      )
      let timeoutWork = DispatchWorkItem { [weak self, weak wait] in
        guard let self,
          let wait,
          self.tunnelWait === wait
        else {
          return
        }
        let status = wait.manager.connection.status
        self.recordObservedTunnelStatus(status, notifyExternal: false)
        guard self.tunnelWait === wait else {
          return
        }
        self.log(
          "wait timeout purpose=\(wait.purpose.description) status=\(self.statusDescription(status))"
        )
        self.resolveTunnelWait(wait, result: .timeout(status))
      }
      wait.timeoutWork = timeoutWork
      tunnelWait = wait
      DispatchQueue.main.asyncAfter(
        deadline: .now() + connectTimeout,
        execute: timeoutWork
      )
      consumeWaitStatus(manager.connection.status)
    }
  }

  private func consumeWaitStatus(_ status: NEVPNStatus) {
    guard let wait = tunnelWait,
      isCurrent(wait.request)
    else {
      return
    }
    switch wait.purpose {
    case .starting:
      if status.tunnelState == .running {
        resolveTunnelWait(wait, result: .status(status))
        return
      }
      if status.isLifecycleActive {
        wait.hasObservedProgress = true
      }
      if status.isTerminal && wait.hasObservedProgress {
        resolveTunnelWait(wait, result: .status(status))
      }
    case .stopping:
      if status.isTerminal {
        resolveTunnelWait(wait, result: .status(status))
      }
    case .settleThenStart:
      if status.tunnelState != nil {
        resolveTunnelWait(wait, result: .status(status))
      }
    }
  }

  private func resolveTunnelWait(
    _ wait: TunnelWait,
    result: TunnelWaitResult
  ) {
    guard tunnelWait === wait else {
      return
    }
    tunnelWait = nil
    wait.timeoutWork?.cancel()
    wait.continuation.resume(returning: result)
  }

  private func cancelTunnelWait() {
    guard let wait = tunnelWait else {
      return
    }
    resolveTunnelWait(wait, result: .superseded)
  }

  private func cleanUpFailedStart(
    manager: NETunnelProviderManager,
    status: NEVPNStatus
  ) {
    if status.isLifecycleActive && status != .disconnecting {
      manager.connection.stopVPNTunnel()
      log("failed start requested cleanup stop")
    }
  }

  private func finishRunningRequestIfSatisfied(
    _ request: TunnelRequest,
    manager: NETunnelProviderManager
  ) -> Bool {
    let status = manager.connection.status
    recordObservedTunnelStatus(status, notifyExternal: false)
    guard status.tunnelState == .running else {
      return false
    }
    finishTunnelRequest(request, actualState: .running)
    return true
  }

  private func finishTunnelRequest(
    _ request: TunnelRequest,
    actualState: TunnelTarget,
    success: Bool? = nil
  ) {
    guard isCurrent(request) else {
      return
    }
    tunnelRequest = nil
    publishedTunnelState = actualState
    applyRunTime(for: actualState)
    let succeeded = success ?? (actualState == request.target)
    log(
      "\(request.target.description) completed success=\(succeeded) actual=\(actualState.description) generation=\(request.generation)"
    )

    for completion in request.completions {
      completion(succeeded)
    }

    let clientState: TunnelTarget =
      request.target == .running && succeeded ? .running : .stopped
    guard actualState != request.target || actualState != clientState else {
      return
    }
    DispatchQueue.main.async {
      guard self.requestGeneration == request.generation,
        self.tunnelRequest == nil,
        self.publishedTunnelState == actualState
      else {
        return
      }
      self.notifyExternalState(actualState)
    }
  }

  private func isCurrent(_ request: TunnelRequest) -> Bool {
    tunnelRequest === request && requestGeneration == request.generation
  }

  @MainActor
  private func performOnDemandRulesReload() async -> Error? {
    var allowPreferenceRetry = true
    while true {
      do {
        guard
          let manager = try await managerStore.loadManager(
            createIfNeeded: false
          )
        else {
          return nil
        }
        managerStore.applyNetworkExtensionOptions(to: manager)
        try await awaitPreferenceResult { completion in
          manager.saveToPreferences(completionHandler: completion)
        }
        return nil
      } catch {
        log(
          "reloadOnDemandRules save failed: \(error.localizedDescription)"
        )
        guard allowPreferenceRetry,
          managerStore.isRetryablePreferenceError(error)
        else {
          return error
        }
        allowPreferenceRetry = false
        log("reloadOnDemandRules retry preferences")
      }
    }
  }

  @MainActor
  private func performStatusRefresh(notifyExternal: Bool) async {
    do {
      let manager = try await managerStore.loadManager(createIfNeeded: false)
      recordObservedTunnelStatus(
        manager?.connection.status ?? .invalid,
        notifyExternal: notifyExternal
      )
    } catch {
      log("refresh status failed: \(error.localizedDescription)")
    }
  }

  private func recordObservedTunnelStatus(
    _ status: NEVPNStatus,
    notifyExternal: Bool
  ) {
    let previousStatus = observedTunnelStatus
    observedTunnelStatus = status
    if previousStatus != status {
      log(
        "status changed \(statusDescription(previousStatus ?? .invalid)) -> \(statusDescription(status)) target=\(tunnelRequest?.target.description ?? "none")"
      )
    }

    if tunnelWait != nil {
      consumeWaitStatus(status)
      return
    }
    guard tunnelRequest == nil,
      let stableState = status.tunnelState
    else {
      return
    }
    if notifyExternal {
      publishExternalState(stableState)
    } else if publishedTunnelState == nil {
      publishedTunnelState = stableState
      applyRunTime(for: stableState)
    }
  }

  private func publishExternalState(_ state: TunnelTarget) {
    applyRunTime(for: state)
    guard publishedTunnelState != state else {
      return
    }
    publishedTunnelState = state
    notifyExternalState(state)
  }

  private func notifyExternalState(_ state: TunnelTarget) {
    switch state {
    case .running:
      log("tunnel started externally")
      onExternalStart()
    case .stopped:
      log("tunnel stopped externally")
      onExternalStop()
    }
  }

  private func applyRunTime(for state: TunnelTarget) {
    switch state {
    case .running:
      if sharedStateStore.runTime() == 0 {
        sharedStateStore.saveRunTime()
      }
    case .stopped:
      sharedStateStore.clearRunTime()
    }
  }

  private func awaitPreferenceResult(
    _ action: (@escaping @Sendable (Error?) -> Void) -> Void
  ) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      action { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }

  private func inferredFailureState(
    for target: TunnelTarget,
    status: NEVPNStatus?
  ) -> TunnelTarget {
    if let status,
      let stableState = status.tunnelState
    {
      return stableState
    }
    guard target == .stopped else {
      return .stopped
    }
    return status == .disconnecting ? .stopped : .running
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

  private func onMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread {
      action()
    } else {
      DispatchQueue.main.async(execute: action)
    }
  }

  private func log(_ message: String) {
    NSLog("[TunnelController] %@", message)
  }
}
