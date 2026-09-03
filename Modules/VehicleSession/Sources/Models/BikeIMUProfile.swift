import BikeDomain
import Foundation

public enum BikeIMUAxis: Equatable, Sendable {
    case positiveX
    case negativeX
    case positiveY
    case negativeY
    case positiveZ
    case negativeZ

    var unitVector: BikeIMUVector {
        switch self {
        case .positiveX: .init(x: 1, y: 0, z: 0)
        case .negativeX: .init(x: -1, y: 0, z: 0)
        case .positiveY: .init(x: 0, y: 1, z: 0)
        case .negativeY: .init(x: 0, y: -1, z: 0)
        case .positiveZ: .init(x: 0, y: 0, z: 1)
        case .negativeZ: .init(x: 0, y: 0, z: -1)
        }
    }
}

public struct BikeIMURigidTransform: Equatable, Sendable {
    public let bikeX: BikeIMUVector
    public let bikeY: BikeIMUVector
    public let bikeZ: BikeIMUVector

    public init(bikeX: BikeIMUVector, bikeY: BikeIMUVector, bikeZ: BikeIMUVector) {
        self.bikeX = bikeX
        self.bikeY = bikeY
        self.bikeZ = bikeZ
    }

    public init(bikeX: BikeIMUAxis, bikeY: BikeIMUAxis, bikeZ: BikeIMUAxis) {
        self.init(
            bikeX: bikeX.unitVector,
            bikeY: bikeY.unitVector,
            bikeZ: bikeZ.unitVector
        )
    }

    func apply(to vector: BikeIMUVector) -> BikeIMUVector {
        .init(
            x: bikeX.dot(vector),
            y: bikeY.dot(vector),
            z: bikeZ.dot(vector)
        )
    }

    var isRigid: Bool {
        let determinant = bikeX.x * (bikeY.y * bikeZ.z - bikeY.z * bikeZ.y)
            - bikeX.y * (bikeY.x * bikeZ.z - bikeY.z * bikeZ.x)
            + bikeX.z * (bikeY.x * bikeZ.y - bikeY.y * bikeZ.x)
        return bikeX.isFinite
            && bikeY.isFinite
            && bikeZ.isFinite
            && abs(bikeX.magnitude - 1) <= Constants.validationTolerance
            && abs(bikeY.magnitude - 1) <= Constants.validationTolerance
            && abs(bikeZ.magnitude - 1) <= Constants.validationTolerance
            && abs(bikeX.dot(bikeY)) <= Constants.validationTolerance
            && abs(bikeX.dot(bikeZ)) <= Constants.validationTolerance
            && abs(bikeY.dot(bikeZ)) <= Constants.validationTolerance
            && abs(determinant - 1) <= Constants.validationTolerance
    }

    private enum Constants {
        static let validationTolerance = 1e-6
    }
}

public struct BikeIMUProfile: Equatable, Sendable {
    public let version: Int
    public let accelerationTransform: BikeIMURigidTransform
    public let gyroscopeTransform: BikeIMURigidTransform
    public let gyroscopeDegreesPerSecondPerRawUnit: BikeIMUVector
    public let oneGRaw: Double

    public init(
        version: Int,
        accelerationTransform: BikeIMURigidTransform,
        gyroscopeTransform: BikeIMURigidTransform,
        gyroscopeDegreesPerSecondPerRawUnit: BikeIMUVector,
        oneGRaw: Double
    ) {
        self.version = version
        self.accelerationTransform = accelerationTransform
        self.gyroscopeTransform = gyroscopeTransform
        self.gyroscopeDegreesPerSecondPerRawUnit = gyroscopeDegreesPerSecondPerRawUnit
        self.oneGRaw = oneGRaw
    }

    /// Physically observed sensor mounting transformed into the bike coordinate frame.
    public static let productionV1 = Self(
        version: 1,
        accelerationTransform: .observedBikeMounting,
        gyroscopeTransform: .observedBikeMounting,
        gyroscopeDegreesPerSecondPerRawUnit: .init(
            x: 1 / 16.4,
            y: 1 / 16.4,
            z: 1 / 16.4
        ),
        oneGRaw: 2_048
    )

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

private extension BikeIMURigidTransform {
    static let observedBikeMounting = Self(
        bikeX: .init(x: 0, y: 0.680_076_895_6, z: 0.733_140_788_7),
        bikeY: .init(x: -1, y: 0, z: 0),
        bikeZ: .init(x: 0, y: -0.733_140_788_7, z: 0.680_076_895_6)
    )
}

private extension BikeIMUVector {
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    var magnitude: Double { sqrt(x * x + y * y + z * z) }

    func dot(_ other: Self) -> Double {
        x * other.x + y * other.y + z * other.z
    }
}
