import Foundation

public struct AppSettingsPendingChanges: Sendable {
    public struct Pending: Equatable, Sendable {
        public let id: UUID
        public let expectedVIN: String
        public let change: AppSettingsChange
    }

    public private(set) var confirmed: AppSettingsSnapshot?
    private var pending: [Pending] = []

    public init() {}

    public var next: Pending? { pending.first }
    public var isEmpty: Bool { pending.isEmpty }

    public var settings: AppSettings {
        pending.reduce(confirmed?.settings ?? AppSettings()) { settings, pending in
            // A concurrent change may invalidate an optimistic name or visibility.
            // Keep the command queued so authoritative validation reports its failure.
            (try? pending.change.applying(to: settings)) ?? settings
        }
    }

    @discardableResult
    public mutating func enqueue(_ change: AppSettingsChange) throws -> UUID {
        guard let vin = confirmed?.settings.vin else { throw AppSettingsUpdateError.vehicleUnavailable }
        _ = try change.applying(to: settings)
        let pending = Pending(id: UUID(), expectedVIN: vin, change: change)
        self.pending.append(pending)
        return pending.id
    }

    public mutating func receive(_ snapshot: AppSettingsSnapshot) {
        if let confirmed, snapshot.revision <= confirmed.revision { return }
        if confirmed?.settings.vin != snapshot.settings.vin { pending.removeAll() }
        confirmed = snapshot
    }

    @discardableResult
    public mutating func complete(id: UUID, result: AppSettingsUpdateResult) -> Bool {
        let isPending = pending.contains { $0.id == id }
        receive(result.snapshot)
        pending.removeAll { $0.id == id }
        return isPending && confirmed?.settings.vin == result.snapshot.settings.vin
    }

    @discardableResult
    public mutating func reject(id: UUID) -> Bool {
        let isPending = pending.contains { $0.id == id }
        pending.removeAll { $0.id == id }
        return isPending
    }

    public mutating func removeAll() { pending.removeAll() }
}
