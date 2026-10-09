import SwiftUI
import SwiftData
import AppIntents
import Observation

// MARK: - Category

enum SpendCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case food, groceries, transport, fuel, shopping, bills, rent, health, fun, other

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .food: "fork.knife"
        case .groceries: "cart.fill"
        case .transport: "bus.fill"
        case .fuel: "fuelpump.fill"
        case .shopping: "bag.fill"
        case .bills: "bolt.fill"
        case .rent: "house.fill"
        case .health: "heart.fill"
        case .fun: "ticket.fill"
        case .other: "ellipsis"
        }
    }

    var color: Color {
        switch self {
        case .food: Color(hex: 0xFF9F0A)
        case .groceries: Color(hex: 0x30D158)
        case .transport: Color(hex: 0x0A84FF)
        case .fuel: Color(hex: 0xBF5AF2)
        case .shopping: Color(hex: 0xFF375F)
        case .bills: Color(hex: 0xFFD60A)
        case .rent: Color(hex: 0x40C8E0)
        case .health: Color(hex: 0xFF453A)
        case .fun: Color(hex: 0xAC8E68)
        case .other: Color(hex: 0x8E8E93)
        }
    }

    /// Dark glyphs on the light tiles, white on the rest.
    var iconColor: Color {
        switch self {
        case .food, .groceries, .bills, .rent: Color(hex: 0x1C1C1E)
        default: .white
        }
    }

    /// Words that point to this category when parsing typed text.
    var keywords: [String] {
        switch self {
        case .food: ["food", "lunch", "dinner", "breakfast", "tea", "coffee", "snack", "snacks", "swiggy", "zomato", "biryani", "meal", "restaurant", "juice", "chai", "hotel", "cafe", "bakery", "dominos", "kfc", "mcdonalds", "starbucks", "eatsure", "chaayos"]
        case .groceries: ["grocery", "groceries", "supermarket", "vegetables", "veggies", "milk", "fruits", "rice", "bigbasket", "blinkit", "zepto"]
        case .transport: ["bus", "auto", "uber", "ola", "taxi", "cab", "train", "metro", "ksrtc", "ticket", "rapido", "parking", "irctc", "redbus", "fastag", "metro", "kmrl", "namma"]
        case .fuel: ["petrol", "diesel", "fuel", "gas", "cng", "hpcl", "bpcl", "iocl", "indianoil", "shell"]
        case .shopping: ["shopping", "clothes", "shirt", "shoes", "amazon", "flipkart", "myntra", "gift", "dress", "ajio", "meesho", "nykaa", "decathlon", "lifestyle", "trends", "lulu"]
        case .bills: ["bill", "bills", "electricity", "kseb", "wifi", "internet", "recharge", "mobile", "water", "broadband", "dth", "airtel", "jio", "vi", "bsnl", "tatasky", "electricity", "kseb"]
        case .rent: ["rent", "hostel", "pg", "lease"]
        case .health: ["medicine", "medicines", "doctor", "hospital", "pharmacy", "gym", "clinic", "tablet", "tablets", "apollo", "medplus", "pharmeasy", "netmeds", "1mg"]
        case .fun: ["movie", "movies", "netflix", "game", "games", "party", "trip", "outing", "concert", "spotify", "bookmyshow", "pvr", "inox", "hotstar", "primevideo", "steam", "playstation"]
        case .other: []
        }
    }
}

extension SpendCategory {
    /// Best category for a piece of text, by keyword.
    static func guess(from text: String) -> SpendCategory? {
        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        for category in SpendCategory.allCases where category != .other {
            if words.contains(where: { category.keywords.contains($0) }) { return category }
        }
        return nil
    }
}

extension SpendCategory: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Category"
    static let caseDisplayRepresentations: [SpendCategory: DisplayRepresentation] = [
        .food: "Food",
        .groceries: "Groceries",
        .transport: "Transport",
        .fuel: "Fuel",
        .shopping: "Shopping",
        .bills: "Bills",
        .rent: "Rent",
        .health: "Health",
        .fun: "Fun",
        .other: "Other"
    ]
}

// MARK: - Expense

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double = 0
    var categoryRaw: String = SpendCategory.other.rawValue
    var note: String = ""
    var date: Date = Date()
    var createdAt: Date = Date()
    /// "manual" or "sms".
    var source: String = "manual"
    /// Bank reference number (or a hash of the message) for SMS spends, to skip duplicates.
    var smsRef: String = ""

    init(amount: Double, category: SpendCategory, note: String, date: Date,
         source: String = "manual", smsRef: String = "") {
        self.id = UUID()
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
        self.createdAt = Date()
        self.source = source
        self.smsRef = smsRef
    }

    var isFromSMS: Bool { source == "sms" }

    var category: SpendCategory {
        get { SpendCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var title: String { note.isEmpty ? category.name : note }
}

// MARK: - Storage

enum DataStore {
    @MainActor static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Expense.self)
        } catch {
            fatalError("Could not open the Spendbook database: \(error)")
        }
    }()
}

// MARK: - Budget settings

@Observable
final class BudgetStore {
    private let defaults = UserDefaults.standard

    var monthly: Double {
        didSet { defaults.set(monthly, forKey: "monthlyBudget") }
    }

    /// Daily and weekly limits, set by hand.
    var daily: Double {
        didSet { defaults.set(daily, forKey: "dailyLimit") }
    }
    var weekly: Double {
        didSet { defaults.set(weekly, forKey: "weeklyLimit") }
    }
    /// Take today's overspend out of the rest of the week.
    var carryOver: Bool {
        didSet { defaults.set(carryOver, forKey: "carryOver") }
    }

    /// Category raw value -> monthly limit.
    var perCategory: [String: Double] {
        didSet {
            if let data = try? JSONEncoder().encode(perCategory) {
                defaults.set(data, forKey: "categoryBudgets")
            }
        }
    }

    init() {
        let d = UserDefaults.standard
        let stored = d.double(forKey: "monthlyBudget")
        monthly = stored > 0 ? stored : 25000
        let m = stored > 0 ? stored : 25000
        let storedDaily = d.double(forKey: "dailyLimit")
        daily = storedDaily > 0 ? storedDaily : (m / 30).rounded()
        let storedWeekly = d.double(forKey: "weeklyLimit")
        weekly = storedWeekly > 0 ? storedWeekly : (m * 7 / 30).rounded()
        carryOver = d.object(forKey: "carryOver") as? Bool ?? true
        if let data = UserDefaults.standard.data(forKey: "categoryBudgets"),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            perCategory = decoded
        } else {
            perCategory = ["food": 5000, "groceries": 3500, "fuel": 2000, "shopping": 1500, "fun": 1000]
        }
    }

    func limit(for category: SpendCategory) -> Double? { perCategory[category.rawValue] }

    /// Weekly and daily limits worked out from the monthly one.
    func splitMonthly() {
        weekly = (monthly * 7 / 30).rounded()
        daily = (monthly / 30).rounded()
    }

    func plan(_ expenses: [Expense], now: Date = .now) -> LimitPlan {
        LimitPlan(all: expenses, daily: daily, weekly: weekly, carryOver: carryOver, now: now)
    }
}
