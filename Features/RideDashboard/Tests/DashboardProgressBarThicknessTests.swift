import Foundation
@testable import RideDashboard
import SettingsDomain
import Testing

struct DashboardProgressBarThicknessTests {
    @Test("Thickness changes invalidate cached presentation and survive continuity updates",
          arguments: DashboardProgressBarThickness.allCases)
    func mapsThickness(_ thickness: DashboardProgressBarThickness) {
        let original = RideDashboardMappingInput(snapshot: DashboardMappingSnapshots.ride())
        let updated = RideDashboardMappingInput(snapshot: DashboardMappingSnapshots.ride(settings: .init(
            dashboardProgressBarThickness: thickness, measurementSystem: .metric
        )))
        #expect((original == updated) == (thickness == .regular))
        let mapper = RideDashboardMapperFactory.makeRideMapper(locale: Locale(identifier: "en_GB"))
        let state = updated.map(using: mapper, measurementMapper: mapper.measurementMapper(for: .metric))
        let expected = DashboardProgressBarMapper().layout(for: thickness)
        #expect(state.progressBarLayout == expected)
        #expect(state.withContinuity(.cold).progressBarLayout == expected)
        #expect(state.waitingForStableTelemetry().progressBarLayout == expected)
        if thickness != .regular {
            #expect(state.progressBarLayout.trackHeight > DashboardProgressBarLayout.regular.trackHeight)
            #expect(state.progressBarLayout.energyHeight > DashboardProgressBarLayout.regular.energyHeight)
        }
    }
}
