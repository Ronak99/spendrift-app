//
//  FeatureRequestView.swift
//  Spendrift
//

import MessageUI
import SwiftUI
import UIKit

struct FeatureRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Color.selectedThemeIndexKey) private var selectedThemeIndex = Color.defaultThemeIndex

    @State private var requestText: String = ""
    @State private var selectedImageData: Data? = nil
    @State private var showLibrary = false
    @State private var showMailComposer  = false
    @State private var showMailUnavailableAlert = false
    @State private var showSentConfirmation = false

    private var accent: Color {
        Color.accentColor(forThemeIndex: selectedThemeIndex)
    }

    private var canSend: Bool {
        !requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topLeading) {
                        if requestText.isEmpty {
                            Text("Describe the feature you'd like to see…")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $requestText)
                            .frame(minHeight: 140)
                    }
                } header: {
                    Text("Your idea")
                } footer: {
                    Text("Be as descriptive as you like — the more detail, the better.")
                        .font(.footnote)
                }

                Section {
                    Button {
                        showLibrary = true
                    } label: {
                        HStack {
                            Label("Attach a screenshot", systemImage: "photo.on.rectangle.angled")
                            Spacer()
                            if selectedImageData != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(accent)
                            }
                        }
                    }

                    if let imageData = selectedImageData,
                       let uiImage = UIImage(data: imageData) {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Spacer()
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            selectedImageData = nil
                        } label: {
                            Label("Remove screenshot", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Screenshot (optional)")
                } footer: {
                    Text("A screenshot helps understand the context of your request.")
                        .font(.footnote)
                }

                Section {
                    Button {
                        sendFeatureRequest()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Send via Email", systemImage: "paperplane.fill")
                                .font(.headline)
                                .foregroundStyle(canSend ? .white : .secondary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(canSend ? accent : Color(.tertiarySystemGroupedBackground))
                    )
                    .disabled(!canSend)
                }
            }
            .navigationTitle("Feature Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showLibrary) {
                PhotoLibraryPicker { image in
                    showLibrary = false
                    if let image {
                        selectedImageData = image.jpegData(compressionQuality: 0.85)
                    }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showMailComposer) {
                MailComposerView(
                    subject: "Feature Request – Spendrift",
                    body: mailBody,
                    recipients: ["me@ronakpunase.dev"],
                    attachments: mailAttachments,
                    onDismiss: { result in
                        if result == .sent {
                            showSentConfirmation = true
                        }
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Mail Not Available", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail account is set up on this device. Please configure one in the Settings app and try again.")
            }
            .alert("Request Sent!", isPresented: $showSentConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("Thanks for taking the time to share your idea. We read every message.")
            }
        }
    }

    private var mailBody: String {
        var body = requestText.trimmingCharacters(in: .whitespacesAndNewlines)
        body += "\n\n---\nSent from Spendrift"
        return body
    }

    private var mailAttachments: [MailComposerView.MailAttachment] {
        guard let data = selectedImageData else { return [] }
        return [
            MailComposerView.MailAttachment(
                data: data,
                mimeType: "image/jpeg",
                fileName: "screenshot.jpg"
            )
        ]
    }

    private func sendFeatureRequest() {
        guard MFMailComposeViewController.canSendMail() else {
            showMailUnavailableAlert = true
            return
        }
        showMailComposer = true
    }
}

#Preview {
    FeatureRequestView()
}
