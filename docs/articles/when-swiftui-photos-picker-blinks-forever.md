# When SwiftUI's PhotosPicker Blinks Forever: A Bug That Looked Fixed But Wasn't

*How a receipt-scanning flow turned into Face ID prompts, gallery relaunches, and a dead-end loop — and why removing one line of SwiftUI code was not enough.*

---

## The user experience was broken in seven seconds

Spendrift is a personal finance app for iOS.
One of its features lets you scan a receipt: open a sheet, tap **Choose from Library**, pick a photo, and let an AI backend read the receipt into a transaction.

In theory, that should take two taps and a selection.
In practice, a screen recording of the flow told a different story.

Over roughly seven seconds, the user was bounced through:

1. The **Scan Receipt** sheet.
2. A system **Face ID Required** prompt (Photos app lock).
3. The photo picker with a **Private Access to Photos** banner.
4. **Face ID Required** again.
5. A full-screen **Loading…** spinner.
6. **Face ID Required** a third time.
7. The photo picker reopening on its own.
8. Back to the **Scan Receipt** sheet — with no receipt scanned.

The gallery did not stay open.
It blinked.
It refreshed.
It felt like the app was crashing and relaunching the picker in a loop.

Nothing in the UI suggested a code bug.
Everything suggested the app was fighting iOS itself.

---

## First diagnosis: the obvious SwiftUI mistake

The first version of the feature used SwiftUI's `PhotosPicker` with an explicit shared photo library:

```swift
PhotosPicker(
    selection: $photoItem,
    matching: .images,
    photoLibrary: .shared()
) {
    Label("Choose from Library", systemImage: "photo.on.rectangle")
}
```

Passing `photoLibrary: .shared()` runs the picker **in-process**.
That forces photo-library authorization.
On devices where the Photos app is locked behind Face ID — common on iOS 18 — the system may re-authenticate on every touch of the library.
Combined with limited photo access, you get the **Private Access to Photos** banner and repeated auth prompts.

The fix looked straightforward: drop `.shared()` and use the default out-of-process picker, which needs no permission and opens once.

```swift
PhotosPicker(selection: $photoItem, matching: .images) {
    Label("Choose from Library", systemImage: "photo.on.rectangle")
}
```

Commit message: *"fix: stop receipt gallery picker from opening/authenticating repeatedly."*

Case closed?

Not even close.

---

## The fix that should have worked — but didn't

After shipping the out-of-process picker, the symptoms changed shape but did not disappear.

Users on fresh installs — no lingering photo permissions, no `.limited` access grant from an older build — still saw the gallery **blink and relaunch** as if something was tearing down and re-presenting the picker on every frame.

The Face ID spam often went away.
The loop did not.

That detail matters.
If the bug were purely about `photoLibrary: .shared()` and stale `.limited` authorization, a clean install should have killed it.
A clean install did not.

The real bug lived somewhere else.

---

## What frame-by-frame analysis revealed

A 10-second screen recording at 60 fps was extracted into still frames (4 fps) to reconstruct the timeline without guessing.

| Approx. time | What appeared on screen |
|---|---|
| 0–3s | Scan Receipt sheet, idle |
| ~3.5s | Face ID Required (Photos) |
| 4–7s | Photo picker + Private Access banner |
| ~7.7s | Face ID Required again |
| ~8.2s | Full-screen Loading… spinner |
| ~8.7s | Face ID Required again |
| 9–10s | Picker reopens, then back to Scan Receipt |

Two separate failure modes were stacked on top of each other:

1. **Authorization-driven re-auth** — caused by in-process picker / limited library access / Photos app Face ID lock.
2. **Presentation-driven relaunch** — the picker dismissing and re-presenting with no user input, even after authorization was removed from the equation.

Fixing only the first layer left the second layer fully intact.

---

## The actual root cause: Form + sheet + PhotosPicker

The receipt flow was structured like this:

```
TransactionsView
  └── .sheet → ReceiptCaptureView
        └── NavigationStack
              └── Form
                    └── PhotosPicker (as a row)
```

This is a comfortable SwiftUI layout.
It is also a known failure mode on recent iOS versions.

When `PhotosPicker` is embedded as a **row inside a `Form` (or `List`) that itself lives inside a `.sheet`**, SwiftUI's presentation lifecycle can enter a loop:

- The parent view's `body` re-evaluates.
- The `Form` re-lays out.
- The `PhotosPicker` row is torn down and recreated.
- UIKit dismisses the picker.
- SwiftUI immediately tries to present it again.

To the user, the gallery **blinks**.
To the developer, logs may show benign LaunchServices noise (`Code=-54 "process may not map database"`) that looks scary but is unrelated simulator sandbox chatter.

The `.shared()` removal was necessary but insufficient.
The architectural placement of `PhotosPicker` was the remaining bug.

---

## Why this bug is easy to misdiagnose

Several factors conspire to send you down the wrong path:

**1. Two bugs, one symptom.**

