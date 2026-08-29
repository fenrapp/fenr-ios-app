import DesignSystem
import SwiftUI

struct DashboardBikeLockCard: View {
    let viewState: BikeLockCardViewState
    let securityOptions: [BikeLockSecurityOptionViewData]
    let performPrimaryAction: () -> Void
    let configure: (String, String) -> Void
    let submitPIN: (String) -> Void
    let dismissSheet: () -> Void

    var body: some View {
        DashboardAdaptiveCardSurface {
            VStack(spacing: Constants.contentSpacing) {
                Image(systemName: viewState.isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: Constants.iconSize, weight: .semibold))
                    .foregroundStyle(viewState.isLocked ? DesignColor.warning : DesignColor.positive)
                    .accessibilityHidden(true)

                VStack(spacing: Constants.textSpacing) {
                    Text(viewState.title)
                        .font(.title2.weight(.semibold))
                    Text(viewState.statusText)
                        .font(.title3.weight(.medium))
                    Text(viewState.detailText)
                        .font(.footnote)
                        .foregroundStyle(DesignColor.secondaryText)
                        .multilineTextAlignment(.center)
                }

                if let errorText = viewState.errorText {
                    Text(errorText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DesignColor.critical)
                        .multilineTextAlignment(.center)
                }

                Button(action: performPrimaryAction) {
                    if viewState.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label(
                            viewState.actionTitle,
                            systemImage: viewState.isLocked ? "lock.open.fill" : "lock.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewState.isWorking)
                .accessibilityIdentifier("dashboard.bike-lock.action")
            }
            .padding(Constants.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: setupBinding) {
            BikeLockSetupView(
                options: securityOptions,
                configure: configure,
                cancel: dismissSheet
            )
        }
        .sheet(isPresented: pinBinding) {
            BikeLockPINEntryView(
                title: "Enter Unlock PIN",
                submit: submitPIN,
                cancel: dismissSheet
            )
        }
    }

    private var setupBinding: Binding<Bool> {
        .init(
            get: { viewState.sheet == .setup },
            set: { if !$0 { dismissSheet() } }
        )
    }

    private var pinBinding: Binding<Bool> {
        .init(
            get: { viewState.sheet == .enterPIN },
            set: { if !$0 { dismissSheet() } }
        )
    }

    private enum Constants {
        static let cardPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 18
        static let textSpacing: CGFloat = 5
        static let iconSize: CGFloat = 44
    }
}
