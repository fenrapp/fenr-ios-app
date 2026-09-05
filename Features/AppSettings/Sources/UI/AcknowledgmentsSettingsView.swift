#if os(iOS)
import DesignSystem
import SwiftUI

struct AcknowledgmentsSettingsView: View {
    let onNavigation: (AppSettingsNavigationEvent) -> Void

    var body: some View {
        Form {
            Section {
                projectRows(AcknowledgedProject.community)
            } header: {
                Text(.appSettingsAcknowledgmentsCommunity)
            } footer: {
                Text(.appSettingsAcknowledgmentsCommunityDetail)
            }
            Section {
                projectRows(AcknowledgedProject.developmentTools)
            } header: {
                Text(.appSettingsAcknowledgmentsTools)
            } footer: {
                Text(.appSettingsAcknowledgmentsToolsDetail)
            }
        }
        .navigationTitle(Text(.appSettingsAcknowledgmentsTitle))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func projectRows(_ projects: [AcknowledgedProject]) -> some View {
        ForEach(projects) { project in
            ListNavigationRow(
                title: String(localized: project.title),
                subtitle: String(localized: project.detail),
                systemImage: "heart.text.clipboard",
                tint: DesignColor.accent,
                action: { onNavigation(.openAcknowledgedProject(project)) }
            )
            .accessibilityIdentifier("settings.acknowledgments.\(project.rawValue)")
        }
    }
}
#endif
