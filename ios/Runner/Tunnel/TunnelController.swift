import Foundation
import NetworkExtension
import UIKit

final class TunnelController {
  private let sharedStateStore: SharedStateStore
  private let managerStore: TunnelManagerStore
  private let coordinator: TunnelCoordinator

  private var tunnelStatusObserver: NSObjectProtocol?
  private var appActiveObserver: NSObjectProtocol?

  init(
    sharedStateStore: SharedStateStore,
    onExternalStart: @escaping () -> Void,
    onExternalStop: @escaping () -> Void
  ) {
    let networkExtensionIdentifier =
      "\(Bundle.main.bundleIdentifier!).NECore"
    let managerStore = TunnelManagerStore(
      sharedStateStore: sharedStateStore,
      networkExtensionIdentifier: networkExtensionIdentifier,
      localizedDescription: "FlClash"
    )
    self.sharedStateStore = sharedStateStore
    self.managerStore = managerStore
    coordinator = TunnelCoordinator(
      sharedStateStore: sharedStateStore,
      managerStore: managerStore,
      onExternalStart: onExternalStart,
      onExternalStop: onExternalStop
    )
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
    onMain {
      if self.tunnelStatusObserver == nil {
        self.tunnelStatusObserver = NotificationCenter.default.addObserver(
          forName: .NEVPNStatusDidChange,
          object: nil,
          queue: .main
        ) { [weak self] notification in
          self?.coordinator.handleTunnelStatusNotification(notification)
        }
      }
      if self.appActiveObserver == nil {
        self.appActiveObserver = NotificationCenter.default.addObserver(
          forName: UIApplication.didBecomeActiveNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          self?.coordinator.requestStatusRefresh(notifyExternal: true)
        }
      }
      self.coordinator.requestStatusRefresh(notifyExternal: false)
    }
  }

  func start(completion: @escaping (Bool) -> Void) {
    coordinator.submitTunnelRequest(
      target: .running,
      completion: completion
    )
  }

  func stop(completion: @escaping (Bool) -> Void) {
    coordinator.submitTunnelRequest(
      target: .stopped,
      completion: completion
    )
  }

  func reloadOnDemandRules(completion: @escaping (Error?) -> Void) {
    coordinator.reloadOnDemandRules(completion: completion)
  }

  func sendProviderMessage(
    _ data: Data,
    completion: @escaping (String?, ProviderMessageError?) -> Void
  ) {
    managerStore.loadManager(createIfNeeded: false) { manager, error in
      if let error {
        self.log(
          "sendProviderMessage failed load manager: \(error.localizedDescription)"
        )
        completion(
          nil,
          ProviderMessageError(
            code: "network_extension_error",
            message: error.localizedDescription
          )
        )
        return
      }
      guard let session = manager?.connection as? NETunnelProviderSession else {
        self.log("sendProviderMessage failed: session not found")
        completion(
          nil,
          ProviderMessageError(
            code: "network_extension_unavailable",
            message: "network extension session not found"
          )
        )
        return
      }
      do {
        self.log("sendProviderMessage to NECore")
        try session.sendProviderMessage(data) { response in
          guard let response,
            let message = String(data: response, encoding: .utf8)
          else {
            self.log("sendProviderMessage empty response")
            completion(nil, nil)
            return
          }
          self.log("sendProviderMessage response bytes=\(response.count)")
          completion(message, nil)
        }
      } catch {
        self.log("sendProviderMessage failed: \(error.localizedDescription)")
        completion(
          nil,
          ProviderMessageError(
            code: "network_extension_error",
            message: error.localizedDescription
          )
        )
      }
    }
  }

  func isCoreActive(completion: @escaping (Bool) -> Void) {
    managerStore.loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      completion(status.tunnelState == .running)
    }
  }

  func getRunTime(completion: @escaping (Int) -> Void) {
    managerStore.loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      guard status.tunnelState == .running else {
        completion(0)
        return
      }
      completion(self.sharedStateStore.runTime())
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
