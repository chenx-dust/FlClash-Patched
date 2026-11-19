import ClashCore
import Foundation
import NetworkExtension
import WidgetKit
import os

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let sharedStateStore = PacketTunnelSharedStateStore()
  private let networkConfiguration = PacketTunnelNetworkConfiguration()
  private lazy var eventQueue = NECoreEventQueue(
    sharedStateStore: sharedStateStore
  )
  private let networkQueue = DispatchQueue(label: "NECoreNetworkObserver")
  private var defaultPathObservation: NSKeyValueObservation?
  private var pendingNetworkReset: DispatchWorkItem?
  private var lastSatisfiedPath: NWPath?
  private var observingNetwork = false
  private var memoryPressureSource: DispatchSourceMemoryPressure?
  private let logger = Logger(
    subsystem: PacketTunnelEnvironment.extensionBundleIdentifier,
    category: "PacketTunnelProvider"
  )

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    logger.info("startTunnel begin")
    sharedStateStore.clearRunTime()
    reloadControls()
    guard let vpnOptions = sharedStateStore.loadVPNOptions(),
      let setupParams = sharedStateStore.loadSetupParams()
    else {
      logger.error("startTunnel failed: missing shared state")
      completionHandler(PacketTunnelProviderError.missingConfiguration)
      return
    }
    logger.info(
      "startTunnel stack=\(vpnOptions.stack, privacy: .public) ipv6=\(vpnOptions.ipv6, privacy: .public) dnsHijacking=\(vpnOptions.dnsHijacking, privacy: .public) systemProxy=\(vpnOptions.systemProxy, privacy: .public)"
    )

    setTunnelNetworkSettings(
      networkConfiguration.makeSettings(for: vpnOptions)
    ) { error in
      if let error {
        self.logger.error(
          "setTunnelNetworkSettings failed: \(error.localizedDescription, privacy: .public)"
        )
        completionHandler(error)
        return
      }
      guard
        let fileDescriptor = self.networkConfiguration.tunnelFileDescriptor()
      else {
        completionHandler(PacketTunnelProviderError.missingFileDescriptor)
        return
      }
      self.eventQueue.start()
      self.watchMemoryPressure()
      MobileQuickSetup(
        self.sharedStateStore.makeInitParams(),
        setupParams,
        CoreResultHandler { result in
          let message = String(data: result, encoding: .utf8) ?? ""
          guard message.isEmpty else {
            self.logger.error(
              "quickSetup failed: \(message, privacy: .public)"
            )
            completionHandler(PacketTunnelProviderError.setupFailed(message))
            return
          }
          completionHandler(
            self.startTun(fileDescriptor: fileDescriptor, options: vpnOptions)
          )
        }
      )
    }
  }

  private func startTun(
    fileDescriptor: Int32,
    options: PacketTunnelVPNOptions
  ) -> Error? {
    let tunOptions: [String: Any] = [
      "mtu": options.tunMTU,
      "congestion-controller": options.congestionController,
    ]
    guard
      let tunOptionsData = try? JSONSerialization.data(withJSONObject: tunOptions)
    else {
      return PacketTunnelProviderError.tunRejected
    }
    let started = MobileStartTun(
      fileDescriptor,
      CoreTunHandler(),
      options.stack,
      networkConfiguration.tunAddress(for: options),
      networkConfiguration.tunDNS(for: options),
      String(data: tunOptionsData, encoding: .utf8)
    )
    logger.info("startTun result=\(started, privacy: .public)")
    guard started else {
      return PacketTunnelProviderError.tunRejected
    }
    sharedStateStore.saveRunTime()
    startNetworkObservation()
    reloadControls()
    return nil
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    logger.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
    sharedStateStore.clearRunTime()
    stopNetworkObservation()
    memoryPressureSource?.cancel()
    memoryPressureSource = nil
    MobileSetMitmPressure(MitmPressure.none.rawValue)
    eventQueue.stop()
    MobileStopTun()
    reloadControls()
    completionHandler()
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    eventQueue.markCoreResponsive()
    guard let completionHandler else {
      return
    }
    MobileInvokeMethod(
      String(data: messageData, encoding: .utf8),
      CoreResultHandler { response in
        completionHandler(response)
      }
    )
  }

  // jetsam ends the extension outright at its memory limit, with no
  // onTrimMemory to warn it first.
  private func watchMemoryPressure() {
    guard memoryPressureSource == nil else {
      return
    }
    let source = DispatchSource.makeMemoryPressureSource(
      eventMask: [.normal, .warning, .critical],
      queue: .global(qos: .utility)
    )
    source.setEventHandler { [weak source] in
      guard let event = source?.data else {
        return
      }
      if event.contains(.critical) {
        MobileSetMitmPressure(MitmPressure.relay.rawValue)
        MobileForceGC()
      } else if event.contains(.warning) {
        MobileSetMitmPressure(MitmPressure.noBodies.rawValue)
        MobileForceGC()
      } else if event.contains(.normal) {
        MobileSetMitmPressure(MitmPressure.none.rawValue)
      }
    }
    source.resume()
    memoryPressureSource = source
  }

  private func startNetworkObservation() {
    stopNetworkObservation()
    let initialPath = defaultPath
    networkQueue.sync {
      observingNetwork = true
      lastSatisfiedPath = initialPath?.status == .satisfied ? initialPath : nil
    }
    defaultPathObservation = observe(\.defaultPath, options: [.new]) {
      [weak self] _, _ in
      self?.scheduleNetworkReset()
    }
  }

  private func stopNetworkObservation() {
    defaultPathObservation?.invalidate()
    defaultPathObservation = nil
    networkQueue.sync {
      observingNetwork = false
      pendingNetworkReset?.cancel()
      pendingNetworkReset = nil
      lastSatisfiedPath = nil
    }
  }

  private func scheduleNetworkReset() {
    networkQueue.async { [weak self] in
      guard let self, self.observingNetwork else {
        return
      }
      self.pendingNetworkReset?.cancel()
      let item = DispatchWorkItem { [weak self] in
        guard let self, self.observingNetwork,
          let path = self.defaultPath, path.status == .satisfied
        else {
          return
        }
        if let previous = self.lastSatisfiedPath, !previous.isEqual(to: path) {
          self.logger.info("defaultPath changed; resetting core network")
          MobileResetNetwork()
        }
        self.lastSatisfiedPath = path
      }
      self.pendingNetworkReset = item
      self.networkQueue.asyncAfter(
        deadline: .now() + .milliseconds(200),
        execute: item
      )
    }
  }

  private func reloadControls() {
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(
        ofKind: PacketTunnelEnvironment.controlKind
      )
    }
  }
}

private enum MitmPressure: Int32 {
  case none = 0
  case noScripts = 1
  case noBodies = 2
  case relay = 3
}

private enum PacketTunnelProviderError: LocalizedError {
  case missingConfiguration
  case missingFileDescriptor
  case setupFailed(String)
  case tunRejected

  var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      return "No configuration found."
    case .missingFileDescriptor:
      return "Could not find the tunnel file descriptor."
    case .setupFailed(let message):
      return message
    case .tunRejected:
      return "Core rejected the tun file descriptor."
    }
  }
}
