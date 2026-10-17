import Flutter
import Foundation
import NetworkExtension
import Shared
import os

/// The iOS side of the channels Android's ServicePlugin and TilePlugin serve.
/// Start and stop are optimistic: the tunnel coordinator owns the intent and
/// serializes the work, and only the revision-stamped `stopped` flows back.
@MainActor
final class ServicePlugin {
  private static let packageName = "com.follow.clash"
  private static var instance: ServicePlugin?
  private static var pendingAction: VPNAction?

  private let channel: FlutterMethodChannel
  private let coreChannel: FlutterMethodChannel
  private let tileChannel: FlutterMethodChannel
  private let sharedStateStore = SharedStateStore()
  private let router = CoreMessageRouter()
  private let eventRelay: CoreEventRelay
  private var tunnelController: TunnelController!
  private var commandRevision = 0
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "",
    category: "ServicePlugin"
  )

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = ServicePlugin(messenger: messenger)
    instance = plugin
    NEHelper.actionHandler = { action in
      ServicePlugin.request(action)
      return true
    }
    if let action = pendingAction {
      pendingAction = nil
      plugin.perform(action)
    }
  }

  /// Before the engine is up only the latest intent survives: a toggle flips a
  /// pending start or stop, and two toggles cancel out.
  static func request(_ action: VPNAction) {
    guard let instance else {
      switch (action, pendingAction) {
      case (.toggle, .start?):
        pendingAction = .stop
      case (.toggle, .stop?):
        pendingAction = .start
      case (.toggle, .toggle?):
        pendingAction = nil
      default:
        pendingAction = action
      }
      return
    }
    instance.perform(action)
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "\(Self.packageName)/service",
      binaryMessenger: messenger
    )
    // Serial: watchRoute keeps the latest intent by the order calls reach the Core.
    coreChannel = FlutterMethodChannel(
      name: "\(Self.packageName)/core",
      binaryMessenger: messenger,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: messenger.makeBackgroundTaskQueue?()
    )
    tileChannel = FlutterMethodChannel(
      name: "\(Self.packageName)/tile",
      binaryMessenger: messenger
    )
    eventRelay = CoreEventRelay(sharedStateStore: sharedStateStore)
    let router = router
    let eventRelay = eventRelay
    router.onEvent = { event in
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          eventRelay.deliver(event)
        }
      }
    }
    tunnelController = TunnelController(
      sharedStateStore: sharedStateStore,
      onSessionChanged: { session in
        router.useNetworkExtension(session)
      },
      onExternalStart: { [weak self] in
        self?.tileChannel.invokeMethod("start", arguments: nil)
      },
      onStopped: { [weak self] in
        self?.notifyStopped()
      }
    )
    channel.setMethodCallHandler { [weak self] call, result in
      MainActor.assumeIsolated {
        guard let self else {
          result(FlutterMethodNotImplemented)
          return
        }
        self.handle(call, result: result)
      }
    }
    coreChannel.setMethodCallHandler { call, result in
      guard call.method == "invokeMethod" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let data = (call.arguments as? String)?.data(using: .utf8) else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Method call payload must be a string",
            details: nil
          )
        )
        return
      }
      router.invoke(data) { response in
        result(FlutterStandardTypedData(bytes: response))
      }
    }
    tunnelController.startObserving()
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      eventRelay.start { [weak self] event, delivered in
        self?.channel.invokeMethod(
          "event",
          arguments: FlutterStandardTypedData(bytes: event)
        ) { reply in
          delivered(!(reply is FlutterError) && (reply as AnyObject?) !== FlutterMethodNotImplemented)
        }
      }
      result("")
    case "shutdown":
      eventRelay.stop()
      result(true)
    case "getRunTime":
      Task {
        result(await tunnelController.getRunTime())
      }
    case "syncState":
      guard let data = (call.arguments as? String)?.data(using: .utf8),
        sharedStateStore.saveSharedState(data)
      else {
        result("Invalid shared state")
        return
      }
      result("")
    case "start":
      commandRevision = call.arguments as? Int ?? commandRevision
      tunnelController.start()
      result(true)
    case "stop":
      commandRevision = call.arguments as? Int ?? commandRevision
      tunnelController.stop()
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Flutter drives a start itself, so its Core is set up before the tunnel
  // comes up. Until Flutter listens, the extension sets up its own Core from
  // the shared state, as Android does from its preferences.
  private func perform(_ action: VPNAction) {
    switch action {
    case .start:
      tileChannel.invokeMethod("start", arguments: nil) { [weak self] reply in
        if (reply as AnyObject?) === FlutterMethodNotImplemented {
          self?.tunnelController.start()
        }
      }
    case .stop:
      tunnelController.stop()
    case .toggle:
      perform(tunnelController.isRunRequested ? .stop : .start)
    }
  }

  private func notifyStopped() {
    guard !tunnelController.isRunRequested else {
      return
    }
    log("stopped revision=\(commandRevision)")
    channel.invokeMethod("stopped", arguments: commandRevision)
  }

  private func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }
}
