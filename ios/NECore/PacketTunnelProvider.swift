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
  private let logger = Logger(
    subsystem: PacketTunnelEnvironment.extensionBundleIdentifier,
    category: "PacketTunnelProvider"
  )

  private var suspendSupport = true

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    logger.info("startTunnel begin")
    sharedStateStore.clearRunTime()
    reloadControlWidget()
    guard let vpnOptions = sharedStateStore.loadVPNOptions() else {
      logger.error("startTunnel failed: missing vpn options")
      completionHandler(PacketTunnelProviderError.missingVPNOptions)
      return
    }
    logger.info(
      "startTunnel options stack=\(vpnOptions.stack, privacy: .public) ipv6=\(vpnOptions.ipv6, privacy: .public) captureDns=\(vpnOptions.captureDns, privacy: .public) systemProxy=\(vpnOptions.systemProxy, privacy: .public) suspendSupport=\(vpnOptions.suspendSupport, privacy: .public)"
    )
    suspendSupport = vpnOptions.suspendSupport

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
      self.logger.info("setTunnelNetworkSettings completed")
      guard let tunnelFileDescriptor =
        self.networkConfiguration.tunnelFileDescriptor()
      else {
        self.logger.error(
          "startTunnel failed: tunnel file descriptor missing"
        )
        completionHandler(
          PacketTunnelProviderError.couldNotDetermineFileDescriptor
        )
        return
      }
      self.logger.debug(
        "startTunnel fileDescriptor=\(tunnelFileDescriptor, privacy: .public)"
      )
      self.eventQueue.start()
      let initParams = self.sharedStateStore.makeInitParams()
      let setupParams = self.sharedStateStore.loadSetupParams()
      self.logger.info(
        "quickSetup initParams=\(initParams, privacy: .public)"
      )
      NECoreBridge.quickSetup(
        withInitParams: initParams,
        setupParams: setupParams
      ) { result in
        if let result,
          !result.isEmpty
        {
          let message = String(data: result, encoding: .utf8) ??
            "unknown core error"
          self.logger.error(
            "quickSetup failed: \(message, privacy: .public)"
          )
          completionHandler(PacketTunnelProviderError.couldNotStartCoreTun)
          return
        }
        self.logger.info("quickSetup completed")
        let coreTunOptions = CoreTunOptions(
          stack: vpnOptions.stack,
          address: self.networkConfiguration.tunAddress(for: vpnOptions),
          dns: self.networkConfiguration.tunDNS(for: vpnOptions),
          mtu: vpnOptions.mtu,
          disableIcmpForwarding: vpnOptions.disableIcmpForwarding,
          endpointIndependentNat: vpnOptions.endpointIndependentNat
        )
        guard let coreTunOptionsData = try? JSONEncoder().encode(coreTunOptions)
        else {
          completionHandler(PacketTunnelProviderError.couldNotStartCoreTun)
          return
        }
        let started = NECoreBridge.startTun(
          withFileDescriptor: tunnelFileDescriptor,
          options: coreTunOptionsData
        )
        self.logger.info(
          "NECoreBridge.startTun result=\(started, privacy: .public)"
        )
        if started {
          self.sharedStateStore.saveRunTime()
        }
        completionHandler(
          started ? nil : PacketTunnelProviderError.couldNotStartCoreTun
        )
      }
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    logger.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
    sharedStateStore.clearRunTime()
    reloadControlWidget()
    eventQueue.stop()
    NECoreBridge.stopTun()
    guard reason == .userInitiated else {
      completionHandler()
      return
    }
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error {
        self.logger.error(
          "stopTunnel loadAllFromPreferences error=\(error.localizedDescription, privacy: .public)"
        )
        completionHandler()
        return
      }
      guard let manager = managers?.first(where: { manager in
        guard let proto = manager.protocolConfiguration
          as? NETunnelProviderProtocol
        else {
          return false
        }
        return proto.providerBundleIdentifier ==
          PacketTunnelEnvironment.extensionBundleIdentifier
      }) else {
        completionHandler()
        return
      }
      manager.isOnDemandEnabled = false
      manager.saveToPreferences { error in
        if let error {
          self.logger.error(
            "stopTunnel saveToPreferences error=\(error.localizedDescription, privacy: .public)"
          )
        }
        completionHandler()
      }
    }
  }

  override func handleAppMessage(
    _ messageData: Data,
    completionHandler: ((Data?) -> Void)?
  ) {
    logger.debug(
      "handleAppMessage bytes=\(messageData.count, privacy: .public)"
    )
    eventQueue.markCoreResponsive()
    guard let completionHandler else {
      logger.warning("handleAppMessage ignored: missing completion handler")
      return
    }

    NECoreBridge.invokeMethod(messageData) { response in
      guard let response else {
        self.logger.warning("handleAppMessage empty core response")
        completionHandler(
          self.methodErrorResponse(
            messageData: messageData,
            code: "empty_response",
            message: "empty core response"
          )
        )
        return
      }
      self.logger.debug(
        "handleAppMessage response bytes=\(response.count, privacy: .public)"
      )
      completionHandler(response)
    }
  }

  override func sleep(completionHandler: @escaping () -> Void) {
    if suspendSupport {
      logger.info("sleep: suspending tunnel")
      NECoreBridge.setSuspended(true)
    }
    completionHandler()
  }

  override func wake() {
    if suspendSupport {
      logger.info("wake: resuming tunnel")
      NECoreBridge.setSuspended(false)
    }
  }

  private func methodErrorResponse(
    messageData: Data,
    code: String,
    message: String
  ) -> Data? {
    var payload: [String: Any] = [
      "result": NSNull(),
      "error": [
        "code": code,
        "message": message,
        "details": NSNull(),
      ],
    ]
    if let id = methodCallID(messageData) {
      payload["id"] = id
    }
    return try? JSONSerialization.data(withJSONObject: payload)
  }

  private func methodCallID(_ messageData: Data) -> String? {
    guard let object = try? JSONSerialization.jsonObject(with: messageData)
      as? [String: Any]
    else {
      return nil
    }
    return object["id"] as? String
  }

  private func reloadControlWidget() {
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(
        ofKind: PacketTunnelEnvironment.widgetIdentifier
      )
    }
  }
}

private struct CoreTunOptions: Encodable {
  let stack: String
  let address: String
  let dns: String
  let mtu: Int
  let disableIcmpForwarding: Bool
  let endpointIndependentNat: Bool
}

private enum PacketTunnelProviderError: LocalizedError {
  case missingVPNOptions
  case couldNotDetermineFileDescriptor
  case couldNotStartCoreTun

  var errorDescription: String? {
    switch self {
    case .missingVPNOptions:
      return "missing VPN options"
    case .couldNotDetermineFileDescriptor:
      return "could not determine tunnel file descriptor"
    case .couldNotStartCoreTun:
      return "could not start core TUN"
    }
  }
}
