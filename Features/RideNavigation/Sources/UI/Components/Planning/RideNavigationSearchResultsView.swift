import DesignSystem
import SwiftUI

struct RideNavigationSearchResultsView: View {
    let query: String
    let results: [RideNavigationSearchResult]
    let isSearching: Bool
    let errorText: String?
    let onSelect: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpace.extraSmall) {
            resultsHeader
            resultsContent
            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(DesignColor.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var resultsHeader: some View {
        HStack {
            Text("Results")
                .font(.headline)
            Spacer()
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !results.isEmpty {
                Text(results.count, format: .number)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if normalizedQuery.count < Constants.minimumSearchCharacters || results.isEmpty && isSearching {
            searchPrompt
        } else {
            ScrollView {
                LazyVStack(spacing: .zero) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        Button { onSelect(result.id) } label: {
                            RideNavigationRow(
                                title: result.title,
                                detail: result.detail,
                                image: "mappin.and.ellipse"
                            )
                        }
                        .buttonStyle(.plain)
                        if index < results.count - 1 {
                            Divider().padding(.leading, Constants.rowDividerInset)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var searchPrompt: some View {
        VStack(spacing: DesignSpace.extraSmall) {
            Image(systemName: "mappin.and.ellipse")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Type a place or address to see nearby matches.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSpace.large)
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private enum Constants {
        static let minimumSearchCharacters = 2
        static let rowDividerInset: CGFloat = 52
    }
}
