import Foundation
import RideSessionDomain
import SwiftData

@MainActor
public final class SwiftDataRideTripRepository: RideTripRepository {
    private let modelContext: ModelContext
    private let mapper: RideTripRecordMapper

    public convenience init(
        mapper: RideTripRecordMapper,
        isStoredInMemoryOnly: Bool = false
    ) throws {
        self.init(
            modelContainer: try Self.makeModelContainer(
                isStoredInMemoryOnly: isStoredInMemoryOnly
            ),
            mapper: mapper
        )
    }

    public init(
        modelContainer: ModelContainer,
        mapper: RideTripRecordMapper
    ) {
        modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
        self.mapper = mapper
    }

    public static func makeModelContainer(
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            Constants.storeName,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: RideTripRecord.self,
            configurations: configuration
        )
    }

    public func prepare(applicationSessionID: UUID) async -> RideTrip? {
        do {
            guard let record = try fetchActiveRecords().first else { return nil }
            let activeTrip = mapper.mapToDomain(record)
            guard activeTrip.applicationSessionID != applicationSessionID else {
                return activeTrip
            }

            mapper.update(record, from: activeTrip.completed(at: activeTrip.updatedAt))
            try saveAndTrimHistory()
            return nil
        } catch {
            report(error)
            return nil
        }
    }

    public func saveActiveTrip(_ trip: RideTrip) async {
        guard trip.endedAt == nil else { return }
        do {
            try upsert(trip)
            try modelContext.save()
        } catch {
            report(error)
        }
    }

    public func completeTrip(_ trip: RideTrip, at date: Date) async {
        do {
            try upsert(trip.completed(at: date))
            try saveAndTrimHistory()
        } catch {
            report(error)
        }
    }

    public func loadCompletedTrips() async -> [RideTrip] {
        do {
            var descriptor = FetchDescriptor<RideTripRecord>(
                predicate: #Predicate { $0.endedAt != nil },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = Constants.maximumStoredTrips
            return try modelContext.fetch(descriptor).map(mapper.mapToDomain)
        } catch {
            report(error)
            return []
        }
    }

    private func fetchActiveRecords() throws -> [RideTripRecord] {
        let descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func fetchRecord(id: UUID) throws -> RideTripRecord? {
        var descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func upsert(_ trip: RideTrip) throws {
        if let record = try fetchRecord(id: trip.id) {
            mapper.update(record, from: trip)
        } else {
            modelContext.insert(mapper.makeRecord(from: trip))
        }
    }

    private func saveAndTrimHistory() throws {
        try modelContext.save()
        let descriptor = FetchDescriptor<RideTripRecord>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let completedRecords = try modelContext.fetch(descriptor)
        guard completedRecords.count > Constants.maximumStoredTrips else { return }
        completedRecords.dropFirst(Constants.maximumStoredTrips).forEach(modelContext.delete)
        try modelContext.save()
    }

    private func report(_ error: Error) {
        assertionFailure("Ride trip persistence failed: \(error)")
    }

    private enum Constants {
        static let storeName = "RideTrips"
        static let maximumStoredTrips = 100
    }
}
