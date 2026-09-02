//
//  DebugSwiftBootstrap.swift
//  Spendrift
//
//  Debug-only DebugSwift setup so SQLite stores in the App Group can be
//  browsed, exported, and shared from a physical device.
//

#if DEBUG
import DebugSwift
import Foundation
import SwiftData
import SwiftUI
import UIKit

enum DebugSwiftBootstrap {
    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITesting")
    private static var pendingLedger: ModelContainer?
    private static var pendingInbox: ModelContainer?

    static func rememberStores(ledger: ModelContainer?, inbox: ModelContainer?) {
        pendingLedger = ledger
        pendingInbox = inbox
    }

    @MainActor
    static func start(_ debugSwift: DebugSwift) {
        guard !isUITesting else { return }

        debugSwift.setup()
        configureResources()
        registerStores(ledger: pendingLedger, inbox: pendingInbox)
        debugSwift.show()
    }

    @MainActor
    static func registerStores(ledger: ModelContainer?, inbox: ModelContainer?) {
        guard !isUITesting else { return }

        var contexts: [SwiftDataContextRegistration] = []

        if let ledger {
            contexts.append(
                SwiftDataContextRegistration(
                    name: "Ledger (Spendrift.sqlite)",
                    container: ledger,
                    models: [
                        SwiftDataModelRegistration(Account.self, displayName: "Account"),
                        SwiftDataModelRegistration(TransactionCategory.self, displayName: "Category"),
                        SwiftDataModelRegistration(Transaction.self, displayName: "Transaction")
                    ]
                )
            )
        }

        if let inbox {
            contexts.append(
                SwiftDataContextRegistration(
                    name: "Message inbox (SpendriftMessages.sqlite)",
                    container: inbox,
                    models: [
                        SwiftDataModelRegistration(
                            CapturedTransactionMessage.self,
                            displayName: "Captured message"
                        )
                    ]
                )
            )
        }

        guard !contexts.isEmpty else { return }
        DebugSwift.Resources.shared.configureSwiftData(contexts: contexts)
        DebugSwift.Resources.shared.swiftDataReadOnly = true
    }

    @MainActor
    private static func configureResources() {
        DebugSwift.Resources.shared.configureAppGroups([IntentSwiftData.appGroupID])

        DebugSwift.App.shared.customInfo = {
            [CustomData(title: "SQLite stores", infos: storeInfoRows())]
        }

        DebugSwift.App.shared.customAction = {
            [
                CustomAction(
                    title: "SQLite",
                    actions: [
                        CustomAction.Action(title: "Share all SQLite files") {
                            shareAllStoreFiles()
                        },
                        CustomAction.Action(title: "Share ledger store") {
                            shareStoreFiles(named: "Spendrift.sqlite")
                        },
                        CustomAction.Action(title: "Share message inbox store") {
                            shareStoreFiles(named: MessageInboxSwiftData.storeFileName)
                        }
                    ]
                )
            ]
        }
    }

    private static func storeInfoRows() -> [CustomData.Info] {
        var rows: [CustomData.Info] = []

        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IntentSwiftData.appGroupID
        ) {
            rows.append(.init(title: "App Group", subtitle: IntentSwiftData.appGroupID))
            rows.append(.init(title: "App Group path", subtitle: groupURL.path))
            rows.append(contentsOf: fileInfoRows(named: "Spendrift.sqlite", in: groupURL))
            rows.append(contentsOf: fileInfoRows(named: MessageInboxSwiftData.storeFileName, in: groupURL))
        } else {
            rows.append(.init(title: "App Group", subtitle: "Unavailable"))
        }

        return rows
    }

    private static func fileInfoRows(named fileName: String, in directory: URL) -> [CustomData.Info] {
        sidecarURLs(named: fileName, in: directory).map { url in
            let exists = FileManager.default.fileExists(atPath: url.path)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let subtitle = exists
                ? ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                : "Missing"
            return .init(title: url.lastPathComponent, subtitle: subtitle)
        }
    }

    private static func sidecarURLs(named fileName: String, in directory: URL) -> [URL] {
        let base = directory.appendingPathComponent(fileName)
        return [
            base,
            URL(fileURLWithPath: base.path + "-wal"),
            URL(fileURLWithPath: base.path + "-shm")
        ]
    }

    private static func existingStoreFiles(named fileName: String) -> [URL] {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: IntentSwiftData.appGroupID
        ) else { return [] }

        return sidecarURLs(named: fileName, in: groupURL).filter {
            FileManager.default.fileExists(atPath: $0.path)
        }
    }

    private static func shareStoreFiles(named fileName: String) {
        presentShareSheet(urls: snapshotForSharing(existingStoreFiles(named: fileName)))
    }

    private static func shareAllStoreFiles() {
        let urls = existingStoreFiles(named: "Spendrift.sqlite")
            + existingStoreFiles(named: MessageInboxSwiftData.storeFileName)
        presentShareSheet(urls: snapshotForSharing(urls))
    }

    /// Copy while the app may still have the stores open so AirDrop gets a stable snapshot.
    private static func snapshotForSharing(_ urls: [URL]) -> [URL] {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpendriftSQLite-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return try urls.map { source in
                let destination = folder.appendingPathComponent(source.lastPathComponent)
                try FileManager.default.copyItem(at: source, to: destination)
                return destination
            }
        } catch {
            return urls
        }
    }

    private static func presentShareSheet(urls: [URL]) {
        guard !urls.isEmpty else { return }

        DispatchQueue.main.async {
            let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
            guard let presenter = topViewController() else { return }
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
            }
            presenter.present(activity, animated: true)
        }
    }

    private static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}

struct DebugSwiftViewControllerRepresentable: UIViewControllerRepresentable {
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let debugVC = DebugSwift.debugViewController()

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: context.coordinator,
            action: #selector(Coordinator.close)
        )
        closeButton.tintColor = .white
        debugVC.navigationItem.rightBarButtonItem = closeButton

        let nav = UINavigationController(rootViewController: debugVC)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .black
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.overrideUserInterfaceStyle = .dark
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    final class Coordinator: NSObject {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        @objc func close() {
            onDismiss()
        }
    }
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)

        guard motion == .motionShake else { return }
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
        appDelegate.debugSwift.toggle()
    }
}
#endif
