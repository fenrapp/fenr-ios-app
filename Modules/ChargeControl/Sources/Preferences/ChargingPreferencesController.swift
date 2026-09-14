import BikeDomain
import Foundation

@MainActor
public final class ChargingPreferencesController {
    public private(set) var state = ChargingPreferencesState() {
        didSet { if state != oldValue { emitter.send(state) } }
    }

    private let useCases: ChargingPreferencesUseCases
    private let store: any BikeChargingPreferencesStore
    private let emitter: ChargingPreferencesEmitter
    private var context = ChargingConnectionContext(
        vin: nil, isReady: false, isChargerConnected: false, charger: nil
    )
    private var generation: UInt = 0
    private var task: Task<Void, Never>?
    private var taskID: UUID?
    private var storageAvailable = true
    private var needsRead = false

    public init(
        useCases: ChargingPreferencesUseCases,
        store: any BikeChargingPreferencesStore,
        emitter: ChargingPreferencesEmitter
    ) {
        self.useCases = useCases
        self.store = store
        self.emitter = emitter
    }

    deinit { task?.cancel() }

    public func observe() -> AsyncStream<ChargingPreferencesState> { emitter.stream(replaying: state) }

    public func receive(_ next: ChargingConnectionContext) {
        let changedBike = next.vin != context.vin
        let changedConnection = changedBike || next.isReady != context.isReady
        let changedCharger = next.charger != context.charger
            || next.isChargerConnected != context.isChargerConnected
        context = next
        if changedConnection || changedCharger {
            generation &+= 1
            task?.cancel()
            state.isReading = false
            state.isApplying = false
            state.hasFreshConfiguration = false
            needsRead = next.isReady
        }
        if changedBike {
            state = .init()
            loadPreferences()
        } else if changedConnection, storageAvailable {
            state.failure = nil
        }
        state.hasBike = next.vin != nil
        state.isConnected = next.isReady
        state.connectedCharger = next.charger
        state.isChargerConnected = next.isChargerConnected
        schedule()
    }

    public func selectCharger(_ charger: BikeChargerType) {
        guard !state.isChargerConnected, isKnown(charger) else { return }
        var preferences = state.preferences
        preferences.selectedCharger = charger
        // Changing context never creates a vehicle write or retargets an existing intent.
        _ = save(preferences)
    }

    public func setPower(watts: Double) {
        guard watts.isFinite, let charger = state.effectiveCharger, isKnown(charger),
              watts >= 300, watts <= Double(charger.maximumChargePowerWatts) else {
            state.failure = .invalidValue
            return
        }
        let value = Int((watts / 100).rounded()) * 100
        var preferences = state.preferences
        preferences.selectedCharger = charger
        preferences.pendingPower = .init(watts: value, charger: charger, revision: UUID())
        if save(preferences) { schedule() }
    }

    public func setTarget(percent: Double) {
        guard percent.isFinite, (1 ... 100).contains(percent) else {
            state.failure = .invalidValue
            return
        }
        var preferences = state.preferences
        preferences.pendingTarget = .init(percent: Int(percent.rounded()), revision: UUID())
        if save(preferences) { schedule() }
    }

    public func cancelPending() {
        var preferences = state.preferences
        preferences.pendingPower = nil
        preferences.pendingTarget = nil
        guard save(preferences) else { return }
        generation &+= 1
        task?.cancel()
        state.isApplying = false
        state.isReading = false
        state.failure = nil
        needsRead = context.isReady
        schedule()
    }

    public func retry() {
        guard !state.isApplying, !state.isReading else { return }
        if !storageAvailable { loadPreferences() }
        guard storageAvailable else { return }
        state.failure = nil
        needsRead = true
        schedule()
    }

    public func stopAndWait() async {
        generation &+= 1
        let previous = task
        previous?.cancel()
        await previous?.value
        task = nil
        taskID = nil
        context = .init(vin: nil, isReady: false, isChargerConnected: false, charger: nil)
        state = .init()
        needsRead = false
    }

    private func loadPreferences() {
        storageAvailable = true
        guard let vin = context.vin else { return }
        do {
            state.preferences = try store.load(vin: vin)
        } catch {
            storageAvailable = false
            state.failure = .storage
        }
    }

