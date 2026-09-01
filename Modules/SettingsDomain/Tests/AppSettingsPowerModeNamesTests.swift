import Foundation
import SettingsDomain
import Testing

@Suite("App settings power mode names")
struct AppSettingsPowerModeNamesTests {
    private let vehicleIdentifier = "FENRTEST000000001"

    @Test("Accepts every supported power map index")
    func acceptsSupportedIndices() throws {
        var settings = AppSettings()

        for mapIndex in 0 ... 4 {
            let name = try PowerModeName("Map\(mapIndex)")
            try settings.setPowerModeName(name, forVIN: vehicleIdentifier, mapIndex: mapIndex)
            #expect(settings.powerModeName(forVIN: vehicleIdentifier, mapIndex: mapIndex) == name)
        }
    }

    @Test("Rejects power map indices outside zero through four", arguments: [-1, 5])
    func rejectsUnsupportedIndices(mapIndex: Int) throws {
        var settings = AppSettings()
        let name = try PowerModeName("Enduro")

        #expect(throws: PowerModeNameAssignmentError.invalidMapIndex) {
            try settings.setPowerModeName(name, forVIN: vehicleIdentifier, mapIndex: mapIndex)
        }
    }

    @Test("Rejects duplicate names between maps without letter case")
    func rejectsCaseInsensitiveDuplicates() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(
            PowerModeName("Eco"),
            forVIN: vehicleIdentifier,
            mapIndex: 0
        )

        #expect(throws: PowerModeNameAssignmentError.duplicate) {
            try settings.setPowerModeName(
                PowerModeName("ECO"),
                forVIN: vehicleIdentifier,
                mapIndex: 1
            )
        }
    }

    @Test("Allows renaming the same map without letter case")
    func allowsRenamingSameMap() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(
            PowerModeName("Eco"),
            forVIN: vehicleIdentifier,
            mapIndex: 0
        )

        let renamed = try PowerModeName("ECO")
        try settings.setPowerModeName(renamed, forVIN: vehicleIdentifier, mapIndex: 0)

        #expect(settings.powerModeName(forVIN: vehicleIdentifier, mapIndex: 0) == renamed)
    }

    @Test("Removes the vehicle entry after clearing its final name")
    func clearsVehicleAfterFinalName() throws {
        var settings = AppSettings()
        try settings.setPowerModeName(
            PowerModeName("Enduro"),
            forVIN: vehicleIdentifier,
            mapIndex: 4
        )

        settings.clearPowerModeName(forVIN: vehicleIdentifier, mapIndex: 4)

        #expect(settings.powerModeNamesByVIN[vehicleIdentifier] == nil)
    }

    @Test("Sanitizes persisted indices and case-insensitive duplicates")
    func sanitizesPersistedNames() throws {
        let data = Data("""
        {
          "powerModeNamesByVIN": {
            "\(vehicleIdentifier)": {
              "-1": { "value": "Outside" },
              "0": { "value": "Eco" },
              "1": { "value": "ECO" },
              "4": { "value": "Enduro" },
              "5": { "value": "Invalid" }
            }
          }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        #expect(settings.powerModeNames(forVIN: vehicleIdentifier) == [
            0: try PowerModeName("Eco"),
            4: try PowerModeName("Enduro")
        ])
    }
}
