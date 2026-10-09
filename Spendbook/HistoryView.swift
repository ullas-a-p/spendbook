import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(\.modelContext) private var context

    @State private var search = ""
    @State private var filter: SpendCategory?
    @State private var month: Date = .now

    private var cal: Calendar { Calendar.current }

    /// Months that have spends, plus the current month, newest first.
    private var months: [Date] {
        var starts = Set(expenses.compactMap { cal.dateInterval(of: .month, for: $0.date)?.start })
        if let current = cal.dateInterval(of: .month, for: .now)?.start { starts.insert(current) }
        return starts.sorted(by: >)
    }

    private var filtered: [Expense] {
        let interval = cal.dateInterval(of: .month, for: month)
        let query = search.trimmingCharacters(in: .whitespaces)
        return expenses.filter { e in
            if let interval, !interval.contains(e.date) { return false }
            if let filter, e.category != filter { return false }
            if !query.isEmpty {
                return e.note.localizedCaseInsensitiveContains(query)
                    || e.category.name.localizedCaseInsensitiveContains(query)
                    || e.amount.inrWhole.contains(query)
            }
            return true
        }
    }

    var body: some View {
        let groups = groupByDay(filtered)
        let total = filtered.reduce(0) { $0 + $1.amount }

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        filterChips
                        Text("\(month.monthYear) · \(filtered.count) spend\(filtered.count == 1 ? "" : "s") · \(total.inrWhole)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.secondary)
                            .monospacedDigit()
                            .padding(.horizontal, 20)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if groups.isEmpty {
                    Section {
                        ContentUnavailableView(
                            search.isEmpty ? "Nothing logged" : "No matches",
                            systemImage: search.isEmpty ? "tray" : "magnifyingglass",
                            description: Text(search.isEmpty
                                              ? "Spends you add for \(month.monthYear) show up here."
                                              : "Try another word, like a note or category.")
                        )
                        .listRowBackground(Color.clear)
                    }
                }

                ForEach(groups) { group in
                    Section {
                        ForEach(group.items) { expense in
                            ExpenseRow(expense: expense, showDivider: false)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowBackground(Color.white.opacity(0.07))
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        withAnimation { context.delete(expense) }
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text(group.day == cal.startOfDay(for: .now) || cal.isDateInYesterday(group.day)
                                 ? "\(group.day.relativeDayLabel) · \(group.day.weekdayDayMonth)"
                                 : group.day.weekdayDayMonth)
                            Spacer()
                            Text(group.total.inrWhole).monospacedDigit()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(14)
            .scrollContentBackground(.hidden)
            .background(AmbientBackground())
            .navigationTitle("History")
            .searchable(text: $search, prompt: "Search spends or notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(months, id: \.self) { m in
                            Button {
                                month = m
                            } label: {
                                if cal.isDate(m, equalTo: month, toGranularity: .month) {
                                    Label(m.monthYear, systemImage: "checkmark")
                                } else {
                                    Text(m.monthYear)
                                }
                            }
                        }
                    } label: {
                        Label(month.monthYear, systemImage: "calendar")
                    }
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip("All", selected: filter == nil) { filter = nil }
                ForEach(SpendCategory.allCases) { c in
                    chip(c.name, selected: filter == c) { filter = (filter == c ? nil : c) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Theme.onAccent : .white)
                .padding(.horizontal, 15)
                .frame(height: 34)
                .background(selected ? Theme.accent : Theme.card, in: Capsule())
                .overlay { if !selected { Capsule().strokeBorder(Theme.separator) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
