import SwiftUI

#Preview("Available · Not configured") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(
                isAvailable: true,
                currentModeTitle: "Not set up",
                protectionOptions: previewOptions(selected: nil)
            ),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
}

#Preview("Available · PIN + Face ID · Accessibility") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(
                isAvailable: true,
                currentModeTitle: "PIN + Face ID",
                canChangePIN: true,
                protectionOptions: previewOptions(selected: .pinAndFaceID)
            ),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Available · No PIN") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(
                isAvailable: true,
                currentModeTitle: "No PIN",
                protectionOptions: previewOptions(selected: .withoutPIN)
            ),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
}

#Preview("Available · PIN") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(
                isAvailable: true,
                currentModeTitle: "PIN",
                canChangePIN: true,
                protectionOptions: previewOptions(selected: .pin)
            ),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
}

#Preview("Protection options · Accessibility") {
    NavigationStack {
        BikeLockProtectionSelectionView(
            options: previewOptions(selected: .pinAndFaceID),
            errorMessage: nil,
            onSelect: { _ in },
            onSaveNewPIN: { _, _, _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Protection options · Failure") {
    NavigationStack {
        BikeLockProtectionSelectionView(
            options: previewOptions(selected: .pin),
            errorMessage: "The saved PIN is unavailable.",
            onSelect: { _ in },
            onSaveNewPIN: { _, _, _ in }
        )
    }
}

#Preview("Protection options · Failure · Accessibility XXXL") {
    NavigationStack {
        BikeLockProtectionSelectionView(
            options: previewOptions(selected: .pin),
            errorMessage: "The saved PIN is unavailable.",
            onSelect: { _ in },
            onSaveNewPIN: { _, _, _ in }
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("New PIN · Mismatch · Accessibility") {
    NavigationStack {
        BikeLockNewPINPreview()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Current PIN · Incorrect · Accessibility") {
    NavigationStack {
        BikeLockPINInputPreview()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Unavailable") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
}

#Preview("Working · Error") {
    NavigationStack {
        BikeLockSettingsContent(
            viewState: .init(
                isAvailable: true,
                currentModeTitle: "PIN",
                canChangePIN: true,
                protectionOptions: previewOptions(selected: .pin),
                isWorking: true,
                errorMessage: "The saved PIN is unavailable."
            ),
            onChangeProtection: {},
            onChangePIN: {}
        )
        .navigationTitle("Bike Lock")
    }
}

private func previewOptions(
    selected: BikeLockProtectionOptionID?
) -> [BikeLockProtectionOptionViewData] {
    [
        .init(
            id: .pinAndFaceID,
            title: "PIN + Face ID",
            detail: "Use Face ID first, with your PIN as a fallback.",
            isSelected: selected == .pinAndFaceID,
            requiresPINSetup: selected == nil
        ),
        .init(
            id: .pin,
            title: "PIN",
            detail: "Enter a 6-digit PIN whenever you unlock.",
            isSelected: selected == .pin,
            requiresPINSetup: selected == nil
        ),
        .init(
            id: .withoutPIN,
            title: "No PIN",
            detail: "Lock and unlock immediately from the card.",
            isSelected: selected == .withoutPIN,
            requiresPINSetup: false
        )
    ]
}

private struct BikeLockNewPINPreview: View {
    @State private var errorMessage: String? = "The PINs do not match."

    var body: some View {
        BikeLockNewPINView(title: "Create PIN", errorMessage: errorMessage) { pin, confirmation in
            errorMessage = pin == confirmation ? nil : "The PINs do not match."
        }
    }
}

private struct BikeLockPINInputPreview: View {
    @State private var errorMessage: String? = "Incorrect PIN"

    var body: some View {
        BikeLockPINInputView(title: "Enter Current PIN", errorMessage: errorMessage) { pin in
            errorMessage = pin == "123456" ? nil : "Incorrect PIN"
        }
    }
}
