//
//  FeatureRequestView.swift
//  Spendrift
//
//  Color-wash editor for sending a feature idea. The request lives in the
//  hero so this sheet matches the category and transaction editors.
//

import MessageUI
import SwiftUI
import UIKit

struct FeatureRequestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DeveloperMode.defaultsKey, store: DeveloperMode.store) private var developerModeUnlocked = false

    @FocusState private var ideaFieldFocused: Bool

    @State private var requestText: String = ""
    @State private var selectedImageData: Data? = nil
    @State private var showLibrary = false
    @State private var showMailComposer  = false
    @State private var showMailUnavailableAlert = false
    @State private var showSentConfirmation = false

    private var accent: Color {
        AppTheme.accent
    }

    private var isDark: Bool { colorScheme == .dark }

    private var canvas: Color {
        SettingsChrome.canvas(isDark: isDark)
    }

    private var heroPrimary: Color {
        SettingsChrome.heroPrimary(isDark: isDark)
    }

    private var canSend: Bool {
        !requestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hero
                detailsScroll
            }
            .background(canvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                CustomSheetCloseToolbarItem()
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .confirmationAction) {
                        sendButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        sendButton
                    }
                }
            }
            .onAppear {
                focusIdeaFieldSoon()
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
                    subject: "Feature Request - Spendrift",
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
            .alert("Mail not available", isPresented: $showMailUnavailableAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("No mail account is set up on this device. Please configure one in the Settings app and try again.")
            }
            .alert("Request sent", isPresented: $showSentConfirmation) {
                Button("Done") { dismiss() }
            } message: {
                Text("Thanks for taking the time to share your idea. We read every message.")
            }
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                CategoryEnamelTile(
                    systemImage: "lightbulb.fill",
                    color: accent
                )
                .frame(width: 70, height: 70)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Feature request")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(heroPrimary)

                    Text("We read every message")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(heroPrimary.opacity(0.6))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 26)
        .background(alignment: .top) {
            ColorWashBackground(color: accent, isDark: isDark)
                .padding(.top, -120)
        }
    }

    // MARK: Details

    private var detailsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TextEditor(text: $requestText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(heroPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .focused($ideaFieldFocused)
                    .tint(AppTheme.cursor)
                    .overlay(alignment: .topLeading) {
                        if requestText.isEmpty {
                            Text("Describe the feature you'd like to see")
                                .font(.system(size: 16))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.bottom, 8)

                featureMetaRow(title: "Screenshot", showsBottomDivider: selectedImageData != nil) {
                    Button {
                        ideaFieldFocused = false
                        showLibrary = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedImageData == nil ? "Attach" : "Attached")
                                .foregroundStyle(heroPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(heroPrimary.opacity(0.28))
                        }
                    }
                    .buttonStyle(.plain)
                }

                if let imageData = selectedImageData,
                   let uiImage = UIImage(data: imageData) {
                    VStack(spacing: 12) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            selectedImageData = nil
                        } label: {
                            Text("Remove screenshot")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color(hex: "#FF6B6B"))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 44)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
    }

    private func featureMetaRow<Trailing: View>(
        title: String,
        showsBottomDivider: Bool,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            trailing()
                .font(.system(size: 14, weight: .regular))
        }
        .frame(minHeight: 46)
        .overlay(alignment: .bottom) {
            if showsBottomDivider {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .contentShape(Rectangle())
    }

    private var sendButton: some View {
        Button(action: sendFeatureRequest) {
            SettingsCapsuleLabel(title: "Send")
        }
        .buttonStyle(.plain)
        .opacity(canSend ? 1 : 0.4)
        .disabled(!canSend)
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

    private func focusIdeaFieldSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ideaFieldFocused = true
        }
    }

    private func sendFeatureRequest() {
        if DeveloperMode.isPassphrase(requestText) {
            developerModeUnlocked = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            return
        }

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
