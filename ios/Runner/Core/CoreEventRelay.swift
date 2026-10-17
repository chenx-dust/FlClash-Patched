import ClashCore
import Foundation
import os

/// Delivers what both Cores publish: the app's directly, the extension's
/// through the files it leaves in the app group.
@MainActor
final class CoreEventRelay {
  typealias SendEvent = (Data, @escaping (Bool) -> Void) -> Void

  private let sharedStateStore: SharedStateStore
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "",
    category: "CoreEventRelay"
  )
  private var sendEvent: SendEvent?
  private var isObserving = false
  private var inFlightEventFiles = Set<URL>()

  init(sharedStateStore: SharedStateStore) {
    self.sharedStateStore = sharedStateStore
  }

  func start(_ sendEvent: @escaping SendEvent) {
    self.sendEvent = sendEvent
    MobileSetEventListener(
      CoreResultHandler { [weak self] event in
        guard !event.isEmpty else {
          return
        }
        DispatchQueue.main.async {
          self?.sendEvent?(event) { _ in }
        }
      }
    )
    if !isObserving {
      isObserving = true
      CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        Unmanaged.passUnretained(self).toOpaque(),
        Self.eventNotificationCallback,
        sharedStateStore.eventNotificationName as CFString,
        nil,
        .deliverImmediately
      )
    }
    drainEventQueue()
  }

  func deliver(_ event: Data) {
    sendEvent?(event) { _ in }
  }

  func stop() {
    sendEvent = nil
    MobileSetEventListener(nil)
  }

  func drainEventQueue() {
    guard let sendEvent,
      let directory = sharedStateStore.eventQueueDirectory(),
      let files = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
      )
    else {
      return
    }
    for fileURL in files
      .filter({ $0.pathExtension == "json" })
      .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
    {
      guard inFlightEventFiles.insert(fileURL).inserted else {
        continue
      }
      guard let event = try? Data(contentsOf: fileURL), !event.isEmpty else {
        try? FileManager.default.removeItem(at: fileURL)
        inFlightEventFiles.remove(fileURL)
        continue
      }
      sendEvent(event) { [weak self] delivered in
        if delivered {
          try? FileManager.default.removeItem(at: fileURL)
        } else {
          self?.logger.debug("event not delivered")
        }
        self?.inFlightEventFiles.remove(fileURL)
      }
    }
  }

  private static let eventNotificationCallback: CFNotificationCallback = {
    _, observer, _, _, _ in
    guard let observer else {
      return
    }
    let relay = Unmanaged<CoreEventRelay>.fromOpaque(observer)
      .takeUnretainedValue()
    DispatchQueue.main.async {
      MainActor.assumeIsolated {
        relay.drainEventQueue()
      }
    }
  }
}
