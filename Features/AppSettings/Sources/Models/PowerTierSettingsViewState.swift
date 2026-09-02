import Foundation

public struct PowerTierSettingsViewState: Equatable, Sendable {
    public let selection: AppSettingsSelectionViewState
    public let navigationDetail: LocalizedStringResource
    public let status: LocalizedStringResource
    public let evidence: LocalizedStringResource?
    public let verificationMessage: LocalizedStringResource?
    public let verificationMessageIsError: Bool
    public let isVerifyEnabled: Bool
    public let isVerifying: Bool

    public init(
        selection: AppSettingsSelectionViewState,
        navigationDetail: LocalizedStringResource? = nil,
        status: LocalizedStringResource,
        evidence: LocalizedStringResource? = nil,
        verificationMessage: LocalizedStringResource? = nil,
        verificationMessageIsError: Bool = false,
        isVerifyEnabled: Bool = false,
        isVerifying: Bool = false
    ) {
        self.selection = selection
        self.navigationDetail = navigationDetail ?? .appSettingsPowerTierStandard
        self.status = status
        self.evidence = evidence
        self.verificationMessage = verificationMessage
        self.verificationMessageIsError = verificationMessageIsError
        self.isVerifyEnabled = isVerifyEnabled
        self.isVerifying = isVerifying
    }
}
