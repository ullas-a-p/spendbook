import SwiftUI
import SwiftData
import Charts

enum InsightPeriod: String, CaseIterable, Identifiable {
    case week = "Week", month = "Month", year = "Year"
    var id: String { rawValue }
}

struct InsightsView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Environment(BudgetStore.self) private var budget

    @State private var period: InsightPeriod = .month
    @State private var calendarMonth: Date = .now

    private var cal: Calendar { Calendar.current }

    private var periodExpenses: [Expense] {
        let now = Date.now
        let start: Date
        switch period {
        case .week: start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) ?? now
        case .month: start = cal.dateInterval(of: .month, for: now)?.start ?? now
        case .year: start = cal.dateInterval(of: .year, for: now)?.start ?? now
        }
        return expenses.filter { $0.date >= start && $0.date <= now.addingTimeInterval(86_400) }
    }

    private var periodTotals: [CategoryTotal] {
        var sums: [SpendCategory: Double] = [:]
        for e in periodExpenses { sums[e.category, default: 0] += e.amount }
        return sums.map { CategoryTotal(category: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    var body: some View {
        let month = MonthStats(all: expenses, month: calendarMonth, budget: budget.monthly, daily: budget.daily)
        let current = MonthStats(all: expenses, month: .now, budget: budget.monthly, daily: budget.daily)
        let totals = periodTotals
        let periodTotal = totals.reduce(0) { $0 + $1.amount }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Period", selection: $period) {
                        ForEach(InsightPeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if !expenses.isEmpty {
                        SummaryCard(text: summary(current))
                    }

                    SpendCalendar(stats: month,
                                  onPrevious: { shiftMonth(-1) },
                                  onNext: { shiftMonth(1) },
                                  canGoNext: !month.isCurrentMonth && !month.isFutureMonth)

                    donutCard(totals: totals, total: periodTotal)

                    dailyChart(month)

                    if !totals.isEmpty {
                        SectionHeader(title: "Top categories")
                        topCategories(totals)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AmbientBackground())
            .navigationTitle("Insights")
        }
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: calendarMonth) {
            withAnimation(.snappy) { calendarMonth = d }
        }
    }

    // MARK: Donut

    private func donutCard(totals: [CategoryTotal], total: Double) -> some View {
        HStack(spacing: 16) {
            ZStack {
                if totals.isEmpty {
                    Circle().stroke(Theme.card2, lineWidth: 22).padding(11)
                } else {
                    Chart(totals) { item in
                        SectorMark(angle: .value("Amount", item.amount),
                                   innerRadius: .ratio(0.64),
                                   angularInset: 1.5)
                            .cornerRadius(3)
                            .foregroundStyle(item.category.color)
                    }
                    .chartLegend(.hidden)
                }
                VStack(spacing: 0) {
                    Text(total.inrWhole)
                        .font(.rounded(20, .heavy))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(period == .week ? "last 7 days" : period == .month ? "this month" : "this year")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
                .frame(width: 100)
            }
            .frame(width: 160, height: 160)

            VStack(alignment: .leading, spacing: 9) {
                if totals.isEmpty {
                    Text("No spends in this period yet.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.secondary)
                }
                ForEach(totals.prefix(5)) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.category.color).frame(width: 10, height: 10)
                        Text(item.category.name)
                        Spacer(minLength: 4)
                        Text("\(Int((item.amount / max(total, 1) * 100).rounded()))%")
                            .foregroundStyle(Theme.secondary)
                            .monospacedDigit()
                    }
                    .font(.system(size: 13))
                }
            }
        }
        .padding(16)
        .card(26)
    }

    // MARK: Daily bars

    private func dailyChart(_ s: MonthStats) -> some View {
        let byDay = s.byDay
        let maxValue = byDay.values.max() ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily spending").font(.system(size: 17, weight: .bold))
                Spacer()
                Text("Avg \(s.averagePerDay.inrWhole) / day")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .monospacedDigit()
            }
            Chart {
                ForEach(1...s.daysInMonth, id: \.self) { day in
                    let value = byDay[day] ?? 0
                    BarMark(x: .value("Day", Double(day)), y: .value("Spent", value), width: .fixed(7))
                        .cornerRadius(2)
                        .foregroundStyle(value > s.pacePerDay ? Theme.warn : Theme.calmDeep)
                }
                RuleMark(y: .value("Daily pace", s.pacePerDay))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Theme.warn.opacity(0.7))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("limit \(s.pacePerDay.inrWhole)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.warnText)
                    }
            }
            .chartXScale(domain: 0.5...(Double(s.daysInMonth) + 0.5))
            .chartYScale(domain: 0.0...(max(maxValue, s.pacePerDay, 1) * 1.1))
            .chartXAxis {
                AxisMarks(values: [1.0, 5, 10, 15, 20, 25, 30]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text("\(Int(v))") }
                    }
                    .foregroundStyle(Theme.secondary)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine().foregroundStyle(Theme.separator)
                    AxisValueLabel {
                        if let v = value.as(Double.self) { Text(v.inrCompact) }
                    }
                    .foregroundStyle(Theme.secondary)
                }
            }
            .frame(height: 140)
        }
        .padding(16)
        .card(26)
    }

    // MARK: Categories

    private func topCategories(_ totals: [CategoryTotal]) -> some View {
        let top = totals.first?.amount ?? 1
        let rows = Array(totals.prefix(8))
        return VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 12) {
                    CategoryTile(category: item.category)
                    VStack(spacing: 6) {
                        HStack {
                            Text(item.category.name)
                            Spacer()
                            Text(item.amount.inrWhole).fontWeight(.semibold).monospacedDigit()
                        }
                        .font(.system(size: 15))
                        ProgressLine(fraction: item.amount / top, color: item.category.color, height: 6)
                    }
                    .padding(.vertical, 11)
                    .padding(.trailing, 16)
                    .overlay(alignment: .bottom) {
                        if index < rows.count - 1 {
                            Rectangle().fill(Theme.separator).frame(height: 0.5)
                        }
                    }
                }
                .padding(.leading, 16)
            }
        }
        .card(22)
    }

    // MARK: Summary

    private func summary(_ s: MonthStats) -> String {
        guard s.total > 0 else {
            return "No spends yet this month. Add a few and a summary of your month will show up here."
        }
        var parts: [String] = []
        let everyday = s.byCategory.filter { $0.category != .rent }
        let hasRent = s.byCategory.contains(where: { $0.category == .rent })
        if let top = everyday.first {
            let afterRent = hasRent ? " after rent" : ""
            parts.append("\(top.category.name) is your biggest spend\(afterRent) at \(top.amount.inrWhole).")
        }
        let over = s.overLimitDays
        if over > 0 {
            parts.append("You went over the \(s.pacePerDay.inrWhole) daily limit on \(over) day\(over == 1 ? "" : "s").")
        } else {
            parts.append("You've stayed under your \(s.pacePerDay.inrWhole) daily limit every day.")
        }
        if s.isCurrentMonth && s.daysElapsed > 0 {
            let projected = s.averagePerDay * Double(s.daysInMonth)
            if projected > s.budget {
                parts.append("At this rate you'll spend about \(projected.inrWhole), which is \((projected - s.budget).inrWhole) over budget.")
            } else {
                parts.append("At this rate you'll finish about \((s.budget - projected).inrWhole) under budget.")
            }
        }
        return parts.joined(separator: " ")
    }
}

