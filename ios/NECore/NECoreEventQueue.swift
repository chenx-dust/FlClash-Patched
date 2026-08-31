import Foundation
import os

final class NECoreEventQueue {
  private let sharedStateStore: PacketTunnelSharedStateStore
  private let eventQueueDirectoryName = "core-events"
  private let maxEventQueueFiles = 10
  private let logger = Logger(
    subsystem: PacketTunnelEnvironment.extensionBundleIdentifier,
    category: "NECoreEventQueue"
  )

  private var eventsSincePrune = 0
  private var coreActive = true

  init(sharedStateStore: PacketTunnelSharedStateStore) {
    self.sharedStateStore = sharedStateStore
  }

  func start() {
    NECoreBridge.setEventListener { [weak self] event in
      guard let self,
        let event,
        !event.isEmpty
      else {
        return
      }
      self.enqueue(event)
    }
  }

  func stop() {
    NECoreBridge.setEventListener(nil)
  }

  func markCoreResponsive() {
    coreActive = true
  }

  private func enqueue(_ event: Data) {
    guard coreActive else {
      logger.warning("enqueue skipped: core is not active")
      return
    }
    guard let directory = eventQueueDirectory() else {
      logger.error("enqueue failed: missing app group dir")
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
        prune(in: directory)
      }
      notifyEventAvailable()
    } catch {
      logger.error(
        "enqueue failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  private func prune(in directory: URL) {
    var files = eventFiles(in: directory)
    var overflowCount = files.count - maxEventQueueFiles
    if overflowCount > 0 {
      coreActive = false
      logger.warning(
        "prune overflow=\(overflowCount, privacy: .public), set core inactive"
      )
    }

    while overflowCount > 0 && !files.isEmpty {
      removeOldestEventFile(&files)
      overflowCount -= 1
    }
  }

  private func eventFiles(in directory: URL) -> [URL] {
    guard let fileURLs = try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isRegularFileKey]
    ) else {
      return []
    }
    return fileURLs.filter { fileURL in
      fileURL.pathExtension == "json" &&
        (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?
          .isRegularFile == true
    }.sorted { lhs, rhs in
      lhs.lastPathComponent < rhs.lastPathComponent
    }
  }

  private func removeOldestEventFile(_ files: inout [URL]) {
    let fileURL = files.removeFirst()
    do {
      try FileManager.default.removeItem(at: fileURL)
    } catch {
      logger.warning(
        "prune failed: \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  private func eventQueueDirectory() -> URL? {
    sharedStateStore.appGroupDirectory()?.appendingPathComponent(
      eventQueueDirectoryName,
      isDirectory: true
    )
  }

  private func notifyEventAvailable() {
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(
        PacketTunnelEnvironment.eventNotificationName as CFString
      ),
      nil,
      nil,
      true
    )
  }
}
