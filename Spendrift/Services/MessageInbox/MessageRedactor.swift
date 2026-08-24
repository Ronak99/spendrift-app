//
//  MessageRedactor.swift
//  Spendrift
//
//  Strips OTPs and masks long digit runs before SMS bodies are stored or uploaded.
//

import Foundation

enum MessageRedactor {
    /// Collapse digit runs of 5+ to `****NNNN` (last 4 kept) and blank OTP-like phrases.
    static func redact(_ body: String) -> String {
        var result = body

        // OTP / one-time password phrases with nearby digits.
        let otpPatterns = [
            #"(?i)\b(?:otp|one[-\s]?time\s+(?:password|pin|code)|verification\s+code)\s*[:=]?\s*\d{4,8}\b"#,
            #"(?i)\b(?:is|code)\s+\d{4,8}\s+(?:is\s+your\s+)?(?:otp|one[-\s]?time)\b"#,
        ]
        for pattern in otpPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: "[OTP redacted]"
            )
        }

        // Digit runs of length 5+: keep last 4, mask the rest.
        guard let digitRegex = try? NSRegularExpression(pattern: #"\d{5,}"#) else {
            return result
        }
        let nsResult = result as NSString
        let matches = digitRegex.matches(
            in: result,
            range: NSRange(location: 0, length: nsResult.length)
        )
        var rebuilt = result
        for match in matches.reversed() {
            guard let range = Range(match.range, in: rebuilt) else { continue }
            let digits = String(rebuilt[range])
            let last4 = String(digits.suffix(4))
            rebuilt.replaceSubrange(range, with: "****\(last4)")
        }
        return rebuilt
    }
}
