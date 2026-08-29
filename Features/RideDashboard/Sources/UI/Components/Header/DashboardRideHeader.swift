import DesignSystem
import SwiftUI

struct DashboardRideHeader: View {
    let deviceBattery: DashboardDeviceBatteryViewData
    let toggleDeviceBatteryDisplayMode: () -> Void

    var body: some View {
        HStack(spacing: Constants.itemSpacing) {
            clock
            if deviceBattery.displayMode != .hidden {
                separator
                phoneBattery
            }
        }
        .font(.system(size: Constants.fontSize, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }

    private var clock: some View {
        TimelineView(.periodic(from: currentMinute, by: Constants.minuteInterval)) { context in
            let time = context.date.formatted(date: .omitted, time: .shortened)
            Text(time)
                .accessibilityLabel("Time")
                .accessibilityValue(time)
        }
    }

    private var phoneBattery: some View {
        Button(action: toggleDeviceBatteryDisplayMode) {
            switch deviceBattery.displayMode {
            case .iconAndText:
                Label(deviceBattery.percentageText, systemImage: deviceBattery.systemImage)
            case .textOnly:
                Text(deviceBattery.percentageText)
            case .iconOnly:
                Image(systemName: deviceBattery.systemImage)
            case .hidden:
                EmptyView()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(phoneBatteryColor)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(deviceBattery.accessibilityLabel)
        .accessibilityHint(deviceBatteryDisplayModeHint)
        .accessibilityIdentifier("dashboard.phone-battery")
    }

    private var separator: some View {
        Rectangle()
            .fill(DesignColor.border)
            .frame(width: Constants.separatorWidth, height: Constants.separatorHeight)
            .accessibilityHidden(true)
    }

    private var phoneBatteryColor: Color {
        switch deviceBattery.emphasis {
        case .unavailable: DesignColor.secondaryText
        case .normal: DesignColor.primaryText
        case .low: DesignColor.critical
        case .charging: DesignColor.positive
        }
    }

    private var deviceBatteryDisplayModeHint: String {
        switch deviceBattery.displayMode {
        case .iconAndText: "Switches to percentage-only display"
        case .textOnly: "Switches to icon-only display"
        case .iconOnly: "Switches to icon and percentage display"
        case .hidden: ""
        }
    }

    private var currentMinute: Date {
        Calendar.autoupdatingCurrent.dateInterval(of: .minute, for: .now)?.start ?? .now
    }

    private enum Constants {
        static let fontSize: CGFloat = 18
        static let itemSpacing: CGFloat = 10
        static let separatorWidth: CGFloat = 1
        static let separatorHeight: CGFloat = 17
        static let minuteInterval: TimeInterval = 60
    }
}
