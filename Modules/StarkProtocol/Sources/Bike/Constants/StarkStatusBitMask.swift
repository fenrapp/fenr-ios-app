public enum StarkStatusBitMask {
    public enum Info {
        public static let charging: UInt16 = 0x0001
        public static let chargerConnected: UInt16 = 0x0002
        public static let inGear: UInt16 = 0x0008
        public static let on: UInt16 = 0x0010
        public static let pump: UInt16 = 0x0020
        public static let fan: UInt16 = 0x0040
    }

    public enum Indicator {
        public static let highBeam: UInt16 = 0x0002
        public static let rightBlinker: UInt16 = 0x0004
        public static let leftBlinker: UInt16 = 0x0008
        public static let checkEngine: UInt16 = 0x1000
    }

    public enum Misc {
        public static let walkMode: UInt16 = 0x000F
        public static let crawlActive: UInt8 = 0x08
        public static let crawlForward: UInt8 = 0x04
    }
}
