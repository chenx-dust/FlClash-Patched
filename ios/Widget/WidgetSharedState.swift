import Foundation
import Shared

struct WidgetSharedState: Decodable {
  let currentProfileName: String?

  static func load() -> WidgetSharedState? {
    guard let url = NEHelper.sharedStateURL,
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    return try? JSONDecoder().decode(WidgetSharedState.self, from: data)
  }
}
