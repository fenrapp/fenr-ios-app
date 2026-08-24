import DesignSystem
import SwiftUI

struct ConnectionTimelineView: View {
    let currentPhase: BikeOnboardingConnectionPhase?

    var body: some View {
        OnboardingMaterialPanel {
            VStack(alignment: .leading, spacing: DesignSpace.small) {
                ForEach(BikeOnboardingConnectionPhase.allCases, id: \.self) { phase in
                    HStack(spacing: DesignSpace.small) {
                        Image(systemName: icon(for: phase))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(tint(for: phase))
                            .frame(width: Constants.iconSize, height: Constants.iconSize)
                        Text(title(for: phase))
                            .font(.subheadline)
                            .foregroundStyle(textColor(for: phase))
                        Spacer()
                    }
                }
            }
        }
    }

    private func icon(for phase: BikeOnboardingConnectionPhase) -> String {
        guard let currentPhase else { return "circle" }
        if phase.rawValue < currentPhase.rawValue { return "checkmark.circle.fill" }
        if phase == currentPhase { return "circle.circle.fill" }
        return "circle"
    }

    private func tint(for phase: BikeOnboardingConnectionPhase) -> Color {
        guard let currentPhase else { return DesignColor.inactive }
        if phase.rawValue <= currentPhase.rawValue { return DesignColor.accent }
        return DesignColor.inactive
    }

    private func textColor(for phase: BikeOnboardingConnectionPhase) -> Color {
        guard let currentPhase else { return DesignColor.secondaryText }
        return phase.rawValue <= currentPhase.rawValue ? DesignColor.primaryText : DesignColor.secondaryText
    }

    private func title(for phase: BikeOnboardingConnectionPhase) -> String {
        switch phase {
        case .scanning: "Scanning for your bike"
        case .connecting: "Connecting"
        case .discovering: "Discovering services"
        case .authenticating: "Authenticating"
        case .subscribing: "Starting telemetry"
        }
    }
}

private enum Constants {
    static let iconSize: CGFloat = 22
}
