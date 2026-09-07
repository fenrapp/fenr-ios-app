import Foundation
import Security

enum DebugUITestCredentialReset {
    static func clear(service: String) throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ResetError.unavailableCredentials
        }
    }

    private enum ResetError: Error {
        case unavailableCredentials
    }
}
