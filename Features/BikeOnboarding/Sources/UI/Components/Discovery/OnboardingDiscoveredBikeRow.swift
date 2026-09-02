import SwiftUI
import UIKit

struct OnboardingDiscoveredBikeRow: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let bike: BikeDiscoveryViewData
    let isSelectable: Bool
    let onSelect: () -> Void

    var body: some View {
        Group {
            if isSelectable {
                Button(action: onSelect) { rowContent }
                    .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelectable
            ? BikeOnboardingL10n.text(.bikeOnboardingAccessibilitySelectBikeHint)
            : BikeOnboardingL10n.text(.bikeOnboardingAccessibilityConfirmingHint))
    }

    @ViewBuilder private var rowContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Constants.accessibilitySpacing) {
                modelHeader
                vinText
                signalText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(RowSurface(reduceTransparency: reduceTransparency))
        } else {
            HStack(spacing: Constants.contentSpacing) {
                bikeIcon
                VStack(alignment: .leading, spacing: Constants.textSpacing) {
                    Text(bike.modelTitle).font(.headline)
                    vinText
                    signalText
                }
                Spacer(minLength: .zero)
                signalBars
                if isSelectable {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .modifier(RowSurface(reduceTransparency: reduceTransparency))
        }
    }

    private var modelHeader: some View {
        HStack(spacing: Constants.contentSpacing) {
            bikeIcon
            Text(bike.modelTitle).font(.headline)
            Spacer(minLength: .zero)
            signalBars
        }
    }

    private var bikeIcon: some View {
        Image(systemName: "bolt.fill")
            .font(.headline)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(Color.primary.opacity(Constants.iconBackgroundOpacity), in: Circle())
            .accessibilityHidden(true)
    }

    private var vinText: some View {
        Text(bike.formattedVIN)
            .font(.caption.monospaced().weight(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var signalText: some View {
        Text(verbatim: "\(bike.signalText)  ·  \(bike.rssiText)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var signalBars: some View {
        HStack(alignment: .bottom, spacing: Constants.signalSpacing) {
            ForEach(1 ... Constants.signalBarCount, id: \.self) { bar in
                Capsule()
                    .fill(bar <= bike.signalLevel ? Color.primary : Color.primary.opacity(Constants.inactiveOpacity))
                    .frame(width: Constants.signalBarWidth, height: CGFloat(bar) * Constants.signalBarHeightUnit)
            }
        }
        .accessibilityHidden(true)
    }

    private var accessibilityLabel: String {
        BikeOnboardingL10n.bikeAccessibility(
            title: bike.modelTitle,
            vin: bike.accessibilityVIN,
            signal: bike.signalText,
            rssi: bike.rssiText
        )
    }
}

private struct RowSurface: ViewModifier {
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        content
            .frame(minHeight: Constants.minimumHeight)
            .padding(Constants.padding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: Constants.radius))
            .contentShape(Rectangle())
    }

    private var backgroundColor: Color {
        reduceTransparency
            ? Color(uiColor: .secondarySystemBackground)
            : Color.primary.opacity(Constants.backgroundOpacity)
    }

    private enum Constants {
        static let minimumHeight: CGFloat = 44
        static let padding: CGFloat = 14
        static let radius: CGFloat = 18
        static let backgroundOpacity = 0.06
    }
}

private extension OnboardingDiscoveredBikeRow {
    enum Constants {
        static let contentSpacing: CGFloat = 12
        static let accessibilitySpacing: CGFloat = 10
        static let textSpacing: CGFloat = 4
        static let iconSize: CGFloat = 44
        static let iconBackgroundOpacity = 0.1
        static let signalSpacing: CGFloat = 2
        static let signalBarCount = 3
        static let signalBarWidth: CGFloat = 3
        static let signalBarHeightUnit: CGFloat = 5
        static let inactiveOpacity = 0.18
    }
}
