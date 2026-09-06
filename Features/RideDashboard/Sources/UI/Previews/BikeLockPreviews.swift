import SwiftUI

#if DEBUG
#Preview("Bike Lock unlocked") {
    BikeLockCardPreview(state: BikeLockPreviewFixtures.unlocked)
}

#Preview("Bike Lock locked") {
    BikeLockCardPreview(state: BikeLockPreviewFixtures.locked)
}

#Preview("Bike Lock needs setup") {
    BikeLockCardPreview(state: BikeLockPreviewFixtures.needsSetup)
}

#Preview("Bike Lock working") {
    BikeLockCardPreview(state: BikeLockPreviewFixtures.working)
}

#Preview("Bike Lock error") {
    BikeLockCardPreview(state: BikeLockPreviewFixtures.failure)
}

#Preview("Bike Lock unavailable") {
    BikeLockCardPreview(state: .init())
}

#Preview("Bike Lock protection setup") {
    BikeLockSetupView(
        options: BikeLockPreviewFixtures.options,
        errorText: nil, isWorking: false, configure: { _, _ in }, cancel: {}
    )
}

#Preview("Bike Lock protection setup error") {
    BikeLockSetupView(
        options: BikeLockPreviewFixtures.options,
        errorText: "Protection could not be saved. Please try again.",
        isWorking: false, configure: { _, _ in }, cancel: {}
    )
}

#Preview("Bike Lock PIN entry") {
    BikeLockPINEntryView(
        title: "Enter your PIN", errorText: nil, isWorking: false, submit: { _ in }, cancel: {}
    )
}

#Preview("Bike Lock PIN error") {
    BikeLockPINEntryView(
        title: "Enter your PIN", errorText: "The PIN is incorrect. Please try again.",
        isWorking: false, submit: { _ in }, cancel: {}
    )
}

#Preview("Bike Lock PIN working") {
    BikeLockPINEntryView(
        title: "Unlocking bike", errorText: nil, isWorking: true, submit: { _ in }, cancel: {}
    )
}

private struct BikeLockCardPreview: View {
    let state: BikeLockCardViewState

    var body: some View {
        DashboardBikeLockCard(
            viewState: state,
            securityOptions: BikeLockPreviewFixtures.options,
            performPrimaryAction: {}, configure: { _, _ in }, submitPIN: { _ in }, dismissSheet: {}
        )
        .dashboardCardPreviewCanvas()
    }
}
#endif
