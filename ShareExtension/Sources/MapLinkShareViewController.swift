import RideNavigationData
import RideNavigationDomain
import UIKit
import UniformTypeIdentifiers

final class MapLinkShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private var loadingTask: Task<Void, Never>?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        loadingTask = Task { [weak self] in
            await self?.receiveSharedURL()
        }
    }

    deinit {
        loadingTask?.cancel()
    }

    private func configureView() {
        view.backgroundColor = .systemBackground
        statusLabel.font = .preferredFont(forTextStyle: .headline)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = .zero
        statusLabel.text = "Preparing route…"

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Done"
        configuration.cornerStyle = .capsule
        doneButton.configuration = configuration
        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
        doneButton.isHidden = true

        let stack = UIStackView(arrangedSubviews: [statusLabel, doneButton])
        stack.axis = .vertical
        stack.spacing = Constants.spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func receiveSharedURL() async {
        do {
            guard let provider = extensionContext?.inputItems
                .compactMap({ $0 as? NSExtensionItem })
                .compactMap(\.attachments)
                .flatMap({ $0 })
                .first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) else {
                throw ShareError.missingURL
            }
            let item = try await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            guard let url = item as? URL, Self.isAllowed(url) else {
                throw ShareError.unsupportedURL
            }
            let store = try UserDefaultsIncomingMapLinkStore.shared()
            try await store.save(IncomingMapLink(url: url, receivedAt: Date()))
            statusLabel.text = "Route ready in FENR"
        } catch {
            statusLabel.text = "FENR could not read this map link."
        }
        doneButton.isHidden = false
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private static func isAllowed(_ url: URL) -> Bool {
        if url.pathExtension.lowercased() == "directionsrequest" { return true }
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return Constants.allowedHosts.contains(host)
    }

    private enum ShareError: Error {
        case missingURL
        case unsupportedURL
    }

    private enum Constants {
        static let spacing: CGFloat = 24
        static let allowedHosts: Set<String> = [
            "maps.app.goo.gl",
            "goo.gl",
            "google.com",
            "www.google.com",
            "maps.google.com",
            "maps.apple.com"
        ]
    }
}
