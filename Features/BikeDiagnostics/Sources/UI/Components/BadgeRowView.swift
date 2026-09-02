import DesignSystem
import SwiftUI

struct BadgeRowView: View {
    let badges: [BikeDiagnosticsBadgeViewData]

    var body: some View {
        SurfacePanel(title: BikeDiagnosticsL10n.text(.bikeDiagnosticsSectionState)) {
            if badges.isEmpty {
                Text(.bikeDiagnosticsNoState)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.badgeSpacing) {
                        ForEach(badges) { badge in
                            Text(verbatim: badge.title)
                                .font(.caption.weight(.semibold))
                                .lineLimit(Constants.lineLimit)
                                .padding(.horizontal, Constants.horizontalPadding)
                                .padding(.vertical, Constants.verticalPadding)
                                .background(Color.accentColor.opacity(Constants.backgroundOpacity), in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private enum Constants {
        static let badgeSpacing = DesignSpace.extraSmall
        static let horizontalPadding = DesignSpace.small
        static let verticalPadding = DesignSpace.extraSmall
        static let lineLimit = 1
        static let backgroundOpacity = 0.16
    }
}

#Preview("Badges") {
    BadgeRowView(badges: [
        .init(kind: .on, title: "On"),
        .init(kind: .charger, title: "Charger"),
        .init(kind: .fault, title: "Fault")
    ])
        .padding()
}
