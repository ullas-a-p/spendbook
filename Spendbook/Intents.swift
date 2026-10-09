import AppIntents
import SwiftData

/// "Hey Siri, log a spend in Spendbook" — also available in Shortcuts and Spotlight.
struct LogSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Spend"
    static let description = IntentDescription("Adds a spend to Spendbook.")

    @Parameter(title: "Amount (₹)")
    var amount: Double

    @Parameter(title: "Category", default: .other)
    var category: SpendCategory

    @Parameter(title: "Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) for \(\.$category)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = DataStore.container.mainContext
        let expense = Expense(amount: amount, category: category, note: note ?? "", date: .now)
        context.insert(expense)
        try context.save()

        let plan = BudgetStore().plan((try? context.fetch(FetchDescriptor<Expense>())) ?? [])
        let left = plan.todayLimit - plan.todaySpent
        let tail = left >= 0
            ? "\(left.inrWhole) left for today."
            : "You're \((-left).inrWhole) over today's limit."
        return .result(dialog: "Logged \(amount.inrWhole) for \(category.name). \(tail)")
    }
}

/// Used by a Shortcuts automation: "When I get a message containing 'debited'".
struct LogBankSMSIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Spend from Bank SMS"
    static let description = IntentDescription("Reads a bank or UPI debit message and adds it to Spendbook. Credits, refunds and OTPs are skipped.")
    static let openAppWhenRun = false

    @Parameter(title: "Message")
    var message: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log spend from \(\.$message)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let sms = BankSMSParser.parse(message) else {
            return .result(dialog: "Not a spend message, so nothing was added.")
        }
        let context = DataStore.container.mainContext
        let ref = sms.reference
        let existing = (try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.smsRef == ref }))) ?? []
        if !existing.isEmpty {
            return .result(dialog: "Already logged \(sms.amount.inrWhole) from this message.")
        }
        let expense = Expense(amount: sms.amount, category: sms.category,
                              note: sms.payee ?? "Bank payment", date: sms.date ?? .now,
                              source: "sms", smsRef: ref)
        context.insert(expense)
        try context.save()
        let to = sms.payee.map { " to \($0)" } ?? ""
        return .result(dialog: "Logged \(sms.amount.inrWhole)\(to).")
    }
}

struct SpendbookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSpendIntent(),
            phrases: [
                "Log a spend in \(.applicationName)",
                "Add an expense in \(.applicationName)",
                "Log \(\.$category) in \(.applicationName)"
            ],
            shortTitle: "Log Spend",
            systemImageName: "indianrupeesign.circle.fill"
        )
        AppShortcut(
            intent: LogBankSMSIntent(),
            phrases: ["Log bank SMS in \(.applicationName)"],
            shortTitle: "Log Bank SMS",
            systemImageName: "message.badge.filled.fill"
        )
    }
}
