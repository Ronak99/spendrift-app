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

    /// Guards `completeRequest` so it is sent exactly once even if a future code
    /// path calls `complete()` twice; sending it twice is undefined behavior.
    /// Only mutated on the main thread.
    private var didComplete = false

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
                if didPersist {
                    self.openHostApp()
                }
                // Complete synchronously, in the same runloop turn as the open call.
                // Once the host app starts foregrounding, iOS suspends and often
                // terminates this extension process, so completion handlers and
                // delayed dispatch blocks scheduled here never run. If completeRequest
                // has not been sent by then, the source app (e.g. Photos) is left
                // frozen behind a share sheet that never dismisses. The open call is
                // an out-of-process request to the system and proceeds independently
                // of this extension's lifetime, so completing now does not cancel it.
                // If the open fails anyway, the image is already saved in the App
                // Group inbox and imports the next time Spendrift is launched.
                self.complete()
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
    /// Fire-and-forget: no completion handler is passed because the extension is
    /// suspended as soon as the host app foregrounds, so the handler would never
    /// reliably run.
    private func openHostApp() {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(Inbox.openURL, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
