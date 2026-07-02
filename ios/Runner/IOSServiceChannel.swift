import Flutter
import Foundation
import NetworkExtension

final class IOSServiceChannel {
  private static var instance: IOSServiceChannel?

  private let channel: FlutterMethodChannel
  private var tunnelStatusObserver: NSObjectProtocol?
  private var lastTunnelStatus: NEVPNStatus?
  private var isTunnelStopExpected = false
  private let providerBundleIdentifier = "com.follow.clash.DEVID.NECore"
  private let appGroupIdentifier = "group.com.follow.clash.DEVID"
  private let sharedStateKey = "sharedState"
  private let runTimeKey = "runTime"
  private let eventQueueDirectoryName = "core-events"
  private let eventNotificationName = "com.follow.clash.DEVID.NECore.event"
  private let localizedDescription = "FlClash"

  private func log(_ message: String) {
    NSLog("[IOSServiceChannel] %@", message)
  }

  static func register(with messenger: FlutterBinaryMessenger) {
    instance = IOSServiceChannel(messenger: messenger)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.follow.clash/service",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler(handle)
    installAppCoreEventListener()
    registerCoreEventObserver()
    registerTunnelStatusObserver()
    drainCoreEventQueue()
  }

  deinit {
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(eventNotificationName as CFString),
      nil
    )
    if let tunnelStatusObserver = tunnelStatusObserver {
      NotificationCenter.default.removeObserver(tunnelStatusObserver)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    log("handle method=\(call.method)")
    switch call.method {
    case "invokeAction":
      guard let message = call.arguments as? String,
            let data = message.data(using: .utf8) else {
        result(actionResult(data: nil, message: "invalid action"))
        return
      }
      invokeAppCore(data, result: result)
    case "invokeAppCore":
      guard let message = call.arguments as? String,
            let data = message.data(using: .utf8) else {
        result(actionResult(data: nil, message: "invalid action"))
        return
      }
      invokeAppCore(data, result: result)
    case "invokeNetworkExtensionCore":
      guard let message = call.arguments as? String,
            let data = message.data(using: .utf8) else {
        result(actionResult(data: nil, message: "invalid action"))
        return
      }
      sendProviderMessage(data, result: result)
    case "start":
      startTunnel(result: result)
    case "stop":
      stopTunnel(result: result)
    case "init":
      drainCoreEventQueue()
      result("")
    case "syncState":
      syncState(call, result: result)
    case "shutdown":
      stopTunnel(result: result)
    case "getAppGroupDir":
      result(appGroupDir())
    case "getRunTime":
      getRunTime(result: result)
    case "isNetworkExtensionCoreActive":
      isNetworkExtensionCoreActive(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadManager(
    createIfNeeded: Bool = true,
    completion: @escaping (NETunnelProviderManager?, Error?) -> Void
  ) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      if let error = error {
        self.log("loadManager failed: \(error.localizedDescription)")
        completion(nil, error)
        return
      }

      if let manager = managers?.first(where: { manager in
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol else {
          return false
        }
        return proto.providerBundleIdentifier == self.providerBundleIdentifier
      }) {
        self.log("loadManager found existing manager status=\(self.statusDescription(manager.connection.status))")
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
      proto.providerBundleIdentifier = self.providerBundleIdentifier
      proto.serverAddress = self.localizedDescription
      manager.protocolConfiguration = proto
      manager.localizedDescription = self.localizedDescription
      manager.isEnabled = true
      completion(manager, nil)
    }
  }

  private func startTunnel(result: @escaping FlutterResult) {
    startTunnelWithCompletion { isStarted in
      result(isStarted)
    }
  }

  private func startTunnelWithCompletion(completion: @escaping (Bool) -> Void) {
    log("startTunnelWithCompletion begin")
    startTunnelAfterLoadingManager(completion: completion)
  }

  private func startTunnelAfterLoadingManager(completion: @escaping (Bool) -> Void) {
    loadManager { manager, error in
      guard let manager = manager else {
        self.log("startTunnel failed: manager missing")
        completion(false)
        return
      }
      if let error = error {
        self.log("startTunnel failed: \(error.localizedDescription)")
        completion(false)
        return
      }

      manager.isEnabled = true
      self.log("startTunnel save preferences")
      manager.saveToPreferences { error in
        if let error = error {
          self.log("startTunnel save preferences failed: \(error.localizedDescription)")
          completion(false)
          return
        }
        self.log("startTunnel reload preferences")
        manager.loadFromPreferences { error in
          if let error = error {
            self.log("startTunnel reload preferences failed: \(error.localizedDescription)")
            completion(false)
            return
          }
          do {
            self.log("startTunnel startVPNTunnel currentStatus=\(self.statusDescription(manager.connection.status))")
            if manager.connection.status == .connected {
              self.log("startTunnel already connected")
              self.isTunnelStopExpected = false
              self.lastTunnelStatus = .connected
              self.saveRunTime()
              completion(true)
              return
            }
            self.isTunnelStopExpected = false
            try manager.connection.startVPNTunnel()
            self.log("startTunnel startVPNTunnel requested")
            self.waitForTunnelConnected(manager: manager) { connected in
              self.log("startTunnel connected result=\(connected)")
              if connected {
                self.saveRunTime()
              }
              completion(connected)
            }
          } catch {
            self.log("startTunnel startVPNTunnel failed: \(error.localizedDescription)")
            completion(false)
          }
        }
      }
    }
  }

  private func waitForTunnelConnected(
    manager: NETunnelProviderManager,
    completion: @escaping (Bool) -> Void
  ) {
    let status = manager.connection.status
    if isConnectedTunnelStatus(status) {
      completion(true)
      return
    }
    if isTerminalTunnelStatus(status) {
      log("waitForTunnelConnected already terminal status=\(statusDescription(status))")
      completion(false)
      return
    }

    var observer: NSObjectProtocol?
    var timeoutWork: DispatchWorkItem?

    let cleanup: () -> Void = {
      if let observer = observer {
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
        self.log("waitForTunnelConnected failed status=\(self.statusDescription(current))")
        cleanup()
        completion(false)
      }
    }

    timeoutWork = DispatchWorkItem { [weak self] in
      let current = manager.connection.status
      self?.log("waitForTunnelConnected timeout status=\(self?.statusDescription(current) ?? "unknown")")
      cleanup()
      completion(self?.isConnectedTunnelStatus(current) ?? false)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeoutWork!)
  }

  private func stopTunnel(result: @escaping FlutterResult) {
    log("stopTunnel requested")
    loadManager { manager, _ in
      let status = manager?.connection.status ?? .invalid
      self.log("stopTunnel currentStatus=\(self.statusDescription(status))")
      self.isTunnelStopExpected = self.isActiveTunnelStatus(status)
      manager?.connection.stopVPNTunnel()
      if !self.isTunnelStopExpected {
        self.isTunnelStopExpected = false
      }
      self.clearRunTime()
      result(true)
    }
  }

  private func syncState(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let message = call.arguments as? String,
          let data = message.data(using: .utf8),
          let userDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
      log("syncState failed")
      result("failed to sync shared state")
      return
    }
    userDefaults.set(data, forKey: sharedStateKey)
    userDefaults.synchronize()
    log("syncState saved bytes=\(data.count)")
    result("")
  }

  private func appGroupDir() -> String {
    guard let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      log("appGroupDir missing")
      return ""
    }
    return url.path
  }

