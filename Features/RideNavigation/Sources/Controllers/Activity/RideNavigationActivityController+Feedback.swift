import Foundation

@MainActor
extension RideNavigationActivityController {
    func synchronizeClock() {
        guard isStarted, presentationMode == .fullScreen, snapshot.hasActiveSession else {
            stopClock()
            return
        }
        guard clockTask == nil else { return }
        clockGeneration &+= 1
        let generation = clockGeneration
        let lifecycle = lifecycleGeneration
        let sleep = dependencies.timing.sleep
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await sleep(.seconds(1)) } catch { return }
                guard !Task.isCancelled, let self, isStarted,
                      clockGeneration == generation, lifecycleGeneration == lifecycle else { return }
                publish()
            }
        }
    }

    func stopClock() {
        clockGeneration &+= 1
        clockTask?.cancel()
        clockTask = nil
    }

    func toggleVoice() {
        isVoiceMuted.toggle()
        if isVoiceMuted {
            voiceAnnouncementTask?.cancel()
            voiceAnnouncementTask = nil
        }
        publish()
    }

    func announce(_ text: String) {
        guard !isVoiceMuted else { return }
        voiceAnnouncementTask?.cancel()
        let guidance = dependencies.guidance
        voiceAnnouncementTask = Task {
            guard !Task.isCancelled else { return }
            await guidance.announce(text)
        }
    }

    func notifySuccess() {
        replaceFeedbackTask { [guidance = dependencies.guidance] in await guidance.notifySuccess() }
    }

    func notifyWarning() {
        replaceFeedbackTask { [guidance = dependencies.guidance] in await guidance.notifyWarning() }
    }

    func replaceFeedbackTask(_ operation: @escaping @Sendable () async -> Void) {
        feedbackTask?.cancel()
        feedbackTask = Task {
            guard !Task.isCancelled else { return }
            await operation()
        }
    }
}
