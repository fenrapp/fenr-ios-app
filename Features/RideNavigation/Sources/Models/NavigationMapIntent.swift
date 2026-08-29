public enum NavigationMapIntent: Sendable {
    case userMovedCamera
    case recenter
    case overview
    case selectMarker(String)
}