  private func registerCoreEventObserver() {
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      IOSServiceChannel.coreEventNotificationCallback,
      eventNotificationName as CFString,
      nil,
      .deliverImmediately
    )
  }

  private static let coreEventNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
    guard let observer = observer else {
      return
    }
    let instance = Unmanaged<IOSServiceChannel>
      .fromOpaque(observer)
      .takeUnretainedValue()
    instance.handleCoreEventNotification()
  }

  private func handleCoreEventNotification() {
    DispatchQueue.main.async {
      self.drainCoreEventQueue()
    }
  }

  private func installAppCoreEventListener() {
    IOSCoreBridge.setEventListener { [weak self] event in
      guard let self = self, let event = event, !event.isEmpty else {
        return
      }
      self.channel.invokeMethod("event", arguments: event)
    }
  }

  private func drainCoreEventQueue() {
    guard let directory = eventQueueDirectory() else {
      log("drainCoreEventQueue skipped: missing app group dir")
      return
    }
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      return
    }
    for fileURL in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      guard let event = try? String(contentsOf: fileURL, encoding: .utf8),
            !event.isEmpty else {
        try? FileManager.default.removeItem(at: fileURL)
        continue
      }
      channel.invokeMethod("event", arguments: event) { callbackResult in
        if callbackResult != nil {
          self.log("drainCoreEventQueue event not delivered")
          return
        }
        try? FileManager.default.removeItem(at: fileURL)
      }
    }
  }

  private func eventQueueDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    )?.appendingPathComponent(eventQueueDirectoryName, isDirectory: true)
  }

  private func registerTunnelStatusObserver() {
    loadManager(createIfNeeded: false) { manager, _ in
      guard let manager else { return }
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
    log("tunnel status changed \(statusDescription(previousStatus ?? .invalid)) -> \(statusDescription(status)) expectedStop=\(isTunnelStopExpected)")

    if isConnectedTunnelStatus(status) {
      isTunnelStopExpected = false
      return
    }

    guard isTerminalTunnelStatus(status) else {
      return
    }

    if isTunnelStopExpected {
      isTunnelStopExpected = false
      return
    }

    guard let previousStatus,
          isActiveTunnelStatus(previousStatus) else {
      return
    }
    isTunnelStopExpected = false
    notifyTunnelCrashed(status: status)
  }

  private func notifyTunnelCrashed(status: NEVPNStatus) {
    let message = "network extension disconnected: \(statusDescription(status))"
    log("notifyTunnelCrashed \(message)")
    channel.invokeMethod("crash", arguments: message)
  }

  private func sendProviderMessage(_ data: Data, result: @escaping FlutterResult) {
    loadManager(createIfNeeded: false) { manager, error in
      if let error = error {
        self.log("sendProviderMessage failed load manager: \(error.localizedDescription)")
        result(self.actionResult(data: data, message: error.localizedDescription))
        return
      }
      guard let session = manager?.connection as? NETunnelProviderSession else {
        self.log("sendProviderMessage failed: session not found")
        result(self.actionResult(data: data, message: "network extension session not found"))
        return
      }
      do {
        self.log("sendProviderMessage to NECore")
        try session.sendProviderMessage(data) { response in
          guard let response = response,
                let message = String(data: response, encoding: .utf8) else {
            self.log("sendProviderMessage empty response")
            result(self.actionResult(data: data, message: "empty network extension response"))
            return
          }
          self.log("sendProviderMessage response bytes=\(response.count)")
          result(message)
        }
      } catch {
        self.log("sendProviderMessage failed: \(error.localizedDescription)")
        result(self.actionResult(data: data, message: error.localizedDescription))
      }
    }
  }

  private func invokeAppCore(
    _ data: Data,
    result: @escaping FlutterResult
  ) {
    guard let action = String(data: data, encoding: .utf8) else {
      log("invokeAppCore invalid action")
      result(actionResult(data: data, message: "invalid action"))
      return
    }
    log("invokeAppCore")
    IOSCoreBridge.invokeAction(action) { response in
      guard let response = response else {
        self.log("invokeAppCore empty response")
        result(self.actionResult(data: data, message: "empty app core response"))
        return
      }
      self.log("invokeAppCore response received")
      result(response)
    }
  }

  private func isNetworkExtensionCoreActive(result: @escaping FlutterResult) {
    loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      result(self.canSendProviderMessage(status: status))
    }
  }

  private func getRunTime(result: @escaping FlutterResult) {
    loadManager(createIfNeeded: false) { manager, _ in
      let status = manager?.connection.status ?? .invalid
      guard self.canSendProviderMessage(status: status) else {
        result(0)
        return
      }
      let ms = UserDefaults(suiteName: self.appGroupIdentifier)?
        .integer(forKey: self.runTimeKey) ?? 0
      result(ms)
    }
  }

  private func saveRunTime() {
    let ms = Int(Date().timeIntervalSince1970 * 1000)
    UserDefaults(suiteName: appGroupIdentifier)?.set(ms, forKey: runTimeKey)
  }

  private func clearRunTime() {
    UserDefaults(suiteName: appGroupIdentifier)?.removeObject(forKey: runTimeKey)
  }

  private func canSendProviderMessage(status: NEVPNStatus) -> Bool {
    switch status {
    case .connected, .reasserting:
      return true
    case .connecting, .disconnecting, .disconnected, .invalid:
      return false
    @unknown default:
      return false
    }
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

  private func actionInfo(_ data: Data) -> (method: String, id: String?)? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return (
      object["method"] as? String ?? "message",
      object["id"] as? String
    )
  }

  private func actionResult(data: Data?, message: String) -> String {
    return actionResult(data: data, payload: message, code: -1)
  }

  private func actionResult(data: Data?, payload resultPayload: Any, code: Int) -> String {
    var method = "message"
    var id: String?

    if let data = data,
       let action = actionInfo(data) {
      method = action.method
      id = action.id
    }

    var payload: [String: Any] = [
      "method": method,
      "data": resultPayload,
      "code": code,
    ]
    if let id = id {
      payload["id"] = id
    }

    guard let resultData = try? JSONSerialization.data(withJSONObject: payload),
          let result = String(data: resultData, encoding: .utf8) else {
      return #"{"method":"message","data":"serialization failed","code":-1}"#
    }
    return result
  }
}
