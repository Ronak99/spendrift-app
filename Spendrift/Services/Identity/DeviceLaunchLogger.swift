//
//  DeviceLaunchLogger.swift
//  Spendrift
//
//  Records install and launch metadata in Supabase via the backend proxy.
//  Fire-and-forget on process start; never blocks app launch.
//

import Foundation
import UIKit

enum DeviceLaunchLogger {
    static func record() {
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else { return }

        Task {
            do {
                let client = try SpendriftBackendClient()
                try await client.recordDeviceLaunch(
                    deviceID: DeviceIdentity.current,
                    posthogID: Analytics.posthogDistinctId,
                    device: AppInfo.machineIdentifier,
                    iosVersion: UIDevice.current.systemVersion,
                    appVersion: AppInfo.appVersionLabel()
                )
            } catch {
                Diagnostics.log(
                    "Device launch logging failed",
                    level: .warning,
                    tags: [
                        Diagnostics.Tag.feature: Diagnostics.Feature.app.rawValue,
                        Diagnostics.Tag.stage: Diagnostics.Stage.bootstrap.rawValue,
                        Diagnostics.Tag.errorDomain: (error as NSError).domain,
                        Diagnostics.Tag.errorCode: String((error as NSError).code),
                    ]
                )
            }
        }
    }
}
