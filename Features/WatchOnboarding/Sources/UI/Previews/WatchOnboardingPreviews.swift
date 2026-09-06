import Foundation
import SwiftUI

#if DEBUG
#Preview("Watch onboarding searching") {
    WatchOnboardingContentView(state: .init(), select: { _ in }, scan: {})
}

#Preview("Watch onboarding nearby bikes") {
    WatchOnboardingContentView(
        state: .init(
            discoveredBikes: [
                .init(vin: "FENRTEST000000001", signalText: "Signal: -42 dBm"),
                .init(vin: "FENRTEST000000002", signalText: "Signal: -68 dBm")
            ],
            detail: "Choose the bike you want to connect."
        ),
        select: { _ in }, scan: {}
    )
}

#Preview("Watch onboarding connecting") {
    WatchOnboardingContentView(
        state: .init(detail: "Connecting to FENRTEST000000001", isConnecting: true),
        select: { _ in }, scan: {}
    )
}

#Preview("Watch onboarding Bluetooth error") {
    WatchOnboardingContentView(
        state: .init(
            detail: "Searching for your bike.",
            errorMessage: "Turn on Bluetooth on your Apple Watch and try again."
        ),
        select: { _ in }, scan: {}
    )
}

#Preview("Watch onboarding diagnostics") {
    WatchOnboardingContentView(
        state: .init(
            debugEvents: [
                .init(id: UUID(), title: "Connection", detail: "Synthetic connection attempt started."),
                .init(id: UUID(), title: "Discovery", detail: "Synthetic nearby bike discovered.")
            ],
            detail: "Preparing the connection.",
            isConnecting: true
        ),
        select: { _ in }, scan: {}
    )
}
#endif
