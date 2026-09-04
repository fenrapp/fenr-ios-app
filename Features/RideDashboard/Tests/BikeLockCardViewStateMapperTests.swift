@testable import RideDashboard
import SettingsDomain
import Testing

@Suite("Bike Lock card view-state mapper")
struct BikeLockCardViewStateMapperTests {
    private let mapper = BikeLockCardViewStateMapper()

    @Test("Maps the compatibility-pending state")
    func mapsCompatibilityPendingState() {
        let state = mapper.map(input())

        #expect(state == BikeLockCardViewState(
            isAvailable: false,
            isLocked: false,
            isWorking: false,
            isActionEnabled: false,
            isConfigured: false,
            title: "Bike Lock",
            statusText: "Unavailable",
            actionTitle: "Set Up",
            detailText: "Bike Lock requires VCU PIC 1.6.29 or newer."
        ))
    }

    @Test("Maps an available unlocked bike")
    func mapsUnlockedBike() {
        let state = mapper.map(input(
            firmware: "1.6.29",
            isReceivingTelemetry: true,
            isVehicleStationary: true,
            securityMode: .withoutPIN
        ))

        #expect(state.isAvailable)
        #expect(!state.isLocked)
        #expect(state.isActionEnabled)
        #expect(state.isConfigured)
        #expect(state.statusText == "Unlocked")
        #expect(state.actionTitle == "Lock")
        #expect(state.detailText == "VCU PIC 1.6.29")
    }

    @Test("Does not invent a lock state before control confirmation")
    func mapsUnconfirmedLockState() {
        let state = mapper.map(input(
            firmware: "1.6.29",
            isControlPrepared: false,
            isLocked: true,
            isReceivingTelemetry: true
        ))

        #expect(state.isAvailable)
        #expect(!state.isLocked)
        #expect(state.statusText == "Status not confirmed")
        #expect(!state.isActionEnabled)
    }

    @Test("Maps an available locked bike")
    func mapsLockedBike() {
        let state = mapper.map(input(
            firmware: "1.10.1",
            isLocked: true,
            isReceivingTelemetry: true,
            isVehicleStationary: true,
            securityMode: .pin
        ))

        #expect(state.isLocked)
        #expect(state.statusText == "Locked")
        #expect(state.actionTitle == "Unlock")
        #expect(state.detailText == "VCU PIC 1.10.1")
    }

    @Test("Enables the action only for available stationary live telemetry while idle")
    func mapsActionAvailabilityExpression() {
        let enabled = mapper.map(input(
            firmware: "1.6.29",
            isReceivingTelemetry: true,
            isVehicleStationary: true
        ))
        let unavailable = mapper.map(input(
            isReceivingTelemetry: true,
            isVehicleStationary: true
        ))
        let disconnected = mapper.map(input(
            firmware: "1.6.29",
            isVehicleStationary: true
        ))
        let moving = mapper.map(input(
            firmware: "1.6.29",
            isReceivingTelemetry: true
        ))
        let working = mapper.map(input(
            firmware: "1.6.29",
            isWorking: true,
            isReceivingTelemetry: true,
            isVehicleStationary: true
        ))

        #expect(enabled.isActionEnabled)
        #expect(!unavailable.isActionEnabled)
        #expect(!disconnected.isActionEnabled)
        #expect(!moving.isActionEnabled)
        #expect(working.isWorking)
        #expect(!working.isActionEnabled)
    }

    @Test("Preserves, presents, and dismisses sheets")
    func mapsSheetUpdates() {
        let preserved = mapper.map(input(currentSheet: .enterPIN))
        let presented = mapper.map(input(
            sheetUpdate: .present(.setup),
            currentSheet: .enterPIN
        ))
        let dismissed = mapper.map(input(
            sheetUpdate: .dismiss,
            currentSheet: .setup
        ))

        #expect(preserved.sheet == .enterPIN)
        #expect(presented.sheet == .setup)
        #expect(dismissed.sheet == nil)
    }

    @Test("Maps an operation error")
    func mapsError() {
        let state = mapper.map(input(error: "Unable to update Bike Lock"))

        #expect(state.errorText == "Unable to update Bike Lock")
    }

    private func input(
        firmware: String? = nil,
        isFirmwareCompatible: Bool? = nil,
        isControlPrepared: Bool? = nil,
        isLocked: Bool = false,
        isWorking: Bool = false,
        isReceivingTelemetry: Bool = false,
        isVehicleStationary: Bool = false,
        securityMode: BikeLockSecurityMode = .notConfigured,
        error: String? = nil,
        sheetUpdate: BikeLockSheetUpdate = .preserve,
        currentSheet: BikeLockCardViewState.Sheet? = nil
    ) -> BikeLockCardMappingInput {
        BikeLockCardMappingInput(
            firmware: firmware,
            isFirmwareCompatible: isFirmwareCompatible ?? (firmware != nil),
            isControlPrepared: isControlPrepared ?? (firmware != nil),
            isLocked: isLocked,
            hasConfirmedLockState: isControlPrepared ?? (firmware != nil),
            isWorking: isWorking,
            isReceivingTelemetry: isReceivingTelemetry,
            isVehicleStationary: isVehicleStationary,
            securityMode: securityMode,
            error: error,
            sheetUpdate: sheetUpdate,
            currentSheet: currentSheet
        )
    }
}
