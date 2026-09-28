//
//  EmailInboxAddress.swift
//  Spendrift
//
//  The personal address a user forwards receipts to. The +tag is the tail of the
//  device id, so the app can fetch its own emails from the backend without an
//  account, and the address survives reinstalls along with the Keychain id.
//

import Foundation

enum EmailInboxAddress {
    static let localPart = "expense"
    static let domain = "ronakpunase.dev"
    static let tagLength = 5

    /// Lowercase tail of the device id. The backend stores emails under this key.
    static var tag: String {
        tag(forDeviceID: DeviceIdentity.current)
    }

    static func tag(forDeviceID deviceID: String) -> String {
        String(deviceID.suffix(tagLength)).lowercased()
    }

    /// `expense+<tag>@ronakpunase.dev`
    static var address: String {
        address(forTag: tag)
    }

    static func address(forTag tag: String) -> String {
        "\(localPart)+\(tag)@\(domain)"
    }
}
