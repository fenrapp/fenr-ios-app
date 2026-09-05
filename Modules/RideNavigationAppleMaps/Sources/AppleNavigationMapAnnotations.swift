import MapKit
import RideNavigation

final class NavigationPolyline: MKPolyline {
    var id = ""
    var role = NavigationMapPolylineRole.planned
    var appearance: NavigationMapLineAppearance?
}

final class FocusBasemapDimOverlay: NSObject, MKOverlay {
    let coordinate = CLLocationCoordinate2D(latitude: .zero, longitude: .zero)
    let boundingMapRect = MKMapRect.world
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
    private let arrowView = UIImageView()
    private let compassRingView = CompassRingView()

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

    func update(
        headingDegrees: Double?,
        mapHeadingDegrees: Double,
        showsCompassRing: Bool,
        usesFocusAppearance: Bool
    ) {
        let relativeHeading = (headingDegrees ?? mapHeadingDegrees) - mapHeadingDegrees
        arrowView.transform = CGAffineTransform(
            rotationAngle: relativeHeading * .pi / Constants.halfCircleDegrees
        )
        arrowView.tintColor = usesFocusAppearance ? .label : .systemBlue
        compassRingView.isHidden = !showsCompassRing
        compassRingView.update(
            mapHeadingDegrees: mapHeadingDegrees,
            usesFocusAppearance: usesFocusAppearance
        )
    }

    private func configure() {
        guard compassRingView.superview == nil else { return }
        image = nil
        bounds = CGRect(
            x: .zero,
            y: .zero,
            width: Constants.annotationSize,
            height: Constants.annotationSize
        )
        compassRingView.frame = bounds
        compassRingView.backgroundColor = .clear
        addSubview(compassRingView)
        arrowView.image = UIImage(
            systemName: "location.north.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Constants.symbolSize)
        )?.withRenderingMode(.alwaysTemplate)
        arrowView.tintColor = .systemBlue
        arrowView.contentMode = .center
        arrowView.frame = CGRect(
            x: (bounds.width - Constants.arrowSize) / 2,
            y: (bounds.height - Constants.arrowSize) / 2,
            width: Constants.arrowSize,
            height: Constants.arrowSize
        )
        addSubview(arrowView)
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
        static let arrowSize: CGFloat = 38
        static let annotationSize: CGFloat = 104
        static let centerOffset: CGFloat = 8
        static let shadowOpacity: Float = 0.28
        static let shadowRadius: CGFloat = 3
        static let shadowOffset = CGSize(width: .zero, height: 2)
        static let halfCircleDegrees = 180.0
    }
}

private final class CompassRingView: UIView {
    private var mapHeadingDegrees = 0.0
    private var usesFocusAppearance = false

    func update(mapHeadingDegrees: Double, usesFocusAppearance: Bool) {
        guard self.mapHeadingDegrees != mapHeadingDegrees
            || self.usesFocusAppearance != usesFocusAppearance else { return }
        self.mapHeadingDegrees = mapHeadingDegrees
        self.usesFocusAppearance = usesFocusAppearance
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        context.setStrokeColor(secondaryColor.cgColor)
        context.setLineWidth(Constants.ringWidth)
        let cardinals = NavigationCardinal.allCases
        let fonts = cardinals.map {
            UIFont.systemFont(ofSize: Constants.fontSize, weight: $0.isNorth ? .bold : .medium)
        }
        let sizes = cardinals.enumerated().map { index, cardinal in
            String(localized: cardinal.resource).size(withAttributes: [.font: fonts[index]])
        }
        let geometry = CompassRingGeometry(
            center: center,
            radius: Constants.ringRadius,
            headingDegrees: mapHeadingDegrees,
            labelSizes: sizes,
            padding: Constants.labelMargin
        )
        context.addPath(geometry.path)
        context.strokePath()

        for (index, cardinal) in cardinals.enumerated() {
            let text = String(localized: cardinal.resource)
            let font = fonts[index]
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: secondaryColor
            ]
            let size = sizes[index]
            let point = geometry.labels[index].center
            let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
            if cardinal.isNorth {
                drawNorth(text, font: font, size: size, at: origin)
            } else {
                text.draw(at: origin, withAttributes: attributes)
            }
        }
    }

    private func drawNorth(_ text: String, font: UIFont, size: CGSize, at origin: CGPoint) {
        let format = UIGraphicsImageRendererFormat.preferred()
        let image = UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            text.draw(
                at: .zero,
                withAttributes: [.font: font, .foregroundColor: UIColor.white]
            )
            rendererContext.cgContext.setBlendMode(.sourceIn)
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor.systemRed.resolvedColor(with: traitCollection).cgColor,
                    UIColor.systemOrange.resolvedColor(with: traitCollection).cgColor
                ] as CFArray,
                locations: [0, 1]
            ) else { return }
            rendererContext.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: CGFloat.zero, y: size.height),
                options: []
            )
        }
        image.draw(at: origin)
    }

    private var secondaryColor: UIColor {
        usesFocusAppearance ? .secondaryLabel : .label.withAlphaComponent(Constants.secondaryOpacity)
    }

    private enum Constants {
        static let ringRadius: CGFloat = 38
        static let ringWidth: CGFloat = 1.5
        static let labelMargin: CGFloat = 2
        static let fontSize: CGFloat = 9
        static let secondaryOpacity: CGFloat = 0.7
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
