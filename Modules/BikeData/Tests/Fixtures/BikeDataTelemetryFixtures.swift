import BikeSDK

enum BikeDataTelemetryFixtures {
    static let batteryStatusFault = BikeSDKTelemetryPayload.batteryStatus(.init(
        positiveFaultBits: 0x0000_0001,
        negativeFaultBits: 0
    ))

    static let battery = BikeSDKTelemetryPayload.battery(.init(
        stateOfChargePercent: 76,
        stateOfHealthPercent: nil,
        dcBusRaw: 3_948
    ))
    static let batteryForPower = BikeSDKTelemetryPayload.battery(.init(
        stateOfChargePercent: 80,
        stateOfHealthPercent: 95,
        dcBusRaw: 4_000
    ))
    static let batteryParameters = BikeSDKTelemetryPayload.batteryParameters(.init(
        seriesCount: 100,
        parallelCount: 2,
        capacityRaw: 6_900
    ))
    static let batterySignals = BikeSDKTelemetryPayload.batterySignals(.init(
        positive: .init(
            voltageCandidateRaw: 408,
            temperatureRaw: 2_534,
            humidityRaw: 5_012,
            controlFlags: 1
        ),
        negative: .init(
            voltageCandidateRaw: 403,
            temperatureRaw: 2_450,
            humidityRaw: 4_899,
            controlFlags: 2
        ),
        currentRaw: 25
    ))
    static let negativeBatterySignals = BikeSDKTelemetryPayload.batterySignals(.init(
        positive: .init(
            voltageCandidateRaw: 408,
            temperatureRaw: 2_534,
            humidityRaw: 5_012,
            controlFlags: 1
        ),
        negative: .init(
            voltageCandidateRaw: 403,
            temperatureRaw: 2_450,
            humidityRaw: 4_899,
            controlFlags: 2
        ),
        currentRaw: -25
    ))
    static let liveEstimations = BikeSDKTelemetryPayload.liveEstimations(.init(
        estimatedRangeRaw: 72,
        estimatedTimeRaw: 55,
        nativeMotorPowerRaw: -100
    ))

    static let status = BikeSDKTelemetryPayload.status(.init(
        miscBits: 0x000C,
        indicatorBits: 0x1004,
        alertBits: 0x0001,
        faultBits: 0x0002,
        infoBits: 0x001B,
        lockStatus: 1,
        lockTime: 42,
        updateAvailable: true,
        batteryStatus: 0x12345678
    ))
    static let activeBrake = BikeSDKTelemetryPayload.vcuBrake(.init(
        primaryBrakeSignal: 1,
        secondaryBrakeSignal: 1
    ))

    static let map = BikeSDKTelemetryPayload.map(3)
    static let speed = BikeSDKTelemetryPayload.speed(.init(
        speedKmh: 42.1,
        speedKmhX10: 421,
        motorRPM: 3_180
    ))
    static let liveTotals = BikeSDKTelemetryPayload.liveTotals(.init(
        firstRawCounter: 18_066,
        secondRawCounter: 20_833,
        thirdRawCounter: 0,
        fourthRawCounter: 203_916
    ))
    static let inverterTemperatures = BikeSDKTelemetryPayload.inverterTemperatures(.init(
        rawValues: [395, 408, 323, 519, 322, 325, 330, 0]
    ))
    static let charger = BikeSDKTelemetryPayload.charger(.init(
        requestedCurrentAmperes: 2.5,
        reportedCurrentAmperes: 2.5,
        targetCellVoltageVolts: 4.275,
        maximumCurrentAmperes: 20,
        maximumPowerWatts: 1_000,
        maximumStateOfChargePercent: 100,
        requestedVoltageRaw: 0,
        reportedVoltageRaw: 0,
        statusRaw: 0,
        isEnabled: false,
        typeRaw: 3
    ))
}
