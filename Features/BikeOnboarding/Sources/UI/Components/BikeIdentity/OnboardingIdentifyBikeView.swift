import BikeDomain
import DesignSystem
import SwiftUI

struct OnboardingIdentifyBikeView: View {
    let vin: String
    let discoveredBikes: [DiscoveredBike]
    let isDiscoveringBikes: Bool
    let onVINChange: (String) -> Void
    let onSelectBike: (DiscoveredBike) -> Void
    let onStartDiscovery: () -> Void
    let onScanVIN: () -> Void

    var body: some View {
        VStack(spacing: DesignSpace.medium) {
            OnboardingMaterialPanel {
                VStack(alignment: .leading, spacing: DesignSpace.small) {
                    HStack {
                        Label("Nearby bikes", systemImage: "dot.radiowaves.left.and.right")
                            .font(.headline)
                        Spacer()
                        Button(action: onStartDiscovery) {
                            if isDiscoveringBikes {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isDiscoveringBikes)
                        .accessibilityLabel("Scan again")
                    }

                    discoveryContent
                }
            }

            HStack(spacing: DesignSpace.small) {
                TextField(
                    "Enter 17-character VIN",
                    text: Binding(
                        get: { vin },
                        set: { updatedVIN in onVINChange(updatedVIN) }
                    )
                )
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .keyboardType(.asciiCapable)
                    .textContentType(.oneTimeCode)
                    .font(.body.monospaced())
                    .padding(.horizontal, DesignSpace.small)
                    .frame(minHeight: Constants.textFieldHeight)
                    .background(
                        .thinMaterial,
                        in: RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                            .stroke(DesignColor.border, lineWidth: Constants.borderWidth)
                    )

                Button(action: onScanVIN) {
                    Image(systemName: "viewfinder")
                        .frame(width: Constants.scanButtonSize, height: Constants.scanButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityLabel("Scan VIN")
            }

            Text("Use the bike label, registration, or a nearby discovered bike.")
                .font(.footnote)
                .foregroundStyle(DesignColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var discoveryContent: some View {
        if discoveredBikes.isEmpty {
            HStack(spacing: DesignSpace.small) {
                if isDiscoveringBikes {
                    ProgressView()
                } else {
                    Image(systemName: "motorcycle")
                        .foregroundStyle(DesignColor.secondaryText)
                }
                Text(isDiscoveringBikes ? "Scanning for your bike..." : "No nearby bikes yet.")
                    .font(.subheadline)
                    .foregroundStyle(DesignColor.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignSpace.extraSmall)
        } else {
            VStack(spacing: DesignSpace.extraSmall) {
                ForEach(discoveredBikes) { bike in
                    Button(
                        action: { onSelectBike(bike) },
                        label: {
                            HStack(spacing: DesignSpace.small) {
                                Image(systemName: "motorcycle")
                                    .foregroundStyle(DesignColor.accent)
                                VStack(alignment: .leading, spacing: DesignSpace.extraExtraSmall) {
                                    Text(bike.vin)
                                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                    Text(signalLabel(for: bike.rssi))
                                        .font(.caption)
                                        .foregroundStyle(DesignColor.secondaryText)
                                }
                                Spacer()
                                Image(systemName: selectedBikeIcon(for: bike))
                                    .foregroundStyle(selectedBikeTint(for: bike))
                            }
                            .contentShape(Rectangle())
                        }
                    )
                    .buttonStyle(.plain)
                    .padding(DesignSpace.small)
                    .background(
                        bikeBackground(for: bike),
                        in: RoundedRectangle(cornerRadius: DesignRadius.medium, style: .continuous)
                    )
                }
            }
        }
    }

    private func signalLabel(for rssi: Int) -> String {
        switch rssi {
        case (-55)...: "Strong signal"
        case -70 ..< -55: "Good signal"
        default: "Weak signal"
        }
    }

    private func bikeBackground(for bike: DiscoveredBike) -> Color {
        vin == bike.vin ? DesignColor.accent.opacity(Constants.selectedBikeOpacity) : DesignColor.controlSurface
    }

    private func selectedBikeIcon(for bike: DiscoveredBike) -> String {
        vin == bike.vin ? "checkmark.circle.fill" : "chevron.right"
    }

    private func selectedBikeTint(for bike: DiscoveredBike) -> Color {
        vin == bike.vin ? DesignColor.accent : DesignColor.secondaryText
    }
}

private enum Constants {
    static let borderWidth: CGFloat = 1
    static let scanButtonSize: CGFloat = 24
    static let selectedBikeOpacity = 0.16
    static let textFieldHeight: CGFloat = 52
}
