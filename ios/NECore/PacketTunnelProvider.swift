import NetworkExtension
import Darwin
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
  private static let extensionBundleId = Bundle.main.bundleIdentifier!
  private static let baseBundleId = String(extensionBundleId.dropLast(".NECore".count))

  private let logger = Logger(
    subsystem: PacketTunnelProvider.extensionBundleId,
    category: "PacketTunnelProvider"
  )
  private let sharedStateKey = "sharedState"
  private let appGroupIdentifier = "group.\(PacketTunnelProvider.baseBundleId)"
  private let eventQueueDirectoryName = "core-events"
  private let eventNotificationName = "\(PacketTunnelProvider.extensionBundleId).event"
  private let ipv4Address = "172.19.0.1"
  private let ipv4AddressPrefix = "172.19.0.1/30"
  private let ipv4SubnetMask = "255.255.255.252"
  private let ipv4Dns = "172.19.0.2"
  private let ipv6Address = "fdfe:dcba:9876::1"
  private let ipv6AddressPrefix = "fdfe:dcba:9876::1/126"
  private let ipv6Dns = "fdfe:dcba:9876::2"
  private let netAny = "0.0.0.0"
  private var suspendSupport = true

  private func log(_ message: String) {
    logger.notice("\(message, privacy: .public)")
  }

  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    log("startTunnel begin")
    guard let vpnOptions = loadSharedState()?.vpnOptions else {
      log("startTunnel failed: missing vpn options")
      completionHandler(PacketTunnelProviderError.missingVpnOptions)
      return
    }
    log("startTunnel options stack=\(vpnOptions.stack) ipv6=\(vpnOptions.ipv6) dnsHijacking=\(vpnOptions.dnsHijacking) systemProxy=\(vpnOptions.systemProxy) suspendSupport=\(vpnOptions.suspendSupport)")
    suspendSupport = vpnOptions.suspendSupport

    setTunnelNetworkSettings(makeNetworkSettings(vpnOptions: vpnOptions)) { error in
      if let error = error {
        self.log("setTunnelNetworkSettings failed: \(error.localizedDescription)")
        completionHandler(error)
        return
      }
      self.log("setTunnelNetworkSettings completed")
      guard let tunnelFileDescriptor = self.tunnelFileDescriptor else {
        self.log("startTunnel failed: tunnel file descriptor missing")
        completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
        return
      }
      self.log("startTunnel fileDescriptor=\(tunnelFileDescriptor)")
      self.installCoreEventListener()
      let started = NECoreBridge.startTun(
        withFileDescriptor: tunnelFileDescriptor,
        stack: vpnOptions.stack,
        address: self.tunAddress(vpnOptions: vpnOptions),
        dns: self.tunDns(vpnOptions: vpnOptions)
      )
      self.log("NECoreBridge.startTun result=\(started)")
      completionHandler(started ? nil : PacketTunnelProviderError.couldNotStartCoreTun)
    }
  }
  
  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    // Add code here to start the process of stopping the tunnel.
    log("stopTunnel reason=\(reason.rawValue)")
    NECoreBridge.setEventListener(nil)
    NECoreBridge.stopTun()
    completionHandler()
  }
  
  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    log("handleAppMessage bytes=\(messageData.count)")
    guard let handler = completionHandler else {
      log("handleAppMessage ignored: missing completion handler")
      return
    }

    guard let action = String(data: messageData, encoding: .utf8) else {
      log("handleAppMessage invalid action")
      handler(actionResult(messageData: nil, message: "invalid action"))
      return
    }

    NECoreBridge.invokeAction(action) { response in
      guard let response = response, let data = response.data(using: .utf8) else {
        self.log("handleAppMessage empty core response")
        handler(self.actionResult(messageData: messageData, message: "empty core response"))
        return
      }
      self.log("handleAppMessage response bytes=\(data.count)")
      handler(data)
    }
  }
  
  override func sleep(completionHandler: @escaping () -> Void) {
    if suspendSupport {
      log("sleep: suspending tunnel")
      NECoreBridge.setSuspended(true)
    }
    completionHandler()
  }

  override func wake() {
    if suspendSupport {
      log("wake: resuming tunnel")
      NECoreBridge.setSuspended(false)
    }
  }

  private func actionResult(messageData: Data?, message: String) -> Data? {
    var method = "message"
    var id: String?
    if let messageData,
       let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] {
      method = object["method"] as? String ?? method
      id = object["id"] as? String
    }
    var payload: [String: Any] = [
      "method": method,
      "data": message,
      "code": -1,
    ]
    if let id = id {
      payload["id"] = id
    }
    return try? JSONSerialization.data(withJSONObject: payload)
  }

  private var tunnelFileDescriptor: Int32? {
    var ctlInfo = ctl_info()
    withUnsafeMutablePointer(to: &ctlInfo.ctl_name) {
      $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
        _ = strcpy($0, "com.apple.net.utun_control")
      }
    }
    for fd: Int32 in 0...1024 {
      var addr = sockaddr_ctl()
      var ret: Int32 = -1
      var len = socklen_t(MemoryLayout.size(ofValue: addr))
      withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          ret = getpeername(fd, $0, &len)
        }
      }
      if ret != 0 || addr.sc_family != AF_SYSTEM {
        continue
      }
      if ctlInfo.ctl_id == 0 {
        ret = ioctl(fd, CTLIOCGINFO, &ctlInfo)
        if ret != 0 {
          continue
        }
      }
      if addr.sc_id == ctlInfo.ctl_id {
        return fd
      }
    }
    return nil
  }

  private func loadSharedState() -> SharedState? {
    guard let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: sharedStateKey) else {
      return nil
    }
    return try? JSONDecoder().decode(SharedState.self, from: data)
  }

  private func installCoreEventListener() {
    NECoreBridge.setEventListener { [weak self] event in
      guard let self = self, let event = event, !event.isEmpty else {
        return
      }
      self.enqueueCoreEvent(event)
    }
  }

  private func enqueueCoreEvent(_ event: String) {
    guard let directory = eventQueueDirectory() else {
      log("enqueueCoreEvent failed: missing event queue directory")
      return
    }
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
      let fileURL = directory.appendingPathComponent(
        "\(timestamp)-\(UUID().uuidString).json"
      )
      try event.write(to: fileURL, atomically: true, encoding: .utf8)
      notifyCoreEventAvailable()
    } catch {
      log("enqueueCoreEvent failed: \(error.localizedDescription)")
    }
  }

  private func eventQueueDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )?.appendingPathComponent(eventQueueDirectoryName, isDirectory: true)
  }

  private func notifyCoreEventAvailable() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(eventNotificationName as CFString),
      nil,
      nil,
      true
    )
  }

  private func makeNetworkSettings(vpnOptions: VpnOptions) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
    settings.mtu = NSNumber(value: 9000)

    let ipv4Settings = NEIPv4Settings(addresses: [ipv4Address], subnetMasks: [ipv4SubnetMask])
    let ipv4Routes = vpnOptions.routeAddress.compactMap { route -> NEIPv4Route? in
      guard route.contains("."),
          let cidr = CIDR(route),
          let subnetMask = ipv4SubnetMask(prefixLength: cidr.prefixLength) else {
        return nil
      }
      return NEIPv4Route(destinationAddress: cidr.address, subnetMask: subnetMask)
    }
    ipv4Settings.includedRoutes = ipv4Routes.isEmpty ? [.default()] : ipv4Routes
    settings.ipv4Settings = ipv4Settings

    if vpnOptions.ipv6 {
      let ipv6Settings = NEIPv6Settings(
        addresses: [ipv6Address],
        networkPrefixLengths: [NSNumber(value: 126)]
      )
      let ipv6Routes = vpnOptions.routeAddress.compactMap { route -> NEIPv6Route? in
        guard route.contains(":"),
            let cidr = CIDR(route) else {
          return nil
        }
        return NEIPv6Route(
          destinationAddress: cidr.address,
          networkPrefixLength: NSNumber(value: cidr.prefixLength)
        )
      }
      ipv6Settings.includedRoutes = ipv6Routes.isEmpty ? [.default()] : ipv6Routes
      settings.ipv6Settings = ipv6Settings
    }

    let dnsServers = vpnOptions.ipv6 ? [ipv4Dns, ipv6Dns] : [ipv4Dns]
    let dnsSettings = NEDNSSettings(servers: dnsServers)
    if vpnOptions.dnsHijacking {
      dnsSettings.matchDomains = [""]
    }
    settings.dnsSettings = dnsSettings

    if vpnOptions.systemProxy {
      let proxySettings = NEProxySettings()
      proxySettings.httpEnabled = true
      proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: vpnOptions.port)
      proxySettings.httpsEnabled = true
      proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: vpnOptions.port)
      proxySettings.exceptionList = vpnOptions.bypassDomain
      settings.proxySettings = proxySettings
    }

    log("makeNetworkSettings settings=\(settings)")

    return settings
  }

  private func tunAddress(vpnOptions: VpnOptions) -> String {
    vpnOptions.ipv6 ? "\(ipv4AddressPrefix),\(ipv6AddressPrefix)" : ipv4AddressPrefix
  }

  private func tunDns(vpnOptions: VpnOptions) -> String {
    if vpnOptions.dnsHijacking {
      return netAny
    }
    return vpnOptions.ipv6 ? "\(ipv4Dns),\(ipv6Dns)" : ipv4Dns
  }

  private func ipv4SubnetMask(prefixLength: Int) -> String? {
    guard (0...32).contains(prefixLength) else {
      return nil
    }
    let mask = prefixLength == 0 ? 0 : UInt32.max << UInt32(32 - prefixLength)
    return [
      (mask >> 24) & 0xff,
      (mask >> 16) & 0xff,
      (mask >> 8) & 0xff,
      mask & 0xff,
    ].map { String($0) }.joined(separator: ".")
  }
}

