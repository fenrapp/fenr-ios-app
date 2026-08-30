import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct GPXShareSheet: UIViewControllerRepresentable {
    let request: GPXExportRequest

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemProvider = NSItemProvider()
        itemProvider.suggestedName = request.filename
        itemProvider.registerDataRepresentation(
            forTypeIdentifier: UTType.gpx.identifier,
            visibility: .all
        ) { completion in
            completion(request.data, nil)
            return nil
        }
        return UIActivityViewController(activityItems: [itemProvider], applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct GPXFileDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.gpx]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}
