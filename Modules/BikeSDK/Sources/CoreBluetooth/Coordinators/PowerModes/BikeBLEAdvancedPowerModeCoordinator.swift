import Foundation
import StarkProtocol

@MainActor
final class BikeBLEAdvancedPowerModeCoordinator {
    private let transport: any BikeBLEPowerModeConfigurationTransporting
    private let eventEmitter: BikeBLEEventEmitter
    private(set) var generation = 0

    init(transport: any BikeBLEPowerModeConfigurationTransporting, eventEmitter: BikeBLEEventEmitter) {
        self.transport = transport
        self.eventEmitter = eventEmitter
    }

    func reset() { generation += 1 }

    func check(_ token: Int) throws {
        try Task.checkCancellation()
        guard token == generation else { throw CancellationError() }
        try transport.ensureReady()
    }

    func read(mapIndex: Int) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        let token = generation
        try check(token)
        let versions = try await transport.readVersions()
        try check(token)
        guard let firmware = StarkFirmwareVersionParser.parseVCUPic(from: versions) else {
            throw BikeSDKError.operationFailed("Advanced curves require recognized VCU PIC firmware")
        }
        let base = try await readBase(mapIndex: mapIndex)
        try check(token)
        guard StarkPowerModeConfigurationCommand.isSupportedReadCurve(base.curve, mapIndex: mapIndex) else {
            throw BikeSDKError.operationFailed("Unsupported map curve selector")
        }
        let curves = try await readCurves(mapIndex: mapIndex)
        try check(token)
        var traction: StarkTractionControlConfigurationPayload?
        if firmware.isTractionControlCompatible {
            do {
                traction = try await readTraction(mapIndex: mapIndex)
            } catch StarkProtocolError.configurationRequestFailed {
                traction = nil
            }
        }
        try check(token)
        return .init(
            mapIndex: mapIndex, firmware: firmware.description,
            torqueRaw: base.torqueRaw, regenerationRaw: base.regenerationRaw, curve: curves.curve,
            power: curves.power, regeneration: curves.regeneration,
            powerTractionRaw: traction?.powerRaw, brakingTractionRaw: traction?.brakingRaw
        )
    }

    private func readBase(mapIndex: Int) async throws -> StarkPowerModeConfigurationPayload {
        let response = try await transport.readConfiguration(
            request: StarkPowerModeConfigurationCommand.readPacket(mapIndex: mapIndex),
            operationName: "4005 advanced base read", allowLiveTelemetrySession: false
        )
        let value = try StarkPowerModeConfigurationCommand.decodeResponse(response, expectedMapIndex: mapIndex)
        await eventEmitter.send(.telemetry(.powerModeConfiguration(value)))
        return value
    }

    private func readCurves(mapIndex: Int) async throws -> StarkPowerCurveConfigurationPayload {
        let curve = try StarkPowerModeConfigurationCommand.normalizedWriteCurve(mapIndex: mapIndex)
        let response = try await transport.readConfiguration(
            request: StarkPowerCurveConfigurationCommand.readPacket(curve: curve),
            operationName: "4005 power curve read", allowLiveTelemetrySession: false
        )
        return try StarkPowerCurveConfigurationCommand.decodeResponse(response, expectedCurve: curve)
    }

    private func readTraction(mapIndex: Int) async throws -> StarkTractionControlConfigurationPayload {
        let response = try await transport.readConfiguration(
            request: StarkTractionControlConfigurationCommand.readPacket(mapIndex: mapIndex),
            operationName: "4005 advanced traction read", allowLiveTelemetrySession: false
        )
        let value = try StarkTractionControlConfigurationCommand.decodeResponse(response, expectedMapIndex: mapIndex)
        await eventEmitter.send(.telemetry(.tractionControlConfiguration(value)))
        return value
    }

    func apply(
        expected: BikeSDKAdvancedPowerModeConfiguration,
        desired: BikeSDKAdvancedPowerModeConfiguration,
        allowsPowerAdaptation: Bool = false,
        allowsRegenerationAdaptation: Bool = false
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        let token = generation
        try validate(expected: expected, desired: desired)
        let current = try await read(mapIndex: expected.mapIndex)
        try check(token)
        guard current == expected else {
            throw BikeSDKError.operationFailed("Map changed since it was read; refresh before applying")
        }
        if current == desired { return current }
        let changesCurves = desired.power != current.power || desired.regeneration != current.regeneration
        let changesBase = changesCurves || desired.torqueRaw != current.torqueRaw
            || desired.regenerationRaw != current.regenerationRaw
        let changesTraction = desired.powerTractionRaw != current.powerTractionRaw
            || desired.brakingTractionRaw != current.brakingTractionRaw

        try await prepare(
            current, curves: changesCurves, base: changesBase, traction: changesTraction, token: token
        )
        let prepared = try await read(mapIndex: current.mapIndex)
        try check(token)
        guard prepared == current else {
            throw BikeSDKError.operationFailed("Configuration changed during preparation; refresh before applying")
        }
        if changesCurves {
            try await writeCurves(desired)
            try check(token)
        }
        if changesBase {
            try await writeBase(desired)
            try check(token)
        }
        if changesTraction {
            try await writeTraction(desired)
            try check(token)
        }
        let verified = try await read(mapIndex: current.mapIndex)
        try check(token)
        var comparison = verified
        if allowsPowerAdaptation { comparison.power = desired.power }
        if allowsRegenerationAdaptation { comparison.regeneration = desired.regeneration }
        guard comparison == desired else {
            throw BikeSDKError.operationFailed("The complete advanced configuration was not confirmed; refresh the map")
        }
        return verified
    }

    func applyBasic(
        mapIndex: Int, horsepower: Int?, regeneration: Int?
    ) async throws -> BikeSDKAdvancedPowerModeConfiguration {
        let token = generation
        let expected = try await read(mapIndex: mapIndex)
        try check(token)
        var desired = expected
        if let horsepower {
            guard 10 ... 80 ~= horsepower else { throw BikeSDKError.operationFailed("Invalid horsepower") }
            desired.torqueRaw = Int((Double(horsepower) * 1.25).rounded())
        }
        if let regeneration {
            guard 0 ... 100 ~= regeneration else { throw BikeSDKError.operationFailed("Invalid regeneration") }
            desired.regenerationRaw = regeneration
        }
        return try await apply(
            expected: expected, desired: desired,
            allowsPowerAdaptation: horsepower != nil, allowsRegenerationAdaptation: regeneration != nil
        )
    }

    private func prepare(
        _ current: BikeSDKAdvancedPowerModeConfiguration,
        curves: Bool, base: Bool, traction: Bool, token: Int
    ) async throws {
        if curves {
            try await writeCurves(current)
            try check(token)
            let verified = try await readCurves(mapIndex: current.mapIndex)
            try check(token)
            guard verified.power == current.power, verified.regeneration == current.regeneration else {
                throw BikeSDKError.operationFailed("Curve no-op was not confirmed")
            }
        }
        if base {
            try await writeBase(current)
            try check(token)
            let verified = try await readBase(mapIndex: current.mapIndex)
            try check(token)
            guard verified.torqueRaw == current.torqueRaw, verified.regenerationRaw == current.regenerationRaw else {
                throw BikeSDKError.operationFailed("Base-map no-op was not confirmed")
            }
        }
        if traction {
            try await writeTraction(current)
            try check(token)
            let verified = try await readTraction(mapIndex: current.mapIndex)
            try check(token)
            guard verified.powerRaw == current.powerTractionRaw,
                  verified.brakingRaw == current.brakingTractionRaw else {
                throw BikeSDKError.operationFailed("Traction no-op was not confirmed")
            }
        }
    }

    private func validate(
        expected: BikeSDKAdvancedPowerModeConfiguration, desired: BikeSDKAdvancedPowerModeConfiguration
    ) throws {
        guard expected.mapIndex == desired.mapIndex, expected.curve == desired.curve,
              desired.curve == desired.mapIndex + 1, expected.firmware == desired.firmware,
              13 ... 100 ~= desired.torqueRaw, 0 ... 100 ~= desired.regenerationRaw else {
            throw BikeSDKError.operationFailed("Invalid advanced configuration")
        }
        for value in [expected, desired] {
            _ = try StarkPowerCurveConfigurationCommand.writePacket(.init(
                curve: value.curve, power: value.power, regeneration: value.regeneration
            ))
            _ = try StarkPowerModeConfigurationCommand.noOpWritePacket(configuration: .init(
                mapIndex: value.mapIndex, torqueRaw: value.torqueRaw,
                regenerationRaw: value.regenerationRaw, curve: value.curve
            ))
        }
        if desired.powerTractionRaw != expected.powerTractionRaw
            || desired.brakingTractionRaw != expected.brakingTractionRaw {
            guard let power = desired.powerTractionRaw, let braking = desired.brakingTractionRaw,
                  let previousPower = expected.powerTractionRaw,
                  let previousBraking = expected.brakingTractionRaw else {
                throw BikeSDKError.operationFailed("Traction control is unavailable")
            }
            for values in [(previousPower, previousBraking), (power, braking)] {
                _ = try StarkTractionControlConfigurationCommand.noOpWritePacket(configuration: .init(
                    mapIndex: desired.mapIndex, powerRaw: values.0, brakingRaw: values.1
                ))
            }
        }
    }

    private func writeCurves(_ value: BikeSDKAdvancedPowerModeConfiguration) async throws {
        try await transport.writeConfiguration(StarkPowerCurveConfigurationCommand.writePacket(.init(
            curve: value.curve, power: value.power, regeneration: value.regeneration
        )))
    }

    private func writeBase(_ value: BikeSDKAdvancedPowerModeConfiguration) async throws {
        try await transport.writeConfiguration(StarkPowerModeConfigurationCommand.noOpWritePacket(configuration: .init(
            mapIndex: value.mapIndex, torqueRaw: value.torqueRaw,
            regenerationRaw: value.regenerationRaw, curve: value.curve
        )))
    }

    private func writeTraction(_ value: BikeSDKAdvancedPowerModeConfiguration) async throws {
        guard let power = value.powerTractionRaw, let braking = value.brakingTractionRaw else {
            throw BikeSDKError.operationFailed("Traction control is unavailable")
        }
        let packet = try StarkTractionControlConfigurationCommand.noOpWritePacket(configuration: .init(
            mapIndex: value.mapIndex, powerRaw: power, brakingRaw: braking
        ))
        try await transport.writeConfiguration(packet)
    }
}
