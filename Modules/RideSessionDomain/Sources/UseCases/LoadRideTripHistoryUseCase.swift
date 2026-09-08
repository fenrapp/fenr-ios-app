import Foundation

public struct LoadRideTripHistoryUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(vin: String) async throws -> [RideTrip] {
        try await repository.loadCompletedTrips(vin: vin)
    }
}

public struct LoadRideTripDetailUseCase: Sendable {
    private let repository: any RideTripRepository

    public init(repository: any RideTripRepository) {
        self.repository = repository
    }

    public func execute(id: UUID, vin: String) async throws -> RideTrip? {
        try await repository.loadCompletedTrip(id: id, vin: vin)
    }
}
