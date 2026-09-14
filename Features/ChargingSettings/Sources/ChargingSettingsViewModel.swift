import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
public final class ChargingSettingsViewModel {
    public private(set) var viewState: ChargingSettingsViewState
    private let useCases: ChargingSettingsUseCases
    private let mapper: ChargingSettingsMapper
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(useCases: ChargingSettingsUseCases, mapper: ChargingSettingsMapper) {
        self.useCases = useCases
        self.mapper = mapper
        viewState = mapper.map(useCases.state)
    }

    deinit { task?.cancel() }

    public func start() {
        guard task == nil else { return }
        viewState = mapper.map(useCases.state)
        task = Task { [weak self, useCases] in
            for await state in useCases.observe() {
                guard !Task.isCancelled, let self else { return }
                viewState = mapper.map(state)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }

    public func setPower(_ watts: Double) { useCases.setPower(watts) }
    public func setTarget(_ percent: Double) { useCases.setTarget(percent) }
    public func cancelPending() { useCases.cancel() }
    public func retry() { useCases.retry() }

    public func selectCharger(id: String) {
        guard let raw = Int(id), [0, 2, 3].contains(raw) else { return }
        useCases.selectCharger(.init(rawValue: raw))
    }
}
