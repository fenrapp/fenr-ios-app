import Foundation
import OSLog
import WatchCompanionDomain
@preconcurrency import WatchConnectivity

@MainActor
public final class WatchConnectivityCompanionSession: NSObject {
    private let session: WCSession
    private let codec: CompanionSnapshotCodec
    private let store: (any CompanionSnapshotStoring)?
    private let logger: Logger
    private var snapshot: CompanionSnapshot?
    #if os(iOS)
    private var latestData: Data?
    #endif
    #if os(watchOS)
    private var observers: [UUID: AsyncStream<CompanionState>.Continuation] = [:]
    #endif
    private let now: @Sendable () -> Date
    private var transferGate: CompanionTransferGate
    #if os(iOS)
    private var lastLiveDate: Date?
    private var lastContextDate: Date?
    private var contextConnection: Bool?
    private var contextCharging: Bool?
    #endif

    public init(
        session: WCSession,
        codec: CompanionSnapshotCodec,
        store: (any CompanionSnapshotStoring)?,
        logger: Logger,
        now: @escaping @Sendable () -> Date,
        transferGate: CompanionTransferGate
    ) {
        self.session = session
        self.codec = codec
        self.store = store
        self.logger = logger
        self.now = now
        self.transferGate = transferGate
    }

    deinit {
        #if os(watchOS)
        for observer in observers.values { observer.finish() }
        #endif
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        guard session.delegate !== self else { return }
        #if os(watchOS)
        if let data = store?.load(), let cached = try? codec.decode(data) {
            snapshot = cached
        }
        #endif
        session.delegate = self
        session.activate()
    }

    #if os(watchOS)
    public func observe() -> AsyncStream<CompanionState> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<CompanionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        observers[identifier] = continuation
        continuation.yield(state)
        continuation.onTermination = { [weak self] _ in
            DispatchQueue.main.async { self?.observers.removeValue(forKey: identifier) }
        }
        return stream
    }

    public func requestLatest() {
        guard session.delegate === self, session.activationState == .activated, session.isReachable,
              let token = transferGate.begin(at: now()) else { return }
        session.sendMessage(["requestLatest": true], replyHandler: { @Sendable [weak self] reply in
            let data = reply["snapshot"] as? Data
            DispatchQueue.main.async {
                guard let self, self.transferGate.complete(token) else { return }
                if let data { self.receive(data) }
            }
        }, errorHandler: { @Sendable [weak self] error in
            let code = (error as NSError).code
            DispatchQueue.main.async {
                guard let self, self.transferGate.complete(token) else { return }
                self.logFailure(code)
            }
        })
    }

    private var state: CompanionState {
        .init(snapshot: snapshot, isReachable: session.activationState == .activated && session.isReachable)
    }

    private func emit() {
        for observer in observers.values { observer.yield(state) }
    }

    private func receive(_ data: Data) {
        guard let incoming = try? codec.decode(data),
              codec.accepts(incoming, after: snapshot)
        else { return }
        snapshot = incoming
        store?.save(data)
        emit()
    }

    #endif

    #if os(iOS)
    public func publish(_ snapshot: CompanionSnapshot) {
        guard let data = try? codec.encode(snapshot) else { return }
        self.snapshot = snapshot
        latestData = data
        sendCurrent()
    }

    private func sendCurrent() {
        guard session.delegate === self, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let data = latestData, let snapshot else { return }
        let now = now()
        if lastContextDate.map({ now.timeIntervalSince($0) >= 5 }) ?? true
            || contextConnection != snapshot.bikeConnected || contextCharging != snapshot.isCharging {
            do {
                try session.updateApplicationContext(["snapshot": data])
                lastContextDate = now
                contextConnection = snapshot.bikeConnected
                contextCharging = snapshot.isCharging
            } catch { logFailure((error as NSError).code) }
        }
        guard session.isReachable,
              lastLiveDate.map({ now.timeIntervalSince($0) >= 1 }) ?? true,
              let token = transferGate.begin(at: now) else { return }
        lastLiveDate = now
        session.sendMessage(["snapshot": data], replyHandler: { @Sendable [weak self] _ in
            DispatchQueue.main.async { _ = self?.transferGate.complete(token) }
        }, errorHandler: { @Sendable [weak self] error in
            let code = (error as NSError).code
            DispatchQueue.main.async {
                guard let self, self.transferGate.complete(token) else { return }
                self.logFailure(code)
            }
        })
    }

    #endif

    private func logFailure(_ code: Int) {
        logger.debug("Companion delivery unavailable code=\(code, privacy: .public)")
    }
}

extension WatchConnectivityCompanionSession: WCSessionDelegate {
    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let code = (error as NSError?)?.code
        DispatchQueue.main.async { [weak self] in
            guard let self, self.session.delegate === self else { return }
            if let code { logFailure(code) }
            logger.info("Companion activated reachable=\(self.session.isReachable, privacy: .public)")
            #if os(watchOS)
            emit()
            #endif
            #if os(iOS)
            lastLiveDate = nil
            sendCurrent()
            #else
            if let data = self.session.receivedApplicationContext["snapshot"] as? Data { receive(data) }
            requestLatest()
            #endif
        }
    }

    nonisolated public func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.session.delegate === self else { return }
            transferGate.reset()
            logger.info("Companion reachability=\(self.session.isReachable, privacy: .public)")
            #if os(watchOS)
            emit()
            #endif
            #if os(iOS)
            lastLiveDate = nil
            sendCurrent()
            #else
            requestLatest()
            #endif
        }
    }

    nonisolated public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        #if os(watchOS)
        let data = context["snapshot"] as? Data
        DispatchQueue.main.async { [weak self] in if let data { self?.receive(data) } }
        #endif
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        #if os(watchOS)
        let data = message["snapshot"] as? Data
        #endif
        #if os(iOS)
        let requestsLatest = message["requestLatest"] as? Bool == true
        #endif
        let reply = CompanionReply(handler: replyHandler)
        DispatchQueue.main.async { [weak self] in
            guard let self else { reply.send([:]); return }
            #if os(watchOS)
            if let data { self.receive(data) }
            reply.send([:])
            #else
            if requestsLatest, let latestData {
                reply.send(["snapshot": latestData])
            } else {
                reply.send([:])
            }
            #endif
        }
    }

    #if os(iOS)
    nonisolated public func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in self?.transferGate.reset() }
    }
    nonisolated public func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.lastContextDate = nil
            self?.transferGate.reset()
            self?.session.activate()
        }
    }
    #endif
}

#if os(iOS)
extension WatchConnectivityCompanionSession: CompanionSnapshotPublishing {}
#else
extension WatchConnectivityCompanionSession: CompanionSession {}
#endif
