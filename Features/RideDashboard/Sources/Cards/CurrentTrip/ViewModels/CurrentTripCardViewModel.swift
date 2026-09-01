import Combine
import Foundation
import RideSession
import RideSessionDomain

@MainActor
public final class CurrentTripCardViewModel: ObservableObject {
    @Published public private(set) var viewState = DashboardCurrentTripViewData()

    private let session: any RideSessionService
    private let mapper: CurrentTripCardMapper
    private var snapshot: RideSessionSnapshot
    private var sessionTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var isVisible = false

    public init(
        session: any RideSessionService,
        mapper: CurrentTripCardMapper
    ) {
        self.session = session
        self.mapper = mapper
        snapshot = .init(
            vehicleIdentity: .temporary(UUID()),
            isCanonicalTelemetryAvailable: false
        )
    }

    deinit {
        sessionTask?.cancel()
        commandTask?.cancel()
    }

    func setIsVisible(_ isVisible: Bool) {
        guard self.isVisible != isVisible else { return }
        self.isVisible = isVisible
        guard isVisible else {
            stopPublishing()
            return
        }
        observeSessionIfNeeded()
        renderIfVisible()
    }

    private func stopPublishing() {
        sessionTask?.cancel()
        sessionTask = nil
    }

    func togglePauseCurrentTrip() {
        enqueue(.togglePause)
    }

    func resetCurrentTrip() {
        enqueue(.reset)
    }

#if DEBUG
    func setPreviewState(_ viewState: DashboardCurrentTripViewData) {
        self.viewState = viewState
    }
#endif
}

private extension CurrentTripCardViewModel {
    func observeSessionIfNeeded() {
        guard sessionTask == nil else { return }
        sessionTask = Task { [weak self, session] in
            let stream = await session.observe()
            for await snapshot in stream {
                guard !Task.isCancelled else { return }
                self?.snapshot = snapshot
                if snapshot.isCanonicalTelemetryAvailable {
                    self?.renderIfVisible()
                }
            }
        }
    }

    func renderIfVisible() {
        guard isVisible else { return }
        viewState = mapper.map(
            trip: snapshot.trip,
            measurementSystem: snapshot.measurementSystem,
            speedSource: snapshot.speedSource,
            isGPSAvailable: snapshot.isGPSAvailable
        )
    }

    func enqueue(_ command: Command) {
        guard isVisible, snapshot.isCanonicalTelemetryAvailable else { return }
        let previousCommand = commandTask
        let session = session
        commandTask = Task {
            await previousCommand?.value
            guard !Task.isCancelled else { return }
            switch command {
            case .togglePause:
                await session.togglePauseCurrentTrip()
            case .reset:
                await session.resetCurrentTrip()
            }
        }
    }

    enum Command {
        case togglePause
        case reset
    }
}
