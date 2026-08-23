import BikeDomain
import Foundation

actor BikeEmulatorCaptureHub {
    private var continuations: [UUID: AsyncStream<BatteryDatasetCapture>.Continuation] = [:]
    private var latestCaptures: [BatteryDataset: BatteryDatasetCapture] = [:]

    func stream() -> AsyncStream<BatteryDatasetCapture> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream<BatteryDatasetCapture>.makeStream()
        continuations[identifier] = continuation
        latestCaptures.values
            .sorted { $0.dataset.rawValue < $1.dataset.rawValue }
            .forEach { continuation.yield($0) }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.remove(identifier: identifier) }
        }
        return stream
    }

    func replace(with captures: [BatteryDatasetCapture]) {
        latestCaptures = Dictionary(uniqueKeysWithValues: captures.map { ($0.dataset, $0) })
        captures.forEach { capture in
            continuations.values.forEach { $0.yield(capture) }
        }
    }

    private func remove(identifier: UUID) {
        continuations[identifier] = nil
    }
}
