//
//  ShareViewController.swift
//  SpendriftShareExtension
//
//  Thin share extension: it only stashes the shared receipt image into the App
//  Group container and opens the host app via the `spendrift://importReceipt`
//  URL scheme. All parsing/auth runs in the host app (keeps secrets out of the
//  extension).
//
//  NOTE: the App Group id, pending-path key, and inbox folder name are duplicated
//  from `ReceiptShareInbox` in the main app because the extension is a separate
//  target/process and cannot share that file directly. Keep them in sync.
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private enum Inbox {
        static let appGroupID = "group.com.ronakpunase.Spendrift"
        static let pendingImagePathKey = "receiptSharePendingImagePath"
        static let inboxFolderName = "ReceiptShareInbox"
        static let openURL = URL(string: "spendrift://importReceipt")!
    }

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureLoadingUI()
        handleSharedImage()
    }

    private func configureLoadingUI() {
        view.backgroundColor = .systemBackground

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Opening Spendrift…"
        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func handleSharedImage() {
        guard let provider = firstImageProvider() else {
            complete()
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            guard let self else { return }
            let didPersist = data.map { self.persist(imageData: $0, provider: provider) } ?? false

            DispatchQueue.main.async {
                guard didPersist else {
                    self.complete()
                    return
                }
                self.openHostApp { opened in
                    if !opened {
                        // The image is already saved in the App Group inbox, so it will
                        // import the next time the user opens Spendrift manually.
                        self.statusLabel.text = "Saved. Open Spendrift to finish importing."
                        self.activityIndicator.stopAnimating()
                    }
                    self.complete()
                }
            }
        }
    }

    private func firstImageProvider() -> NSItemProvider? {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }
        for item in items {
            for provider in item.attachments ?? [] where provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                return provider
            }
        }
        return nil
    }

    private func persist(imageData: Data, provider: NSItemProvider) -> Bool {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Inbox.appGroupID
        ) else {
            return false
        }

        let dir = container.appendingPathComponent(Inbox.inboxFolderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let ext = fileExtension(for: provider)
        let dest = dir.appendingPathComponent("shared-receipt-\(UUID().uuidString).\(ext)")
        do {
            try imageData.write(to: dest, options: .atomic)
        } catch {
            return false
        }

        UserDefaults(suiteName: Inbox.appGroupID)?.set(dest.path, forKey: Inbox.pendingImagePathKey)
        return true
    }

    private func fileExtension(for provider: NSItemProvider) -> String {
        for identifier in provider.registeredTypeIdentifiers {
            if let type = UTType(identifier), type.conforms(to: .image),
               let ext = type.preferredFilenameExtension {
                return ext
            }
        }
        return "jpg"
    }

    /// Launches the containing app by walking the responder chain to reach the
    /// `UIApplication` instance and calling the modern `open(_:options:completionHandler:)`.
    ///
    /// `NSExtensionContext.open` is not honored for share extensions (it always reports
    /// failure), and the deprecated `openURL:` selector is a no-op on iOS 18+ (it always
    /// returns `false`). Casting to `UIApplication` is allowed here because only
    /// `UIApplication.shared` is marked unavailable in extensions, not the instance method.
    ///
    /// `completion` receives whether the open was dispatched successfully. Do not call
    /// `completeRequest` until it fires, or the pending open may be cancelled.
    private func openHostApp(completion: @escaping (Bool) -> Void) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(Inbox.openURL, options: [:]) { success in
                    DispatchQueue.main.async { completion(success) }
                }
                return
            }
            responder = current.next
        }
        completion(false)
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
