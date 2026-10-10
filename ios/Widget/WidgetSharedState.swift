import Foundation
import Shared
import SwiftUI

struct WidgetSharedState: Decodable {
  let currentProfileName: String?
  let showQuickSettingsProfileName: Bool?
  let widgetTheme: WidgetTheme?

  static func load() -> WidgetSharedState? {
    guard
      let data = UserDefaults(suiteName: NEHelper.appGroupIdentifier)?
        .data(forKey: "sharedState")
    else {
      return nil
    }
    return try? JSONDecoder().decode(WidgetSharedState.self, from: data)
  }
}

struct WidgetTheme: Decodable {
  let themeMode: String
  let light: WidgetColors
  let dark: WidgetColors

  func colors(for scheme: ColorScheme) -> WidgetColors {
    switch themeMode {
    case "light": light
    case "dark": dark
    default: scheme == .dark ? dark : light
    }
  }

  var forcedColorScheme: ColorScheme? {
    switch themeMode {
    case "light": .light
    case "dark": .dark
    default: nil
    }
  }
}

struct WidgetColors: Decodable {
  let background: UInt32
  let onBackground: UInt32
  let onBackgroundVariant: UInt32
  let primary: UInt32
  let onPrimary: UInt32
  let trackOff: UInt32
  let thumbOff: UInt32
}

extension Color {
  init(argb: UInt32) {
    self.init(
      .sRGB,
      red: Double((argb >> 16) & 0xFF) / 255,
      green: Double((argb >> 8) & 0xFF) / 255,
      blue: Double(argb & 0xFF) / 255,
      opacity: Double(argb >> 24) / 255
    )
  }
}
