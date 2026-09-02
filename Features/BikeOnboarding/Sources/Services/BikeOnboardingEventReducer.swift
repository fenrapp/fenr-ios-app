enum BikeOnboardingEffect {
    case none
    case beginDiscovery
    case selectBike(BikeDiscoveryViewData)
    case completeOnboarding
    case showBluetoothRecovery(BikeOnboardingBluetoothState)
    case stopFailedDiscovery
    case finish(String)
}

@MainActor
public struct BikeOnboardingEventReducer {
    private let pairingCoordinator: BikeOnboardingPairingCoordinator

    public init(pairingCoordinator: BikeOnboardingPairingCoordinator) {
        self.pairingCoordinator = pairingCoordinator
    }

    func reduce(
        _ event: BikeOnboardingEvent,
        state: inout BikeOnboardingViewState
    ) -> BikeOnboardingEffect {
        switch event {
        case .discovery(let event):
            reduce(event, state: &state)
        case .connection(let event):
            reduce(event, state: &state)
        case .bluetooth(let event):
            reduce(event, state: &state)
        case .completion(.completed(let vin)):
            .finish(vin)
        }
    }

    private func reduce(
        _ event: BikeOnboardingDiscoveryEvent,
        state: inout BikeOnboardingViewState
    ) -> BikeOnboardingEffect {
        guard state.step == .discovery else { return .none }
        switch event {
        case .started:
            state.discoveredBikes = []
            state.discoveryState = .scanning
            state.isDiscoveringBikes = true
        case .updated(let bikes, let discoveryState):
            state.discoveredBikes = bikes
            state.discoveryState = discoveryState
        case .selected(let bike):
            return .selectBike(bike)
        case .timedOut:
            state.discoveryState = .timedOut
            state.isDiscoveringBikes = false
        }
        return .none
    }

    private func reduce(
        _ event: BikeOnboardingConnectionEvent,
        state: inout BikeOnboardingViewState
    ) -> BikeOnboardingEffect {
        switch event {
        case .permissionReady:
            return state.isRequestingBluetoothAccess ? .beginDiscovery : .none
        case .telemetry(let peripheralName):
            return pairingCoordinator.matches(peripheralName: peripheralName, targetVIN: state.vin)
                ? .completeOnboarding
                : .none
        case .recovery(let recovery):
            if state.step == .discovery {
                return .stopFailedDiscovery
            }
            guard state.step == .connecting else { return .none }
            state.connectionState = recovery
        case .progress(let progress):
            guard state.step == .connecting else { return .none }
            state.connectionState = progress
        case .bluetooth(let bluetoothState):
            return .showBluetoothRecovery(bluetoothState)
        case .attemptFailed:
            guard state.step == .connecting else { return .none }
            state.connectionState = .disconnected
        }
        return .none
    }

    private func reduce(
        _ event: BikeOnboardingBluetoothAccessEvent,
        state: inout BikeOnboardingViewState
    ) -> BikeOnboardingEffect {
        guard state.isRequestingBluetoothAccess else { return .none }
        switch event {
        case .allowed:
            return .beginDiscovery
        case .denied:
            return .showBluetoothRecovery(.denied)
        case .unanswered:
            state.isRequestingBluetoothAccess = false
            state.bluetoothState = .preparation
            return .none
        }
    }
}
