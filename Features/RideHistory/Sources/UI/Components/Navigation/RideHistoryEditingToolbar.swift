import DesignSystem
import Foundation
import SwiftUI

struct RideHistoryEditingToolbar: ToolbarContent {
    let isVisible: Bool
    let isEditing: Bool
    let availableRideIDs: Set<UUID>
    @Binding var selectedRideIDs: Set<UUID>
    let isDeleting: Bool
    let deleteSelection: () -> Void

    var body: some ToolbarContent {
        if isVisible {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button(allRidesSelected ? "Deselect All" : "Select All") {
                        selectedRideIDs = allRidesSelected ? [] : availableRideIDs
                    }
                    .disabled(isDeleting)
                }
                editingBottomBar
            }

            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .disabled(isDeleting)
            }
        }
    }

    @ToolbarContentBuilder
    private var editingBottomBar: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .bottomBar) {
                selectionLabel
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, Constants.bottomBarHorizontalPadding)
            }
            ToolbarSpacer(.flexible, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                deleteSelectionButton
            }
        } else {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    selectionLabel
                    Spacer()
                    deleteSelectionButton
                }
                .padding(.horizontal, Constants.bottomBarHorizontalPadding)
                .padding(.vertical, Constants.bottomBarVerticalPadding)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var selectionLabel: some View {
        Text(selectionText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(DesignColor.secondaryText)
            .monospacedDigit()
    }

    private var deleteSelectionButton: some View {
        Button(role: .destructive, action: deleteSelection) {
            Image(systemName: "trash")
                .frame(
                    width: Constants.deleteButtonSize,
                    height: Constants.deleteButtonSize,
                    alignment: .center
                )
        }
        .tint(DesignColor.critical)
        .disabled(selectedRideIDs.isEmpty || isDeleting)
        .accessibilityLabel("Delete selected rides")
    }

    private var allRidesSelected: Bool {
        !availableRideIDs.isEmpty && selectedRideIDs == availableRideIDs
    }

    private var selectionText: String {
        let count = selectedRideIDs.count
        return count == 1 ? "1 Selected" : "\(count) Selected"
    }

    private enum Constants {
        static let bottomBarHorizontalPadding: CGFloat = 8
        static let bottomBarVerticalPadding: CGFloat = 4
        static let deleteButtonSize: CGFloat = 32
    }
}
