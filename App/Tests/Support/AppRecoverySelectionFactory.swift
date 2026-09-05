import Foundation

@MainActor
func makeSelection(defaults: UserDefaults) -> DemoSelectionStore {
    DemoSelectionStore(
        defaults: defaults, encoder: JSONEncoder(), decoder: JSONDecoder(),
        makeID: UUID.init, makeDigits: { "123456789" }, now: Date.init
    )
}
