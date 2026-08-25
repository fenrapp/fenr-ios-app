struct ChargeControlOperationState {
    private(set) var hasAttemptedPreparation = false
    private(set) var isPreparing = false
    private(set) var isWriting = false
    private(set) var pendingConfirmation: ChargeControlCommand?
    private(set) var optimisticPowerWatts: Int?
    private(set) var optimisticTargetPercent: Int?
    private(set) var connectionGeneration = 0
    private var queuedCommands: [ChargeControlCommand] = []

    var hasBlockingOperation: Bool { isWriting || pendingConfirmation != nil }

    var hasOptimisticSelection: Bool {
        optimisticPowerWatts != nil || optimisticTargetPercent != nil
    }

    var interaction: ChargeControlInteractionState {
        .init(
            optimisticPowerWatts: optimisticPowerWatts,
            pendingPowerConfirmationWatts: pendingPowerWatts,
            optimisticTargetPercent: optimisticTargetPercent,
            pendingTargetConfirmationPercent: pendingTargetPercent
        )
    }

    mutating func select(_ command: ChargeControlCommand) {
        removeQueuedCommand(controlling: command)
        switch command {
        case .power(let watts): optimisticPowerWatts = watts
        case .target(let percent): optimisticTargetPercent = percent
        }
    }

    mutating func beginPreparation() -> Int? {
        guard !hasAttemptedPreparation, !isPreparing else { return nil }
        hasAttemptedPreparation = true
        isPreparing = true
        return connectionGeneration
    }

    mutating func finishPreparation() { isPreparing = false }

    mutating func beginWrite() -> Int {
        isWriting = true
        return connectionGeneration
    }

    mutating func finishWrite() { isWriting = false }

    mutating func awaitConfirmation(of command: ChargeControlCommand) {
        pendingConfirmation = command
    }

    mutating func clearPendingConfirmation(_ command: ChargeControlCommand) -> Bool {
        guard pendingConfirmation == command else { return false }
        pendingConfirmation = nil
        clearOptimisticValue(matching: command)
        return true
    }

    mutating func clearOptimisticValue(matching command: ChargeControlCommand) {
        switch command {
        case .power(let watts) where optimisticPowerWatts == watts:
            optimisticPowerWatts = nil
        case .target(let percent) where optimisticTargetPercent == percent:
            optimisticTargetPercent = nil
        default:
            break
        }
    }

    func hasOptimisticValue(controlling command: ChargeControlCommand) -> Bool {
        switch command {
        case .power: optimisticPowerWatts != nil
        case .target: optimisticTargetPercent != nil
        }
    }

    mutating func enqueue(_ command: ChargeControlCommand) {
        removeQueuedCommand(controlling: command)
        queuedCommands.append(command)
    }

    mutating func nextQueuedCommand() -> ChargeControlCommand? {
        guard !hasBlockingOperation, !queuedCommands.isEmpty else { return nil }
        return queuedCommands.removeFirst()
    }

    func belongsToCurrentConnection(_ generation: Int) -> Bool {
        generation == connectionGeneration
    }

    mutating func reset() {
        connectionGeneration += 1
        hasAttemptedPreparation = false
        isPreparing = false
        isWriting = false
        pendingConfirmation = nil
        optimisticPowerWatts = nil
        optimisticTargetPercent = nil
        queuedCommands.removeAll()
    }

    private var pendingPowerWatts: Int? {
        guard case .power(let watts) = pendingConfirmation else { return nil }
        return watts
    }

    private var pendingTargetPercent: Int? {
        guard case .target(let percent) = pendingConfirmation else { return nil }
        return percent
    }

    private mutating func removeQueuedCommand(controlling command: ChargeControlCommand) {
        queuedCommands.removeAll { $0.controlsSameSetting(as: command) }
    }
}
