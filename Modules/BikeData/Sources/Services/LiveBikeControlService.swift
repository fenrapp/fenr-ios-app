import BikeDomain
import BikeSDK

public struct LiveBikeControlService: Sendable {
    private let advancedPowerModeMapper: BikeAdvancedPowerModeMapper
    private let client: BikeTelemetryClient
    private let chargePowerMapper: BikeSDKChargePowerControlToDomainMapper
    private let bikeLockMapper: BikeSDKBikeLockControlToDomainMapper

    public init(
        client: BikeTelemetryClient,
        chargePowerMapper: BikeSDKChargePowerControlToDomainMapper,
        bikeLockMapper: BikeSDKBikeLockControlToDomainMapper,
        advancedPowerModeMapper: BikeAdvancedPowerModeMapper
    ) {
        self.client = client
        self.advancedPowerModeMapper = advancedPowerModeMapper
        self.chargePowerMapper = chargePowerMapper
        self.bikeLockMapper = bikeLockMapper
    }

    func readBikeLockFirmwareCompatibility() async throws -> BikeLockFirmwareCompatibility {
        let compatibility = try await client.readBikeLockFirmwareCompatibility()
        return .init(
            firmware: compatibility.firmware,
            isCompatible: compatibility.isCompatible
        )
    }

    func prepareBikeLockControl() async throws -> BikeLockControlSnapshot {
        bikeLockMapper.map(try await client.prepareBikeLockControl())
    }

    func setBikeLocked(_ isLocked: Bool) async throws -> BikeLockControlSnapshot {
        bikeLockMapper.map(try await client.setBikeLocked(isLocked))
    }

    func refreshPowerModeConfigurations() async throws {
        try await client.refreshPowerModeConfigurations()
    }

    func refreshPowerModeConfiguration(mapIndex: Int) async throws {
        try await client.refreshPowerModeConfiguration(mapIndex: mapIndex)
    }

    func preparePowerModeControl(mapIndex: Int) async throws {
        try await client.preparePowerModeControl(mapIndex: mapIndex)
    }

    func setPowerModeConfiguration(
        mapIndex: Int,
        horsepower: Int,
        regenerativeBrakingPercent: Int
    ) async throws {
        try await client.setPowerModeConfiguration(
            mapIndex: mapIndex,
            horsepower: horsepower,
            regenerativeBrakingPercent: regenerativeBrakingPercent
        )
    }

    func prepareTractionControl(mapIndex: Int) async throws {
        try await client.prepareTractionControl(mapIndex: mapIndex)
    }

    func setTractionControlConfiguration(
        mapIndex: Int,
        powerTractionPercent: Double,
        brakingTractionPercent: Double
    ) async throws {
        try await client.setTractionControlConfiguration(
            mapIndex: mapIndex,
            powerTractionPercent: powerTractionPercent,
            brakingTractionPercent: brakingTractionPercent
        )
    }

    func refreshTractionControlConfiguration(mapIndex: Int) async throws {
        try await client.refreshTractionControlConfiguration(mapIndex: mapIndex)
    }

    func prepareChargePowerControl(
        chargingStatus: BikeChargingStatus
    ) async throws -> BikeChargePowerControlSnapshot {
        let snapshot = try await client.prepareChargePowerControl(context: .init(
            requestedCurrentAmperes: chargingStatus.requestedCurrentAmperes,
            maximumCurrentAmperes: chargingStatus.maximumCurrentAmperes,
            maximumPowerWatts: chargingStatus.maximumPowerWatts,
            maximumStateOfChargePercent: chargingStatus.maximumStateOfChargePercent,
            chargerTypeRaw: chargingStatus.chargerType.rawValue
        ))
        return chargePowerMapper.map(snapshot)
    }

    func setChargePowerLimit(watts: Int) async throws -> BikeChargePowerControlSnapshot {
        chargePowerMapper.map(try await client.setChargePowerLimit(watts: watts))
    }

    func setChargeTarget(percent: Int) async throws -> BikeChargePowerControlSnapshot {
        chargePowerMapper.map(try await client.setChargeTarget(percent: percent))
    }
    func readAdvancedPowerMode(mapIndex: Int) async throws -> BikeAdvancedPowerModeConfiguration {
        advancedPowerModeMapper.map(try await client.readAdvancedPowerMode(mapIndex: mapIndex))
    }
    func applyAdvancedPowerMode(
        expected: BikeAdvancedPowerModeConfiguration, desired: BikeAdvancedPowerModeConfiguration
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        advancedPowerModeMapper.map(try await client.applyAdvancedPowerMode(
            expected: advancedPowerModeMapper.map(expected), desired: advancedPowerModeMapper.map(desired)
        ))
    }
    func applyBasicPowerMode(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeAdvancedPowerModeConfiguration {
        advancedPowerModeMapper.map(try await client.applyBasicPowerMode(
            mapIndex: mapIndex, horsepower: horsepower, regeneration: regeneration
        ))
    }
}
