import Foundation
import os

enum CoreRoute: Hashable {
  case app
  case networkExtension

  var description: String {
    switch self {
    case .app:
      return "app"
    case .networkExtension:
      return "networkExtension"
    }
  }
}

enum CoreNotificationKind: CaseIterable {
  case log
  case request

  var startMethod: String {
    switch self {
    case .log:
      return "startLogNotify"
    case .request:
      return "startRequestNotify"
    }
  }

  var stopMethod: String {
    switch self {
    case .log:
      return "stopLogNotify"
    case .request:
      return "stopRequestNotify"
    }
  }
}

enum CoreNotificationAction {
  case start(CoreNotificationKind)
  case stop(CoreNotificationKind)
}

private struct CoreNotificationSubscription {
  var startData: Data
  var stopData: Data?
  var activeRoutes: Set<CoreRoute>
  var desiredActive: Bool
}

@MainActor
final class CoreNotificationCoordinator {
  typealias SendMessage = (Data, CoreRoute) async throws -> String

  private let sendMessage: SendMessage
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.follow.clash",
    category: "CoreNotificationCoordinator"
  )
  private let maxMigrationRetryCount = 1
  private let migrationRetryBaseDelay: UInt64 = 250_000_000

  private var desiredRoute = CoreRoute.app
  private var logSubscription: CoreNotificationSubscription?
  private var requestSubscription: CoreNotificationSubscription?
  private var migrationTask: Task<Void, Never>?
  private var migrationRetryTask: Task<Void, Never>?
  private var migrationRetryCount = 0
  private var actionInFlight = false
  private var actionWaiters: [CheckedContinuation<Void, Never>] = []

  init(sendMessage: @escaping SendMessage) {
    self.sendMessage = sendMessage
  }

  deinit {
    migrationTask?.cancel()
    migrationRetryTask?.cancel()
  }

  func action(for data: Data) -> CoreNotificationAction? {
    guard let object = try? JSONSerialization.jsonObject(with: data)
      as? [String: Any]
    else {
      return nil
    }
    switch object["method"] as? String {
    case "startLogNotify":
      return .start(.log)
    case "stopLogNotify":
      return .stop(.log)
    case "startRequestNotify":
      return .start(.request)
    case "stopRequestNotify":
      return .stop(.request)
    default:
      return nil
    }
  }

  func prepare(for action: CoreNotificationAction?) async {
    guard action != nil else {
      return
    }
    await migrationTask?.value
    await acquireAction()
  }

  func finish(_ action: CoreNotificationAction?) {
    guard action != nil else {
      return
    }
    releaseAction()
  }

  func recordSuccessfulStart(
    _ kind: CoreNotificationKind,
    data: Data,
    route: CoreRoute
  ) {
    var current = subscription(for: kind) ?? CoreNotificationSubscription(
      startData: data,
      stopData: nil,
      activeRoutes: [],
      desiredActive: true
    )
    current.startData = data
    current.stopData = nil
    current.desiredActive = true
    current.activeRoutes.insert(route)
    setSubscription(current, for: kind)
    resetMigrationRetry()
    driveMigration()
  }

  func beginStop(
    _ kind: CoreNotificationKind,
    data: Data,
    defaultRoute: CoreRoute
  ) -> [CoreRoute] {
    guard var current = subscription(for: kind) else {
      return [defaultRoute]
    }
    current.stopData = data
    current.desiredActive = false
    let routes = orderedRoutes(current.activeRoutes)
    setSubscription(current, for: kind)
    resetMigrationRetry()
    return routes.isEmpty ? [defaultRoute] : routes
  }

  func recordSuccessfulStop(
    _ kind: CoreNotificationKind,
    route: CoreRoute
  ) {
    guard var current = subscription(for: kind) else {
      return
    }
    current.activeRoutes.remove(route)
    if current.activeRoutes.isEmpty && !current.desiredActive {
      setSubscription(nil, for: kind)
    } else {
      setSubscription(current, for: kind)
    }
    driveMigration()
  }

  func setDesiredRoute(_ route: CoreRoute) {
    let discardedNetworkExtension = route == .app
      ? discardNetworkExtensionOwnership()
      : false
    guard desiredRoute != route else {
      if discardedNetworkExtension {
        resetMigrationRetry()
      }
      driveMigration()
      return
    }
    log(
      "actual core route \(desiredRoute.description) -> \(route.description)"
    )
    desiredRoute = route
    resetMigrationRetry()
    driveMigration()
  }

  private func driveMigration() {
    guard migrationTask == nil,
      migrationRetryTask == nil,
      !actionInFlight,
      hasPendingMigration
    else {
      return
    }
    migrationTask = Task { [weak self] in
      await self?.runMigration()
    }
  }

  private func acquireAction() async {
    guard actionInFlight else {
      actionInFlight = true
      return
    }
    await withCheckedContinuation { continuation in
      actionWaiters.append(continuation)
    }
  }

  private func releaseAction() {
    guard actionWaiters.isEmpty else {
      actionWaiters.removeFirst().resume()
      return
    }
    actionInFlight = false
    driveMigration()
  }

  private func runMigration() async {
    while !Task.isCancelled {
      let targetRoute = desiredRoute
      var failed = false
      for kind in CoreNotificationKind.allCases {
        if !(await migrate(kind, to: targetRoute)) {
          failed = true
        }
      }

      if targetRoute != desiredRoute {
        continue
      }
      if !failed && hasPendingMigration {
        continue
      }

      migrationTask = nil
      if failed && hasPendingMigration {
        scheduleMigrationRetry()
      } else {
        resetMigrationRetry()
      }
      return
    }
    migrationTask = nil
  }

  private func migrate(
    _ kind: CoreNotificationKind,
    to targetRoute: CoreRoute
  ) async -> Bool {
    guard let snapshot = subscription(for: kind) else {
      return true
    }
    guard snapshot.desiredActive else {
      let stopData = snapshot.stopData ?? replacingMethod(
        in: snapshot.startData,
        with: kind.stopMethod
      )
      guard let stopData else {
        return false
      }
      return await stopRoutes(
        snapshot.activeRoutes,
        kind: kind,
        startData: snapshot.startData,
        stopData: stopData
      )
    }

    if !snapshot.activeRoutes.contains(targetRoute) {
      guard await sendMigrationMessage(
        snapshot.startData,
        route: targetRoute
      ) else {
        return false
      }
      guard var current = subscription(for: kind),
        current.startData == snapshot.startData,
        current.desiredActive
      else {
        return true
      }
      current.activeRoutes.insert(targetRoute)
      setSubscription(current, for: kind)
      migrationRetryCount = 0
      log("started \(kind.startMethod) on \(targetRoute.description)")
      if desiredRoute == .app {
        _ = discardNetworkExtensionOwnership()
      }
    }

    guard targetRoute == desiredRoute,
      let current = subscription(for: kind),
      current.startData == snapshot.startData,
      current.desiredActive
    else {
      return true
    }
    let staleRoutes = current.activeRoutes.filter { $0 != targetRoute }
    guard !staleRoutes.isEmpty else {
      return true
    }
    guard let stopData = replacingMethod(
      in: current.startData,
      with: kind.stopMethod
    ) else {
      return false
    }
    return await stopRoutes(
      Set(staleRoutes),
      kind: kind,
      startData: current.startData,
      stopData: stopData
    )
  }

  private func stopRoutes(
    _ routes: Set<CoreRoute>,
    kind: CoreNotificationKind,
    startData: Data,
    stopData: Data
  ) async -> Bool {
    var stoppedAll = true
    for route in orderedRoutes(routes) {
      guard await sendMigrationMessage(stopData, route: route) else {
        stoppedAll = false
        continue
      }
      guard var current = subscription(for: kind),
        current.startData == startData
      else {
        continue
      }
      current.activeRoutes.remove(route)
      if current.activeRoutes.isEmpty && !current.desiredActive {
        setSubscription(nil, for: kind)
      } else {
        setSubscription(current, for: kind)
      }
      migrationRetryCount = 0
      log("stopped \(kind.stopMethod) on \(route.description)")
    }
    return stoppedAll
  }

  private func sendMigrationMessage(
    _ data: Data,
    route: CoreRoute
  ) async -> Bool {
    do {
      let response = try await sendMessage(data, route)
      return responseSucceeded(response)
    } catch {
      log(
        "notification migration on \(route.description) failed: \(error.localizedDescription)"
      )
      return false
    }
  }

  private func scheduleMigrationRetry() {
    guard migrationRetryTask == nil,
      migrationRetryCount < maxMigrationRetryCount,
      hasPendingMigration
    else {
      if hasPendingMigration {
        log("notification migration retry exhausted")
      }
      return
    }
    let delay = migrationRetryBaseDelay << migrationRetryCount
    migrationRetryCount += 1
    log("notification migration retry=\(migrationRetryCount)")
    migrationRetryTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: delay)
      } catch {
        return
      }
      guard let self else {
        return
      }
      self.migrationRetryTask = nil
      self.driveMigration()
    }
  }

  private func resetMigrationRetry() {
    migrationRetryTask?.cancel()
    migrationRetryTask = nil
    migrationRetryCount = 0
  }

  private var hasPendingMigration: Bool {
    CoreNotificationKind.allCases.contains { kind in
      guard let current = subscription(for: kind) else {
        return false
      }
      if !current.desiredActive {
        return !current.activeRoutes.isEmpty
      }
      return !current.activeRoutes.contains(desiredRoute) ||
        current.activeRoutes.contains { $0 != desiredRoute }
    }
  }

  private func discardNetworkExtensionOwnership() -> Bool {
    var discarded = false
    for kind in CoreNotificationKind.allCases {
      guard var current = subscription(for: kind),
        current.activeRoutes.remove(.networkExtension) != nil
      else {
        continue
      }
      discarded = true
      if current.activeRoutes.isEmpty && !current.desiredActive {
        setSubscription(nil, for: kind)
      } else {
        setSubscription(current, for: kind)
      }
      log("discarded \(kind.stopMethod) Network Extension ownership")
    }
    return discarded
  }

  private func orderedRoutes(
    _ routes: Set<CoreRoute>
  ) -> [CoreRoute] {
    [.app, .networkExtension].filter(routes.contains)
  }

  private func subscription(
    for kind: CoreNotificationKind
  ) -> CoreNotificationSubscription? {
    switch kind {
    case .log:
      return logSubscription
    case .request:
      return requestSubscription
    }
  }

  private func setSubscription(
    _ subscription: CoreNotificationSubscription?,
    for kind: CoreNotificationKind
  ) {
    switch kind {
    case .log:
      logSubscription = subscription
    case .request:
      requestSubscription = subscription
    }
  }

  private func replacingMethod(
    in data: Data,
    with method: String
  ) -> Data? {
    guard var object = try? JSONSerialization.jsonObject(with: data)
      as? [String: Any]
    else {
      return nil
    }
    object["method"] = method
    return try? JSONSerialization.data(withJSONObject: object)
  }

  private func responseSucceeded(_ response: String) -> Bool {
    guard let data = response.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data)
        as? [String: Any]
    else {
      return false
    }
    return object["error"] == nil || object["error"] is NSNull
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
