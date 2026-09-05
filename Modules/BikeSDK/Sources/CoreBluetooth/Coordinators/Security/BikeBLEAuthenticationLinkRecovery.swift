import BLETraceDomain
import CoreBluetooth

@MainActor
struct BikeBLEAuthenticationLinkRecovery {
    let adapter: CoreBluetoothAdapter
    let sessionStore: BLESessionStore
    let eventEmitter: BikeBLEEventEmitter
    let traceEmitter: BikeBLETraceEmitter

    func restart() async {
        await eventEmitter.sendDiagnostic(.debug(.init(
            title: BikeSDKText.pairingTitle,
            detail: "Restarting BLE link for normal authentication"
        )))
        guard sessionStore.shouldConnectWhenPoweredOn else { return }
        guard let peripheral = sessionStore.peripheral else {
            guard adapter.state == .poweredOn else { return }
            await traceEmitter.record(
                category: "central",
                operation: .scanStarted,
                direction: .outbound,
                detail: "authentication_link_recovery"
            )
            adapter.scanForBike()
            return
        }
        await traceEmitter.record(
            category: "link",
            operation: .disconnectRequested,
            direction: .outbound,
            detail: "authentication_link_recovery"
        )
        adapter.cancelConnection(peripheral)
    }
}
