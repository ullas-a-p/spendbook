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
        case .food: ["food", "lunch", "dinner", "breakfast", "tea", "coffee", "snack", "snacks", "swiggy", "zomato", "biryani", "meal", "restaurant", "juice", "chai", "hotel"]
        case .groceries: ["grocery", "groceries", "supermarket", "vegetables", "veggies", "milk", "fruits", "rice", "bigbasket", "blinkit", "zepto"]
        case .transport: ["bus", "auto", "uber", "ola", "taxi", "cab", "train", "metro", "ksrtc", "ticket", "rapido", "parking"]
        case .fuel: ["petrol", "diesel", "fuel", "gas", "cng"]
        case .shopping: ["shopping", "clothes", "shirt", "shoes", "amazon", "flipkart", "myntra", "gift", "dress"]
        case .bills: ["bill", "bills", "electricity", "kseb", "wifi", "internet", "recharge", "mobile", "water", "broadband", "dth"]
        case .rent: ["rent", "hostel", "pg", "lease"]
        case .health: ["medicine", "medicines", "doctor", "hospital", "pharmacy", "gym", "clinic", "tablet", "tablets"]
        case .fun: ["movie", "movies", "netflix", "game", "games", "party", "trip", "outing", "concert", "spotify"]
        case .other: []
        }
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

    init(amount: Double, category: SpendCategory, note: String, date: Date) {
        self.id = UUID()
        self.amount = amount
        self.categoryRaw = category.rawValue
        self.note = note
        self.date = date
        self.createdAt = Date()
    }

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

    /// Category raw value -> monthly limit.
    var perCategory: [String: Double] {
        didSet {
            if let data = try? JSONEncoder().encode(perCategory) {
                defaults.set(data, forKey: "categoryBudgets")
            }
        }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: "monthlyBudget")
        monthly = stored > 0 ? stored : 25000
        if let data = UserDefaults.standard.data(forKey: "categoryBudgets"),
           let decoded = try? JSONDecoder().decode([String: Double].self, from: data) {
            perCategory = decoded
        } else {
            perCategory = ["food": 5000, "groceries": 3500, "fuel": 2000, "shopping": 1500, "fun": 1000]
        }
    }

    func limit(for category: SpendCategory) -> Double? { perCategory[category.rawValue] }
}
