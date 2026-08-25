import BikeDomain

public struct ChargeControlUseCases: Sendable {
    public let prepare: PrepareChargePowerControlUseCase
    public let setPowerLimit: SetChargePowerLimitUseCase
    public let setTarget: SetChargeTargetUseCase

    public init(
        prepare: PrepareChargePowerControlUseCase,
        setPowerLimit: SetChargePowerLimitUseCase,
        setTarget: SetChargeTargetUseCase
    ) {
        self.prepare = prepare
        self.setPowerLimit = setPowerLimit
        self.setTarget = setTarget
    }
}
