import SwiftUI

struct OnboardingBluetoothView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let viewState: BikeOnboardingViewState
    let onContinue: () -> Void
    let onOpenSettings: () -> Void

    @State private var rowsVisible = false

    var body: some View {
        OnboardingStepLayout(
            eyebrow: BikeOnboardingL10n.text(.bikeOnboardingBluetoothEyebrow),
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
                OnboardingPrimaryButton(
                    title: BikeOnboardingL10n.text(.bikeOnboardingActionOpenSettings),
                    action: onOpenSettings
                )
            case .poweredOff, .unavailable:
                OnboardingPrimaryButton(
                    title: BikeOnboardingL10n.text(.bikeOnboardingActionTryAgain),
                    systemImage: "arrow.clockwise",
                    action: onContinue
                )
            case .preparation, .requestingAccess:
                OnboardingPrimaryButton(
                    title: BikeOnboardingL10n.text(.bikeOnboardingActionContinue),
                    systemImage: "arrow.right",
                    accessibilityLabel: viewState.isRequestingBluetoothAccess
                        ? BikeOnboardingL10n.text(.bikeOnboardingAccessibilityRequestingBluetooth)
                        : BikeOnboardingL10n.text(.bikeOnboardingActionContinue),
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
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationTitle)
        case .denied:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothDeniedTitle)
        case .poweredOff:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothPoweredOffTitle)
        case .unavailable:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothUnavailableTitle)
        }
    }

    private var detail: String {
        switch viewState.bluetoothState {
        case .preparation, .requestingAccess:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationDetail)
        case .denied:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothDeniedDetail)
        case .poweredOff:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothPoweredOffDetail)
        case .unavailable:
            BikeOnboardingL10n.text(.bikeOnboardingBluetoothUnavailableDetail)
        }
    }

    private var showsPreparation: Bool {
        viewState.bluetoothState == .preparation || viewState.bluetoothState == .requestingAccess
    }

    private var preparationItems: [PreparationItem] {
        [
            .init(
                icon: "power",
                title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationBikeTitle),
                detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationBikeDetail)
            ),
            .init(
                icon: "power.circle",
                title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationArkenstoneTitle),
                detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationArkenstoneDetail)
            ),
            .init(
                icon: "iphone",
                title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationIphoneTitle),
                detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothPreparationIphoneDetail)
            )
        ]
    }

    private var recoverySteps: [OnboardingBluetoothRecoveryGuide.Step] {
        switch viewState.bluetoothState {
        case .denied:
            [
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryOpenSettingsTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryOpenSettingsDetail)
                ),
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryTurnOnTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryReturnDetail)
                )
            ]
        case .poweredOff:
            [
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryControlCenterTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryControlCenterDetail)
                ),
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryTurnOnTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryReturnDetail)
                )
            ]
        case .unavailable:
            [
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryRestartTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryRestartDetail)
                ),
                .init(
                    title: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryReturnTitle),
                    detail: BikeOnboardingL10n.text(.bikeOnboardingBluetoothRecoveryTryAgainDetail)
                )
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
