import Flutter
import Shared
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(
    for windowScene: UIWindowScene
  ) -> UIWindowScene.WindowingControlStyle {
    return .minimal
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let shortcutItem = connectionOptions.shortcutItem {
      handleShortcutItem(shortcutItem)
    }
    handleURLContexts(connectionOptions.urlContexts)
  }

  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    handleURLContexts(URLContexts)
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    handleShortcutItem(shortcutItem)
    completionHandler(true)
  }

  private func handleURLContexts(_ urlContexts: Set<UIOpenURLContext>) {
    guard !urlContexts.isEmpty else {
      return
    }
    ServicePlugin.openLinks(urlContexts.map(\.url.absoluteString))
  }

  private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
    guard let action = VPNAction(rawValue: shortcutItem.type) else {
      return
    }
    ServicePlugin.request(action)
  }
}
