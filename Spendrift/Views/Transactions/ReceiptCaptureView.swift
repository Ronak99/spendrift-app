//
//  ReceiptCaptureView.swift
//  Spendrift
//
//  In-app entry point for "Scan receipt": capture with the camera or pick from the
//  photo library, send to the backend, then create the transaction or open the
//  "missing fields" review sheet (UpdateTransactionSheet).
//

import SwiftUI
import SwiftData
import UIKit

struct ReceiptCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.createdOn) private var accounts: [Account]
    @Query(sort: \TransactionCategory.name) private var categories: [TransactionCategory]

    @State private var controller = ReceiptCaptureController()
    @State private var showLibrary = false
    @State private var showCamera = false

    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        @Bindable var controller = controller
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Privacy notice")
                                .font(.subheadline.weight(.semibold))
                            Text(
                                "The receipt image you choose is sent to a third-party AI service so it can read the receipt and suggest a transaction. "
                                + "Only continue if you are comfortable with that image leaving your device."
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                    .disabled(!cameraAvailable || controller.isProcessing)

                    // NOTE: Use PhotoLibraryPicker (UIKit PHPickerViewController) rather than
                    // SwiftUI's `PhotosPicker`. Embedding `PhotosPicker` as a row inside a Form
                    // that lives in a sheet makes iOS repeatedly dismiss and re-present the
                    // gallery (it "blinks"). PHPicker presents exactly once and needs no
                    // photo-library permission.
                    Button {
                        showLibrary = true
                    } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                    .disabled(controller.isProcessing)
                } footer: {
                    if !cameraAvailable {
                        Text("Camera is not available on this device.")
                            .font(.caption)
                    }
                }

                if controller.isProcessing {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Reading receipt…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ReceiptCameraPicker { image in
                    showCamera = false
                    if let image {
                        handle(image: image)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { image in
                    showLibrary = false
                    if let image {
                        handle(image: image)
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Couldn't Scan Receipt", isPresented: Binding(
                get: { if case .error = controller.state { return true } else { return false } },
                set: { if !$0 { controller.dismissError() } }
            )) {
                Button("OK", role: .cancel) { controller.dismissError() }
            } message: {
                if case .error(let message) = controller.state {
                    Text(message)
                }
            }
            .onChange(of: controller.didCreate) { _, created in
                if created {
                    controller.acknowledgeCreate()
                    dismiss()
                }
            }
            .sheet(item: $controller.reviewPayload, onDismiss: { dismiss() }) { payload in
                UpdateTransactionSheet(
                    transaction: nil,
                    draft: payload.draft,
                    voiceReviewHint: payload.hint
                )
            }
        }
    }

    private func handle(image: UIImage) {
        controller.process(
            image: image,
            accounts: accounts,
            categories: categories,
            modelContext: modelContext
        )
    }
}

// MARK: - Camera picker

/// Thin UIKit wrapper for live camera capture (PhotosPicker cannot take new photos).
struct ReceiptCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            onImage(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
        }
    }
}

#Preview {
    ReceiptCaptureView()
        .modelContainer(for: [Transaction.self, Account.self, TransactionCategory.self], inMemory: true)
}