    private func save(_ preferences: BikeChargingPreferences) -> Bool {
        guard storageAvailable, let vin = context.vin else { return false }
        do {
            try store.save(preferences, vin: vin)
            state.preferences = preferences
            return true
        } catch {
            state.failure = .storage
            return false
        }
    }

    private func schedule() {
        guard context.isReady, storageAvailable, state.failure == nil,
              needsRead || state.preferences.hasPendingChanges else { return }
        if let task, !task.isCancelled { return }
        let previous = task
        let generation = generation
        let id = UUID()
        taskID = id
        task = Task { [weak self] in
            await previous?.value
            guard let self, self.isCurrent(generation) else { return }
            await self.process(generation: generation)
            guard self.taskID == id else { return }
            self.task = nil
            self.taskID = nil
        }
    }

    private func isCurrent(_ generation: UInt) -> Bool {
        !Task.isCancelled && generation == self.generation && context.isReady
    }

    private func isKnown(_ charger: BikeChargerType) -> Bool {
        if case .unknown = charger { false } else { true }
    }
}

private extension ChargingPreferencesController {
    func process(generation: UInt) async {
        do {
            while isCurrent(generation), state.failure == nil {
                state.isReading = true
                let read = try await useCases.read()
                guard isCurrent(generation) else { return }
                state.isReading = false
                needsRead = false
                guard record(read.parsedConfig) else { return }
                state.hasFreshConfiguration = true
                guard state.preferences.hasPendingChanges else { return }
                guard read.isFirmwareCompatible else {
                    state.failure = .incompatibleFirmware
                    return
                }
                if let target = state.preferences.pendingTarget {
                    try await apply(target, current: read.parsedConfig, generation: generation)
                } else if let power = state.preferences.pendingPower {
                    if context.isChargerConnected,
                       context.charger.map(isKnown) != true { return }
                    try await apply(power, current: read.parsedConfig, generation: generation)
                }
                guard isCurrent(generation) else { return }
                state.isApplying = false
                guard state.preferences.hasPendingChanges else { return }
            }
        } catch {
            guard isCurrent(generation) else { return }
            state.isReading = false
            state.isApplying = false
            state.failure = .unavailable
        }
    }

    func apply(
        _ target: BikeChargingPreferences.PendingTarget,
        current: BikeChargePowerConfiguration, generation: UInt
    ) async throws {
        var confirmed = current
        if current.maximumStateOfChargeDeciPercent != target.percent * 10 {
            state.isApplying = true
            let result = try await useCases.applyTarget(target)
            guard isCurrent(generation) else { return }
            confirmed = result.parsedConfig
        }
        guard confirmed.maximumStateOfChargeDeciPercent == target.percent * 10 else {
            state.failure = .confirmation
            return
        }
        var preferences = state.preferences
        preferences.confirmed = confirmed
        preferences.confirmedAt = Date()
        if preferences.pendingTarget?.revision == target.revision { preferences.pendingTarget = nil }
        _ = save(preferences)
    }

    func apply(
        _ power: BikeChargingPreferences.PendingPower,
        current: BikeChargePowerConfiguration, generation: UInt
    ) async throws {
        guard !context.isChargerConnected || context.charger == power.charger else {
            state.failure = .chargerChanged
            return
        }
        var confirmed = current
        if current.chargePowerWatts != power.watts {
            state.isApplying = true
            let result = try await useCases.applyPower(power)
            guard isCurrent(generation) else { return }
            confirmed = result.parsedConfig
        }
        guard confirmed.chargePowerWatts == power.watts else {
            state.failure = .confirmation
            return
        }
        var preferences = state.preferences
        preferences.confirmed = confirmed
        preferences.confirmedAt = Date()
        if preferences.pendingPower?.revision == power.revision { preferences.pendingPower = nil }
        _ = save(preferences)
    }

    func record(_ configuration: BikeChargePowerConfiguration) -> Bool {
        var preferences = state.preferences
        preferences.confirmed = configuration
        preferences.confirmedAt = Date()
        return save(preferences)
    }
}
