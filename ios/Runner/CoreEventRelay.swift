import Foundation

final class CoreEventRelay {
  private let sharedStateStore: SharedStateStore
  private let sendEvent: (String, @escaping (Bool) -> Void) -> Void
  private var isStarted = false

  init(
    sharedStateStore: SharedStateStore,
    sendEvent: @escaping (String, @escaping (Bool) -> Void) -> Void
  ) {
    self.sharedStateStore = sharedStateStore
    self.sendEvent = sendEvent
  }

  deinit {
    guard isStarted else {
      return
    }
    CFNotificationCenterRemoveObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CFNotificationName(sharedStateStore.eventNotificationName as CFString),
      nil
    )
  }

  func start() {
    guard !isStarted else {
      return
    }
    isStarted = true
    IOSCoreBridge.setEventListener { [weak self] event in
      guard let self,
            let event,
            !event.isEmpty else {
        return
      }
      self.sendEvent(event) { _ in }
    }
    CFNotificationCenterAddObserver(
      CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(),
      CoreEventRelay.eventNotificationCallback,
      sharedStateStore.eventNotificationName as CFString,
      nil,
      .deliverImmediately
    )
    drainEventQueue()
  }

  func invokeAppCore(
    _ methodCall: String,
    completion: @escaping (String?) -> Void
  ) {
    IOSCoreBridge.invokeMethod(methodCall, result: completion)
  }

  func drainEventQueue() {
    guard let directory = sharedStateStore.eventQueueDirectory() else {
      log("drainEventQueue skipped: missing app group dir")
      return
    }
    guard let files = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    ) else {
      return
    }
    for fileURL in files
      .filter({ $0.pathExtension == "json" })
      .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      guard let event = try? String(contentsOf: fileURL, encoding: .utf8),
            !event.isEmpty else {
        try? FileManager.default.removeItem(at: fileURL)
        continue
      }
      sendEvent(event) { delivered in
        if !delivered {
          self.log("drainEventQueue event not delivered")
          return
        }
        try? FileManager.default.removeItem(at: fileURL)
      }
    }
  }

  private func handleEventNotification() {
    DispatchQueue.main.async {
      self.drainEventQueue()
    }
  }

  private func log(_ message: String) {
    NSLog("[CoreEventRelay] %@", message)
  }

  private static let eventNotificationCallback: CFNotificationCallback = {
    _, observer, _, _, _ in
    guard let observer else {
      return
    }
    let instance = Unmanaged<CoreEventRelay>
      .fromOpaque(observer)
      .takeUnretainedValue()
    instance.handleEventNotification()
  }
}
