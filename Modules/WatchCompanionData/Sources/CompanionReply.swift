// WatchConnectivity supplies a one-shot callback on its delegate queue.
struct CompanionReply: @unchecked Sendable {
    let handler: ([String: Any]) -> Void
    func send(_ value: [String: Any]) { handler(value) }
}
