import SettingsDomain

enum RecordingBikeLockCredentialStoreError: Error {
    case saveFailed
}

actor RecordingBikeLockCredentialStore: BikeLockCredentialStoring {
    private var pinsByVehicleIdentifier: [String: String]
    private var savedCredentials: [(pin: String, vehicleIdentifier: String)] = []
    private var removedVehicleIdentifiers: [String] = []
    private let failsSavingPIN: Bool
    private let operationRecorder: SettingsDomainOperationRecorder?
    private let afterSave: (@Sendable () async -> Void)?

    init(
        pinsByVehicleIdentifier: [String: String] = [:],
        failsSavingPIN: Bool = false,
        operationRecorder: SettingsDomainOperationRecorder? = nil,
        afterSave: (@Sendable () async -> Void)? = nil
    ) {
        self.pinsByVehicleIdentifier = pinsByVehicleIdentifier
        self.failsSavingPIN = failsSavingPIN
        self.operationRecorder = operationRecorder
        self.afterSave = afterSave
    }

    func save(pin: String, for vehicleIdentifier: String) async throws {
        guard !failsSavingPIN else {
            throw RecordingBikeLockCredentialStoreError.saveFailed
        }
        pinsByVehicleIdentifier[vehicleIdentifier] = pin
        savedCredentials.append((pin, vehicleIdentifier))
        await operationRecorder?.record(.credentialSaved(vehicleIdentifier: vehicleIdentifier))
        await afterSave?()
    }

    func verify(pin: String, for vehicleIdentifier: String) async -> Bool {
        pinsByVehicleIdentifier[vehicleIdentifier] == pin
    }

    func containsPIN(for vehicleIdentifier: String) async -> Bool {
        pinsByVehicleIdentifier[vehicleIdentifier] != nil
    }

    func removePIN(for vehicleIdentifier: String) async throws {
        pinsByVehicleIdentifier[vehicleIdentifier] = nil
        removedVehicleIdentifiers.append(vehicleIdentifier)
        await operationRecorder?.record(.credentialRemoved(vehicleIdentifier: vehicleIdentifier))
    }

    func saves() -> [(pin: String, vehicleIdentifier: String)] {
        savedCredentials
    }

    func removals() -> [String] {
        removedVehicleIdentifiers
    }

    func pin(for vehicleIdentifier: String) -> String? {
        pinsByVehicleIdentifier[vehicleIdentifier]
    }
}
