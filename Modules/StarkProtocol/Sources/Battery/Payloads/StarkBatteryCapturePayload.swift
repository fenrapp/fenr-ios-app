import Foundation

/// Raw dataset observed from a protected Battery Health characteristic.
/// Numeric layouts are intentionally decoded only after a real payload is validated per firmware family.
public struct StarkBatteryCapturePayload: StarkPayload {
    public let bytes: Data

    public init(bytes: Data) {
        self.bytes = bytes
    }
}
