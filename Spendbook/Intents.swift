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

        let stats = MonthStats(all: (try? context.fetch(FetchDescriptor<Expense>())) ?? [],
                               month: .now,
                               budget: BudgetStore().monthly)
        let left = stats.todayLimit - stats.todaySpent
        let tail = left >= 0
            ? "\(left.inrWhole) left for today."
            : "You're \((-left).inrWhole) over today's limit."
        return .result(dialog: "Logged \(amount.inrWhole) for \(category.name). \(tail)")
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
    }
}
