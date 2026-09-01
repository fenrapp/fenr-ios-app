import BikeDomain

extension PowerModeSettingsViewModel {
    func prepareControlIfPossible() {
        guard canPrepareSelectedMap else { return }

        let mapIndex = selectedMapIndex
        let shouldPrepareTraction = telemetry.powerModeConfigurations[mapIndex]?
            .hasTractionControlConfiguration == true
        attemptedPreparationMapIndex = mapIndex
        isPreparingControl = true
        controlError = nil
        controlMessage = nil
        controlGeneration += 1
        let generation = controlGeneration
        let preparePowerModeControl = useCases.preparePowerModeControl
        render()

        controlTask = Task { [weak self] in
            do {
                try await preparePowerModeControl.execute(mapIndex: mapIndex)
                guard !Task.isCancelled else { return }
                await self?.finishBasePreparation(
                    mapIndex: mapIndex,
                    generation: generation,
                    shouldPrepareTraction: shouldPrepareTraction
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.finishControlPreparation(
                    mapIndex: mapIndex,
                    generation: generation,
                    tractionReady: false,
                    error: "Map controls unavailable: \(error.localizedDescription)"
                )
            }
        }
    }

    func resetControlState() {
        controlGeneration += 1
        controlTask?.cancel()
        controlTask = nil
        preparedBaseMapIndex = nil
        preparedTractionMapIndex = nil
        attemptedPreparationMapIndex = nil
        isPreparingControl = false
        isApplyingControl = false
        controlMessage = nil
        controlError = nil
    }
}

private extension PowerModeSettingsViewModel {
    var canPrepareSelectedMap: Bool {
        !isRefreshing
            && controlTask == nil
            && preparedBaseMapIndex != selectedMapIndex
            && attemptedPreparationMapIndex != selectedMapIndex
            && isAuthenticated(connection.state)
            && telemetry.powerModeConfigurations[selectedMapIndex]?.hasBaseConfiguration == true
    }

    func finishBasePreparation(
        mapIndex: Int,
        generation: Int,
        shouldPrepareTraction: Bool
    ) async {
        guard generation == controlGeneration,
              mapIndex == selectedMapIndex
        else {
            return
        }
        preparedBaseMapIndex = mapIndex
        await prepareTractionControlIfAvailable(
            mapIndex: mapIndex,
            generation: generation,
            isAvailable: shouldPrepareTraction
        )
    }

    func prepareTractionControlIfAvailable(
        mapIndex: Int,
        generation: Int,
        isAvailable: Bool
    ) async {
        guard isAvailable else {
            finishControlPreparation(
                mapIndex: mapIndex,
                generation: generation,
                tractionReady: false,
                error: nil
            )
            return
        }
        do {
            try await useCases.prepareTractionControl.execute(mapIndex: mapIndex)
            guard !Task.isCancelled else { return }
            finishControlPreparation(
                mapIndex: mapIndex,
                generation: generation,
                tractionReady: true,
                error: nil
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            finishControlPreparation(
                mapIndex: mapIndex,
                generation: generation,
                tractionReady: false,
                error: "TC controls unavailable: \(error.localizedDescription)"
            )
        }
    }

    func finishControlPreparation(
        mapIndex: Int,
        generation: Int,
        tractionReady: Bool,
        error: String?
    ) {
        guard generation == controlGeneration,
              mapIndex == selectedMapIndex
        else {
            return
        }
        controlTask = nil
        isPreparingControl = false
        controlError = error
        if preparedBaseMapIndex == mapIndex {
            preparedTractionMapIndex = tractionReady ? mapIndex : nil
            if error == nil {
                controlMessage = tractionReady
                    ? "All map controls ready"
                    : "Power and regeneration controls ready"
            }
        }
        render()
    }
}
