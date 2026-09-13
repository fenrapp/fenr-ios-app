import Foundation

public struct RideDisplayOverviewViewState: Equatable, Sendable {
    public let progressBar: LocalizedStringResource
    public let batteryDisplay: LocalizedStringResource
    public let rideInformation: LocalizedStringResource
    public let speed: LocalizedStringResource

    public init(
        progressBar: LocalizedStringResource? = nil,
        batteryDisplay: LocalizedStringResource? = nil,
        rideInformation: LocalizedStringResource? = nil,
        speed: LocalizedStringResource? = nil
    ) {
        self.progressBar = progressBar ?? .appSettingsUnavailable
        self.batteryDisplay = batteryDisplay ?? .appSettingsUnavailable
        self.rideInformation = rideInformation ?? .appSettingsUnavailable
        self.speed = speed ?? .appSettingsUnavailable
    }
}
