//
//  FeedbackView.swift
//  Spendrift
//
//  Multi-step in-app feedback survey. Submissions go to Supabase keyed by
//  DeviceIdentity.current.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var flow = FeedbackFlow()
    @State private var isSubmitting = false
    @State private var showError = false
    @State private var showThanks = false
    @State private var errorMessage = ""
    @State private var showLibrary = false

    private var accent: Color { AppTheme.accent }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack(alignment: .bottom) {
            SettingsAtmosphere(washColor: accent, watermarkIcon: "bubble.left.and.text.bubble.right")

            VStack(spacing: 0) {
                FeedbackStepContent(flow: flow, showLibrary: $showLibrary)

                if flow.showsSkipToNotes {
                    Button("Skip to notes") {
                        flow.skipToNotes()
                    }
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(isDark ? .dark : .light, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") {
                    flow.goBack { dismiss() }
                }
                .font(.system(size: 16, weight: .regular))
            }

            ToolbarItem(placement: .principal) {
                Text("Feedback")
                    .font(.system(size: 17, weight: .semibold))
            }

            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .confirmationAction) {
                    trailingAction
                }
                .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .confirmationAction) {
                    trailingAction
                }
            }
        }
        .sheet(isPresented: $showLibrary) {
            PhotoLibraryPicker { image in
                showLibrary = false
                if let image {
                    flow.draft.screenshotData = image.jpegData(compressionQuality: 0.85)
                }
            }
            .ignoresSafeArea()
        }
        .alert("Couldn't send feedback", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Thanks for your feedback", isPresented: $showThanks) {
            Button("Done") { dismiss() }
        } message: {
            Text("We read every submission.")
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if flow.currentStep == .notes {
            Button(action: submit) {
                SettingsCapsuleLabel(title: isSubmitting ? "Sending..." : "Submit")
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
            .opacity(isSubmitting ? 0.6 : 1)
        } else {
            Button {
                flow.advance()
            } label: {
                SettingsCapsuleLabel(title: "Next")
            }
            .buttonStyle(.plain)
            .opacity(flow.canProceed ? 1 : 0.4)
            .disabled(!flow.canProceed)
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            do {
                let client = try FeedbackClient()
                try await client.submit(draft: flow.draft)
                Analytics.capture(.feedbackSubmitted, [
                    Analytics.Key.skippedToNotes: flow.draft.skippedToNotes
                ])
                await MainActor.run {
                    isSubmitting = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    showThanks = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
