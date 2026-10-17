import NetworkExtension
import Shared
import SwiftUI
import WidgetKit

struct WidgetControl: ControlWidget {
  static let kind = NEHelper.controlKind

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
          isRunning && !status.profileName.isEmpty
            ? status.profileName
            : String(localized: isRunning ? "connected" : "disconnected"),
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
  }

  struct VPNStatusProvider: ControlValueProvider {
    var previewValue: VPNStatus {
      VPNStatus(isOn: false, profileName: "")
    }

    func currentValue() async throws -> VPNStatus {
      let manager = try await NEHelper.loadManager()
      return VPNStatus(
        isOn: manager.map { NEHelper.isRunning($0.connection.status) } ?? false,
        profileName: WidgetSharedState.load()?.currentProfileName ?? ""
      )
    }
  }
}
