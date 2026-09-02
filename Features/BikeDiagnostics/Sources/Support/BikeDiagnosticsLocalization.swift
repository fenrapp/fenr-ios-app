import Foundation

enum BikeDiagnosticsL10n {
    static func text(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }
}
