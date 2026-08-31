actor BikeEmulatorStreamRecorder<Value: Sendable> {
    private(set) var values: [Value] = []

    var count: Int {
        values.count
    }

    var latest: Value? {
        values.last
    }

    func record(_ stream: AsyncStream<Value>) async {
        for await value in stream {
            values.append(value)
        }
    }

    func value(at index: Int) -> Value? {
        values.indices.contains(index) ? values[index] : nil
    }
}
