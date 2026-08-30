@testable import BikeData
import Foundation
import Testing

@Suite("Bike IMU sample rate limiter")
struct BikeIMUSampleRateLimiterTests {
    @Test("Publishes no more than ten samples per second")
    func limitsToTenHertz() async {
        let limiter = BikeIMUSampleRateLimiter(minimumInterval: 0.1)
        let start = Date(timeIntervalSince1970: 100)

        #expect(await limiter.shouldAccept(start))
        #expect(!(await limiter.shouldAccept(start.addingTimeInterval(0.05))))
        #expect(await limiter.shouldAccept(start.addingTimeInterval(0.1)))
    }

    @Test("Sustained high-rate input remains capped at ten samples per second")
    func sustainedRateLimit() async {
        let limiter = BikeIMUSampleRateLimiter(minimumInterval: 0.1)
        let start = Date(timeIntervalSince1970: 100)
        var acceptedDates: [Date] = []

        for index in 0 ..< 50 {
            let date = start.addingTimeInterval(Double(index) / 50)
            if await limiter.shouldAccept(date) {
                acceptedDates.append(date)
            }
        }

        #expect(acceptedDates.count == 10)
        for (previous, next) in zip(acceptedDates, acceptedDates.dropFirst()) {
            #expect(next.timeIntervalSince(previous) >= 0.1 - 1e-9)
        }
    }

    @Test("A wall-clock rollback starts a new rate-limit timeline")
    func clockRollback() async {
        let limiter = BikeIMUSampleRateLimiter(minimumInterval: 0.1)
        let initial = Date(timeIntervalSince1970: 100)
        let rolledBack = Date(timeIntervalSince1970: 90)

        #expect(await limiter.shouldAccept(initial))
        #expect(await limiter.shouldAccept(rolledBack))
        #expect(!(await limiter.shouldAccept(rolledBack.addingTimeInterval(0.05))))
        #expect(await limiter.shouldAccept(rolledBack.addingTimeInterval(0.1)))
    }

    @Test("Session reset accepts the next sample immediately")
    func resetsBetweenSessions() async {
        let limiter = BikeIMUSampleRateLimiter(minimumInterval: 0.1)
        let date = Date(timeIntervalSince1970: 100)

        #expect(await limiter.shouldAccept(date))
        await limiter.reset()
        #expect(await limiter.shouldAccept(date))
    }
}
