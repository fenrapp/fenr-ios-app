import DesignSystem
import Foundation
import SwiftUI

struct DashboardCardRowLabel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringResource
    let detail: LocalizedStringResource?
    let thumbnail: DashboardCardThumbnailViewData

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Constants.spacing) {
                    DashboardCardThumbnail(state: thumbnail)
                    labelText
                }
            } else {
                HStack(spacing: Constants.spacing) {
                    DashboardCardThumbnail(state: thumbnail)
                    labelText
                }
            }
        }
    }

    private var labelText: some View {
        VStack(alignment: .leading, spacing: Constants.labelSpacing) {
            Text(title)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : Constants.detailLineLimit)
                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
            }
        }
    }

    private enum Constants {
        static let spacing = DesignSpace.small
        static let labelSpacing: CGFloat = 2
        static let detailLineLimit = 2
    }
}
