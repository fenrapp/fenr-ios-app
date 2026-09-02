#if DEBUG
enum RideDashboardPreviewFixtures {
    static let systemHealth = DashboardSystemHealthViewData(
        status: .healthy,
        statusText: "OK",
        statusDetail: "ALL SYSTEMS NORMAL",
        stateOfHealthText: "94%",
        stateOfHealthProgress: 0.94,
        cellDeltaText: "8 mV",
        dcBusVoltageText: "394.8 V",
        batteryTemperatureText: "29°C",
        inverterTemperatureText: "44°C"
    )
}
#endif
