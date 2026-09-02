import BikeDomain
import Foundation

public struct BikeOnboardingPresentationMapper: Sendable {
    public init() {}

    public func discoveryViewData(_ bike: DiscoveredBike) -> BikeDiscoveryViewData {
        BikeDiscoveryViewData(
            vin: bike.vin,
            formattedVIN: BikeDiscoveryViewData.formatVIN(bike.vin),
            accessibilityVIN: BikeDiscoveryViewData.formatAccessibleVIN(bike.vin),
            modelTitle: modelTitle(for: bike.vin),
            rssiText: "\(bike.rssi) dBm",
            signalText: signalText(for: bike.rssi),
            signalLevel: signalLevel(for: bike.rssi)
        )
    }

    public func modelTitle(for vin: String) -> String {
        switch BikeVariant(vin: vin) {
        case .mx: "VARG MX"
        case .ex: "VARG EX"
        case .sm: "VARG SM"
        case .unknown: "Stark bike"
        }
    }

    public func connectionState(for state: ConnectionState) -> BikeOnboardingConnectionState? {
        switch state {
        case .scanning, .connecting, .reconnecting: .inProgress(.finding)
        case .discovering, .authenticating, .authenticated, .subscribed: .inProgress(.securing)
        case .receivingTelemetry: .inProgress(.live)
        case .pairingResetRequired: .pairingResetRequired
        case .disconnected: .disconnected
        case .failed(let message): recoveryState(for: message)
        default: nil
        }
    }

    private func signalText(for rssi: Int) -> String {
        switch rssi {
        case (-55)...: "Strong signal"
        case -70 ..< -55: "Good signal"
        default: "Weak signal"
        }
    }

    private func signalLevel(for rssi: Int) -> Int {
        switch rssi {
        case (-55)...: 3
        case -70 ..< -55: 2
        default: 1
        }
    }

    private func recoveryState(for message: String) -> BikeOnboardingConnectionState {
        let normalizedMessage = message.lowercased()
        if normalizedMessage.contains("timed out") || normalizedMessage.contains("timeout") {
            return .timedOut
        }
        let authenticationTerms = ["authentication", "security", "pairing", "encryption", "code"]
        if authenticationTerms.contains(where: normalizedMessage.contains) {
            return .authenticationFailed
        }
        return .disconnected
    }
}
