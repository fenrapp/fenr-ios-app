import Foundation
import RideNavigationDomain

public actor UserDefaultsIncomingMapLinkStore: IncomingMapLinkStoring {
    private let userDefaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults,
        key: String = "ride-navigation.pending-map-link",
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.encoder = encoder
        self.decoder = decoder
    }

    public init(suiteName: String, key: String = "ride-navigation.pending-map-link") throws {
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            throw IncomingMapLinkStoreError.sharedContainerUnavailable
        }
        self.init(userDefaults: userDefaults, key: key)
    }

    public static func shared() throws -> UserDefaultsIncomingMapLinkStore {
        guard let userDefaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            throw IncomingMapLinkStoreError.sharedContainerUnavailable
        }
        return UserDefaultsIncomingMapLinkStore(userDefaults: userDefaults)
    }

    public func save(_ link: IncomingMapLink) throws {
        userDefaults.set(try encoder.encode(link), forKey: key)
    }

    public func consume() throws -> IncomingMapLink? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        defer { userDefaults.removeObject(forKey: key) }
        return try decoder.decode(IncomingMapLink.self, from: data)
    }

    private enum Constants {
        static let appGroupIdentifier = "group.com.fenr.app.shared"
    }
}

public enum IncomingMapLinkStoreError: Error, Equatable {
    case sharedContainerUnavailable
}
