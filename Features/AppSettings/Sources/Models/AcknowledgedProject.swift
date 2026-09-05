import Foundation

public enum AcknowledgedProject: String, CaseIterable, Identifiable, Sendable {
    case svagMini
    case svagTelemetryFormat
    case starkVargGarminBridge
    case boschGarminBridge
    case xcodeGen
    case swiftLint
    case appStoreConnectCLI

    public var id: String { rawValue }

    static let community: [Self] = [.svagMini, .svagTelemetryFormat, .starkVargGarminBridge, .boschGarminBridge]
    static let developmentTools: [Self] = [.xcodeGen, .swiftLint, .appStoreConnectCLI]

    var title: LocalizedStringResource {
        switch self {
        case .svagMini: .appSettingsCreditSvagMiniTitle
        case .svagTelemetryFormat: .appSettingsCreditSvagTelemetryTitle
        case .starkVargGarminBridge: .appSettingsCreditStarkBridgeTitle
        case .boschGarminBridge: .appSettingsCreditBoschBridgeTitle
        case .xcodeGen: .appSettingsCreditXcodeGenTitle
        case .swiftLint: .appSettingsCreditSwiftLintTitle
        case .appStoreConnectCLI: .appSettingsCreditASCTitle
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .svagMini: .appSettingsCreditSvagMiniDetail
        case .svagTelemetryFormat: .appSettingsCreditSvagTelemetryDetail
        case .starkVargGarminBridge: .appSettingsCreditStarkBridgeDetail
        case .boschGarminBridge: .appSettingsCreditBoschBridgeDetail
        case .xcodeGen: .appSettingsCreditXcodeGenDetail
        case .swiftLint: .appSettingsCreditSwiftLintDetail
        case .appStoreConnectCLI: .appSettingsCreditASCDetail
        }
    }
}
