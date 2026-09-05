import Foundation

struct DemoIdentity: Codable, Equatable, Sendable {
    let id: UUID
    let vin: String
    let createdAt: Date

    var suiteName: String { "com.fenr.demo.\(id.uuidString)" }
    var credentialService: String { "com.fenr.demo.bike-lock.\(id.uuidString)" }
}
