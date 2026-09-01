import MapKit
import RideNavigation

final class NavigationPolyline: MKPolyline {
    var id = ""
    var role = NavigationMapPolylineRole.planned
}

final class NavigationAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let role: NavigationMapMarkerRole

    init(coordinate: CLLocationCoordinate2D, title: String, role: NavigationMapMarkerRole) {
        self.coordinate = coordinate
        self.title = title
        self.role = role
    }
}

final class DirectionalAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let rotationDegrees: Double

    init(id: String, coordinate: CLLocationCoordinate2D, rotationDegrees: Double) {
        self.id = id
        self.coordinate = coordinate
        self.rotationDegrees = rotationDegrees
    }
}

final class RiderAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var headingDegrees: Double?

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

final class RiderAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func update(headingDegrees: Double?, mapHeadingDegrees: Double) {
        let relativeHeading = (headingDegrees ?? mapHeadingDegrees) - mapHeadingDegrees
        transform = CGAffineTransform(
            rotationAngle: relativeHeading * .pi / Constants.halfCircleDegrees
        )
    }

    private func configure() {
        image = UIImage(
            systemName: "location.north.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Constants.symbolSize)
        )?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        displayPriority = .required
        collisionMode = .circle
        centerOffset = CGPoint(x: .zero, y: -Constants.centerOffset)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Constants.shadowOpacity
        layer.shadowRadius = Constants.shadowRadius
        layer.shadowOffset = Constants.shadowOffset
    }

    private enum Constants {
        static let symbolSize: CGFloat = 34
        static let centerOffset: CGFloat = 8
        static let shadowOpacity: Float = 0.28
        static let shadowRadius: CGFloat = 3
        static let shadowOffset = CGSize(width: .zero, height: 2)
        static let halfCircleDegrees = 180.0
    }
}

final class DirectionalAnnotationView: MKAnnotationView {
    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    func update(rotationDegrees: Double, mapHeadingDegrees: Double) {
        transform = CGAffineTransform(
            rotationAngle: (rotationDegrees - mapHeadingDegrees) * .pi / Constants.halfCircleDegrees
        )
    }

    private func configure() {
        image = UIImage(
            systemName: "chevron.up",
            withConfiguration: UIImage.SymbolConfiguration(
                pointSize: Constants.symbolSize,
                weight: .black
            )
        )?.withTintColor(.white, renderingMode: .alwaysOriginal)
        displayPriority = .required
        collisionMode = .none
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Constants.shadowOpacity
        layer.shadowRadius = Constants.shadowRadius
        layer.shadowOffset = .zero
    }

    private enum Constants {
        static let symbolSize: CGFloat = 18
        static let shadowOpacity: Float = 0.45
        static let shadowRadius: CGFloat = 2
        static let halfCircleDegrees = 180.0
    }
}
