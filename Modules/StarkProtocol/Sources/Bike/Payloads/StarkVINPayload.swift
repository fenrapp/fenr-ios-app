public struct StarkVINPayload: StarkPayload {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}
