public struct StarkStatusPayload: StarkPayload {
    public let miscBits: UInt16
    public let indicatorBits: UInt16
    public let alertBits: UInt16
    public let faultBits: UInt16
    public let infoBits: UInt16
    public let lockStatus: UInt8
    public let lockTime: UInt16
    public let updateAvailable: Bool
    public let batteryStatus: UInt32

    public init(
        miscBits: UInt16,
        indicatorBits: UInt16,
        alertBits: UInt16,
        faultBits: UInt16,
        infoBits: UInt16,
        lockStatus: UInt8,
        lockTime: UInt16,
        updateAvailable: Bool,
        batteryStatus: UInt32
    ) {
        self.miscBits = miscBits
        self.indicatorBits = indicatorBits
        self.alertBits = alertBits
        self.faultBits = faultBits
        self.infoBits = infoBits
        self.lockStatus = lockStatus
        self.lockTime = lockTime
        self.updateAvailable = updateAvailable
        self.batteryStatus = batteryStatus
    }

    public var isCharging: Bool { infoBits & StarkStatusBitMask.Info.charging != 0 }
    public var isChargerConnected: Bool { infoBits & StarkStatusBitMask.Info.chargerConnected != 0 }
    public var isInGear: Bool { infoBits & StarkStatusBitMask.Info.inGear != 0 }
    public var isOn: Bool { infoBits & StarkStatusBitMask.Info.on != 0 }
    public var isHibernating: Bool { !isOn }
    public var isPumpOn: Bool { infoBits & StarkStatusBitMask.Info.pump != 0 }
    public var isFanOn: Bool { infoBits & StarkStatusBitMask.Info.fan != 0 }
    public var isHighBeamOn: Bool { indicatorBits & StarkStatusBitMask.Indicator.highBeam != 0 }
    public var isRightBlinkerOn: Bool { indicatorBits & StarkStatusBitMask.Indicator.rightBlinker != 0 }
    public var isLeftBlinkerOn: Bool { indicatorBits & StarkStatusBitMask.Indicator.leftBlinker != 0 }
    public var isCheckEngineLightOn: Bool { indicatorBits & StarkStatusBitMask.Indicator.checkEngine != 0 }
    public var isFaultActive: Bool { alertBits != 0 }
    public var walkMode: UInt8 { UInt8(miscBits & StarkStatusBitMask.Misc.walkMode) }
    public var isCrawlActive: Bool { walkMode & StarkStatusBitMask.Misc.crawlActive != 0 }
    public var isCrawlForward: Bool { walkMode & StarkStatusBitMask.Misc.crawlForward != 0 }
}
