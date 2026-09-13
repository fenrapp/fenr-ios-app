import BikeDomain

extension BikeEmulatorState {
    var hasValidAdvancedMaps: Bool {
        guard let advancedMaps else { return true }
        return Set(advancedMaps.map(\.mapIndex)).count == advancedMaps.count
            && advancedMaps.allSatisfy { value in
                (0 ... 4).contains(value.mapIndex) && value.curve == value.mapIndex + 1
                    && value.firmware == "1.10.1"
                    && (13 ... 100).contains(value.torqueRaw)
                    && (0 ... 100).contains(value.regenerationRaw)
                    && value.power.count == BikePowerCurveCalibration.sampleCount
                    && value.regeneration.count == BikePowerCurveCalibration.sampleCount
                    && (value.power + value.regeneration).allSatisfy { (0 ... 1_000).contains($0) }
                    && [value.powerTractionRaw, value.brakingTractionRaw].allSatisfy {
                        $0.map { (-1_000 ... 1_000).contains($0) } != false
                    }
            }
    }
}
