import Foundation
import NetworkExtension
import Shared
import UIKit
import os

@MainActor
final class TunnelController {
  private let sharedStateStore: SharedStateStore
  private let managerStore: TunnelManagerStore
  private let coordinator: TunnelCoordinator
  private let onSessionChanged: (NETunnelProviderSession?) -> Void

  private var tunnelStatusObserver: NSObjectProtocol?
  private var appActiveObserver: NSObjectProtocol?
  private var sessionGeneration: UInt64 = 0
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "",
    category: "TunnelController"
  )

  init(
    sharedStateStore: SharedStateStore,
    onSessionChanged: @escaping (NETunnelProviderSession?) -> Void,
    onExternalStart: @escaping () -> Void,
    onStopped: @escaping () -> Void
  ) {
    let managerStore = TunnelManagerStore(
      networkExtensionIdentifier: NEHelper.providerBundleIdentifier,
      localizedDescription: "FlClash"
    )
    self.sharedStateStore = sharedStateStore
    self.managerStore = managerStore
    self.onSessionChanged = onSessionChanged
    var stateChanged: (TunnelTarget) -> Void = { _ in }
    coordinator = TunnelCoordinator(
      managerStore: managerStore,
      onTunnelStateChanged: { stateChanged($0) },
      onExternalStart: onExternalStart,
      onExternalStop: onStopped
    )
    stateChanged = { [weak self] state in
      self?.updateSession(for: state)
    }
  }

  deinit {
    for observer in [tunnelStatusObserver, appActiveObserver].compactMap({ $0 }) {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  var isRunRequested: Bool {
    coordinator.isRunRequested
  }

  func startObserving() {
    if tunnelStatusObserver == nil {
      tunnelStatusObserver = NotificationCenter.default.addObserver(
        forName: .NEVPNStatusDidChange,
        object: nil,
        queue: .main
      ) { [weak self] notification in
        MainActor.assumeIsolated {
          self?.handleStatusNotification(notification)
        }
      }
    }
    if appActiveObserver == nil {
      appActiveObserver = NotificationCenter.default.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.coordinator.requestStatusRefresh(notifyExternal: true)
        }
      }
    }
    coordinator.requestStatusRefresh(notifyExternal: false)
  }

  func start() {
    coordinator.submitTunnelRequest(target: .running)
  }

  func stop() {
    coordinator.submitTunnelRequest(target: .stopped)
  }

  // Asked right after launch, before the first status refresh has settled an
  // intent, so the tunnel itself answers unless a request says otherwise.
  func getRunTime() async -> Int {
    guard coordinator.requestedTarget != .stopped,
      await isTunnelRunning(),
      coordinator.requestedTarget != .stopped
    else {
      return 0
    }
    return sharedStateStore.runTime()
  }

  private func isTunnelRunning() async -> Bool {
    do {
      let manager = try await managerStore.loadManager(createIfNeeded: false)
      return manager?.connection.status.tunnelState == .running
    } catch {
      log("load manager failed: \(error.localizedDescription)")
      return false
    }
  }

  // A restart replaces the extension's Core without the coordinator ever
  // settling on stopped, so the route follows every stop the system reports.
  private func handleStatusNotification(_ notification: Notification) {
    coordinator.handleTunnelStatusNotification(notification)
    guard let connection = notification.object as? NEVPNConnection,
      managerStore.isManagedConnection(connection),
      let state = connection.status.tunnelState
    else {
      return
    }
    updateSession(for: state)
  }

  // A later state supersedes a session lookup still loading for an earlier one.
  private func updateSession(for state: TunnelTarget) {
    sessionGeneration &+= 1
    guard state == .running else {
      onSessionChanged(nil)
      return
    }
    let generation = sessionGeneration
    Task {
      let manager = try? await managerStore.loadManager(createIfNeeded: false)
      guard generation == sessionGeneration else {
        return
      }
      onSessionChanged(manager?.connection as? NETunnelProviderSession)
    }
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
