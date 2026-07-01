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

    override func viewDidLoad() {
        super.viewDidLoad()
        handleSharedImage()
    }

    private func handleSharedImage() {
        guard let provider = firstImageProvider() else {
            complete()
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
            guard let self else { return }
            let didPersist = data.map { self.persist(imageData: $0, provider: provider) } ?? false

            // Opening the host app (via the responder-chain `openURL:` hack) and tearing
            // the extension down must both happen on the main thread. Completing the
            // request immediately would dismiss the extension before the open fires, so
            // open first and defer `complete()` by a beat to let the launch take effect.
            DispatchQueue.main.async {
                if didPersist {
                    self.openHostApp()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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

    private func openHostApp() {
        // Share extensions cannot call UIApplication.shared.open directly; walk the
        // responder chain to find an object that responds to openURL:.
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                current.perform(selector, with: Inbox.openURL)
                return
            }
            responder = current.next
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
