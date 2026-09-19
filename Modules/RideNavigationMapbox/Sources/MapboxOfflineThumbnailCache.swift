import Foundation
import UIKit

@MainActor
struct MapboxOfflineThumbnailCache {
    let directory: URL
    let files: FileManager
    let memory: NSCache<NSString, UIImage>

    func image(key: String) -> UIImage? {
        if let image = memory.object(forKey: key as NSString) { return image }
        guard let image = UIImage(contentsOfFile: url(key).path) else { return nil }
        memory.setObject(image, forKey: key as NSString)
        return image
    }

    func store(_ image: UIImage, key: String, areaID: UUID) {
        memory.setObject(image, forKey: key as NSString)
        guard let data = image.pngData() else { return }
        do {
            try files.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url(key), options: .atomic)
            let previous = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in previous where file.lastPathComponent.hasPrefix(areaID.uuidString)
                && file != url(key) {
                try? files.removeItem(at: file)
            }
        } catch {
            // A disposable preview must not interrupt map downloads when storage is unavailable.
        }
    }

    private func url(_ key: String) -> URL { directory.appendingPathComponent(key).appendingPathExtension("png") }
}
