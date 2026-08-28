import SwiftUI

struct DashboardCardRowLabel: View {
    let title: String
    let detail: String?
    let thumbnail: DashboardCardThumbnailViewData

    var body: some View {
        HStack(spacing: Constants.spacing) {
            DashboardCardThumbnail(state: thumbnail)

            VStack(alignment: .leading, spacing: Constants.labelSpacing) {
                Text(title)
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(Constants.detailLineLimit)
                }
            }
        }
    }

    private enum Constants {
        static let spacing: CGFloat = 12
        static let labelSpacing: CGFloat = 2
        static let detailLineLimit = 2
    }
}
