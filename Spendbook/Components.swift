import SwiftUI
import SwiftData

/// One spend in a list.
struct ExpenseRow: View {
    let expense: Expense
    var showDivider = true

    var body: some View {
        HStack(spacing: 12) {
            CategoryTile(category: expense.category)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(expense.title)
                        .font(.system(size: 16))
                        .lineLimit(1)
                    Text("\(expense.category.name) · \(expense.date.time)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer(minLength: 8)
                Text(expense.amount.inr)
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }
            .padding(.vertical, 11)
            .padding(.trailing, 16)
            .overlay(alignment: .bottom) {
                if showDivider {
                    Rectangle().fill(Theme.separator).frame(height: 0.5)
                }
            }
        }
        .padding(.leading, 16)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A rounded card of expense rows with a delete action on long-press.
struct ExpenseGroup: View {
    let expenses: [Expense]
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                ExpenseRow(expense: expense, showDivider: index < expenses.count - 1)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            withAnimation { context.delete(expense) }
                        }
                    }
            }
        }
        .card(22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String = ""

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .bold))
            Spacer()
            Text(trailing)
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 4)
    }
}

/// Big bold screen title with a small uppercase line above it.
struct ScreenTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.6)
                    .foregroundStyle(Theme.secondary)
            }
            Text(title)
                .font(.system(size: 34, weight: .heavy))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
