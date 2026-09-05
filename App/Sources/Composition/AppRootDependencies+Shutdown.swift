import Foundation

extension AppRootDependencies {
    func shutDown() async {
        await incomingMapLinkController.cancelAndWait()
        await featureStore.diagnosticsViewModel.stopAndWait()
        await featureStore.batteryHealthViewModel.stopAndWait()
        await featureStore.appSettingsViewModel.stopAndWait()
        await featureStore.dashboardCardSettingsViewModel.stopAndWait()
        await featureStore.powerModeSettingsViewModel.stopAndWait()
        await featureStore.rideHistoryViewModel.stopAndWait()
        await featureStore.maintenanceViewModel.stopAndWait()
        await featureStore.bikeLockSettingsViewModel.stopAndWait()
        await featureStore.onboardingViewModel.stopAndWait()
        await chargeControlSession?.stopAndWait()
        await lifecycleController.stopAndWait()
    }
}
