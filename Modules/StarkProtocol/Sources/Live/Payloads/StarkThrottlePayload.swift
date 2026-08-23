public struct StarkThrottlePayload: StarkPayload {
    public let idFeedbackRaw: Int
    public let iqFeedbackRaw: Int
    public let positionRaw: Int

    public init(idFeedbackRaw: Int, iqFeedbackRaw: Int, positionRaw: Int) {
        self.idFeedbackRaw = idFeedbackRaw
        self.iqFeedbackRaw = iqFeedbackRaw
        self.positionRaw = positionRaw
    }
}