struct SummaryCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18))
                .foregroundStyle(Theme.ai)
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color(hex: 0xE6E0EE))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(hex: 0x15121C), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color(hex: 0xBF5AF2).opacity(0.35))
        }
    }
}

/// Month grid showing what was spent each day. Green days are under the
/// daily pace (darker = more spent), orange days went over it.
struct SpendCalendar: View {
    let stats: MonthStats
    let onPrevious: () -> Void
    let onNext: () -> Void
    let canGoNext: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        let byDay = stats.byDay
        let cal = Calendar.current
        let today = stats.isCurrentMonth ? cal.component(.day, from: stats.now) : -1
        let pace = stats.pacePerDay

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Spending calendar").font(.system(size: 17, weight: .bold))
                    Text(stats.monthStart.monthYear)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                Spacer()
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left").frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Previous month")
                Button(action: onNext) {
                    Image(systemName: "chevron.right").frame(width: 32, height: 32)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(!canGoNext)
                .accessibilityLabel("Next month")
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.tertiary)
                }
                ForEach(0..<stats.firstWeekdayColumn, id: \.self) { _ in
                    Color.clear.frame(height: 48)
                }
                ForEach(1...stats.daysInMonth, id: \.self) { day in
                    let future = stats.isFutureMonth || (stats.isCurrentMonth && day > today)
                    DayCell(day: day,
                            amount: byDay[day] ?? 0,
                            pace: pace,
                            isToday: day == today,
                            isFuture: future)
                }
            }

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Theme.accent.opacity(0.4)).frame(width: 12, height: 12)
                    Text("Under \(pace.inrWhole)/day")
                }
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x3A1A10))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Theme.warn))
                        .frame(width: 12, height: 12)
                    Text("Over limit · \(stats.overLimitDays) day\(stats.overLimitDays == 1 ? "" : "s")")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondary)
        }
        .padding(16)
        .card(26)
    }
}

struct DayCell: View {
    let day: Int
    let amount: Double
    let pace: Double
    let isToday: Bool
    let isFuture: Bool

    var body: some View {
        let over = amount > pace
        let background: Color = {
            if isFuture { return Color(hex: 0x111113) }
            if over { return Color(hex: 0x3A1A10) }
            if amount == 0 { return Theme.card2.opacity(0.6) }
            return Theme.accent.opacity(0.10 + 0.42 * min(amount / max(pace, 1), 1))
        }()

        VStack(spacing: 1) {
            Text("\(day)")
                .font(.system(size: 13, weight: isToday ? .heavy : .semibold))
                .foregroundStyle(isFuture ? Color(hex: 0x48484A) : .white)
            if !isFuture {
                Text(amount > 0 ? amount.inrCompact : "–")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(over ? Theme.warnText : Theme.accentSoft)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if over && !isFuture {
                Circle().fill(Theme.warn).frame(width: 5, height: 5).padding(4)
            }
        }
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFuture ? "Day \(day)" : "Day \(day), spent \(amount.inrWhole)\(over ? ", over the daily pace" : "")")
    }
}
