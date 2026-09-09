import DesignSystem
import SwiftUI

struct PowerCurveValueInput: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let point: PowerCurvePointViewData
    let unit: String
    let commit: (Double) -> Void
    @State private var input = ""
    @FocusState private var isFocused: Bool

    private var numberFormat: FloatingPointFormatStyle<Double> {
        .number.locale(locale).grouping(.never).precision(.fractionLength(0 ... Constants.fractionDigits))
    }

    private var initialInput: String { point.value.formatted(numberFormat) }

    private var validValue: Double? {
        guard let value = try? Double(input, format: numberFormat, lenient: false),
              value.isFinite, 0 ... point.maximum ~= value else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DesignSpace.small) {
                        TextField(String(localized: .powerCurvePointValue), text: $input)
                            .keyboardType(.decimalPad)
                            .focused($isFocused)
                            .monospacedDigit()
                            .accessibilityLabel(.powerCurvePointAccessibility(point.rpmText))
                            .onSubmit(save)
                        Text(verbatim: unit)
                            .foregroundStyle(DesignColor.secondaryText)
                    }
                } header: {
                    Text(.powerCurvePointAccessibility(point.rpmText))
                } footer: {
                    Text(.powerCurveInputRange(point.maximum.formatted(numberFormat), unit))
                }
                Section {
                    Text(.powerCurveInputDraftHint)
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
                    Button(.powerCurveSetPoint, action: save)
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
        guard let value = validValue else { return }
        if input != initialInput, value != point.value { commit(value) }
        dismiss()
    }

    private enum Constants {
        static let fractionDigits = 1
    }
}
