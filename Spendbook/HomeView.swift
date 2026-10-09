import SwiftUI
import SwiftData

struct HomeView: View {
    @Binding var showAdd: Bool
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(BudgetStore.self) private var budget
    @Environment(\.modelContext) private var context

    var body: some View {
        let stats = MonthStats(all: expenses, month: .now, budget: budget.monthly, daily: budget.daily)
        let plan = budget.plan(expenses)
        let recentDays = Array(groupByDay(Array(expenses.prefix(60))).prefix(3))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ScreenTitle(title: Date.now.monthName,
                                subtitle: Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                        .padding(.top, 8)

                    LimitCard(plan: plan, monthLeft: stats.remaining)

                    monthCard(stats)

                    HStack(spacing: 12) {
                        statCard(title: "Today",
                                 value: plan.todaySpent.inrWhole,
                                 detail: "of \(plan.todayLimit.inrWhole) limit",
                                 color: plan.isOverToday ? Theme.warnText : .white)
                        statCard(title: "This week",
                                 value: max(plan.weekLeft, 0).inrWhole,
                                 detail: plan.weekLeft >= 0 ? "left of \(plan.weekly.inrWhole)" : "\((-plan.weekLeft).inrWhole) over the week",
                                 color: plan.weekLeft >= 0 ? Theme.accent : Theme.warnText)
                    }

                    WeekStrip(plan: plan)

                    if expenses.isEmpty {
                        emptyState
                    } else {
                        ForEach(recentDays) { group in
                            SectionHeader(title: group.day.relativeDayLabel,
                                          trailing: group.total.inrWhole)
                            ExpenseGroup(expenses: group.items)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AmbientBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func monthCard(_ s: MonthStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spent this month")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
            Text(s.total.inrWhole)
                .font(.rounded(46, .heavy))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy, value: s.total)
            ProgressLine(fraction: s.usedFraction,
                         color: s.usedFraction > 1 ? Theme.warn : Theme.accent,
                         height: 10)
            HStack {
                if s.remaining >= 0 {
                    Text("\(Text(s.remaining.inrWhole).bold().foregroundStyle(.white)) left of \(s.budget.inrWhole)")
                } else {
                    Text("\(Text((-s.remaining).inrWhole).bold().foregroundStyle(Theme.warnText)) over \(s.budget.inrWhole)")
                }
                Spacer()
                Text("\(s.daysLeftAfterToday) days to go")
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.secondary)
            .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(28, tint: Theme.accent.opacity(0.18))
    }

    private func statCard(title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13)).foregroundStyle(Theme.secondary)
            Text(value)
                .font(.rounded(26, .heavy))
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail).font(.system(size: 13)).foregroundStyle(Theme.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(22)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "indianrupeesign.circle")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent)
            Text("No spends yet")
                .font(.system(size: 20, weight: .bold))
            Text("Tap + to log what you paid. Your daily and monthly totals update as you go.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
            Button("Add your first spend") { showAdd = true }
                .buttonStyle(.glassProminent)
                .padding(.top, 4)
            Button("Or fill in sample data to try the app") {
                SampleData.insert(into: context)
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .card()
    }
}
