import BikeDomain

extension BikeChargerType {
    var technicalLogName: String {
        switch self {
        case .standard:
            "Standard"
        case .fast:
            "Fast"
        case .backpack:
            "Backpack"
        case .unknown(let rawValue):
            "Unknown (\(rawValue))"
        }
    }
}
