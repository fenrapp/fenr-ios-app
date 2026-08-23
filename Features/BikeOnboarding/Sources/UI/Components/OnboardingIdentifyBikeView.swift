import BikeDomain
import SwiftUI

struct OnboardingIdentifyBikeView: View {
    let vin: String
    let discoveredBikes: [DiscoveredBike]
    let isDiscoveringBikes: Bool
    let onVINChange: (String) -> Void
    let onSelectBike: (DiscoveredBike) -> Void
    let onStartDiscovery: () -> Void
    let onScanVIN: () -> Void

    var body: some View {
        TextField(
            "17-character VIN",
            text: Binding(
                get: { vin },
                set: { updatedVIN in onVINChange(updatedVIN) }
            )
        )
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .textFieldStyle(.roundedBorder)

        Button("Scan Again", systemImage: "antenna.radiowaves.left.and.right", action: onStartDiscovery)
            .buttonStyle(.bordered)
            .disabled(isDiscoveringBikes)

        if isDiscoveringBikes {
            ProgressView("Looking for nearby bikes")
        }

        if discoveredBikes.count > 1 {
            Picker(
                "Nearby bike",
                selection: Binding(
                    get: { vin },
                    set: { selectedVIN in selectBike(vin: selectedVIN) }
                )
            ) {
                Text("Select a bike").tag("")
                ForEach(discoveredBikes) { bike in
                    Text("\(bike.vin) (\(bike.rssi) dBm)").tag(bike.vin)
                }
            }
        }

        Button("Scan VIN", systemImage: "viewfinder", action: onScanVIN)
            .buttonStyle(.bordered)

        Text("You can find the VIN on the bike label or registration documents.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func selectBike(vin: String) {
        guard let bike = discoveredBikes.first(where: { $0.vin == vin }) else { return }
        onSelectBike(bike)
    }
}

#Preview("Identify bike") {
    OnboardingIdentifyBikeView(
        vin: "FENRTEST000000001",
        discoveredBikes: [],
        isDiscoveringBikes: false,
        onVINChange: { _ in },
        onSelectBike: { _ in },
        onStartDiscovery: {},
        onScanVIN: {}
    )
    .padding()
}
