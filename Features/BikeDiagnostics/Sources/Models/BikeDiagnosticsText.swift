import Foundation

public enum BikeDiagnosticsText {
    public static let placeholder = "--"
    public static let placeholderPIN = "000000"
    public static var idle: String { BikeDiagnosticsL10n.text(.bikeDiagnosticsConnectionIdle) }
    public static var enterVINToConnect: String { BikeDiagnosticsL10n.text(.bikeDiagnosticsEnterVINToConnect) }
    public static var emptyRSSI: String { BikeDiagnosticsL10n.text(.bikeDiagnosticsEmptyRSSI) }
    public static var noPeripheral: String { BikeDiagnosticsL10n.text(.bikeDiagnosticsNoPeripheral) }
    public static var unknown: String { BikeDiagnosticsL10n.text(.bikeDiagnosticsUnknown) }
}
