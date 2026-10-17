import AppIntents
import Shared

@available(iOS 16.4, *)
public struct FlClashShortcutsProvider: AppShortcutsProvider {
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: StartVPNIntent(),
      phrases: [
        "Start \(.applicationName)",
        "Connect \(.applicationName)",
        "Turn on \(.applicationName)",
      ],
      shortTitle: "startVPNShortTitle",
      systemImageName: "power"
    )
    AppShortcut(
      intent: StopVPNIntent(),
      phrases: [
        "Stop \(.applicationName)",
        "Disconnect \(.applicationName)",
        "Turn off \(.applicationName)",
      ],
      shortTitle: "stopVPNShortTitle",
      systemImageName: "stop.fill"
    )
    AppShortcut(
      intent: ToggleVPNIntent(),
      phrases: [
        "Toggle \(.applicationName)",
        "Switch \(.applicationName)",
      ],
      shortTitle: "toggleVPNShortTitle",
      systemImageName: "arrow.triangle.2.circlepath"
    )
  }
}
