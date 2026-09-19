import OfflineMapsDomain
import Testing

struct OfflineGeometryTests {
    private let geometry = OfflineGeometryService()

    @Test func dateLineSelectionSplitsWithoutDownloadingTheWorld() {
        let value = geometry.rectangle(west: 179, south: 10, east: -179, north: 11)
        #expect(value.isValid)
        #expect(value.rectangles.count == 2)
        #expect(value.rectangles.reduce(0) { $0 + $1.east - $1.west } == 2)
    }

    @Test func unionOfAdjacentRegionsCoversSelection() {
        let requested = geometry.rectangle(west: 0, south: 0, east: 2, north: 2)
        let left = geometry.rectangle(west: 0, south: 0, east: 1, north: 2)
        let right = geometry.rectangle(west: 1, south: 0, east: 2, north: 2)
        #expect(geometry.availability(of: requested, within: [left, right]) == .complete)
    }

    @Test func interiorHoleIsNotCompleteDespiteCoveredCorners() {
        let requested = geometry.rectangle(west: 0, south: 0, east: 2, north: 2)
        let strips = [
            geometry.rectangle(west: 0, south: 0, east: 0.9, north: 2),
            geometry.rectangle(west: 1.1, south: 0, east: 2, north: 2),
            geometry.rectangle(west: 0, south: 0, east: 2, north: 0.9),
            geometry.rectangle(west: 0, south: 1.1, east: 2, north: 2)
        ]
        #expect(geometry.availability(of: requested, within: strips) == .partial)
    }

    @Test func corridorPreservesDisconnectedSegmentsAndDateLine() {
        let value = geometry.corridor(segments: [
            [.init(latitude: 41, longitude: 2), .init(latitude: 41.02, longitude: 2)],
            [.init(latitude: 43, longitude: 4), .init(latitude: 43.02, longitude: 4)]
        ], marginMeters: 2_000)
        #expect(value.isValid)
        #expect(!geometry.contains(.init(latitude: 42, longitude: 3), in: value))
        let wrapped = geometry.corridor(segments: [[
            .init(latitude: 10, longitude: 179.99), .init(latitude: 10, longitude: -179.99)
        ]], marginMeters: 2_000)
        #expect(wrapped.isValid)
        #expect(!geometry.contains(.init(latitude: 10, longitude: 0), in: wrapped))
        #expect(geometry.contains(.init(latitude: 10, longitude: 180), in: wrapped))
    }

    @Test func denseTrackProducesBoundedStripsWithoutDroppingCoverage() {
        let points = (0..<10_000).map { OfflineCoordinate(latitude: 40 + Double($0) * 0.00001, longitude: 2) }
        let value = geometry.corridor(segments: [points], marginMeters: 2_000)
        #expect(value.isValid)
        #expect(value.rectangles.count < 20)
        for point in points {
            #expect(geometry.contains(point, in: value))
        }
    }

    @Test func invalidAndPolarInputsAreBounded() {
        #expect(!geometry.rectangle(west: .nan, south: 0, east: 1, north: 1).isValid)
        #expect(!geometry.corridor(segments: [[.init(latitude: .infinity, longitude: 0)]], marginMeters: 2_000).isValid)
        let polar = geometry.rectangle(west: 0, south: 84, east: 10, north: 90)
        #expect(polar.isValid)
        #expect(polar.rectangles[0].north <= 85.051129)
    }
}
