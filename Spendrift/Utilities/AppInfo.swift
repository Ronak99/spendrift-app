//
//  AppInfo.swift
//  Spendrift
//
//  Shared app and device metadata for feedback, launch logging, and settings.
//

import Darwin
import Foundation

enum AppInfo {
    static func appVersionLabel() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    /// Hardware machine identifier (e.g. iPhone17,1). Never the user-assigned device name.
    static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "unknown"
            }
        }
    }
}
