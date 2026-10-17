import Foundation
import Shared
import WidgetKit

/// The app group is the only place the Network Extension and the Control
/// Center control can read what Flutter last synced.
final class SharedStateStore {
  private let eventQueueDirectoryName = "core-events"

  let eventNotificationName = "\(NEHelper.providerBundleIdentifier).event"

  func saveSharedState(_ data: Data) -> Bool {
    guard let url = NEHelper.sharedStateURL,
      (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
    else {
      return false
    }
    let previousName = profileName(try? Data(contentsOf: url))
    do {
      try data.write(to: url, options: .atomic)
    } catch {
      return false
    }
    if previousName != profileName(data), #available(iOS 18.0, *) {
      ControlCenter.shared.reloadControls(ofKind: NEHelper.controlKind)
    }
    return true
  }

  func runTime() -> Int {
    guard let url = NEHelper.runTimeURL,
      let text = try? String(contentsOf: url, encoding: .utf8)
    else {
      return 0
    }
    return Int(text) ?? 0
  }

  func eventQueueDirectory() -> URL? {
    FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: NEHelper.appGroupIdentifier
    )?.appendingPathComponent(eventQueueDirectoryName, isDirectory: true)
  }

  private func profileName(_ data: Data?) -> String? {
    guard let data,
      let object = try? JSONSerialization.jsonObject(with: data)
        as? [String: Any]
    else {
      return nil
    }
    return object["currentProfileName"] as? String
  }
}
