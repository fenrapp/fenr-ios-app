import SwiftUI

public struct WatchDashboardView: View {
    @ObservedObject private var viewModel: WatchDashboardViewModel
    private let onChangeBike: () -> Void

    public init(
        viewModel: WatchDashboardViewModel,
        onChangeBike: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onChangeBike = onChangeBike
    }

    public var body: some View {
        Group {
            switch viewModel.viewState.mode {
            case .unavailable(let detail): unavailable(detail: detail)
            case .ride: rideDashboard
            case .charging: chargingDashboard
            }
        }
        .navigationTitle("FENR")
        .task { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var rideDashboard: some View {
        ScrollView {
            VStack(spacing: 12) {
                batteryRing
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("GEAR")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.viewState.gear)
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .foregroundStyle(.green)
                }
                metric("ODOMETER", value: viewModel.viewState.odometer ?? "--")
                changeBikeButton
            }
            .padding(.horizontal, 8)
        }
    }

    private var chargingDashboard: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(viewModel.viewState.chargeETA.map { "ETA: \($0)" } ?? "CHARGING")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                batteryRing
                HStack(spacing: 8) {
                    metric("POWER", value: viewModel.viewState.chargingPower ?? "--")
                    Divider()
                    metric("CURRENT", value: viewModel.viewState.chargingCurrent ?? "--")
                }
                metric("PACK TEMP", value: viewModel.viewState.batteryTemperature ?? "--")
                changeBikeButton
            }
            .padding(.horizontal, 8)
        }
    }

    private var batteryRing: some View {
        Gauge(value: Double(viewModel.viewState.batteryPercent ?? 0), in: 0 ... 100) {
            EmptyView()
        } currentValueLabel: {
            Text(viewModel.viewState.batteryPercent.map { "\($0)%" } ?? "--")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(viewModel.viewState.mode == .charging ? .cyan : .green)
        .frame(width: 100, height: 100)
        .accessibilityLabel("Battery \(viewModel.viewState.batteryPercent.map(String.init) ?? "unknown") percent")
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func unavailable(detail: String) -> some View {
        VStack(spacing: 12) {
            ContentUnavailableView(
                "Waiting for bike",
                systemImage: "bolt.horizontal.circle",
                description: Text(detail)
            )
            changeBikeButton
        }
    }

    private var changeBikeButton: some View {
        Button("Change Bike", role: .destructive, action: onChangeBike)
            .font(.caption)
    }
}

#if DEBUG
#Preview("Ride") {
    NavigationStack {
        WatchDashboardView(
            viewModel: WatchDashboardPreviewFactory.ride(),
            onChangeBike: {}
        )
    }
}
#endif
