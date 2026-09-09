import DesignSystem
import SwiftUI

struct PowerModeValueInput: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let title: String
    let value: Double
    let bounds: ClosedRange<Double>
    let wholeNumbersOnly: Bool
    let hint: LocalizedStringResource
    let confirmationTitle: LocalizedStringResource
    let unit: String
    let commit: (Double) -> Void
    @State private var input = ""
    @FocusState private var isFocused: Bool

    private var numberFormat: FloatingPointFormatStyle<Double> {
        .number.locale(locale).grouping(.never)
            .precision(.fractionLength(0 ... (wholeNumbersOnly ? 0 : Constants.fractionDigits)))
    }

    private var initialInput: String { value.formatted(numberFormat) }

    private var validValue: Double? {
        guard let value = try? Double(input, format: numberFormat, lenient: false),
              value.isFinite, bounds.contains(value),
              !wholeNumbersOnly || value.rounded() == value else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignSpace.small) {
                        TextField(String(localized: .powerCurvePointValue), text: $input)
                            .keyboardType(wholeNumbersOnly ? .numberPad : .decimalPad)
                            .focused($isFocused)
                            .monospacedDigit()
                            .accessibilityLabel(Text(verbatim: title))
                            .accessibilityIdentifier("powerModes.exactValue.input")
                            .onSubmit(save)
                        Text(verbatim: unit)
                            .foregroundStyle(DesignColor.secondaryText)
                    }
                } header: {
                    Text(verbatim: title)
                } footer: {
                    Text(.powerModeSettingsRangeAccessibility(
                        measurement(bounds.lowerBound), measurement(bounds.upperBound)
                    ))
                }
                Section {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(DesignColor.secondaryText)
                }
            }
            .navigationTitle(Text(.powerCurveExactValue))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.powerCurveCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmationTitle, action: save)
                        .disabled(validValue == nil)
                }
            }
            .onAppear {
                input = initialInput
                isFocused = true
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard let selectedValue = validValue else { return }
        if input != initialInput, selectedValue != value { commit(selectedValue) }
        dismiss()
    }

    private func measurement(_ value: Double) -> String {
        String(localized: .powerModeSettingsMeasurement(value.formatted(numberFormat), unit))
    }

    private enum Constants {
        static let fractionDigits = 1
    }
}
