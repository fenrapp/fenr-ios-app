import Foundation

public struct MaintenanceNumberParser: Sendable {
    private let locale: Locale

    public init(locale: Locale) {
        self.locale = locale
    }

    public func parse(_ text: String) -> Double? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty,
              let number = try? FloatingPointFormatStyle<Double>.number
              .locale(locale)
              .parseStrategy
              .parse(value),
              number.isFinite else { return nil }
        return number
    }
}
