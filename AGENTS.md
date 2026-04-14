# Spendrift — Agent Instructions

## Overview

Spendrift is a native iOS personal finance / expense tracking app built with **Swift**, **SwiftUI**, and **SwiftData**. It targets **iPhone only** (iOS 18.5+, Xcode 16.4+). There are **zero third-party dependencies** — only Apple frameworks.

### Xcode Targets

| Target | Purpose |
|---|---|
| `Spendrift` | Main app |
| `SpendriftTests` | Unit tests (Swift Testing + XCTest) |
| `SpendriftUITests` | UI tests |
| `SpendriftWidget` | WidgetKit extension |

### External Services

The only external dependency is the **OpenAI API** (for voice transaction parsing and bank statement PDF import). The API key is injected via `.xcconfig` files (`Spendrift/Configuration/DevSecrets.xcconfig` and `ProdSecrets.xcconfig`), which are gitignored. Manual transaction entry works without the key.

## Cursor Cloud specific instructions

### Environment limitations

This is a pure iOS/Xcode project. **Full compilation and on-device/simulator testing require macOS with Xcode 16.4+.** The Linux Cloud Agent VM cannot build or run the `.app` target. However, the following development tasks are fully supported on the Linux VM:

### Available on Linux

- **Linting**: `swiftlint lint` — runs SwiftLint (static binary) against all 98 Swift source files. No `.swiftlint.yml` config exists in the repo, so default rules apply.
- **Syntax validation**: `swiftc -parse <file.swift>` — verifies Swift syntax for individual files. Run against all files: `find . -name "*.swift" | xargs -I{} swiftc -parse {}`
- **Code review and editing**: All source files can be read/modified normally.

### Key conventions

- The Xcode scheme is called `MyMoney` (at `Spendrift.xcodeproj/xcshareddata/xcschemes/MyMoney.xcscheme`), not `Spendrift`.
- Swift version: 5.0 (per `project.pbxproj`); the project compiles with Xcode 16.4 / Swift 6 compiler in Swift 5 language mode.
- No package managers (no SPM `Package.swift`, no CocoaPods, no Carthage).
- The `.gitignore` only ignores `*.xcconfig` (secret config files containing `OPENAI_API_KEY`).

### On macOS (for reference)

- **Build**: Open `Spendrift.xcodeproj` in Xcode, select an iPhone simulator, ⌘B.
- **Run tests**: ⌘U (runs both `SpendriftTests` and `SpendriftUITests` via the `MyMoney` scheme).
- **API key setup**: Create `Spendrift/Configuration/DevSecrets.xcconfig` with `OPENAI_API_KEY = sk-...`.
