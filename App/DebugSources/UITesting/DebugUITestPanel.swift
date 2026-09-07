import SwiftUI

struct DebugUITestPanel: View {
    let controls: DebugUITestControls
    let navigation: DebugNavigationControls?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Toggle(.uiTestingHistoryReadFailure, isOn: Binding(
                    get: { controls.historyReadFailure }, set: { controls.setHistoryReadFailure($0) }
                ))
                .accessibilityIdentifier("uiTesting.historyReadFailure")
                Toggle(.uiTestingMaintenanceReadFailure, isOn: Binding(
                    get: { controls.maintenanceReadFailure }, set: { controls.setMaintenanceReadFailure($0) }
                ))
                .accessibilityIdentifier("uiTesting.maintenanceReadFailure")
                if let navigation {
                    Button(.uiTestingAdvanceGPS, action: navigation.advanceGPS)
                        .accessibilityIdentifier("uitest.navigation.advanceGPS")
                    Button(.uiTestingFailNextRouteSave, action: navigation.failNextRouteSave)
                        .accessibilityIdentifier("uitest.navigation.failNextSave")
                    Text(verbatim: String(navigation.emittedSampleCount))
                        .accessibilityIdentifier("uitest.navigation.sampleCount")
                    Text(verbatim: String(navigation.saveFailureRequests))
                        .accessibilityIdentifier("uitest.navigation.saveFailureRequests")
                }
            }
            .navigationTitle(.uiTestingControls)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(.uiTestingDone, action: onClose)
                        .accessibilityIdentifier("uiTesting.controls.close")
                }
            }
        }
    }
}
