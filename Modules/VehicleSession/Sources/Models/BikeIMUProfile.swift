import BikeDomain

public enum BikeIMUAxis: Equatable, Sendable {
    case positiveX
    case negativeX
    case positiveY
    case negativeY
    case positiveZ
    case negativeZ

    func value(from vector: BikeIMUVector) -> Double {
        switch self {
        case .positiveX: vector.x
        case .negativeX: -vector.x
        case .positiveY: vector.y
        case .negativeY: -vector.y
        case .positiveZ: vector.z
        case .negativeZ: -vector.z
        }
    }

    var sensorAxisIndex: Int {
        switch self {
        case .positiveX, .negativeX: 0
        case .positiveY, .negativeY: 1
        case .positiveZ, .negativeZ: 2
        }
    }
}

public struct BikeIMUAxisTransform: Equatable, Sendable {
    public let bikeX: BikeIMUAxis
    public let bikeY: BikeIMUAxis
    public let bikeZ: BikeIMUAxis

    public init(bikeX: BikeIMUAxis, bikeY: BikeIMUAxis, bikeZ: BikeIMUAxis) {
        self.bikeX = bikeX
        self.bikeY = bikeY
        self.bikeZ = bikeZ
    }

    func apply(to vector: BikeIMUVector) -> BikeIMUVector {
        .init(
            x: bikeX.value(from: vector),
            y: bikeY.value(from: vector),
            z: bikeZ.value(from: vector)
        )
    }

    var isBijective: Bool {
        Set([bikeX.sensorAxisIndex, bikeY.sensorAxisIndex, bikeZ.sensorAxisIndex]).count == 3
    }
}

public struct BikeIMUProfile: Equatable, Sendable {
    public let version: Int
    public let accelerationTransform: BikeIMUAxisTransform
    public let gyroscopeTransform: BikeIMUAxisTransform
    public let gyroscopeDegreesPerSecondPerRawUnit: BikeIMUVector
    public let oneGRaw: Double

    public init(
        version: Int,
        accelerationTransform: BikeIMUAxisTransform,
        gyroscopeTransform: BikeIMUAxisTransform,
        gyroscopeDegreesPerSecondPerRawUnit: BikeIMUVector,
        oneGRaw: Double
    ) {
        self.version = version
        self.accelerationTransform = accelerationTransform
        self.gyroscopeTransform = gyroscopeTransform
        self.gyroscopeDegreesPerSecondPerRawUnit = gyroscopeDegreesPerSecondPerRawUnit
        self.oneGRaw = oneGRaw
    }

    /// Set only after physical measurements validate axes, scale, and gravity magnitude.
    public static let productionV1: Self? = nil

#if DEBUG
    public static let debug = Self(
        version: 1,
        accelerationTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
        gyroscopeTransform: .init(bikeX: .positiveX, bikeY: .positiveY, bikeZ: .positiveZ),
        gyroscopeDegreesPerSecondPerRawUnit: .init(x: 1, y: 1, z: 1),
        oneGRaw: 1_000
    )
#endif
}
