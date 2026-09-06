import SwiftUI

#if DEBUG
#Preview("Maintenance history and due service") {
    NavigationStack {
        MaintenanceListContent(
            state: MaintenancePreviewData.list,
            onAdd: {}, onSelect: { _ in }, onDelete: { _ in }, onRefresh: {}
        )
        .navigationTitle(.maintenanceTitle)
    }
}

#Preview("Maintenance empty") {
    MaintenanceListContent(
        state: .init(status: .loaded),
        onAdd: {}, onSelect: { _ in }, onDelete: { _ in }, onRefresh: {}
    )
}

#Preview("Maintenance detail") {
    NavigationStack {
        MaintenanceDetailContent(detail: MaintenancePreviewData.detail, isMutating: false, onDelete: {})
            .navigationTitle(.maintenanceDetailTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Maintenance detail accessibility") {
    NavigationStack {
        MaintenanceDetailContent(detail: MaintenancePreviewData.detail, isMutating: true, onDelete: {})
            .navigationTitle(.maintenanceDetailTitle)
            .navigationBarTitleDisplayMode(.inline)
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Maintenance type selection") {
    NavigationStack {
        MaintenanceTypeSelectionView(options: MaintenancePreviewData.types, selection: .constant("gearOil"))
    }
}

#Preview("Maintenance currency selection") {
    NavigationStack {
        MaintenanceCurrencySelectionView(
            options: [.init(id: "EUR", title: "EUR - Euro"), .init(id: "USD", title: "USD - US Dollar")],
            selection: .constant("EUR")
        )
    }
}
#endif
