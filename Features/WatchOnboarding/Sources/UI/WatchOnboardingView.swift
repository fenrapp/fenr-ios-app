import DesignSystem
import SwiftUI

public struct WatchOnboardingView: View {
    @ObservedObject private var viewModel: WatchOnboardingViewModel

    public init(viewModel: WatchOnboardingViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let state = viewModel.viewState
        List {
            Section {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.title)
                    .foregroundStyle(.tint)
                Text("Find Your Bike")
                    .font(.headline)
                Text(state.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if state.discoveredBikes.count > 1 {
                Section("Nearby Bikes") {
                    ForEach(state.discoveredBikes) { bike in
                        Button {
                            viewModel.select(bike)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                Text(bike.vin).font(.caption.monospaced())
                                Text(bike.signalText).font(.caption2)
                            }
                        }
                    }
                }
            }

            if state.discoveredBikes.isEmpty, !state.isConnecting {
                Section {
                    Button("Scan Again", action: viewModel.scan)
                }
            }

            if let errorMessage = state.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red)
                    Button("Try Again", action: viewModel.scan)
                }
            }

            if !state.debugEvents.isEmpty {
                Section("Debug") {
                    ForEach(state.debugEvents) { event in
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(event.title)
                                .font(.caption2.weight(.semibold))
                            Text(event.detail)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                }
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
