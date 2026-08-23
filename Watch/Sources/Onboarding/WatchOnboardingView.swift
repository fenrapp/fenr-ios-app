import BikeDomain
import SwiftUI

struct WatchOnboardingView: View {
    @ObservedObject var viewModel: WatchOnboardingViewModel

    var body: some View {
        List {
            Section {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("Find Your Bike")
                    .font(.headline)
                Text(viewModel.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if viewModel.discoveredBikes.count > 1 {
                Section("Nearby Bikes") {
                    ForEach(viewModel.discoveredBikes) { bike in
                        Button {
                            viewModel.select(bike)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(bike.vin).font(.caption.monospaced())
                                Text("Signal \(bike.rssi) dBm").font(.caption2)
                            }
                        }
                    }
                }
            }

            if viewModel.discoveredBikes.isEmpty, !viewModel.isConnecting {
                Section {
                    Button("Scan Again", action: viewModel.scan)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Try Again", action: viewModel.scan)
                }
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
