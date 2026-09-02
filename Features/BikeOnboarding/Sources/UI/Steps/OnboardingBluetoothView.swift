import SwiftUI

struct OnboardingBluetoothView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewState: BikeOnboardingViewState
    let onContinue: () -> Void
    let onOpenSettings: () -> Void

    @State private var rowsVisible = false

    var body: some View {
        OnboardingStepLayout(
            eyebrow: "BLUETOOTH",
            title: title,
            detail: detail
        ) {
            if showsPreparation {
                VStack(spacing: Constants.rowSpacing) {
                    ForEach(Array(preparationItems.enumerated()), id: \.offset) { index, item in
                        preparationRow(item)
                            .opacity(rowsVisible ? 1 : .zero)
                            .offset(y: rowsVisible ? .zero : Constants.rowEntranceOffset)
                            .animation(
                                reduceMotion
                                    ? nil
                                    : .easeOut(duration: Constants.rowEntranceDuration)
                                        .delay(Double(index) * Constants.rowEntranceDelay),
                                value: rowsVisible
                            )
                    }
                }
            } else {
                OnboardingBluetoothRecoveryGuide(steps: recoverySteps)
            }
        } footer: {
            switch viewState.bluetoothState {
            case .denied:
                OnboardingPrimaryButton(title: "Open Settings", action: onOpenSettings)
            case .poweredOff, .unavailable:
                OnboardingPrimaryButton(title: "Try Again", systemImage: "arrow.clockwise", action: onContinue)
            case .preparation, .requestingAccess:
                OnboardingPrimaryButton(
                    title: "Continue",
                    systemImage: "arrow.right",
                    accessibilityLabel: viewState.isRequestingBluetoothAccess
                        ? "Requesting Bluetooth access"
                        : "Continue",
                    isBusy: viewState.isRequestingBluetoothAccess,
                    action: onContinue
                )
            }
        }
        .task(id: viewState.bluetoothState) {
            rowsVisible = reduceMotion
            guard showsPreparation, !reduceMotion else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            rowsVisible = true
        }
    }

    private var title: String {
        switch viewState.bluetoothState {
        case .preparation, .requestingAccess:
            "Get ready to connect."
        case .denied:
            "Bluetooth access is off."
        case .poweredOff:
            "Turn on Bluetooth."
        case .unavailable:
            "Bluetooth isn't available."
        }
    }

    private var detail: String {
        switch viewState.bluetoothState {
        case .preparation, .requestingAccess:
            "Keep your bike on and nearby. FENR will ask for Bluetooth access when you continue."
        case .denied:
            "Allow FENR to use Bluetooth, then return to connect."
        case .poweredOff:
            "Turn on Bluetooth in Control Center or Settings, then return to FENR."
        case .unavailable:
            "FENR can't start Bluetooth on this iPhone right now. Restart your iPhone and try again."
        }
    }

    private var showsPreparation: Bool {
        viewState.bluetoothState == .preparation || viewState.bluetoothState == .requestingAccess
    }

    private var preparationItems: [PreparationItem] {
        [
            .init(
                icon: "power",
                title: "Bike powered on",
                detail: "Wake the bike and keep it within reach."
            ),
            .init(
                icon: "power.circle",
                title: "Power off Arkenstone",
                detail: "Switch off your Arkenstone so FENR can connect directly."
            ),
            .init(
                icon: "iphone",
                title: "Keep your iPhone nearby",
                detail: "Stay close while FENR secures the connection."
            )
        ]
    }

    private var recoverySteps: [OnboardingBluetoothRecoveryGuide.Step] {
        switch viewState.bluetoothState {
        case .denied:
            [
                .init(title: "Open FENR Settings", detail: "Use the button below."),
                .init(title: "Turn Bluetooth on", detail: "Then return to FENR.")
            ]
        case .poweredOff:
            [
                .init(title: "Open Control Center", detail: "Swipe down from the top-right."),
                .init(title: "Turn Bluetooth on", detail: "Then return to FENR.")
            ]
        case .unavailable:
            [
                .init(title: "Restart your iPhone", detail: "Wait until iOS is ready."),
                .init(title: "Return to FENR", detail: "Then try connecting again.")
            ]
        case .preparation, .requestingAccess:
            []
        }
    }

    private func preparationRow(_ item: PreparationItem) -> some View {
        HStack(alignment: .top, spacing: Constants.iconSpacing) {
            Image(systemName: item.icon)
                .font(.title3.weight(.semibold))
                .frame(width: Constants.iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Constants.textSpacing) {
                Text(item.title).font(.headline)
                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: .zero)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension OnboardingBluetoothView {
    struct PreparationItem {
        let icon: String
        let title: String
        let detail: String
    }

    enum Constants {
        static let rowSpacing: CGFloat = 20
        static let iconSpacing: CGFloat = 14
        static let iconWidth: CGFloat = 28
        static let textSpacing: CGFloat = 4
        static let rowEntranceOffset: CGFloat = 8
        static let rowEntranceDuration = 0.32
        static let rowEntranceDelay = 0.06
    }
}
