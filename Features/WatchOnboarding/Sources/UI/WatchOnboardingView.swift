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
                Text(.watchOnboardingFindYourBike)
                    .font(.headline)
                Text(verbatim: state.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if state.discoveredBikes.count > 1 {
                Section {
                    ForEach(state.discoveredBikes) { bike in
                        Button {
                            viewModel.select(bike)
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                Text(verbatim: bike.vin).font(.caption.monospaced())
                                Text(verbatim: bike.signalText).font(.caption2)
                            }
                        }
                    }
                } header: {
                    Text(.watchOnboardingNearbyBikes)
                }
            }

            if state.discoveredBikes.isEmpty, !state.isConnecting {
                Section {
                    Button(action: viewModel.scan) {
                        Text(.watchOnboardingScanAgain)
                    }
                }
            }

            if let errorMessage = state.errorMessage {
                Section {
                    Text(verbatim: errorMessage).foregroundStyle(.red)
                    Button(action: viewModel.scan) {
                        Text(.watchOnboardingTryAgain)
                    }
                }
            }

            if !state.debugEvents.isEmpty {
                Section {
                    ForEach(state.debugEvents) { event in
                        VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                            Text(verbatim: event.title)
                                .font(.caption2.weight(.semibold))
                            Text(verbatim: event.detail)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                } header: {
                    Text(.watchOnboardingDebug)
                }
            }
        }
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}
