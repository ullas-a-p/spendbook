import SwiftUI
import SwiftData

struct BudgetView: View {
    @Query private var expenses: [Expense]
    @Environment(BudgetStore.self) private var budget
    @State private var editing = false

    var body: some View {
        let s = MonthStats(all: expenses, month: .now, budget: budget.monthly, daily: budget.daily)
        let plan = budget.plan(expenses)
        let limited = SpendCategory.allCases.filter { budget.limit(for: $0) != nil }

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ringCard(s, plan: plan)

                    WeekStrip(plan: plan)

                    SectionHeader(title: "Category budgets")
                    VStack(spacing: 0) {
                        ForEach(limited) { c in
                            categoryRow(c, spent: s.spent(in: c), limit: budget.limit(for: c) ?? 0)
                        }
                        Button {
                            editing = true
                        } label: {
                            Label("Add category budget", systemImage: "plus")
                                .font(.system(size: 16))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .card(22)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AmbientBackground())
            .navigationTitle("Budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editing = true }
                }
            }
            .sheet(isPresented: $editing) {
                BudgetEditView()
            }
        }
    }

    private func ringCard(_ s: MonthStats, plan: LimitPlan) -> some View {
        let over = s.remaining < 0
        return VStack(spacing: 14) {
            ZStack {
                Circle().stroke(Theme.card2, lineWidth: 18)
                Circle()
                    .trim(from: 0, to: min(s.usedFraction, 1))
                    .stroke(over ? Theme.warn : Theme.accent,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.snappy, value: s.usedFraction)
                VStack(spacing: 2) {
                    Text(over ? "Over budget by" : "Left to spend")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                    Text(abs(s.remaining).inrWhole)
                        .font(.rounded(34, .heavy))
                        .foregroundStyle(over ? Theme.warnText : .white)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("of \(s.budget.inrWhole)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: 200, height: 200)
            .padding(.top, 6)

            Divider().overlay(Theme.separator)

            HStack {
                stat("Spent", s.total.inrWhole, .white)
                stat("Today's limit", plan.todayLimit.inrWhole, plan.isOverToday ? Theme.warnText : Theme.accent)
                stat("Week left", max(plan.weekLeft, 0).inrWhole, plan.weekLeft >= 0 ? .white : Theme.warnText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .card(28)
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func categoryRow(_ c: SpendCategory, spent: Double, limit: Double) -> some View {
        let fraction = limit > 0 ? spent / limit : 0
        let warn = fraction >= 0.85
        return HStack(spacing: 12) {
            CategoryTile(category: c)
            VStack(spacing: 6) {
                HStack {
                    Text(c.name)
                    Spacer()
                    Text("\(Text(spent.inrWhole).bold()) \(Text("of \(limit.inrWhole)").foregroundStyle(Theme.secondary))")
                        .monospacedDigit()
                }
                .font(.system(size: 15))
                ProgressLine(fraction: fraction, color: warn ? Theme.warn : c.color, height: 6)
                HStack {
                    Text("\(Int((fraction * 100).rounded()))% used")
                    Spacer()
                    if spent > limit {
                        Text("\((spent - limit).inrWhole) over").bold().foregroundStyle(Theme.warnText)
                    } else if warn {
                        Text("Only \((limit - spent).inrWhole) left").bold().foregroundStyle(Theme.warnText)
                    } else {
                        Text("\((limit - spent).inrWhole) left")
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .monospacedDigit()
            }
            .padding(.vertical, 12)
            .padding(.trailing, 16)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.separator).frame(height: 0.5)
            }
        }
        .padding(.leading, 16)
    }
}

struct BudgetEditView: View {
    @Environment(BudgetStore.self) private var budget
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("₹").foregroundStyle(Theme.secondary)
                        TextField("25000", text: monthlyBinding)
                            .keyboardType(.numberPad)
                            .font(.rounded(22, .bold))
                    }
                } header: {
                    Text("Monthly limit")
                }

                Section {
                    HStack {
                        Text("Weekly limit")
                        Spacer()
                        Text("₹").foregroundStyle(Theme.secondary)
                        TextField("5833", text: amountBinding(\.weekly))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                    HStack {
                        Text("Daily limit")
                        Spacer()
                        Text("₹").foregroundStyle(Theme.secondary)
                        TextField("833", text: amountBinding(\.daily))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                    }
                    Button("Work out from monthly limit") { budget.splitMonthly() }
                    Toggle("Take overspending out of the rest of the week", isOn: carryBinding)
                } header: {
                    Text("Weekly and daily limits")
                } footer: {
                    Text("When this is on and you go over today's limit, the extra is taken out of the remaining days of the same week. Weeks run Monday to Sunday.")
                }

                Section("Category budgets") {
                    ForEach(SpendCategory.allCases) { c in
                        HStack(spacing: 12) {
                            CategoryTile(category: c, size: 30, corner: 8)
                            Text(c.name)
                            Spacer()
                            TextField("No limit", text: categoryBinding(c))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)
                        }
                    }
                }

                Section {
                    NavigationLink {
                        SMSSetupView()
                    } label: {
                        Label("Auto-add spends from bank SMS", systemImage: "message.badge.filled.fill")
                    }
                } footer: {
                    Text("Uses a Shortcuts automation so debit messages from your bank are logged for you.")
                }

                Section {
                    Button("Fill in sample data") {
                        SampleData.insert(into: context)
                        dismiss()
                    }
                    Button("Delete all spends", role: .destructive) {
                        confirmDelete = true
                    }
                } footer: {
                    Text("Sample data adds example spends so you can see how the app looks. Delete them any time.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.sheet)
            .navigationTitle("Edit Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .confirmationDialog("Delete every spend you've logged?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Delete all spends", role: .destructive) {
                    try? context.delete(model: Expense.self)
                    try? context.save()
                }
            } message: {
                Text("This can't be undone.")
            }
        }
        .presentationBackground(Theme.sheet)
    }

    private func amountBinding(_ key: ReferenceWritableKeyPath<BudgetStore, Double>) -> Binding<String> {
        Binding(
            get: { String(Int(budget[keyPath: key])) },
            set: { newValue in
                if let v = Double(newValue.filter(\.isNumber)), v > 0 { budget[keyPath: key] = v }
            }
        )
    }

    private var carryBinding: Binding<Bool> {
        Binding(get: { budget.carryOver }, set: { budget.carryOver = $0 })
    }

    private var monthlyBinding: Binding<String> {
        Binding(
            get: { String(Int(budget.monthly)) },
            set: { newValue in
                if let v = Double(newValue.filter(\.isNumber)), v > 0 { budget.monthly = v }
            }
        )
    }

    private func categoryBinding(_ c: SpendCategory) -> Binding<String> {
        Binding(
            get: { budget.perCategory[c.rawValue].map { String(Int($0)) } ?? "" },
            set: { newValue in
                let v = Double(newValue.filter(\.isNumber)) ?? 0
                budget.perCategory[c.rawValue] = v > 0 ? v : nil
            }
        )
    }
}
