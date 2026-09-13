import Foundation
import Testing
@testable import WatchCompanionData

struct CompanionTransferGateTests {
    @Test func aMissingReplyAllowsRecoveryAfterTimeout() throws {
        var gate = CompanionTransferGate(timeout: 15)
        let now = Date()
        let firstToken = gate.begin(at: now)
        let original = try #require(firstToken)
        let earlyRetry = gate.begin(at: now.addingTimeInterval(14))
        #expect(earlyRetry == nil)
        let nextToken = gate.begin(at: now.addingTimeInterval(15))
        let retry = try #require(nextToken)
        let acceptsOldReply = gate.complete(original)
        #expect(!acceptsOldReply)
        let overlappingRetry = gate.begin(at: now.addingTimeInterval(16))
        #expect(overlappingRetry == nil)
        let acceptsCurrentReply = gate.complete(retry)
        #expect(acceptsCurrentReply)
        let freshTransfer = gate.begin(at: now.addingTimeInterval(16))
        #expect(freshTransfer != nil)
    }

    @Test func repliesFromThePreviousConnectionCannotCompleteTheNewTransfer() throws {
        var gate = CompanionTransferGate(timeout: 15)
        let now = Date()
        let firstToken = gate.begin(at: now)
        let original = try #require(firstToken)
        gate.reset()
        let nextToken = gate.begin(at: now)
        let current = try #require(nextToken)
        let acceptsOldReply = gate.complete(original)
        #expect(!acceptsOldReply)
        let overlappingTransfer = gate.begin(at: now)
        #expect(overlappingTransfer == nil)
        let acceptsCurrentReply = gate.complete(current)
        #expect(acceptsCurrentReply)
    }
}
