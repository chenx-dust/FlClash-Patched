import Flutter
import UIKit
import Shared

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let shortcutItem = connectionOptions.shortcutItem {
      handleShortcutItem(shortcutItem)
    }
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    handleShortcutItem(shortcutItem)
    completionHandler(true)
  }

  private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    switch shortcutItem.type {
    case "toggle":
      Task {
        guard let manager = try await NEHelper.loadManager() else {
          return
        }
        try await NEHelper.toggle(manager: manager)
      }
      break
    default:
      break
    }
  }
}
