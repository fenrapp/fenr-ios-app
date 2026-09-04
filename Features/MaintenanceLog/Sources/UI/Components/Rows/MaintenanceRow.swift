import DesignSystem
import SwiftUI

struct MaintenanceRow: View {
    let row: MaintenanceLogViewState.Row
    let showsReminder: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .top, spacing: DesignSpace.small) {
            Image(systemName: row.symbolName)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .background(Color.accentColor.gradient, in: RoundedRectangle(cornerRadius: Constants.iconRadius))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
                if dynamicTypeSize.isAccessibilitySize {
                    Text(row.title)
                        .font(.headline)
                    if !showsReminder { serviceDate }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.title)
                            .font(.headline)
                        Spacer(minLength: DesignSpace.extraSmall)
                        if !showsReminder { serviceDate }
                    }
                }
                if showsReminder, let reminder = row.reminderText {
                    Label {
                        Text(reminder)
                    } icon: {
                        Image(systemName: "bell.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                    Text(.maintenanceLastServiced(row.dateText))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let detail = row.detailText {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignSpace.extraSmall)
        .contentShape(Rectangle())
    }

    private var serviceDate: some View {
        Text(row.dateText)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private enum Constants {
        static let iconSize: CGFloat = 36
        static let iconRadius: CGFloat = 9
    }
}
