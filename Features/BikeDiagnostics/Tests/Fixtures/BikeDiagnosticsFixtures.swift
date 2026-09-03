import BikeDomain
import Foundation
import VehicleSession

func fullSnapshot(connection: BikeConnection? = nil) -> VehicleSessionSnapshot {
    let update = Date(timeIntervalSince1970: 1_000)
    let bms = BikeBMSSignalsTelemetry(
        voltageCandidateRaw: 408,
        temperatureRaw: 2_534,
        temperatureCelsius: 25.34,
        humidityRaw: 5_012,
        humidityPercent: 50.12
    )
    return VehicleSessionSnapshot(
        telemetry: fullTelemetry(update: update, bms: bms),
        connection: connection ?? fullConnection(),
        profile: .init(
            vin: "FENRTEST000000001",
            declaredPowerTier: .alpha,
            alphaEvidence: [.powerAboveStandard]
        )
    )
}

private func fullTelemetry(
    update: Date,
    bms: BikeBMSSignalsTelemetry
) -> BikeTelemetry {
    BikeTelemetry(
        vin: "FENRTEST000000001",
        mode: .index(1),
        speed: .known(kmh: 42.1, kmhX10: 421),
        motorRPM: .known(3_180),
        odometer: .known(kilometers: 123.45, centiKilometers: 12_345),
        inverterTemperatureRawValues: [310, 322],
        inverterTemperaturesCelsius: [31, 32.2],
        statusFlags: .init(
            isOn: true,
            isChargerConnected: true,
            isInGear: true,
            isFaultActive: true,
            isBrakeActive: true,
            indicatorState: .init(isLeftBlinkerOn: true)
        ),
        rawStatusFlags: .init(misc: 12, indicator: 4, alert: 1, fault: 2, info: 24),
        powerModeConfigurations: [
            0: .init(
                mapIndex: 0,
                horsepower: 62,
                regenerativeBrakingPercent: 35,
                powerTractionPercent: 18,
                brakingTractionPercent: 12
            )
        ],
        detectedPowerTier: .alpha(evidence: [.powerAboveStandard, .tractionControlConfigured]),
        powerTelemetry: .init(electricalPowerWatts: 10_000, calculatedPowerUpdatedAt: update),
        batteryTelemetry: .init(
            stateOfCharge: .known(percent: 91),
            stateOfHealth: .known(percent: 99),
            dcBusRaw: 4_000,
            dcBusVolts: 400,
            currentRaw: 25,
            currentCandidateAmperes: 25,
            positiveBMS: bms,
            negativeBMS: bms,
            stateUpdatedAt: update,
            signalsUpdatedAt: update
        ),
        lastUpdated: update
    )
}

private func fullConnection() -> BikeConnection {
    .init(
        state: .receivingTelemetry(peripheralName: "FENR Bike"),
        peripheralName: "FENR Bike",
        peripheralIdentifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001"),
        rssi: -58
    )
}
