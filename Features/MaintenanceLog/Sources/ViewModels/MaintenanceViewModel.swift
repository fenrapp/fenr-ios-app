import Combine
import Foundation
import MaintenanceDomain
import SettingsDomain
import VehicleSession

@MainActor
public final class MaintenanceViewModel: ObservableObject {
    @Published public private(set) var viewState = MaintenanceLogViewState()
    @Published public private(set) var formState: MaintenanceFormViewState
    @Published public private(set) var isMutating = false

    private let useCases: MaintenanceUseCases
    private let vehicleSession: any VehicleSessionService
    private let mapper: MaintenanceViewStateMapper
    private let draftMapper: MaintenanceFormDraftMapper
    private let reminderScheduler: any MaintenanceReminderScheduling
    private let now: @Sendable () -> Date
    private var entries: [MaintenanceEntry] = []
    private var activeVIN: String?
    private var measurementSystem: MeasurementSystem = .system
    private var odometerKilometers: Double?
    private var observationTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var mutationTask: Task<Void, Never>?
    private var mutationID: UUID?
    private var errorMessage: String?

    public init(
        useCases: MaintenanceUseCases,
        vehicleSession: any VehicleSessionService,
        mapper: MaintenanceViewStateMapper,
        draftMapper: MaintenanceFormDraftMapper,
        reminderScheduler: any MaintenanceReminderScheduling,
        now: @escaping @Sendable () -> Date
    ) {
        self.useCases = useCases
        self.vehicleSession = vehicleSession
        self.mapper = mapper
        self.draftMapper = draftMapper
        self.reminderScheduler = reminderScheduler
        self.now = now
        formState = mapper.mapForm(measurementSystem: .system)
    }

    deinit {
        observationTask?.cancel()
        loadTask?.cancel()
        mutationTask?.cancel()
    }

    public func start() {
        guard observationTask == nil else { return }
        observationTask = Task { [weak self, vehicleSession] in
            for await snapshot in await vehicleSession.observe() {
                guard !Task.isCancelled else { return }
                self?.receive(snapshot)
            }
        }
    }

    public func stopAndWait() async {
        let tasks = [observationTask, loadTask, mutationTask]
        tasks.forEach { $0?.cancel() }
        stop()
        for task in tasks { await task?.value }
    }

    public func stop() {
        observationTask?.cancel()
        observationTask = nil
        loadTask?.cancel()
        loadTask = nil
        mutationTask?.cancel()
        mutationTask = nil
        mutationID = nil
        isMutating = false
    }

    public func refresh() {
        guard mutationTask == nil else { return }
        loadEntries()
    }

    public func detail(id: UUID) -> MaintenanceDetailViewState? {
        entries.first { $0.id == id }.map {
            mapper.mapDetail($0, measurementSystem: measurementSystem)
        }
    }

    public func makeDraft(id: UUID?) -> MaintenanceFormDraft {
        let entry = id.flatMap { id in entries.first { $0.id == id } }
        return mapper.makeDraft(
            entry: entry,
            measurementSystem: measurementSystem,
            suggestedOdometerKilometers: odometerKilometers,
            suggestedRidingHours: currentRidingHours
        )
    }

    public func applyOfficialRecommendation(to draft: inout MaintenanceFormDraft) {
        guard let kind = MaintenanceKind(rawValue: draft.kindID),
              let schedule = draftMapper.suggestedSchedule(
                  after: draft.performedAt,
                  ridingHoursText: draft.ridingHoursText,
                  for: kind
              ) else {
            draft.hasDateReminder = false
            draft.hasHoursReminder = false
            return
        }
        if let date = schedule.dueDate {
            draft.hasDateReminder = true
            draft.dueDate = date
        } else {
            draft.hasDateReminder = false
        }
        if let hours = schedule.dueRidingHours {
            draft.hasHoursReminder = true
            draft.dueHoursText = numberText(hours)
        } else {
            draft.hasHoursReminder = false
            draft.dueHoursText = ""
        }
    }

    public func officialGuidance(kindID: String) -> String? {
        guard let kind = MaintenanceKind(rawValue: kindID) else { return nil }
        return mapper.officialGuidance(for: kind)
    }

    public func hasOfficialSchedule(kindID: String) -> Bool {
        guard let kind = MaintenanceKind(rawValue: kindID),
              let recommendation = MaintenanceCatalog.recommendation(for: kind) else { return false }
        return recommendation.monthInterval != nil || recommendation.ridingHourInterval != nil
    }

    public func save(_ draft: MaintenanceFormDraft, onSuccess: @escaping @MainActor () -> Void) {
        guard mutationTask == nil else { return }
        guard let vin = activeVIN,
              let entry = makeEntry(from: draft, vin: vin) else {
            errorMessage = String(localized: .maintenanceValidationError)
            render()
            return
        }
        loadTask?.cancel()
        loadTask = nil
        errorMessage = nil
        isMutating = true
        render()
        let operationID = UUID()
        mutationID = operationID
        mutationTask = Task { [weak self] in
            let saved = await self?.useCases.saveEntry.execute(entry) == true
            guard !Task.isCancelled, let self, self.mutationID == operationID else { return }
            guard saved else {
                self.finishMutation(
                    operationID: operationID,
                    vin: vin,
                    error: String(localized: .maintenanceSaveError)
                )
                return
            }
            let refreshed = await self.useCases.loadEntries.execute(vin: vin)
            guard !Task.isCancelled, self.mutationID == operationID else { return }
            await self.synchronizeDateReminders(
                refreshed,
                requestingAuthorizationFor: self.activeVIN == vin ? entry.id : nil
            )
            guard !Task.isCancelled, self.mutationID == operationID else { return }
            self.finishMutation(operationID: operationID, entries: refreshed, vin: vin)
            guard self.activeVIN == vin else { return }
            onSuccess()
        }
    }

