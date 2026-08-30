import SwiftUI

public struct NumericPINPad: View {
    @Binding private var pin: String
    private let digitCount: Int
    private let onComplete: (String) -> Void

    public init(
        pin: Binding<String>,
        digitCount: Int = 6,
        onComplete: @escaping (String) -> Void
    ) {
        precondition(digitCount > 0, "NumericPINPad digitCount must be greater than zero")
        _pin = pin
        self.digitCount = digitCount
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: DesignSpace.small) {
            HStack(spacing: DesignSpace.small) {
                ForEach(0 ..< digitCount, id: \.self) { index in
                    Circle()
                        .fill(
                            index < enteredDigitCount
                                ? DesignColor.primaryText
                                : DesignColor.secondaryText.opacity(Constants.emptyOpacity)
                        )
                        .frame(width: Constants.dotSize, height: Constants.dotSize)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PIN entry progress")
            .accessibilityValue("\(enteredDigitCount) of \(digitCount) digits entered")

            LazyVGrid(columns: columns, spacing: Constants.keySpacing) {
                ForEach(1 ... 9, id: \.self) { digit in
                    key(String(digit)) { append(String(digit)) }
                }
                Color.clear.accessibilityHidden(true)
                key("0") { append("0") }
                key(
                    "Delete",
                    systemImage: "delete.left",
                    isDisabled: pin.isEmpty,
                    accessibilityHint: "Deletes the last entered digit",
                    action: deleteLastDigit
                )
            }
            .frame(maxWidth: Constants.keypadWidth)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Constants.keySpacing), count: 3)
    }

    private var enteredDigitCount: Int {
        min(pin.count, digitCount)
    }

    private func append(_ digit: String) {
        guard pin.count < digitCount else { return }
        pin.append(digit)
        if pin.count == digitCount { onComplete(pin) }
    }

    private func deleteLastDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    private func key(
        _ title: String,
        systemImage: String? = nil,
        isDisabled: Bool = false,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage { Image(systemName: systemImage) } else { Text(title) }
            }
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: Constants.minimumTouchTargetSize)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .accessibilityLabel(title)
        .accessibilityHint(Text(accessibilityHint ?? ""))
    }

    private enum Constants {
        static let dotSize: CGFloat = 14
        static let emptyOpacity = 0.35
        static let keySpacing: CGFloat = 6
        static let minimumTouchTargetSize: CGFloat = 44
        static let keypadWidth: CGFloat = 280
    }
}

#Preview("4-digit PIN") {
    @Previewable @State var pin = ""

    NumericPINPad(pin: $pin, digitCount: 4) { _ in }
        .padding()
}

#Preview("6-digit PIN") {
    @Previewable @State var pin = "12"

    NumericPINPad(pin: $pin) { _ in }
        .padding()
}

#Preview("6-digit PIN - long Dynamic Type") {
    @Previewable @State var pin = "123"

    NumericPINPad(pin: $pin) { _ in }
        .padding()
        .environment(\.dynamicTypeSize, .accessibility3)
}
