import SwiftUI

struct BikeLockPINPad: View {
    @Binding var pin: String

    let onComplete: (String) -> Void

    var body: some View {
        VStack(spacing: Constants.contentSpacing) {
            HStack(spacing: Constants.dotSpacing) {
                ForEach(0 ..< Constants.pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < pin.count ? Color.primary : Color.secondary.opacity(Constants.emptyOpacity))
                        .frame(width: Constants.dotSize, height: Constants.dotSize)
                }
            }
            .accessibilityLabel("\(pin.count) of 6 digits entered")

            LazyVGrid(columns: columns, spacing: Constants.keySpacing) {
                ForEach(1 ... 9, id: \.self) { digit in
                    key(String(digit)) { append(String(digit)) }
                }
                Color.clear
                    .accessibilityHidden(true)
                key("0") { append("0") }
                key("Delete", systemImage: "delete.left", action: deleteLastDigit)
            }
            .frame(maxWidth: Constants.keypadWidth)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Constants.keySpacing), count: 3)
    }

    private func append(_ digit: String) {
        guard pin.count < Constants.pinLength else { return }
        pin.append(digit)
        if pin.count == Constants.pinLength {
            onComplete(pin)
        }
    }

    private func deleteLastDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }

    private func key(
        _ title: String,
        systemImage: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                } else {
                    Text(title)
                }
            }
            .font(.title2.weight(.medium))
            .frame(maxWidth: .infinity, minHeight: Constants.keyHeight)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(title)
    }

    private enum Constants {
        static let pinLength = 6
        static let contentSpacing: CGFloat = 12
        static let dotSpacing: CGFloat = 12
        static let dotSize: CGFloat = 14
        static let emptyOpacity = 0.35
        static let keySpacing: CGFloat = 6
        static let keyHeight: CGFloat = 36
        static let keypadWidth: CGFloat = 280
    }
}
