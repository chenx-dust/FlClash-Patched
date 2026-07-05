import AppIntents
import Foundation
import NetworkExtension
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
                action: ToggleVPNIntent()
            ) { isRunning in
                Label(
                    isRunning ? "Connected" : "Disconnected",
                    systemImage: isRunning ? "lock.shield.fill" : "lock.shield"
                )
            }
        }
        .displayName("FlClash")
        .description("Toggle VPN connection.")
    }
}

extension WidgetControl {
    struct VPNStatusProvider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            guard let manager = managers.first else { return false }
            let status = manager.connection.status
            return [.connecting, .connected, .reasserting].contains(status)
        }
    }
}

struct ToggleVPNIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle FlClash VPN"

    private static let appBundleId = String(Bundle.main.bundleIdentifier!.dropLast(".NECore".count))
    private static let appGroupIdentifier = "group.\(appBundleId)"
    private static let runTimeKey = "runTime"

    @Parameter(title: "VPN is running")
    var value: Bool

    func perform() async throws -> some IntentResult {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        guard let manager = managers.first else {
            return .result()
        }
        if value {
            try manager.connection.startVPNTunnel()
            let ms = Int(Date().timeIntervalSince1970 * 1000)
            UserDefaults(suiteName: Self.appGroupIdentifier)?.set(ms, forKey: Self.runTimeKey)
        } else {
            manager.connection.stopVPNTunnel()
            UserDefaults(suiteName: Self.appGroupIdentifier)?.removeObject(forKey: Self.runTimeKey)
        }
        return .result()
    }
}
