import Foundation

extension LiveRideSessionService {
    func updateTripLocationMonitoring() {
        let required = stopTask == nil
            && recorder.trip.map { !$0.isPaused && $0.endedAt == nil } == true
        guard required != isRequestingLocation else { return }
        isRequestingLocation = required
        let previousRequest = locationRequestTask
        let vehicleSession = vehicleSession
        let consumerID = locationConsumerID
        locationRequestTask = Task {
            await previousRequest?.value
            await vehicleSession.setLocationMonitoringRequired(required, consumerID: consumerID)
        }
    }
}
