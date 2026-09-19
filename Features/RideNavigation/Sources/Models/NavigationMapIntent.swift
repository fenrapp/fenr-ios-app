public enum NavigationMapIntent: Sendable {
    case rememberViewport(NavigationMapViewport)
    case userMovedCamera
    case recenter
    case overview
    case selectMarker(String)
}
