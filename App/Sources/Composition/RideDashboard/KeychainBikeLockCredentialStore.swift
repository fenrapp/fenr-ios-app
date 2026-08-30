import Foundation
import Security
import SettingsDomain

actor KeychainBikeLockCredentialStore: BikeLockCredentialStoring {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func save(pin: String, for vehicleIdentifier: String) throws {
        let data = Data(pin.utf8)
        let query = baseQuery(for: vehicleIdentifier)
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainBikeLockCredentialError(status: updateStatus)
        }
        var attributes = query
        attributes[kSecValueData] = data
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(attributes as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainBikeLockCredentialError(status: addStatus)
        }
    }

    func verify(pin: String, for vehicleIdentifier: String) -> Bool {
        var query = baseQuery(for: vehicleIdentifier)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let storedData = item as? Data else { return false }
        return storedData == Data(pin.utf8)
    }

    func containsPIN(for vehicleIdentifier: String) -> Bool {
        SecItemCopyMatching(baseQuery(for: vehicleIdentifier) as CFDictionary, nil) == errSecSuccess
    }

    func removePIN(for vehicleIdentifier: String) throws {
        let status = SecItemDelete(baseQuery(for: vehicleIdentifier) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainBikeLockCredentialError(status: status)
        }
    }

    private func baseQuery(for vehicleIdentifier: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: vehicleIdentifier
        ]
    }
}

private struct KeychainBikeLockCredentialError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        SecCopyErrorMessageString(status, nil) as String?
            ?? "Unable to access the Bike Lock PIN"
    }
}
