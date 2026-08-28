import Combine

@MainActor
public final class DashboardDeviceBatteryViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardDeviceBatteryViewData()

    private let monitor: any DashboardDeviceBatteryMonitoring
    private var observationTask: Task<Void, Never>?

    public init(monitor: any DashboardDeviceBatteryMonitoring) {
        self.monitor = monitor
    }

    deinit {
        observationTask?.cancel()
    }

    func start() {
        guard observationTask == nil else { return }
        monitor.start()
        observationTask = Task { [weak self, monitor] in
            let stream = monitor.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.viewState = Self.map(snapshot)
            }
        }
    }

    func stop() {
        observationTask?.cancel()
        observationTask = nil
        monitor.stop()
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardDeviceBatteryViewData) {
        self.viewState = viewState
    }
#endif

    private static func map(_ snapshot: DashboardDeviceBatterySnapshot) -> DashboardDeviceBatteryViewData {
        guard let level = snapshot.level, level.isFinite, level >= .zero else {
            return .init()
        }
        let percent = min(max(Int((level * Constants.percentageScale).rounded()), .zero), 100)
        let emphasis: DashboardDeviceBatteryViewData.Emphasis
        if snapshot.isCharging {
            emphasis = .charging
        } else if percent <= Constants.lowBatteryPercent {
            emphasis = .low
        } else {
            emphasis = .normal
        }
        let chargingText = snapshot.isCharging ? ", charging" : ""
        return .init(
            percentageText: "\(percent)%",
            systemImage: batterySymbol(percent: percent),
            emphasis: emphasis,
            accessibilityLabel: "iPhone battery \(percent) percent\(chargingText)"
        )
    }

    private static func batterySymbol(percent: Int) -> String {
        switch percent {
        case ...10: "battery.0percent"
        case ...37: "battery.25percent"
        case ...62: "battery.50percent"
        case ...87: "battery.75percent"
        default: "battery.100percent"
        }
    }

    private enum Constants {
        static let percentageScale = 100.0
        static let lowBatteryPercent = 20
    }
}
