import Foundation

public struct CompanionTransferGate {
    private let timeout: TimeInterval
    private var nextToken: UInt64 = 0
    private var pendingToken: UInt64?
    private var deadline: Date?

    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    public mutating func begin(at now: Date) -> UInt64? {
        guard deadline.map({ now >= $0 }) ?? true else { return nil }
        nextToken &+= 1
        pendingToken = nextToken
        deadline = now.addingTimeInterval(timeout)
        return nextToken
    }

    @discardableResult
    public mutating func complete(_ token: UInt64) -> Bool {
        guard pendingToken == token else { return false }
        reset()
        return true
    }

    public mutating func reset() {
        pendingToken = nil
        deadline = nil
    }
}
