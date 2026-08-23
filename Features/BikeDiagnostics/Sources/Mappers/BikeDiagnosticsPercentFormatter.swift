import Foundation

@MainActor
public struct BikeDiagnosticsPercentFormatter {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    func string(fromPercent value: Int) -> String {
        (Double(value) / Constants.divisor).formatted(
            .percent.precision(.fractionLength(Constants.fractionDigits)).locale(locale)
        )
    }

    private enum Constants {
        static let divisor = 100.0
        static let fractionDigits = 0
    }
}
