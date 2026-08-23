import DesignSystem
import SwiftUI

struct BadgeRowView: View {
    let badges: [String]

    var body: some View {
        SurfacePanel(title: "State") {
            if badges.isEmpty {
                Text("No state yet")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.badgeSpacing) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
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
    BadgeRowView(badges: ["On", "Charger", "Fault", "Crawl FWD"])
        .padding()
}