In-process picker + limited access produces Face ID loops and the Private Access banner.
Form-in-sheet presentation produces blinking with no permission involved.
A screen recording often shows both at once if you tested on a device that already had limited access from an earlier build.

**2. The "fix" is plausible.**

Apple's documentation nudges you toward the default out-of-process picker.
Removing `.shared()` is the correct advice for permission issues.
It is reasonable to assume the problem is solved when Face ID stops appearing.

**3. Fresh install doesn't help.**

If the presentation loop is structural, resetting photo permissions changes nothing.
That is the tell.

**4. SwiftUI hides UIKit presentation.**

You never see `PHPickerViewController` in your code.
The relaunch happens inside framework glue you do not control.

---

## The fix: stop using SwiftUI's PhotosPicker here

The reliable pattern is the same one many teams use for camera capture: wrap UIKit, present explicitly, handle the delegate once.

### Step 1 — Replace the picker row with a Button

```swift
Button {
    showLibrary = true
} label: {
    Label("Choose from Library", systemImage: "photo.on.rectangle")
}
.disabled(controller.isProcessing)
```

### Step 2 — Present PHPickerViewController in its own sheet

```swift
.sheet(isPresented: $showLibrary) {
    PhotoLibraryPicker { image in
        showLibrary = false
        if let image {
            handle(image: image)
        }
    }
    .ignoresSafeArea()
}
```

### Step 3 — UIKit wrapper with out-of-process configuration

```swift
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        // No PHPhotoLibrary passed → out-of-process, no permission prompt
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage?) -> Void
        private var didFinish = false

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !didFinish else { return }
            didFinish = true
            // load UIImage from itemProvider, call onImage on main queue
        }
    }
}
```

Key properties of this approach:

- **Out-of-process** — no `PHPhotoLibrary`, no authorization dialog, no limited-access banner.
- **Explicit presentation** — a `Bool` drives a dedicated sheet; the picker is not a `Form` row subject to list recycling.
- **Single delegate callback** — `didFinish` guard prevents double-firing if UIKit calls the delegate twice.
- **Same pattern as camera** — `ReceiptCameraPicker` already used `UIImagePickerController` via `UIViewControllerRepresentable`; library pick now mirrors that.

The shared component was extracted to `PhotoLibraryPicker.swift` and reused anywhere the app previously had a `PhotosPicker` inside a form sheet (receipt capture, feature-request screenshot attachment).

---

## Before and after

| | SwiftUI `PhotosPicker` in Form+sheet | UIKit `PHPickerViewController` in dedicated sheet |
|---|---|---|
| Photo permission | Required if `.shared()`; fragile even without | Not required |
| Face ID loops (Photos lock) | Common with in-process picker | Avoided |
| Gallery blink / relaunch | Yes, on iOS 18+ | No |
| Control over presentation | Implicit | Explicit |
| Code complexity | Fewer lines | Slightly more, but predictable |

---

## Lessons for iOS developers

**Treat SwiftUI pickers as convenience, not infrastructure.**

`PhotosPicker` is fine in simple layouts: a standalone view, a settings screen, a toolbar button with `.photosPicker(isPresented:selection:)`.
It is a liability inside nested containers that re-render aggressively (`Form`, `List`, `.sheet`, `.fullScreenCover` stacks).

**When a "fixed" bug survives a fresh install, suspect lifecycle — not state.**

Stale permissions, cached auth, and bad user defaults are real.
But if wiping the app changes nothing, you are probably looking at a structural presentation bug, not data on disk.

**Screen recordings beat stack traces for UX bugs.**

The blink loop produced no crash, no assert, no obvious log line.
Extracting frames from a 10-second clip made the relaunch pattern undeniable.

**Document the negative space.**

The final code carries a comment explaining *why* not to revert to `PhotosPicker`:

> Embedding `PhotosPicker` as a row inside a Form that lives in a sheet makes iOS repeatedly dismiss and re-present the gallery (it "blinks").

Future-you (or future-teammate) will otherwise "simplify" the code and reopen the bug.

**Reach for UIKit bridges without guilt.**

SwiftUI is the default UI layer.
UIKit is still the truth layer for system view controllers that manage their own presentation.
`UIViewControllerRepresentable` is not a failure of SwiftUI.
It is the integration point SwiftUI gives you for exactly this class of problem.

---

## Closing thought

The interesting part of this bug was not a single wrong API call.
It was a **stack of plausible fixes** that each addressed a real sub-problem while leaving the user-facing loop alive.

Removing `photoLibrary: .shared()` was correct.
Assuming that finished the job was not.

If your photo gallery blinks, Face ID keeps firing, or users report that "the picker opens and closes by itself," check permissions first — then check **where** the picker lives in your view hierarchy.

Sometimes the fix is not fewer lines of SwiftUI.
Sometimes it is one UIKit view controller, presented on your terms, once.

---

*Written from debugging Spendrift's receipt capture flow on iOS 18.
The shared picker lives in `PhotoLibraryPicker.swift`; receipt capture uses it from `ReceiptCaptureView.swift`.*
