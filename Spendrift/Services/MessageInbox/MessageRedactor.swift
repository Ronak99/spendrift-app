//
//  MessageRedactor.swift
//  Spendrift
//
//  Strips OTPs and masks account-length digit runs before SMS bodies are stored or uploaded.
//

import Foundation

enum MessageRedactor {
    /// Words that mark a message as OTP / verification traffic.
    /// Bare "pin" and bare "code" are deliberately absent: they appear in legitimate
    /// bank alerts ("ATM PIN changed") and would anchor masking onto real amounts.
    private static let otpAnchorPattern =
        #"(?i)\b(?:otps?|o\.t\.p\.?|one[-\s]?time\s+(?:password|passcode|pin|code)|verification\s+code|security\s+code|authentication\s+code|auth\s+code|passcode)\b"#

    /// Verbs that mean money has already moved. Used only to decide whether an
    /// OTP-bearing message is worth keeping, never to parse the transaction itself.
    /// Bare nouns ("payment", "charge", "transaction") are excluded on purpose --
    /// they are common in OTP authorisation requests, whereas a genuine alert that
    /// also carries an OTP practically always uses a completed verb.
    private static let completedMovementPattern =
        #"(?i)\b(?:debited|credited|spent|withdrawn|paid|charged|transferred|received|deposited|refunded|reversed|dr|cr)\b"#

    /// Whole digit runs an OTP could plausibly be.
    private static let otpDigitPattern = #"(?<!\d)\d{4,8}(?!\d)"#

    /// Digit runs long enough to be an account / card / reference number.
    private static let accountDigitPattern = #"\d{9,}"#

    /// How far from an OTP keyword a digit run may sit and still be treated as the code.
    private static let anchorWindow = 40

    /// Collapse digit runs of 9+ to `****NNNN` (last 4 kept) and blank OTP-like codes.
    /// Runs of 8 digits or fewer survive untouched unless they sit next to an OTP
    /// keyword, so amounts such as `INR 12500` and `Rs.150000.00` come through intact.
    static func redact(_ body: String) -> String {
        maskLongDigitRuns(in: redactOTPCodes(in: body))
    }

    /// True when the message is OTP / verification traffic with no completed money
    /// movement in it. Such messages are never transactions, so callers drop them
    /// rather than storing and uploading a body that reads "[OTP redacted]".
    static func isOTPOnlyMessage(_ body: String) -> Bool {
        containsOTPAnchor(body) && !containsCompletedMovement(body)
    }

    static func containsOTPAnchor(_ body: String) -> Bool {
        body.range(of: otpAnchorPattern, options: .regularExpression) != nil
    }

    static func containsCompletedMovement(_ body: String) -> Bool {
        body.range(of: completedMovementPattern, options: .regularExpression) != nil
    }

    // MARK: - Step 1-3: anchor, window, amount guard

    /// Finds OTP keywords, then blanks 4-8 digit runs within `anchorWindow` characters
    /// of one -- looking both directions, so "OTP is 482913" and "482913 is your OTP"
    /// are the same case. Amount-shaped runs inside the window are left alone.
    private static func redactOTPCodes(in body: String) -> String {
        guard
            let anchorRegex = try? NSRegularExpression(pattern: otpAnchorPattern),
            let digitRegex = try? NSRegularExpression(pattern: otpDigitPattern)
        else { return body }

        let nsBody = body as NSString
        let fullRange = NSRange(location: 0, length: nsBody.length)
        let anchors = anchorRegex.matches(in: body, range: fullRange).map(\.range)
        guard !anchors.isEmpty else { return body }

        let targets = digitRegex.matches(in: body, range: fullRange)
            .map(\.range)
            .filter { run in
                guard let anchor = anchor(near: run, in: anchors) else { return false }
                // A run touching the keyword is the code, whatever it looks like.
                if isAdjacent(run: run, to: anchor, in: nsBody) { return true }
                return !isAmountShaped(run: run, in: nsBody)
            }

        // Replace back-to-front so earlier ranges stay valid.
        var result = body
        for range in targets.sorted(by: { $0.location > $1.location }) {
            guard let stringRange = Range(range, in: result) else { continue }
            result.replaceSubrange(stringRange, with: "[OTP redacted]")
        }
        return result
    }

    /// The first OTP keyword within the window on either side of `run`.
    private static func anchor(near run: NSRange, in anchors: [NSRange]) -> NSRange? {
        anchors.first { anchor in
            let gap: Int
            if anchor.upperBound <= run.location {
                gap = run.location - anchor.upperBound
            } else if run.upperBound <= anchor.location {
                gap = anchor.location - run.upperBound
            } else {
                gap = 0
            }
            return gap <= anchorWindow
        }
    }

    /// Keyword and digits separated by nothing but spaces or `:` / `=` / `-`.
    private static func isAdjacent(run: NSRange, to anchor: NSRange, in nsBody: NSString) -> Bool {
        guard anchor.upperBound <= run.location else { return false }
        let gap = nsBody.substring(
            with: NSRange(location: anchor.upperBound, length: run.location - anchor.upperBound)
        )
        return gap.range(of: #"^[\s:=\-]*$"#, options: .regularExpression) != nil
    }

    /// Amount guard: a currency cue immediately before the digits, or a decimal part
    /// straight after. Comma-grouped amounts ("Rs 1,23,456") split into runs shorter
    /// than four digits and never reach this check.
    private static func isAmountShaped(run: NSRange, in nsBody: NSString) -> Bool {
        let prefixStart = max(0, run.location - 12)
        let prefix = nsBody.substring(
            with: NSRange(location: prefixStart, length: run.location - prefixStart)
        )
        if prefix.range(of: #"(?i)(?:inr|rs\.?|₹|\$|usd)\s*$"#, options: .regularExpression) != nil {
            return true
        }

        let suffixLength = min(4, nsBody.length - run.upperBound)
        guard suffixLength > 0 else { return false }
        let suffix = nsBody.substring(with: NSRange(location: run.upperBound, length: suffixLength))
        return suffix.range(of: #"^\.\d{1,2}(?!\d)"#, options: .regularExpression) != nil
    }

    // MARK: - Account / card / reference numbers

    private static func maskLongDigitRuns(in body: String) -> String {
        guard let digitRegex = try? NSRegularExpression(pattern: accountDigitPattern) else {
            return body
        }
        let nsBody = body as NSString
        let matches = digitRegex.matches(
            in: body,
            range: NSRange(location: 0, length: nsBody.length)
        )
        var result = body
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let digits = String(result[range])
            let last4 = String(digits.suffix(4))
            result.replaceSubrange(range, with: "****\(last4)")
        }
        return result
    }
}
