import CoreBluetooth

@MainActor
struct BikeBLEAuthenticationLinkRecovery {
    let adapter: CoreBluetoothAdapter
    let sessionStore: BLESessionStore
    let eventEmitter: BikeBLEEventEmitter

    func restart() async {
        await eventEmitter.send(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "Restarting BLE link for normal authentication"
        )))
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        guard let peripheral = sessionStore.peripheral else {
            guard adapter.state == .poweredOn else { return }
            adapter.scanForBike()
            return
        }
        adapter.cancelConnection(peripheral)
    }
}
