import DesignSystem
import SwiftUI

struct PowerModeControlFeedbackView: View {
    let feedback: PowerModeControlFeedback

    var body: some View {
        if let title = feedback.title {
            HStack(spacing: DesignSpace.extraSmall) {
                if feedback.isActivity {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else if let systemImage = feedback.systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .accessibilityElement(children: .combine)
        }
    }

    private var color: Color {
        switch feedback.emphasis {
        case .neutral: DesignColor.secondaryText
        case .informational: DesignColor.informational
        case .positive: DesignColor.positive
        case .warning: DesignColor.warning
        case .critical: DesignColor.critical
        }
    }
}
