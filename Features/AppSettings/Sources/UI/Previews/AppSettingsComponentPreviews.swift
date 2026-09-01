import SwiftUI

#if os(iOS)
#Preview("Location and navigation") {
    Form {
        Section("Location") {
            LocationPermissionRow(status: .authorized, onRequestAccess: {})
            LocationPermissionRow(status: .notDetermined, onRequestAccess: {})
            LocationPermissionRow(status: .denied, onRequestAccess: {})
        }
        Section("Navigation") {
            SettingsNavigationRow(
                icon: "rectangle.stack.fill",
                title: "Dashboard cards",
                detail: "Choose their order and visibility",
                accessibilityIdentifier: "settings.dashboardCards",
                action: {}
            )
            SettingsNavigationRow(
                icon: "slider.horizontal.3",
                title: "Power modes",
                detail: "5 maps configured",
                accessibilityIdentifier: "settings.powerModes",
                action: {}
            )
            SettingsNavigationRow(
                icon: "clock.arrow.circlepath",
                title: "Ride history",
                detail: "Review saved rides and recent comparisons",
                accessibilityIdentifier: "settings.rideHistory",
                action: {}
            )
            TelemetryActionRow(action: {})
        }
    }
}

#Preview("Power tier states") {
    Form {
        PowerTierSettingsSection(
            state: PreviewFixtures.standardPowerTier,
            onSelectDeclaredTier: { _ in },
            onVerify: {}
        )
        PowerTierSettingsSection(
            state: PreviewFixtures.claimedAlphaPowerTier,
            onSelectDeclaredTier: { _ in },
            onVerify: {}
        )
        PowerTierSettingsSection(
            state: PreviewFixtures.mismatchedPowerTier,
            onSelectDeclaredTier: { _ in },
            onVerify: {}
        )
        PowerTierSettingsSection(
            state: PreviewFixtures.failedVerificationPowerTier,
            onSelectDeclaredTier: { _ in },
            onVerify: {}
        )
    }
}
#endif

private enum PreviewFixtures {
    static let powerTierSelection = AppSettingsSelectionViewState(
        selectedID: "standard",
        options: [
            .init(id: "standard", title: "Standard"),
            .init(id: "alpha", title: "Alpha")
        ]
    )

    static let standardPowerTier = PowerTierSettingsViewState(
        selection: powerTierSelection,
        status: "Standard baseline · 60 HP max",
        isVerifyEnabled: true
    )
    static let claimedAlphaPowerTier = PowerTierSettingsViewState(
        selection: .init(selectedID: "alpha", options: powerTierSelection.options),
        status: "Pending bike verification",
        isVerifyEnabled: true,
        isVerifying: true
    )
    static let mismatchedPowerTier = PowerTierSettingsViewState(
        selection: powerTierSelection,
        status: "Tier mismatch: bike reports Alpha evidence",
        evidence: "Power above 60 HP · TC configured",
        verificationMessage: "Bike verification completed",
        isVerifyEnabled: true
    )
    static let failedVerificationPowerTier = PowerTierSettingsViewState(
        selection: powerTierSelection,
        status: "Standard baseline · 60 HP max",
        verificationMessage: "Verification failed: The operation could not be completed",
        isVerifyEnabled: true
    )
}
