import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// What we understood from a typed or spoken sentence like "lunch 180 at office".
struct ParsedSpend {
    var amount: Double?
    var category: SpendCategory?
    var note: String?
    var date: Date?
    var usedAppleIntelligence = false
}

enum SpendParser {
    /// Uses the on-device Apple Intelligence model when it is available,
    /// and falls back to simple keyword matching otherwise.
    static func parse(_ text: String) async -> ParsedSpend {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ParsedSpend() }
        #if canImport(FoundationModels)
        if let ai = await parseWithAppleIntelligence(trimmed) {
            return ai
        }
        #endif
        return parseLocally(trimmed)
    }

    // MARK: On-device keyword parser

    static func parseLocally(_ text: String) -> ParsedSpend {
        var result = ParsedSpend()
        let lower = text.lowercased()

        // Amount: first number, allowing 1,200 or 45.50 or ₹300 or 300rs
        let cleaned = lower.replacingOccurrences(of: ",", with: "")
        if let range = cleaned.range(of: #"\d+(\.\d{1,2})?"#, options: .regularExpression) {
            result.amount = Double(cleaned[range])
        }

        let words = lower
            .replacingOccurrences(of: "₹", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for category in SpendCategory.allCases where result.category == nil {
            if words.contains(where: { category.keywords.contains($0) }) {
                result.category = category
            }
        }

        let cal = Calendar.current
        if words.contains("yesterday") {
            result.date = cal.date(byAdding: .day, value: -1, to: .now)
        } else if let index = words.firstIndex(of: "ago"), index > 0,
                  let n = Int(words[index - 1]) ?? wordNumber(words[index - 1]) {
            result.date = cal.date(byAdding: .day, value: -n, to: .now)
        } else if words.contains("today") {
            result.date = .now
        }

        let stop: Set<String> = ["rs", "inr", "rupees", "rupee", "for", "on", "at", "in", "the", "a", "an",
                                 "spent", "paid", "yesterday", "today", "ago", "days", "day", "of", "to", "and", "my"]
        // Note: the first run of words, skipping numbers, ending at a linking word.
        var noteWords: [String] = []
        for word in text.replacingOccurrences(of: "₹", with: " ").components(separatedBy: .whitespaces) {
            let w = word.trimmingCharacters(in: .punctuationCharacters)
            let lw = w.lowercased()
            if lw.isEmpty { continue }
            let numeric = lw.replacingOccurrences(of: ",", with: "")
            if Double(numeric) != nil { continue }
            if lw.hasSuffix("rs"), Double(numeric.dropLast(2)) != nil { continue }
            if stop.contains(lw) {
                if noteWords.isEmpty { continue } else { break }
            }
            noteWords.append(w)
            if noteWords.count == 3 { break }
        }
        if !noteWords.isEmpty {
            let note = noteWords.joined(separator: " ")
            result.note = note.prefix(1).uppercased() + note.dropFirst()
        }
        return result
    }

    private static func wordNumber(_ word: String) -> Int? {
        ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7][word]
    }

    // MARK: Apple Intelligence

    #if canImport(FoundationModels)
    @Generable
    struct AISpend {
        @Guide(description: "Amount of money spent, in Indian rupees, as a number")
        var amount: Double
        @Guide(description: "One of: food, groceries, transport, fuel, shopping, bills, rent, health, fun, other")
        var category: String
        @Guide(description: "A short note naming what was bought, 1 to 3 words, first letter capitalised")
        var note: String
        @Guide(description: "How many days ago it happened: 0 for today, 1 for yesterday")
        var daysAgo: Int
    }

    static func parseWithAppleIntelligence(_ text: String) async -> ParsedSpend? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        do {
            let session = LanguageModelSession(instructions: """
                You read one short sentence where a person in India describes money they spent, \
                and extract the amount, a category, a short note and how many days ago it was.
                """)
            let response = try await session.respond(to: text, generating: AISpend.self)
            let spend = response.content
            var parsed = ParsedSpend(usedAppleIntelligence: true)
            parsed.amount = spend.amount > 0 ? spend.amount : nil
            parsed.category = SpendCategory(rawValue: spend.category.lowercased())
            parsed.note = spend.note.isEmpty ? nil : spend.note
            parsed.date = Calendar.current.date(byAdding: .day, value: -max(spend.daysAgo, 0), to: .now)
            // Keep keyword matches when the model leaves something out.
            let local = parseLocally(text)
            if parsed.amount == nil { parsed.amount = local.amount }
            if parsed.category == nil { parsed.category = local.category }
            return parsed
        } catch {
            return nil
        }
    }
    #endif
}
