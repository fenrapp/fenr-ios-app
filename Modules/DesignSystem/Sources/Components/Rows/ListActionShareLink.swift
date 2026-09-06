import SwiftUI

public struct ListActionShareLink: View {
    @Environment(\.isEnabled) private var environmentIsEnabled
    @State private var feedbackToken = 0

    private let item: String
    private let title: String
    private let systemImage: String
    private let tint: Color
    private let isEnabled: Bool

    public init(
        item: String,
        title: String,
        systemImage: String,
        tint: Color = .indigo,
        isEnabled: Bool = true
    ) {
        self.item = item
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isEnabled = isEnabled
    }

    public var body: some View {
        ShareLink(item: item) {
            ListActionLabel(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(ListActionRowButtonStyle(tint: tint))
        .listRowInsets(ListRowConstants.actionInsets)
        .disabled(!isEnabled)
        .simultaneousGesture(TapGesture().onEnded {
            guard isEnabled, environmentIsEnabled else { return }
            feedbackToken += 1
        })
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackToken)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Share action") {
    List {
        ListActionShareLink(item: "Synthetic report", title: "Share report", systemImage: "square.and.arrow.up")
        ListActionShareLink(
            item: "Synthetic report", title: "Unavailable report", systemImage: "square.and.arrow.up", isEnabled: false
        )
    }
}
