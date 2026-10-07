import Foundation

struct CategoryTotal: Identifiable {
    let category: SpendCategory
    let amount: Double
    var id: String { category.rawValue }
}

/// All the numbers for one calendar month.
struct MonthStats {
    private let cal = Calendar.current

    let monthStart: Date
    let monthEnd: Date
    let expenses: [Expense]
    let budget: Double
    let now: Date

    init(all: [Expense], month: Date, budget: Double, now: Date = .now) {
        let interval = Calendar.current.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, duration: 86_400 * 30)
        monthStart = interval.start
        monthEnd = interval.end
        expenses = all.filter { $0.date >= interval.start && $0.date < interval.end }
        self.budget = budget
        self.now = now
    }

    var total: Double { expenses.reduce(0) { $0 + $1.amount } }
    var remaining: Double { budget - total }
    var usedFraction: Double { budget > 0 ? total / budget : 0 }

    var daysInMonth: Int { cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30 }
    var isCurrentMonth: Bool { now >= monthStart && now < monthEnd }
    var isFutureMonth: Bool { monthStart > now }

    /// Day of month of "now" when this is the current month, otherwise the full month.
    var daysElapsed: Int {
        if isCurrentMonth { return cal.component(.day, from: now) }
        return isFutureMonth ? 0 : daysInMonth
    }

    /// Days after today until the month ends.
    var daysLeftAfterToday: Int { isCurrentMonth ? daysInMonth - daysElapsed : 0 }

    var averagePerDay: Double { daysElapsed > 0 ? total / Double(daysElapsed) : 0 }

    /// Even pace that uses the budget up exactly by month end.
    var pacePerDay: Double { budget / Double(daysInMonth) }

    var byDay: [Int: Double] {
        var result: [Int: Double] = [:]
        for e in expenses {
            result[cal.component(.day, from: e.date), default: 0] += e.amount
        }
        return result
    }

    var byCategory: [CategoryTotal] {
        var sums: [SpendCategory: Double] = [:]
        for e in expenses { sums[e.category, default: 0] += e.amount }
        return sums.map { CategoryTotal(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    func spent(in category: SpendCategory) -> Double {
        expenses.filter { $0.category == category }.reduce(0) { $0 + $1.amount }
    }

    // MARK: Today

    var todayExpenses: [Expense] { expenses.filter { cal.isDate($0.date, inSameDayAs: now) } }
    var todaySpent: Double { todayExpenses.reduce(0) { $0 + $1.amount } }

    /// What is left before today, spread over today and the remaining days.
    var todayLimit: Double {
        guard isCurrentMonth else { return pacePerDay }
        let before = total - todaySpent
        let days = Double(daysLeftAfterToday + 1)
        return max(budget - before, 0) / days
    }

    /// Safe amount per day from tomorrow, given what is left now.
    var safePerDay: Double {
        let days = max(daysLeftAfterToday, 1)
        return max(remaining, 0) / Double(days)
    }

    var overLimitDays: Int { byDay.values.filter { $0 > pacePerDay }.count }

    /// Monday-first column (0...6) of the 1st of the month.
    var firstWeekdayColumn: Int {
        let weekday = cal.component(.weekday, from: monthStart) // 1 = Sunday
        return (weekday + 5) % 7
    }
}

struct DayGroup: Identifiable {
    let day: Date
    let items: [Expense]
    var id: Date { day }
    var total: Double { items.reduce(0) { $0 + $1.amount } }
}

/// Expenses grouped by calendar day, newest first.
func groupByDay(_ expenses: [Expense]) -> [DayGroup] {
    let cal = Calendar.current
    let groups = Dictionary(grouping: expenses) { cal.startOfDay(for: $0.date) }
    return groups
        .map { DayGroup(day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
        .sorted { $0.day > $1.day }
}
