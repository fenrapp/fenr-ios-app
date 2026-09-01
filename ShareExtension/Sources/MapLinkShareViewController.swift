import UIKit

@MainActor
final class MapLinkShareViewController: UIViewController {
    private let statusLabel = UILabel()
    private let doneButton = UIButton(type: .system)
    private let processor: (any MapLinkShareProcessing)?
    private var loadingTask: Task<Void, Never>?

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        processor = try? MapLinkShareProcessor.live()
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        processor = try? MapLinkShareProcessor.live()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        let context = extensionContext
        let statusLabel = statusLabel
        let doneButton = doneButton
        guard let processor else {
            statusLabel.text = "FENR could not read this map link."
            doneButton.isHidden = false
            return
        }
        loadingTask = Task { @MainActor [processor, context, statusLabel, doneButton] in
            let message: String
            do {
                let inputItems = (context?.inputItems ?? []).compactMap { item in
                    item as? NSExtensionItem
                }
                try await processor.process(inputItems: inputItems)
                message = "Route ready in FENR"
            } catch is CancellationError {
                return
            } catch {
                message = "FENR could not read this map link."
            }
            guard !Task.isCancelled else { return }
            statusLabel.text = message
            doneButton.isHidden = false
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

    @objc private func finish() {
        loadingTask?.cancel()
        loadingTask = nil
        extensionContext?.completeRequest(returningItems: nil)
    }

    private enum Constants {
        static let spacing: CGFloat = 24
    }
}
