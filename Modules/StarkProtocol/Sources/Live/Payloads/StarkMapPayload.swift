public struct StarkMapPayload: StarkPayload {
    public let modeIndex: Int

    public init(modeIndex: Int) {
        self.modeIndex = modeIndex
    }
}
