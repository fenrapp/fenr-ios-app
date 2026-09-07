import Foundation

struct RideNavigationActivityCompletion: Sendable {
    let reason: RideNavigationCompletionReason
    let isSuccessful: Bool
    let hasGPSPoints: Bool
    let distanceFirst: Bool
    let distanceMeters: Double
    let elapsedSeconds: TimeInterval
}
