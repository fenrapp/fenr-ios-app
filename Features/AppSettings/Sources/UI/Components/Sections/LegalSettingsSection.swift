#if os(iOS)
import SwiftUI

struct LegalSettingsSection: View {
    let onNavigation: (AppSettingsNavigationEvent) -> Void

    var body: some View {
        Section {
            SettingsNavigationRow(
                icon: "hand.raised",
                iconTint: .blue,
                title: .appSettingsPrivacyPolicyTitle,
                detail: .appSettingsSupportDetail,
                accessibilityIdentifier: "settings.privacyPolicy",
                action: { onNavigation(.openPrivacyPolicy) }
            )
            SettingsNavigationRow(
                icon: "doc.text",
                iconTint: .gray,
                title: .appSettingsTermsTitle,
                detail: .appSettingsSupportDetail,
                accessibilityIdentifier: "settings.terms",
                action: { onNavigation(.openTerms) }
            )
        } header: {
            Text(.appSettingsLegalSection)
        }
    }

}
#endif
