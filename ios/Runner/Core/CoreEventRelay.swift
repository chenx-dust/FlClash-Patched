import Foundation
import os

@MainActor
final class CoreEventRelay {
  private let sharedStateStore: SharedStateStore
  private let sendEvent: (String, @escaping (Bool) -> Void) -> Void
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.follow.clash",
    category: "CoreEventRelay"
  )
  private var isStarted = false
  private var inFlightEventFiles = Set<URL>()

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
      guard let event,
        !event.isEmpty
      else {
        return
      }
      Task { @MainActor [weak self] in
        self?.sendEvent(event) { _ in }
      }
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
      guard inFlightEventFiles.insert(fileURL).inserted else {
        continue
      }
      guard let event = try? String(contentsOf: fileURL, encoding: .utf8),
        !event.isEmpty
      else {
        try? FileManager.default.removeItem(at: fileURL)
        inFlightEventFiles.remove(fileURL)
        continue
      }
      sendEvent(event) { [weak self] delivered in
        Task { @MainActor in
          guard let self else {
            return
          }
          if delivered {
            try? FileManager.default.removeItem(at: fileURL)
          } else {
            self.log("drainEventQueue event not delivered")
          }
          self.inFlightEventFiles.remove(fileURL)
        }
      }
    }
  }

  nonisolated private func handleEventNotification() {
    Task { @MainActor [weak self] in
      self?.drainEventQueue()
    }
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
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
