import DesignSystem
import SwiftUI

public struct BikeDemoIntroductionView: View {
    private let isBusy: Bool
    private let hasError: Bool
    private let onStart: () -> Void
    private let onCancel: () -> Void

    public init(isBusy: Bool, hasError: Bool, onStart: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.isBusy = isBusy
        self.hasError = hasError
        self.onStart = onStart
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSpace.large) {
                    Image(systemName: "motorcycle")
                        .font(.system(size: Constants.symbolSize))
                        .foregroundStyle(DesignColor.warning)
                        .accessibilityHidden(true)
                    Text(.bikeDemoIntroHeading).font(.largeTitle.bold())
                    Text(.bikeDemoIntroDetail).foregroundStyle(.secondary)
                    Label(.bikeDemoIntroOffline, systemImage: "iphone")
                    Label(.bikeDemoPersistence, systemImage: "arrow.clockwise")
                    Label(.bikeDemoExitDetail, systemImage: "motorcycle")
                    if hasError {
                        Text(.bikeDemoPreparationError).foregroundStyle(DesignColor.critical)
                    }
                    Button(action: onStart) {
                        HStack {
                            if isBusy { ProgressView() }
                            Text(.bikeDemoStart).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSpace.small)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignColor.warning)
                    .disabled(isBusy)
                    .accessibilityIdentifier("demo.start")
                }
                .padding(DesignSpace.large)
                .frame(maxWidth: Constants.maximumWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle(Text(.bikeDemoTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.bikeDemoCancel, action: onCancel).disabled(isBusy)
                }
            }
        }
        .interactiveDismissDisabled(isBusy)
    }

    private enum Constants {
        static let symbolSize: CGFloat = 48
        static let maximumWidth: CGFloat = 560
    }
}