    public func delete(id: UUID, onSuccess: @escaping @MainActor () -> Void = {}) {
        guard mutationTask == nil, let vin = activeVIN else { return }
        loadTask?.cancel()
        loadTask = nil
        errorMessage = nil
        isMutating = true
        render()
        let operationID = UUID()
        mutationID = operationID
        mutationTask = Task { [weak self] in
            let deleted = await self?.useCases.deleteEntry.execute(id: id, vin: vin) == true
            guard !Task.isCancelled, let self, self.mutationID == operationID else { return }
            guard deleted else {
                self.finishMutation(
                    operationID: operationID,
                    vin: vin,
                    error: String(localized: .maintenanceDeleteError)
                )
                return
            }
            await self.reminderScheduler.cancel(id: id)
            let refreshed = await self.useCases.loadEntries.execute(vin: vin)
            guard !Task.isCancelled, self.mutationID == operationID else { return }
            await self.synchronizeDateReminders(refreshed, requestingAuthorizationFor: nil)
            guard !Task.isCancelled, self.mutationID == operationID else { return }
            self.finishMutation(operationID: operationID, entries: refreshed, vin: vin)
            guard self.activeVIN == vin else { return }
            onSuccess()
        }
    }

    public func dismissError() {
        errorMessage = nil
        render()
    }
}

private extension MaintenanceViewModel {
    var currentRidingHours: Double? {
        entries.compactMap(\.ridingHours).max()
    }

    func receive(_ snapshot: VehicleSessionSnapshot) {
        let nextVIN = snapshot.profile?.vin
        let didChangeVIN = nextVIN != activeVIN
        activeVIN = nextVIN
        measurementSystem = snapshot.settings.measurementSystem
        if snapshot.isCanonicalTelemetryAvailable,
           let updated = snapshot.telemetry.lastUpdated,
           now().timeIntervalSince(updated) <= Constants.telemetryFreshnessInterval {
            odometerKilometers = snapshot.telemetry.odometer.kilometers
        } else {
            odometerKilometers = nil
        }
        formState = mapper.mapForm(measurementSystem: measurementSystem)
        if didChangeVIN {
            entries = []
            loadEntries()
        } else {
            render()
        }
    }

    func loadEntries() {
        loadTask?.cancel()
        guard let vin = activeVIN else {
            entries = []
            viewState = .init(status: .bikeUnavailable)
            return
        }
        viewState = .init(status: .loading, errorMessage: errorMessage)
        loadTask = Task { [weak self] in
            let loaded = await self?.useCases.loadEntries.execute(vin: vin) ?? []
            guard !Task.isCancelled, let self, self.activeVIN == vin else { return }
            await self.synchronizeDateReminders(loaded, requestingAuthorizationFor: nil)
            guard !Task.isCancelled, self.activeVIN == vin else { return }
            self.loadTask = nil
            self.entries = loaded
            self.render()
        }
    }

    func render() {
        guard activeVIN != nil else {
            viewState = .init(status: .bikeUnavailable, errorMessage: errorMessage)
            return
        }
        viewState = mapper.mapList(
            entries: entries,
            measurementSystem: measurementSystem,
            odometerKilometers: odometerKilometers,
            ridingHours: currentRidingHours,
            errorMessage: errorMessage
        )
    }

    func makeEntry(from draft: MaintenanceFormDraft, vin: String) -> MaintenanceEntry? {
        let existing = draft.entryID.flatMap { id in entries.first { $0.id == id } }
        return draftMapper.map(
            draft,
            vin: vin,
            existing: existing,
            measurementSystem: measurementSystem
        )
    }

    func synchronizeDateReminders(
        _ entries: [MaintenanceEntry],
        requestingAuthorizationFor entryID: UUID?
    ) async {
        let notificationTitle = String(localized: .maintenanceNotificationTitle)
        let currentDate = now()
        for entry in entries {
            guard entry.schedule?.completedAt == nil,
                  let dueDate = entry.schedule?.dueDate,
                  dueDate > currentDate else {
                await reminderScheduler.cancel(id: entry.id)
                continue
            }
            await reminderScheduler.schedule(
                .init(
                    id: entry.id,
                    date: dueDate,
                    title: notificationTitle,
                    body: mapper.title(for: entry.selection)
                ),
                requestingAuthorization: entry.id == entryID
            )
        }
    }

    func finishMutation(
        operationID: UUID,
        entries refreshedEntries: [MaintenanceEntry]? = nil,
        vin: String? = nil,
        error: String? = nil
    ) {
        guard mutationID == operationID else { return }
        mutationTask = nil
        mutationID = nil
        isMutating = false
        errorMessage = vin == nil || activeVIN == vin ? error : nil
        if let refreshedEntries, activeVIN == vin {
            entries = refreshedEntries
        }
        render()
    }

    func numberText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    enum Constants {
        static let telemetryFreshnessInterval: TimeInterval = 60
    }
}