private enum PacketTunnelProviderError: LocalizedError {
  case missingVpnOptions
  case couldNotDetermineFileDescriptor
  case couldNotStartCoreTun

  var errorDescription: String? {
    switch self {
    case .missingVpnOptions:
      return "missing VPN options"
    case .couldNotDetermineFileDescriptor:
      return "could not determine tunnel file descriptor"
    case .couldNotStartCoreTun:
      return "could not start core TUN"
    }
  }
}

private struct SharedState: Decodable {
  let vpnOptions: VpnOptions?
}

private struct VpnOptions: Decodable {
  let port: Int
  let ipv6: Bool
  let dnsHijacking: Bool
  let systemProxy: Bool
  let suspendSupport: Bool
  let bypassDomain: [String]
  let stack: String
  let routeAddress: [String]
  let includeAllNetworks: Bool
  let excludeLocalNetworks: Bool
  let excludeAPNs: Bool
  let excludeCellularServices: Bool
  let enforceRoutes: Bool
  let excludeDeviceCommunication: Bool

  private enum CodingKeys: String, CodingKey {
    case port
    case ipv6
    case dnsHijacking
    case systemProxy
    case suspendSupport
    case bypassDomain
    case stack
    case routeAddress
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
    dnsHijacking = try container.decode(Bool.self, forKey: .dnsHijacking)
    systemProxy = try container.decode(Bool.self, forKey: .systemProxy)
    suspendSupport = try container.decodeIfPresent(Bool.self, forKey: .suspendSupport) ?? true
    bypassDomain = try container.decodeIfPresent([String].self, forKey: .bypassDomain) ?? []
    stack = try container.decode(String.self, forKey: .stack)
    routeAddress = try container.decodeIfPresent([String].self, forKey: .routeAddress) ?? []
    includeAllNetworks = try container.decodeIfPresent(Bool.self, forKey: .includeAllNetworks) ?? false
    excludeLocalNetworks = try container.decodeIfPresent(Bool.self, forKey: .excludeLocalNetworks) ?? true
    excludeAPNs = try container.decodeIfPresent(Bool.self, forKey: .excludeAPNs) ?? true
    excludeCellularServices = try container.decodeIfPresent(Bool.self, forKey: .excludeCellularServices) ?? true
    enforceRoutes = try container.decodeIfPresent(Bool.self, forKey: .enforceRoutes) ?? false
    excludeDeviceCommunication = try container.decodeIfPresent(Bool.self, forKey: .excludeDeviceCommunication) ?? true
  }
}

private struct CIDR {
  let address: String
  let prefixLength: Int

  init?(_ value: String) {
    let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
    guard parts.count == 2, let prefixLength = Int(parts[1]) else {
      return nil
    }
    self.address = parts[0]
    self.prefixLength = prefixLength
  }
}
