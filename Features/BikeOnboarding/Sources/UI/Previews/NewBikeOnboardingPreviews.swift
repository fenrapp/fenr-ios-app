import SwiftUI

#if DEBUG
#Preview("Hero") {
    BikeOnboardingView(viewModel: BikeOnboardingPreviewFactory.makeViewModel(state: .init()))
}

#Preview("Hero - Small Phone") {
    BikeOnboardingView(viewModel: BikeOnboardingPreviewFactory.makeViewModel(state: .init()))
        .frame(width: 320, height: 568)
}

#Preview("Bluetooth - Ready - Light") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .bluetooth, bluetoothState: .preparation)
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Bluetooth - Requesting - Dark") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .bluetooth,
                bluetoothState: .requestingAccess,
                isRequestingBluetoothAccess: true
            )
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Bluetooth - Denied - Light") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .bluetooth, bluetoothState: .denied)
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Bluetooth - Powered off - Dark") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .bluetooth, bluetoothState: .poweredOff)
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Bluetooth - Unavailable") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .bluetooth, bluetoothState: .unavailable)
        )
    )
}

#Preview("Bluetooth - AX5") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .bluetooth, bluetoothState: .preparation)
        )
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Multiple bikes") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .discovery,
                discoveredBikes: [
                    .init(
                        vin: "UDUMXTEST00000001",
                        modelTitle: "VARG MX",
                        rssiText: "-46 dBm",
                        signalText: "Strong signal",
                        signalLevel: 3
                    ),
                    .init(
                        vin: "UDUEXTEST00000002",
                        modelTitle: "VARG EX",
                        rssiText: "-62 dBm",
                        signalText: "Good signal",
                        signalLevel: 2
                    )
                ],
                discoveryState: .multiple,
                isDiscoveringBikes: true
            )
        )
    )
}

#Preview("Discovery - Scanning - Light") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .scanning, isDiscoveringBikes: true)
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Discovery - Scanning - Dark") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .scanning, isDiscoveringBikes: true)
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Discovery - One bike") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .discovery,
                discoveredBikes: [
                    .init(
                        vin: "UDUMXTEST00000001",
                        modelTitle: "VARG MX",
                        rssiText: "-46 dBm",
                        signalText: "Strong signal",
                        signalLevel: 3
                    )
                ],
                discoveryState: .stabilizing,
                isDiscoveringBikes: true
            )
        )
    )
}

#Preview("Discovery - Failure") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .failed)
        )
    )
}

#Preview("Discovery - Timed out - Light") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .timedOut)
        )
    )
    .preferredColorScheme(.light)
}

#Preview("Discovery - Timed out - Dark") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .timedOut)
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Discovery - Timed out - AX5") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(step: .discovery, discoveryState: .timedOut)
        )
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Discovery - AX5") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .discovery,
                discoveredBikes: [
                    .init(
                        vin: "UDUMXTEST00000001",
                        modelTitle: "VARG MX",
                        rssiText: "-46 dBm",
                        signalText: "Strong signal",
                        signalLevel: 3
                    ),
                    .init(
                        vin: "UDUEXTEST00000002",
                        modelTitle: "VARG EX",
                        rssiText: "-62 dBm",
                        signalText: "Good signal",
                        signalLevel: 2
                    )
                ],
                discoveryState: .multiple,
                isDiscoveringBikes: true
            )
        )
    )
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Pairing") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .pairing,
                vin: "FENRTEST000000001",
                pairingPIN: "123456",
                selectedBikeTitle: "Stark bike"
            )
        )
    )
}

#Preview("Connection failure") {
    BikeOnboardingView(
        viewModel: BikeOnboardingPreviewFactory.makeViewModel(
            state: .init(
                step: .connecting,
                vin: "FENRTEST000000001",
                pairingPIN: "123456",
                selectedBikeTitle: "Stark bike",
                connectionState: .authenticationFailed
            )
        )
    )
}
#endif
