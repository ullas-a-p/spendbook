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
    /// The daily limit the user set; falls back to an even split of the monthly budget.
    let dailyLimit: Double?

    init(all: [Expense], month: Date, budget: Double, daily: Double? = nil, now: Date = .now) {
        let interval = Calendar.current.dateInterval(of: .month, for: month)
            ?? DateInterval(start: month, duration: 86_400 * 30)
        monthStart = interval.start
        monthEnd = interval.end
        expenses = all.filter { $0.date >= interval.start && $0.date < interval.end }
        self.budget = budget
        self.now = now
        self.dailyLimit = daily
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
    var pacePerDay: Double { dailyLimit ?? budget / Double(daysInMonth) }

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


// MARK: - Weekly plan

/// One day of the current week (Monday to Sunday).
struct WeekDay: Identifiable {
    let date: Date
    let spent: Double
    let isToday: Bool
    let isFuture: Bool
    /// What this day is allowed: the daily limit, or less when overspending is carried over.
    let allowance: Double
    var id: Date { date }
    var letter: String { date.formatted(.dateTime.weekday(.narrow)) }
}

/// Daily and weekly limits, with today's overspend taken out of the rest of the week.
struct LimitPlan {
    let daily: Double
    let weekly: Double
    let carryOver: Bool
    let todaySpent: Double
    let spentThisWeek: Double
    let spentBeforeToday: Double
    /// Days left in the week, today included (1...7).
    let daysLeft: Int
    let days: [WeekDay]

    init(all: [Expense], daily: Double, weekly: Double, carryOver: Bool, now: Date = .now) {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = cal.startOfDay(for: now)
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? today

        var perDay: [Date: Double] = [:]
        for e in all where e.date >= weekStart && e.date < weekEnd {
            perDay[cal.startOfDay(for: e.date), default: 0] += e.amount
        }
        let todaySpent = perDay[today] ?? 0
        let thisWeek = perDay.values.reduce(0, +)
        let elapsed = cal.dateComponents([.day], from: weekStart, to: today).day ?? 0

        self.daily = daily
        self.weekly = weekly
        self.carryOver = carryOver
        self.todaySpent = todaySpent
        self.spentThisWeek = thisWeek
        self.spentBeforeToday = thisWeek - todaySpent
        self.daysLeft = max(7 - elapsed, 1)

        // Allowance for today, and for each day after today.
        let todayAllowance = LimitPlan.allowance(daily: daily, weekly: weekly, carryOver: carryOver,
                                                 spentSoFar: thisWeek - todaySpent, days: max(7 - elapsed, 1))
        let futureAllowance = LimitPlan.allowance(daily: daily, weekly: weekly, carryOver: carryOver,
                                                  spentSoFar: thisWeek, days: max(6 - elapsed, 1))
        days = (0..<7).compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let isToday = d == today
            let isFuture = d > today
            return WeekDay(date: d, spent: perDay[d] ?? 0, isToday: isToday, isFuture: isFuture,
                           allowance: isToday ? todayAllowance : (isFuture ? futureAllowance : daily))
        }
    }

    /// The daily limit, cut down if what is left of the week can't cover it.
    private static func allowance(daily: Double, weekly: Double, carryOver: Bool,
                                  spentSoFar: Double, days: Int) -> Double {
        guard carryOver else { return daily }
        let fair = max(weekly - spentSoFar, 0) / Double(max(days, 1))
        return min(daily, fair)
    }

    var todayLimit: Double { days.first(where: \.isToday)?.allowance ?? daily }
    /// How much today's limit was cut to cover earlier overspending this week.
    var todayCut: Double { max(daily - todayLimit, 0) }
    var isOverToday: Bool { todaySpent > todayLimit && todaySpent > 0 }
    var overToday: Double { max(todaySpent - todayLimit, 0) }

    /// Limit for each remaining day after today; nil on Sunday (a new week starts tomorrow).
    var tomorrowLimit: Double? {
        guard daysLeft > 1 else { return nil }
        return days.first(where: \.isFuture)?.allowance
    }
    var tomorrowCut: Double { max(daily - (tomorrowLimit ?? daily), 0) }
    var weekLeft: Double { weekly - spentThisWeek }
}
