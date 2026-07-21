import NetworkExtension
import WidgetKit
import Darwin
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
  private static let extensionBundleId = Bundle.main.bundleIdentifier!
  private static let baseBundleId = String(extensionBundleId.dropLast(".NECore".count))
  private static let emptySetupParams = Data("{}".utf8)

  private let logger = Logger(
    subsystem: PacketTunnelProvider.extensionBundleId,
    category: "PacketTunnelProvider"
  )
  private let sharedStateKey = "sharedState"
  private let appGroupIdentifier = "group.\(PacketTunnelProvider.baseBundleId)"
  private let widgetIdentifier = "\(PacketTunnelProvider.baseBundleId).Widget"
  private let eventQueueDirectoryName = "core-events"
  private let eventNotificationName = "\(PacketTunnelProvider.extensionBundleId).event"
  private let setupParamsKey = "setupParams"
  private let maxEventQueueFiles = 10
  private var eventsSincePrune = 0
  private var coreActive = true
  private let ipv4Address = "172.19.0.1"
  private let ipv4AddressPrefix = "172.19.0.1/30"
  private let ipv4SubnetMask = "255.255.255.252"
  private let ipv4Dns = "172.19.0.2"
  private let ipv6Address = "fdfe:dcba:9876::1"
  private let ipv6AddressPrefix = "fdfe:dcba:9876::1/126"
  private let ipv6Dns = "fdfe:dcba:9876::2"
  private let netAny = "0.0.0.0"
  private var suspendSupport = true

  override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    logger.info("startTunnel begin")
    reloadControlWidget()
    guard let sharedState = loadSharedState(), let vpnOptions = sharedState.vpnOptions else {
      logger.error("startTunnel failed: missing vpn options")
      completionHandler(PacketTunnelProviderError.missingVpnOptions)
      return
    }
    logger.info("startTunnel options stack=\(vpnOptions.stack, privacy: .public) ipv6=\(vpnOptions.ipv6, privacy: .public) dnsHijacking=\(vpnOptions.dnsHijacking, privacy: .public) systemProxy=\(vpnOptions.systemProxy, privacy: .public) suspendSupport=\(vpnOptions.suspendSupport, privacy: .public)")
    suspendSupport = vpnOptions.suspendSupport

    setTunnelNetworkSettings(makeNetworkSettings(vpnOptions: vpnOptions)) { error in
      if let error = error {
        self.logger.error("setTunnelNetworkSettings failed: \(error.localizedDescription, privacy: .public)")
        completionHandler(error)
        return
      }
      self.logger.info("setTunnelNetworkSettings completed")
      guard let tunnelFileDescriptor = self.tunnelFileDescriptor else {
        self.logger.error("startTunnel failed: tunnel file descriptor missing")
        completionHandler(PacketTunnelProviderError.couldNotDetermineFileDescriptor)
        return
      }
      self.logger.debug("startTunnel fileDescriptor=\(tunnelFileDescriptor, privacy: .public)")
      self.installCoreEventListener()
      let initParams = self.makeInitParams()
      let setupParams = self.loadSetupParams()
      self.logger.info("quickSetup initParams=\(initParams, privacy: .public)")
      NECoreBridge.quickSetup(withInitParams: initParams, setupParams: setupParams) { result in
        if let result = result, !result.isEmpty {
          let message = String(data: result, encoding: .utf8) ?? "unknown core error"
          self.logger.error("quickSetup failed: \(message, privacy: .public)")
          completionHandler(PacketTunnelProviderError.couldNotStartCoreTun)
          return
        }
        self.logger.info("quickSetup completed")
        let started = NECoreBridge.startTun(
          withFileDescriptor: tunnelFileDescriptor,
          stack: vpnOptions.stack,
          address: self.tunAddress(vpnOptions: vpnOptions),
          dns: self.tunDns(vpnOptions: vpnOptions)
        )
        self.logger.info("NECoreBridge.startTun result=\(started, privacy: .public)")
        completionHandler(started ? nil : PacketTunnelProviderError.couldNotStartCoreTun)
      }
    }
  }
  
  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    logger.info("stopTunnel reason=\(reason.rawValue, privacy: .public)")
    reloadControlWidget()
    NECoreBridge.setEventListener(nil)
    NECoreBridge.stopTun()
    guard reason == .userInitiated else {
      completionHandler()
      return
    }
    NETunnelProviderManager.loadAllFromPreferences() { managers, error in
      if let error {
        self.logger.error("stopTunnel loadAllFromPreferences error=\(error.localizedDescription, privacy: .public)")
        completionHandler()
        return
      }
      guard let manager = managers?.first else {
        completionHandler()
        return
      }
      manager.isOnDemandEnabled = false
      manager.saveToPreferences() { error in
        if let error {
          self.logger.error("stopTunnel saveToPreferences error=\(error.localizedDescription, privacy: .public)")
        }
        completionHandler()
      }
    }
  }
  
  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    logger.debug("handleAppMessage bytes=\(messageData.count, privacy: .public)")
    coreActive = true
    guard let handler = completionHandler else {
      logger.warning("handleAppMessage ignored: missing completion handler")
      return
    }

    NECoreBridge.invokeMethod(messageData) { response in
      guard let response = response else {
        self.logger.warning("handleAppMessage empty core response")
        handler(self.methodErrorResponse(
          messageData: messageData,
          code: "empty_response",
          message: "empty core response"
        ))
        return
      }
      self.logger.debug("handleAppMessage response bytes=\(response.count, privacy: .public)")
      handler(response)
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

  private func methodCallID(_ messageData: Data?) -> String? {
    guard let messageData,
          let object = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any] else {
      return nil
    }
    return object["id"] as? String
  }

  private func methodErrorResponse(
    messageData: Data?,
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

  private func makeInitParams() -> String {
    let homeDir = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )?.path ?? ""
    return "{\"home-dir\":\"\(homeDir)\",\"version\":0}"
  }

  private func loadSharedState() -> SharedState? {
    guard let data = UserDefaults(suiteName: appGroupIdentifier)?.data(forKey: sharedStateKey) else {
      return nil
    }
    return try? JSONDecoder().decode(SharedState.self, from: data)
  }

  private func loadSetupParams() -> Data {
    guard let userDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
      return PacketTunnelProvider.emptySetupParams
    }
    if let data = userDefaults.data(forKey: setupParamsKey) {
      return data
    }
    guard let sharedStateData = userDefaults.data(forKey: sharedStateKey),
          let json = try? JSONSerialization.jsonObject(with: sharedStateData) as? [String: Any],
          let setupParams = json[setupParamsKey],
          !(setupParams is NSNull),
          JSONSerialization.isValidJSONObject(setupParams),
          let data = try? JSONSerialization.data(withJSONObject: setupParams) else {
      return PacketTunnelProvider.emptySetupParams
    }
    userDefaults.set(data, forKey: setupParamsKey)
    return data
  }

  private func installCoreEventListener() {
    NECoreBridge.setEventListener { [weak self] event in
      guard let self = self, let event = event, !event.isEmpty else {
        return
      }
      self.enqueueCoreEvent(event)
    }
  }

  private func enqueueCoreEvent(_ event: Data) {
    guard coreActive else {
      logger.warning("enqueueCoreEvent skip: core is not active")
      return
    }
    guard let directory = eventQueueDirectory() else {
      logger.error("enqueueCoreEvent failed: missing event queue directory")
      return
    }
    do {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000)
      let fileName = "\(timestamp)-\(UUID().uuidString)"
      let fileURL = directory.appendingPathComponent("\(fileName).json")
      let temporaryURL = directory.appendingPathComponent(".\(fileName).tmp")
      do {
        try event.write(to: temporaryURL)
        try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
      } catch {
        try? FileManager.default.removeItem(at: temporaryURL)
        throw error
      }
      eventsSincePrune += 1
      if eventsSincePrune >= maxEventQueueFiles {
        eventsSincePrune = 0
        pruneCoreEventQueue(in: directory)
      }
      notifyCoreEventAvailable()
    } catch {
      logger.error("enqueueCoreEvent failed: \(error.localizedDescription, privacy: .public)")
    }
  }

  private func pruneCoreEventQueue(in directory: URL) {
    var files = coreEventFiles(in: directory)
    var overflowCount = files.count - maxEventQueueFiles
    if overflowCount > 0 {
      coreActive = false
      logger.warning("pruneCoreEventQueue: overflow count=\(overflowCount, privacy: .public), set coreActive=false")
    }

    while overflowCount > 0 && !files.isEmpty {
      removeOldestCoreEventFile(&files)
      overflowCount -= 1
    }
  }

  private func coreEventFiles(in directory: URL) -> [URL] {
    guard let fileURLs = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey]
    ) else {
      return []
    }
    return fileURLs.filter { fileURL in
      fileURL.pathExtension == "json"
        && (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
    }.sorted { lhs, rhs in
      lhs.lastPathComponent < rhs.lastPathComponent
    }
  }

  private func removeOldestCoreEventFile(
    _ files: inout [URL]
  ) {
    let fileURL = files.removeFirst()
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch {
      logger.warning("pruneCoreEventQueue failed: \(error.localizedDescription, privacy: .public)")
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

    var ipv6RouteCount = 0
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
      ipv6RouteCount = ipv6Routes.count
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

    logger.debug(
      "makeNetworkSettings ipv4Routes=\(ipv4Routes.count, privacy: .public) ipv6Routes=\(ipv6RouteCount, privacy: .public)"
    )

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

  private func reloadControlWidget() {
    if #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(ofKind: widgetIdentifier)
    }
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

  private enum CodingKeys: String, CodingKey {
    case vpnOptions
  }
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
