import SwiftUI

struct TelemetryActionRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Open telemetry", systemImage: "waveform.path.ecg")
        }
    }
}

#Preview("Telemetry action") {
    Form {
        TelemetryActionRow(action: {})
    }
}
