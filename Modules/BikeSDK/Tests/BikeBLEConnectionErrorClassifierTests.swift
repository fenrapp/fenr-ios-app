@testable import BikeSDK
import CoreBluetooth
import Foundation
import Testing

@Suite("BLE connection error classifier")
struct BikeBLEConnectionErrorClassifierTests {
    private let classifier = BikeBLEConnectionErrorClassifier()

    @Test("Recognizes pairing information removed in the CoreBluetooth domain")
    func recognizesCoreBluetoothPairingReset() {
        let error = NSError(
            domain: CBErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue
        )

        #expect(classifier.requiresPairingReset(error))
    }

    @Test("Does not confuse an ATT error that shares the numeric code")
    func ignoresATTCodeCollision() {
        let error = NSError(
            domain: CBATTErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue
        )

        #expect(!classifier.requiresPairingReset(error))
    }

    @Test("Recognizes pairing reset text from a system domain")
    func recognizesPairingResetDescription() {
        let error = NSError(
            domain: CBATTErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Peer removed pairing information"]
        )

        #expect(classifier.requiresPairingReset(error))
    }

    @Test("Recognizes a pairing reset wrapped by another system error")
    func recognizesUnderlyingPairingReset() {
        let underlyingError = NSError(
            domain: CBErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue
        )
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: 1,
            userInfo: [NSUnderlyingErrorKey: underlyingError]
        )

        #expect(classifier.requiresPairingReset(error))
    }

    @Test("Keeps normal connection failures retryable")
    func ignoresRetryableConnectionFailure() {
        let error = NSError(
            domain: CBErrorDomain,
            code: CBError.connectionTimeout.rawValue
        )

        #expect(!classifier.requiresPairingReset(error))
    }

    @Test("Diagnostic detail includes domain code and description")
    func buildsDiagnosticDetail() {
        let error = NSError(
            domain: CBErrorDomain,
            code: CBError.peerRemovedPairingInformation.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "Peer removed pairing information"]
        )

        let detail = classifier.diagnosticDetail(error)

        #expect(detail.contains("domain=CBErrorDomain"))
        #expect(detail.contains("code=14"))
        #expect(detail.contains("description=Peer removed pairing information"))
    }
}
