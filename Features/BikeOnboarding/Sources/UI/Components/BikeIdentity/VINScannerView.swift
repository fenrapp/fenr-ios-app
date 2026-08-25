import SwiftUI
import UIKit
import VisionKit

@available(iOS 16.0, *)
struct VINScannerView: UIViewControllerRepresentable {
    let onVIN: (String) -> Void
    let onUnavailable: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onVIN: onVIN) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(), .barcode(symbologies: [.code128, .qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        guard DataScannerViewController.isSupported, DataScannerViewController.isAvailable else {
            onUnavailable()
            return scanner
        }
        do {
            try scanner.startScanning()
        } catch {
            onUnavailable()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onVIN: (String) -> Void

        init(onVIN: @escaping (String) -> Void) { self.onVIN = onVIN }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            submit(item)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            addedItems.forEach(submit)
        }

        private func submit(_ item: RecognizedItem) {
            let value: String
            switch item {
            case .text(let text): value = text.transcript
            case .barcode(let barcode): value = barcode.payloadStringValue ?? ""
            @unknown default: return
            }
            onVIN(value)
        }
    }
}
