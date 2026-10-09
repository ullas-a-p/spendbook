import SwiftUI
import SwiftData

struct AddSpendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(BudgetStore.self) private var budget
    @Query private var expenses: [Expense]

    @State private var amountText = ""
    @State private var category: SpendCategory = .food
    @State private var note = ""
    @State private var date = Date()
    @State private var sentence = ""
    @State private var understood: ParsedSpend?
    @State private var parsing = false
    @State private var savedCount = 0
    @State private var smsRef: String?
    @FocusState private var focusedField: Field?

    private enum Field { case sentence, note }

    private var amount: Double { Double(amountText) ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            header
            sentenceField
            if let understood { understoodChips(understood) }

            amountDisplay
            categoryPicker
            HStack(spacing: 10) {
                noteField
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
            keypad
            saveButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(Theme.sheet)
        .sensoryFeedback(.selection, trigger: amountText)
        .sensoryFeedback(.success, trigger: savedCount)
        .animation(.snappy, value: understood?.amount)
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Cancel")
            Spacer()
            Text("Add Spend").font(.system(size: 17, weight: .bold))
            Spacer()
            // Paste a copied bank SMS to fill the form.
            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first else { return }
                Task { @MainActor in pasteSMS(text) }
            }
            .labelStyle(.iconOnly)
            .buttonBorderShape(.circle)
            .tint(Theme.card2)
            .accessibilityLabel("Paste bank SMS")
        }
    }

    /// Type or dictate a sentence; Apple Intelligence fills in the rest.
    private var sentenceField: some View {
        HStack(spacing: 10) {
            Image(systemName: parsing ? "ellipsis" : "sparkles")
                .foregroundStyle(Theme.ai)
                .symbolEffect(.variableColor.iterative, isActive: parsing)
            TextField("Try “lunch 180 at office”", text: $sentence)
                .focused($focusedField, equals: .sentence)
                .submitLabel(.done)
                .onSubmit(understandSentence)
                .autocorrectionDisabled()
            if !sentence.isEmpty {
                Button("Fill", action: understandSentence)
                    .font(.system(size: 14, weight: .bold))
                    .buttonStyle(.glass)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 48)
        .background(Color(hex: 0x141416), in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                AngularGradient(colors: [Color(hex: 0xFF9F0A), Color(hex: 0xFF375F), Color(hex: 0xBF5AF2),
                                         Color(hex: 0x0A84FF), Theme.accent, Color(hex: 0xFF9F0A)],
                                center: .center),
                lineWidth: 2)
        }
    }

    private func understoodChips(_ p: ParsedSpend) -> some View {
        HStack(spacing: 6) {
            Text(p.usedAppleIntelligence ? "Apple Intelligence read" : "Understood as")
                .foregroundStyle(Theme.secondary)
            if let a = p.amount { chip(a.inr, Theme.accent) }
            if let c = p.category { chip(c.name, c.color) }
            if let n = p.note { chip(n, .white) }
            if let d = p.date { chip(d.relativeDayLabel, .white) }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
        .lineLimit(1)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color == .white ? .white : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(color == .white ? 0.12 : 0.18), in: RoundedRectangle(cornerRadius: 8))
    }

    private var amountDisplay: some View {
        let stats = MonthStats(all: expenses, month: .now, budget: budget.monthly)
        let isToday = Calendar.current.isDateInToday(date)
        let plan = budget.plan(expenses)
        let leftAfter = plan.todayLimit - plan.todaySpent - amount

        return VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₹").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.secondary)
                Text(displayAmount)
                    .font(.rounded(74, .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .animation(.snappy(duration: 0.2), value: amountText)
            Group {
                if isToday && amount > 0 {
                    if leftAfter >= 0 {
                        Text("\(leftAfter.inrWhole) left in today's limit after this")
                    } else {
                        Text("This puts you \((-leftAfter).inrWhole) over today's limit")
                            .foregroundStyle(Theme.warnText)
                    }
                } else {
                    Text(category.name + " · " + date.relativeDayLabel)
                }
            }
            .font(.system(size: 14))
            .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayAmount: String {
        guard !amountText.isEmpty else { return "0" }
        let parts = amountText.split(separator: ".", omittingEmptySubsequences: false)
        let whole = Double(parts[0]).map { $0.formatted(.number.locale(indiaLocale)) } ?? String(parts[0])
        return parts.count > 1 ? whole + "." + parts[1] : whole
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(SpendCategory.allCases) { c in
                    Button {
                        category = c
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: c.symbol)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(c.iconColor)
                                .frame(width: 50, height: 50)
                                .background(c.color, in: Circle())
                                .overlay {
                                    if category == c {
                                        Circle().strokeBorder(Theme.accent, lineWidth: 2.5).padding(-5)
                                    }
                                }
                                .padding(5)
                            Text(c.name)
                                .font(.system(size: 12, weight: category == c ? .bold : .regular))
                                .foregroundStyle(category == c ? .white : Theme.secondary)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(category == c ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
        .sensoryFeedback(.selection, trigger: category)
    }

    private var noteField: some View {
        HStack(spacing: 8) {
            Image(systemName: "pencil").foregroundStyle(Theme.secondary)
            TextField("Note", text: $note)
                .focused($focusedField, equals: .note)
                .submitLabel(.done)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Theme.card, in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ".", "0", "⌫"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(keys, id: \.self) { key in
                Button {
                    press(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left").font(.system(size: 24))
                        } else {
                            Text(key).font(.rounded(28, .medium))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.card2, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(key == "⌫" ? "Delete digit" : key)
            }
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(amount > 0 ? "Save \(amount.inr)" : "Enter an amount")
                .font(.system(size: 17, weight: .heavy))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(.glassProminent)
        .tint(Theme.accent)
        .foregroundStyle(Theme.onAccent)
        .disabled(amount <= 0)
    }

    // MARK: Actions

    private func press(_ key: String) {
        focusedField = nil
        switch key {
        case "⌫":
            if !amountText.isEmpty { amountText.removeLast() }
        case ".":
            if !amountText.contains(".") { amountText += amountText.isEmpty ? "0." : "." }
        default:
            if let dot = amountText.firstIndex(of: ".") {
                guard amountText[dot...].count <= 2 else { return }
            } else {
                guard amountText.count < 8 else { return }
            }
            amountText = amountText == "0" ? key : amountText + key
        }
    }

    private func understandSentence() {
        let text = sentence
        guard !text.isEmpty else { return }
        focusedField = nil
        parsing = true
        Task {
            let parsed = await SpendParser.parse(text)
            parsing = false
            withAnimation(.snappy) { understood = parsed }
            if let a = parsed.amount {
                let rounded = (a * 100).rounded() / 100
                amountText = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
            }
            if let c = parsed.category { category = c }
            if let n = parsed.note { note = n }
            if let d = parsed.date { date = d }
        }
    }

    /// Fills the form from a copied bank SMS, or treats the text as a sentence.
    private func pasteSMS(_ text: String) {
        if let sms = BankSMSParser.parse(text) {
            let rounded = (sms.amount * 100).rounded() / 100
            amountText = rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
            category = sms.category
            note = sms.payee ?? "Bank payment"
            date = sms.date ?? .now
            smsRef = sms.reference
            withAnimation(.snappy) {
                understood = ParsedSpend(amount: sms.amount, category: sms.category,
                                         note: note, date: date, usedAppleIntelligence: false)
            }
        } else {
            sentence = text
            understandSentence()
        }
    }

    private func save() {
        guard amount > 0 else { return }
        // Keep today's current time so the list stays in order; use noon for past days.
        var when = date
        if !Calendar.current.isDateInToday(date) {
            when = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        } else {
            when = .now
        }
        if let ref = smsRef,
           let existing = try? context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.smsRef == ref })),
           !existing.isEmpty {
            dismiss()   // already logged from this message
            return
        }
        let expense = Expense(amount: amount, category: category,
                              note: note.trimmingCharacters(in: .whitespaces), date: when,
                              source: smsRef == nil ? "manual" : "sms", smsRef: smsRef ?? "")
        context.insert(expense)
        try? context.save()
        savedCount += 1
        dismiss()
    }
}
