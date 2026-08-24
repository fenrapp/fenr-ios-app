import DesignSystem
import SwiftUI

struct HeaderView: View {
    let vin: String
    let pin: String
    let isVINEditingEnabled: Bool
    let isConnectEnabled: Bool
    let isDisconnectEnabled: Bool
    let isPairRetryEnabled: Bool
    let isBatteryHealthEnabled: Bool
    let onVINChange: (String) -> Void
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let onPairRetry: () -> Void
    let onBatteryHealth: () -> Void

    @FocusState private var isVINFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.verticalSpacing) {
            HStack(alignment: .bottom, spacing: Constants.horizontalSpacing) {
                pinView
                Spacer(minLength: Constants.minimumSpacerLength)
                buttonRow
            }

            vinField
        }
        .padding(Constants.containerPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .fill(DesignColor.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
        )
    }

    private var vinField: some View {
        VStack(alignment: .leading, spacing: Constants.labelSpacing) {
            Text("VIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("FENRTEST000000002", text: Binding(get: { vin }, set: { value in onVINChange(value) }))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
                .focused($isVINFocused)
                .font(.system(.callout, design: .monospaced))
                .textFieldStyle(.plain)
                .disabled(!isVINEditingEnabled)
                .padding(Constants.inputPadding)
                .background(
                    DesignColor.controlSurface,
                    in: RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                        .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
                )
                .onSubmit {
                    isVINFocused = false
                }
        }
        .frame(maxWidth: .infinity)
    }

    private var pinView: some View {
        VStack(alignment: .leading, spacing: Constants.labelSpacing) {
            Text("PIN")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(pin)
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .lineLimit(Constants.lineLimit)
                .minimumScaleFactor(Constants.minimumScaleFactor)
                .padding(Constants.inputPadding)
                .frame(width: Constants.pinWidth, alignment: .leading)
                .background(
                    DesignColor.accent.opacity(Constants.pinBackgroundOpacity),
                    in: RoundedRectangle(cornerRadius: Constants.cornerRadius, style: .continuous)
                )
        }
    }

    private var buttonRow: some View {
        HStack(spacing: Constants.buttonSpacing) {
            Button(action: connectTapped) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(connectButtonForeground)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .background(connectButtonBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!isConnectEnabled)
            .accessibilityLabel("Connect")

            Button(action: disconnectTapped) {
                Image(systemName: "xmark.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .background(disconnectButtonBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!isDisconnectEnabled)
            .accessibilityLabel("Disconnect")

            Button(action: pairRetryTapped) {
                Image(systemName: "key.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(pairRetryButtonForeground)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .background(pairRetryButtonBackground, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
            }
            .buttonStyle(.plain)
            .disabled(!isPairRetryEnabled)
            .accessibilityLabel("Retry security")

            Button(action: onBatteryHealth) {
                Image(systemName: "battery.100percent")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(batteryHealthButtonForeground)
                    .frame(width: Constants.buttonSize, height: Constants.buttonSize)
                    .background(
                        batteryHealthButtonBackground,
                        in: RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isBatteryHealthEnabled)
            .accessibilityLabel("Battery Health")
        }
        .labelStyle(.iconOnly)
    }

    private func connectTapped() {
        isVINFocused = false
        onConnect()
    }

    private func disconnectTapped() {
        isVINFocused = false
        onDisconnect()
    }

    private func pairRetryTapped() {
        isVINFocused = false
        onPairRetry()
    }

    private var connectButtonBackground: Color {
        isConnectEnabled ? DesignColor.accent : DesignColor.disabledControl
    }

    private var connectButtonForeground: Color {
        isConnectEnabled ? .white : .secondary
    }

    private var disconnectButtonBackground: Color {
        DesignColor.disabledControl
    }

    private var pairRetryButtonBackground: Color {
        isPairRetryEnabled
            ? DesignColor.warning.opacity(Constants.pairRetryBackgroundOpacity)
            : DesignColor.disabledControl
    }

    private var pairRetryButtonForeground: Color {
        isPairRetryEnabled ? DesignColor.warning : .secondary
    }

    private var batteryHealthButtonBackground: Color {
        isBatteryHealthEnabled
            ? DesignColor.informational.opacity(Constants.batteryHealthBackgroundOpacity)
            : DesignColor.disabledControl
    }

    private var batteryHealthButtonForeground: Color {
        isBatteryHealthEnabled ? DesignColor.informational : .secondary
    }

    private enum Constants {
        static let horizontalSpacing = DesignSpace.small
        static let verticalSpacing = DesignSpace.extraSmall
        static let buttonSpacing = DesignSpace.extraSmall
        static let labelSpacing = DesignSpace.extraExtraSmall
        static let inputPadding = DesignSpace.extraSmall
        static let containerPadding = DesignSpace.small
        static let cornerRadius = DesignRadius.small
        static let borderWidth: CGFloat = 1
        static let minimumSpacerLength = DesignSpace.extraSmall
        static let pinWidth: CGFloat = 88
        static let buttonSize: CGFloat = 40
        static let lineLimit = 1
        static let minimumScaleFactor = 0.75
        static let pinBackgroundOpacity = 0.14
        static let pairRetryBackgroundOpacity = 0.2
        static let batteryHealthBackgroundOpacity = 0.2
    }
}

#Preview("Header") {
    HeaderView(
        vin: "FENRTEST000000002",
        pin: "003421",
        isVINEditingEnabled: true,
        isConnectEnabled: true,
        isDisconnectEnabled: true,
        isPairRetryEnabled: true,
        isBatteryHealthEnabled: true,
        onVINChange: { _ in },
        onConnect: {},
        onDisconnect: {},
        onPairRetry: {},
        onBatteryHealth: {}
    )
    .padding()
}
