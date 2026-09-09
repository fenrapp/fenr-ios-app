import BikeDomain
import Foundation
import Observation

@MainActor
@Observable
final class PowerModePresetCoordinator {
    private let useCases: PowerModeAdvancedUseCases
    private let makeID: @Sendable () -> UUID
    private(set) var values: [BikePowerModePreset] = []
    private(set) var isLoaded = false
    private(set) var isBusy = false
    private(set) var message: String?
    private var vin: String?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(useCases: PowerModeAdvancedUseCases, makeID: @escaping @Sendable () -> UUID) {
        self.useCases = useCases
        self.makeID = makeID
    }

    deinit { task?.cancel() }

    func load(vin: String, force: Bool = false) {
        guard let editing = useCases.editing, task == nil, force || !isLoaded || self.vin != vin else { return }
        self.vin = vin
        let token = generation
        isBusy = true
        message = nil
        task = Task { [weak self] in
            do {
                let values = try await editing.loadPresets(vin: vin)
                guard let self, self.isCurrent(token, vin: vin) else { return }
                self.values = values
                self.isLoaded = true
                self.message = nil
            } catch {
                guard let self, self.isCurrent(token, vin: vin) else { return }
                self.isLoaded = false
                self.message = String(localized: .powerCurvePresetError)
            }
            guard let self, self.isCurrent(token, vin: vin) else { return }
            self.task = nil
            self.isBusy = false
        }
    }

    func save(name: String, configuration: BikeAdvancedPowerModeConfiguration, maximum: Int) {
        guard let name = validatedName(name) else { return }
        persist(values + [.init(id: makeID(), name: name, maximumHorsepower: maximum, configuration: configuration)])
    }

    func rename(_ id: UUID, name: String) {
        guard let name = validatedName(name), let index = values.firstIndex(where: { $0.id == id }),
              values[index].name != name else { return }
        var updated = values
        updated[index].name = name
        persist(updated)
    }

    func duplicate(_ id: UUID) {
        guard let preset = values.first(where: { $0.id == id }) else { return }
        let decorationLength = String(localized: .powerCurvePresetCopy("")).count
        let name = String(preset.name.prefix(max(0, PowerModePresetViewData.maximumNameLength - decorationLength)))
        persist(values + [.init(
            id: makeID(), name: String(localized: .powerCurvePresetCopy(name)),
            maximumHorsepower: preset.maximumHorsepower, configuration: preset.configuration,
            calibrationProfileID: preset.calibrationProfileID
        )])
    }

    func delete(_ id: UUID) {
        guard values.contains(where: { $0.id == id }) else { return }
        persist(values.filter { $0.id != id })
    }
    func clearMessage() { message = nil }

    @discardableResult
    func cancel(clear: Bool) -> Task<Void, Never>? {
        generation += 1
        let pending = task
        pending?.cancel()
        task = nil
        isBusy = false
        message = nil
        if clear {
            values.removeAll()
            vin = nil
            isLoaded = false
        }
        return pending
    }

    private func persist(_ updated: [BikePowerModePreset]) {
        guard isLoaded, let editing = useCases.editing, let vin, task == nil else { return }
        let token = generation
        isBusy = true
        message = nil
        task = Task { [weak self] in
            do {
                try await editing.savePresets(updated, vin: vin)
                guard let self, self.isCurrent(token, vin: vin) else { return }
                self.values = updated
                self.message = String(localized: .powerCurvePresetSaved)
            } catch {
                guard let self, self.isCurrent(token, vin: vin) else { return }
                self.message = String(localized: .powerCurvePresetError)
            }
            guard let self, self.isCurrent(token, vin: vin) else { return }
            self.task = nil
            self.isBusy = false
        }
    }

    private func isCurrent(_ token: Int, vin: String) -> Bool {
        !Task.isCancelled && generation == token && self.vin == vin
    }

    private func validatedName(_ candidate: String) -> String? {
        let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= PowerModePresetViewData.maximumNameLength else {
            message = String(localized: .powerCurvePresetNameError(PowerModePresetViewData.maximumNameLength))
            return nil
        }
        return name
    }
}
