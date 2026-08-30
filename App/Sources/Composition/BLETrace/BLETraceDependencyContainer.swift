import AsyncSupport
import BLETraceData
import BLETraceDomain
import Foundation
import UIKit

@MainActor
struct BLETraceDependencyContainer {
    func makeRepository() -> any BLETraceRecording & BLETraceLogRepository {
        let fileManager = FileManager.default
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first,
            let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
        else {
            return NoOpBLETraceRepository()
        }
        do {
            return try FileBLETraceLogRepository(
                directory: applicationSupport.appendingPathComponent("BLELogs", isDirectory: true),
                exportDirectory: caches.appendingPathComponent("BLELogExports", isDirectory: true),
                environment: makeEnvironment(),
                configuration: BLETraceFileStoreConfiguration(),
                fileManager: fileManager,
                lineEncoder: BLETraceJSONLineEncoder(),
                sessionHub: AsyncEventHub(bufferingPolicy: .bufferingNewest(1), replaysLatestValue: true),
                now: Date.init,
                uptimeNanoseconds: { DispatchTime.now().uptimeNanoseconds }
            )
        } catch {
            return NoOpBLETraceRepository()
        }
    }

    private func makeEnvironment() -> BLETraceEnvironment {
        let bundle = Bundle.main
        return BLETraceEnvironment(
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            operatingSystem: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model
        )
    }
}
