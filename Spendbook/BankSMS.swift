import Foundation

/// A spend read from a bank / UPI text message.
struct BankSMS: Equatable {
    var amount: Double
    var payee: String?
    var date: Date?
    var reference: String
    var category: SpendCategory
}

/// Reads Indian bank and UPI debit messages, for example
/// "Dear UPI user A/C X0705 debited by 75.00 on date 23Jul26 trf to SAJITH E Refno 657041341221 ... -SBI"
/// "Rs.500.00 debited from A/c XX1234 on 08-10-26 to VPA zomato@paytm (UPI Ref No 123456789012)"
/// "INR 1,240.00 spent on HDFC Bank Card x1234 at AMAZON on 2026-10-08"
/// "Sent Rs.40.00 From HDFC Bank A/C x1234 To CHAI POINT On 08/10/26 Ref 123456789012"
/// Credits, refunds, failed payments and OTP messages return nil.
enum BankSMSParser {

    static func parse(_ raw: String, now: Date = .now) -> BankSMS? {
        let text = raw
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()
        guard !text.isEmpty else { return nil }

        // Skip things that are not money going out.
        let skip = ["otp", "one time password", "one-time password", "verification code",
                    "refund", "reversed", "reversal", "failed", "declined", "unsuccessful",
                    "will be debited", "is due", "due on", "request", "requested money", "collect request"]
        if skip.contains(where: { lower.contains($0) }) { return nil }

        let debitWords = ["debited", "spent", "sent rs", "sent inr", "sent ₹", "paid", "withdrawn",
                          "purchase", "deducted", "txn of", "transaction of", "trf to", "transferred to"]
        guard debitWords.contains(where: { lower.contains($0) }) else { return nil }

        // A message that only talks about money coming in is not a spend.
        if lower.contains("credited") && !lower.contains("debited") && !lower.contains("spent")
            && !lower.contains("sent") && !lower.contains("paid") {
            return nil
        }

        guard let amount = findAmount(lower), amount > 0, amount < 10_000_000 else { return nil }

        let payee = findPayee(text)
        let date = findDate(text, now: now)
        let reference = findReference(text) ?? "h" + stableHash(lower)
        let category = SpendCategory.guess(from: (payee ?? "") + " " + lower) ?? .other

        return BankSMS(amount: amount, payee: payee, date: date, reference: reference, category: category)
    }

    // MARK: Amount

    private static let number = #"([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
    private static let currency = #"(?:rs\.?|inr|₹)"#

    static func findAmount(_ lower: String) -> Double? {
        // Amounts that sit right next to a debit word come first, so a balance
        // ("Avl Bal Rs 12,000") later in the message is not picked up.
        let patterns = [
            #"debited (?:by|for|with)\s*"# + currency + #"?\s*"# + number,
            #"(?:spent|paid|sent|withdrawn|deducted)\s*(?:of|for)?\s*"# + currency + #"\s*"# + number,
            #"(?:txn|transaction|purchase) of\s*"# + currency + #"?\s*"# + number,
            currency + #"\s*"# + number + #"\s*(?:has been |is |was )?(?:debited|spent|paid|sent|withdrawn|deducted)"#,
            currency + #"\s*"# + number
        ]
        for pattern in patterns {
            if let value = firstGroup(pattern, in: lower), let amount = Double(value.replacingOccurrences(of: ",", with: "")) {
                return amount
            }
        }
        return nil
    }

    // MARK: Payee

    static func findPayee(_ text: String) -> String? {
        let stops = #"(?=\s+(?:on|ref|refno|ref\.|upi|avl|avail|bal|via|using|if|from|for|txn|dated|date|not|call|-)\b|[.;(]|\s*$)"#
        let patterns = [
            #"(?i)\bvpa\s+([A-Za-z0-9.\-_]+@[A-Za-z0-9.\-_]+)"#,
            #"(?i)\b(?:trf to|transferred to|transfer to|paid to|sent to)\s+([A-Za-z0-9@&'._ \-]{2,40}?)"# + stops,
            #"(?i)\bat\s+([A-Za-z0-9@&'._ \-]{2,40}?)"# + stops,
            #"(?i)\bto\s+([A-Za-z@&'._ \-][A-Za-z0-9@&'._ \-]{1,39}?)"# + stops,
            #"(?i)\binfo[:\s]+([A-Za-z0-9@&'._ \-/]{2,40}?)"# + stops
        ]
        for pattern in patterns {
            guard var name = firstGroup(pattern, in: text)?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { continue }
            let lowerName = name.lowercased()
            if lowerName.hasPrefix("a/c") || lowerName.hasPrefix("your") || lowerName.hasPrefix("ac ") { continue }
            if let at = name.firstIndex(of: "@") {
                name = String(name[..<at])
            }
            name = name.replacingOccurrences(of: "[._]", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            guard name.count >= 2 else { continue }
            return name.capitalized
        }
        return nil
    }

    // MARK: Date

    static func findDate(_ text: String, now: Date) -> Date? {
        let pattern = #"(?i)\b(\d{1,2}[-/ ]?[A-Za-z]{3}[-/ ]?\d{2,4}|\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}|\d{4}-\d{2}-\d{2})\b"#
        guard let token = firstGroup(pattern, in: text) else { return nil }
        let formats = ["ddMMMyy", "dMMMyy", "ddMMMyyyy", "dd-MMM-yy", "d-MMM-yy", "dd-MMM-yyyy", "dd MMM yy",
                       "dd MMM yyyy", "dd/MMM/yy", "dd-MM-yy", "d-M-yy", "dd/MM/yy", "d/M/yy", "dd-MM-yyyy",
                       "dd/MM/yyyy", "dd.MM.yy", "dd.MM.yyyy", "yyyy-MM-dd"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: token) {
                let cal = Calendar.current
                // Ignore dates in the future or more than a year back (likely a misread).
                guard date <= now.addingTimeInterval(86_400),
                      date > cal.date(byAdding: .year, value: -1, to: now) ?? .distantPast else { return nil }
                if cal.isDate(date, inSameDayAs: now) { return now }
                return cal.date(bySettingHour: 12, minute: 0, second: 0, of: date)
            }
        }
        return nil
    }

    // MARK: Reference

    static func findReference(_ text: String) -> String? {
        firstGroup(#"(?i)\b(?:upi\s*ref(?:\s*no)?|ref\s*no|refno|ref|utr|rrn|txn\s*id|transaction\s*id)[\s.:#-]*([A-Za-z0-9]{6,})"#, in: text)
    }

    // MARK: Helpers

    private static func firstGroup(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }

    /// FNV-1a hash, stable between launches (unlike Swift's hashValue).
    private static func stableHash(_ s: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}
