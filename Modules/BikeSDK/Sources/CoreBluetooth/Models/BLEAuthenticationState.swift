public enum BLEAuthenticationState: Equatable, Sendable {
    case idle
    case enablingNotifications
    case readingNonce
    case writingResponse
    case waitingForResult
    case authenticated
    case failed
}
