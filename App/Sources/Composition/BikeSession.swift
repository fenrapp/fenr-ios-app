import BikeDomain

struct BikeSession {
    let repository: any BikeRepository & BikeBatteryHealthRepository & BikeDiscoveryRepository
    let pinDeriver: any BikePinDeriving
}
