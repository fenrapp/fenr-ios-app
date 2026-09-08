import DesignSystem
import SwiftUI

struct DashboardRideHeader: View {
    let deviceBattery: DashboardDeviceBatteryViewData
    let connectionNotice: DashboardConnectionNoticeViewData?
    let toggleDeviceBatteryDisplayMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.compactSpacing) {
            ViewThatFits(in: .horizontal) {
                horizontalHeader
                    .fixedSize(horizontal: true, vertical: true)
                verticalHeader
            }
            if let error = deviceBattery.errorText {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(DesignColor.critical)
                    .accessibilityIdentifier("dashboard.phone-battery.error")
            }
        }
        .font(.system(size: Constants.fontSize, weight: .semibold, design: .rounded))
        .monospacedDigit()
    }

    private var horizontalHeader: some View {
        HStack(spacing: Constants.itemSpacing) {
            clock
            if deviceBattery.isVisible {
                separator
                phoneBattery
            }
            if let connectionNotice {
                separator
                reconnectingChip(connectionNotice)
            }
        }
    }

    private var verticalHeader: some View {
        VStack(alignment: .leading, spacing: Constants.compactSpacing) {
            clock
            if deviceBattery.isVisible { phoneBattery }
            if let connectionNotice { reconnectingChip(connectionNotice) }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func reconnectingChip(_ notice: DashboardConnectionNoticeViewData) -> some View {
        Label(notice.text, systemImage: "arrow.triangle.2.circlepath")
            .font(.system(size: Constants.noticeFontSize, weight: .semibold, design: .rounded))
            .foregroundStyle(DesignColor.warning)
            .padding(.horizontal, Constants.noticeHorizontalPadding)
            .padding(.vertical, Constants.noticeVerticalPadding)
            .background(DesignColor.warning.opacity(Constants.noticeBackgroundOpacity), in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(notice.accessibilityLabel)
            .accessibilityIdentifier("dashboard.reconnecting")
    }

    private var clock: some View {
        TimelineView(.periodic(from: currentMinute, by: Constants.minuteInterval)) { context in
            let time = context.date.formatted(date: .omitted, time: .shortened)
            Text(time)
                .accessibilityLabel(.rideDashboardHeaderTimeAccessibility)
                .accessibilityValue(time)
        }
    }

    private var phoneBattery: some View {
        Button(action: toggleDeviceBatteryDisplayMode) {
            Group {
                if deviceBattery.showsIcon, deviceBattery.showsPercentage {
                    Label(deviceBattery.percentageText, systemImage: deviceBattery.systemImage)
                } else if deviceBattery.showsPercentage {
                    Text(deviceBattery.percentageText)
                } else if deviceBattery.showsIcon {
                    Image(systemName: deviceBattery.systemImage)
                } else {
                    EmptyView()
                }
            }
            .frame(minWidth: Constants.minimumTouchTarget, minHeight: Constants.minimumTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!deviceBattery.canChangeDisplayMode)
        .foregroundStyle(phoneBatteryColor)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(deviceBattery.accessibilityLabel)
        .accessibilityHint(deviceBattery.displayModeAccessibilityHint)
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

    private var currentMinute: Date {
        Calendar.autoupdatingCurrent.dateInterval(of: .minute, for: .now)?.start ?? .now
    }

    private enum Constants {
        static let fontSize: CGFloat = 18
        static let itemSpacing: CGFloat = 10
        static let compactSpacing: CGFloat = 2
        static let minimumTouchTarget: CGFloat = 44
        static let separatorWidth: CGFloat = 1
        static let separatorHeight: CGFloat = 17
        static let minuteInterval: TimeInterval = 60
        static let noticeFontSize: CGFloat = 13
        static let noticeHorizontalPadding: CGFloat = 9
        static let noticeVerticalPadding: CGFloat = 5
        static let noticeBackgroundOpacity = 0.16
    }
}
