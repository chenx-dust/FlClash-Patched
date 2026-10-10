import AppIntents
import NetworkExtension
import Shared
import SwiftUI
import WidgetKit

struct WidgetStatus: Widget {
  static let kind = "\(Bundle.main.bundleIdentifier!).Status"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: Self.kind, provider: Provider()) { entry in
      WidgetStatusView(entry: entry)
    }
    .configurationDisplayName("FlClash")
    .description(LocalizedStringResource("widgetDescription"))
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

extension WidgetStatus {
  struct Entry: TimelineEntry {
    let date: Date
    let isOn: Bool
    let profileName: String
    let theme: WidgetTheme?
  }

  struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
      Entry(date: .now, isOn: false, profileName: "FlClash", theme: nil)
    }

    func getSnapshot(
      in context: Context,
      completion: @escaping (Entry) -> Void
    ) {
      if context.isPreview {
        completion(placeholder(in: context))
        return
      }
      Task { completion(await currentEntry()) }
    }

    func getTimeline(
      in context: Context,
      completion: @escaping (Timeline<Entry>) -> Void
    ) {
      // The app and the tunnel reload this timeline on every change it shows.
      Task {
        completion(Timeline(entries: [await currentEntry()], policy: .never))
      }
    }

    private func currentEntry() async -> Entry {
      let manager = try? await NEHelper.loadManager()
      let isOn = manager.map { NEHelper.isRunning($0.connection.status) } ?? false
      let state = WidgetSharedState.load()
      let profileName = state?.currentProfileName ?? ""
      return Entry(
        date: .now,
        isOn: isOn,
        profileName: profileName.isEmpty ? "FlClash" : profileName,
        theme: state?.widgetTheme
      )
    }
  }
}

private struct WidgetStatusView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme
  let entry: WidgetStatus.Entry

  private var colors: WidgetColors? {
    entry.theme?.colors(for: colorScheme)
  }

  var body: some View {
    content
      .environment(\.colorScheme, entry.theme?.forcedColorScheme ?? colorScheme)
      .containerBackground(for: .widget) {
        if let colors {
          Color(argb: colors.background)
        } else {
          Rectangle().fill(.fill.tertiary)
        }
      }
  }

  @ViewBuilder
  private var content: some View {
    switch family {
    case .systemMedium:
      HStack(spacing: 12) {
        icon
        labels
        Spacer(minLength: 0)
        toggle
      }
    default:
      VStack(alignment: .leading) {
        HStack(alignment: .center) {
          icon
          Spacer(minLength: 0)
          toggle
        }
        Spacer(minLength: 0)
        labels
      }
      .padding(.top, 6)
    }
  }

  private var icon: some View {
    Image("AppLogo")
      .resizable()
      .scaledToFit()
      .frame(height: 48)
  }

  private var labels: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(entry.profileName)
        .font(.headline)
        .lineLimit(2)
        .foregroundStyle(colors.map { Color(argb: $0.onBackground) } ?? .primary)
      Text(entry.isOn ? "connected" : "disconnected")
        .font(.caption)
        .foregroundStyle(colors.map { Color(argb: $0.onBackgroundVariant) } ?? .secondary)
    }
  }

  private var toggle: some View {
    // Unlike ControlWidgetToggle, a widget Toggle does not fill in `value`.
    Toggle(isOn: entry.isOn, intent: SetVPNIntent(value: !entry.isOn)) {
      Text("toggleVPNDescription")
    }
    // Widgets cannot host the UISwitch behind `.switch`; draw the switch instead.
    .toggleStyle(WidgetSwitchStyle(colors: colors))
  }
}

private struct WidgetSwitchStyle: ToggleStyle {
  let colors: WidgetColors?

  // Material 3 switch metrics scaled by 1.25, kept in step with Android's widget_toggle.xml.
  func makeBody(configuration: Configuration) -> some View {
    Capsule()
      .fill(trackColor(isOn: configuration.isOn))
      .strokeBorder(trackBorderColor(isOn: configuration.isOn), lineWidth: 2.5)
      .frame(width: 65, height: 40)
      .overlay(alignment: configuration.isOn ? .trailing : .leading) {
        Circle()
          .fill(thumbColor(isOn: configuration.isOn))
          .frame(width: configuration.isOn ? 30 : 20, height: configuration.isOn ? 30 : 20)
          .padding(configuration.isOn ? 5 : 10)
      }
      .accessibilityRepresentation {
        Toggle(isOn: configuration.$isOn) { configuration.label }
      }
  }

  private func trackColor(isOn: Bool) -> Color {
    guard let colors else {
      return isOn ? .accentColor : .secondary.opacity(0.3)
    }
    return Color(argb: isOn ? colors.primary : colors.trackOff)
  }

  private func trackBorderColor(isOn: Bool) -> Color {
    guard let colors, !isOn else {
      return .clear
    }
    return Color(argb: colors.thumbOff)
  }

  private func thumbColor(isOn: Bool) -> Color {
    guard let colors else {
      return .white
    }
    return Color(argb: isOn ? colors.onPrimary : colors.thumbOff)
  }
}
