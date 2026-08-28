import SwiftUI
import UIKit

struct ActivityShareSheet: UIViewControllerRepresentable {
    let itemURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [itemURL], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
