public struct PowerTierSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let navigationDetail: String
    public let status: String
    public let evidence: String?
    public let verificationMessage: String?
    public let verificationMessageIsError: Bool
    public let isVerifyEnabled: Bool
    public let isVerifying: Bool

    public init(
        selection: AppSettingsSelectionViewState,
        navigationDetail: String = "Standard",
        status: String,
        evidence: String? = nil,
        verificationMessage: String? = nil,
        verificationMessageIsError: Bool = false,
        isVerifyEnabled: Bool = false,
        isVerifying: Bool = false
    ) {
        self.selection = selection
        self.navigationDetail = navigationDetail
        self.status = status
        self.evidence = evidence
        self.verificationMessage = verificationMessage
        self.verificationMessageIsError = verificationMessageIsError
        self.isVerifyEnabled = isVerifyEnabled
        self.isVerifying = isVerifying
    }
}
