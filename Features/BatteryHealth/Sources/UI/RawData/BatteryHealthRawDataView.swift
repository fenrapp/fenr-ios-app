import DesignSystem
import SwiftUI
import UIKit

struct BatteryHealthRawDataView: View {
    let state: BatteryHealthRawDataViewData
    let exportText: String

    var body: some View {
        List {
            Section(BatteryHealthText.actions) {
                ListActionButton(
                    title: BatteryHealthText.copyAll,
                    systemImage: "doc.on.doc",
                    tint: DesignColor.informational,
                    isEnabled: !exportText.isEmpty,
                    action: copyAll
                )

                ListActionShareLink(
                    item: exportText,
                    title: BatteryHealthText.export,
                    systemImage: "square.and.arrow.up",
                    tint: .indigo,
                    isEnabled: !exportText.isEmpty
                )
            }

            Section(BatteryHealthText.rawFlags) {
                BatteryHealthMetricRows(metrics: state.rawFlags)
            }

            ForEach(state.datasets) { dataset in
                Section(dataset.title) {
                    LabeledContent(BatteryHealthText.state, value: dataset.status.text)
                    if let timestamp = dataset.timestamp {
                        LabeledContent(BatteryHealthText.captured, value: timestamp)
                    }
                    if let byteCount = dataset.byteCount {
                        LabeledContent(BatteryHealthText.bytes, value: byteCount.formatted())
                    }
                    if let hex = dataset.hex {
                        Text(hex)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        ListActionButton(
                            title: BatteryHealthText.copyHexadecimal,
                            systemImage: "doc.on.doc",
                            tint: DesignColor.informational,
                            action: { UIPasteboard.general.string = hex }
                        )
                    }
                }
            }

            Section(BatteryHealthText.chargeOperationAudit) {
                if state.chargeAuditLines.isEmpty {
                    Text(BatteryHealthText.noChargeOperations)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(state.chargeAuditLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func copyAll() {
        UIPasteboard.general.string = exportText
    }
}
