import NetworkExtension
import Shared
import SwiftUI
import WidgetKit

struct WidgetControl: ControlWidget {
  static let kind = Bundle.main.bundleIdentifier!

  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: Self.kind,
      provider: VPNStatusProvider()
    ) { status in
      ControlWidgetToggle(
        "FlClash",
        isOn: status.isOn,
        action: SetVPNIntent()
      ) { isRunning in
        Label(
          status.showProfileName
            ? (isRunning ? status.profileName : "")
            : (isRunning
                ? String(localized: "connected")
                : String(localized: "disconnected")),
          image: "FlClash"
        )
      }
    }
    .displayName("FlClash")
    .description(LocalizedStringResource("toggleVPNDescription"))
  }
}

extension WidgetControl {
  struct VPNStatus {
    let isOn: Bool
    let profileName: String
    let showProfileName: Bool
  }

  struct VPNStatusProvider: ControlValueProvider {
    var previewValue: VPNStatus {
      VPNStatus(isOn: false, profileName: "", showProfileName: true)
    }

    func currentValue() async throws -> VPNStatus {
      let manager = try await NEHelper.loadManager()
      let isOn = manager.map {
        NEHelper.isRunning($0.connection.status)
      } ?? false
      let defaults = UserDefaults(suiteName: NEHelper.appGroupIdentifier)
      let profileName: String
      let showProfileName: Bool
      if let data = defaults?.data(forKey: "sharedState"),
        let state = try? JSONDecoder().decode(ProfileState.self, from: data)
      {
        profileName = state.currentProfileName ?? ""
        showProfileName = state.showQuickSettingsProfileName ?? true
      } else {
        profileName = ""
        showProfileName = true
      }
      return VPNStatus(
        isOn: isOn,
        profileName: profileName,
        showProfileName: showProfileName
      )
    }
  }

  private struct ProfileState: Decodable {
    let currentProfileName: String?
    let showQuickSettingsProfileName: Bool?
  }
}
