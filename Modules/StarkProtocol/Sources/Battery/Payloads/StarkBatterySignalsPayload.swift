public struct StarkBMSSignalsPayload: Equatable, Sendable {
    public let voltageCandidateRaw: Int
    public let temperatureRaw: Int
    public let humidityRaw: Int
    public let controlFlags: Int

    public init(
        voltageCandidateRaw: Int,
        temperatureRaw: Int,
        humidityRaw: Int,
        controlFlags: Int
    ) {
        self.voltageCandidateRaw = voltageCandidateRaw
        self.temperatureRaw = temperatureRaw
        self.humidityRaw = humidityRaw
        self.controlFlags = controlFlags
    }

    public var temperatureCelsius: Double {
        Double(temperatureRaw) / StarkBatteryElectricalScale.environment
    }

    public var humidityPercent: Double {
        Double(humidityRaw) / StarkBatteryElectricalScale.environment
    }
}

public struct StarkBatterySignalsPayload: StarkPayload {
    public let positive: StarkBMSSignalsPayload
    public let negative: StarkBMSSignalsPayload
    public let currentRaw: Int

    public init(positive: StarkBMSSignalsPayload, negative: StarkBMSSignalsPayload, currentRaw: Int) {
        self.positive = positive
        self.negative = negative
        self.currentRaw = currentRaw
    }

    public var currentCandidateAmperes: Double {
        Double(currentRaw)
    }
}
