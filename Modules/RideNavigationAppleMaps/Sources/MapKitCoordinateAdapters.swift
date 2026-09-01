import EnvironmentDomain
import MapKit
import RideNavigation

extension GeographicCoordinate {
    init?(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitudeDegrees: coordinate.latitude, longitudeDegrees: coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitudeDegrees, longitude: longitudeDegrees)
    }
}

extension NavigationMapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitudeDegrees, longitude: longitudeDegrees)
    }
}

extension CLLocationCoordinate2D {
    var mapPoint: MKMapPoint { MKMapPoint(self) }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coordinates = Array(repeating: CLLocationCoordinate2D(), count: pointCount)
        getCoordinates(&coordinates, range: NSRange(location: .zero, length: pointCount))
        return coordinates
    }
}
