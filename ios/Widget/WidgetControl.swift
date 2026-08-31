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
    ) { isOn in
      ControlWidgetToggle(
        "FlClash",
        isOn: isOn,
        action: SetVPNIntent()
      ) { isRunning in
        Label(
          isRunning
            ? String(localized: "connected")
            : String(localized: "disconnected"),
          image: "FlClash"
        )
      }
    }
    .displayName("FlClash")
    .description(LocalizedStringResource("toggleVPNDescription"))
  }
}

extension WidgetControl {
  struct VPNStatusProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
      guard let manager = try await NEHelper.loadManager() else {
        return false
      }
      return NEHelper.isRunning(manager.connection.status)
    }
  }
}
