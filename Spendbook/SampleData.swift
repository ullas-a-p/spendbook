import Foundation
import SwiftData

/// Example spends for the current month, so the app can be tried before real use.
enum SampleData {
    static func insert(into context: ModelContext) {
        let cal = Calendar.current
        let now = Date.now
        let today = cal.component(.day, from: now)
        guard let monthStart = cal.dateInterval(of: .month, for: now)?.start else { return }

        func at(day: Int, hour: Int, minute: Int = 0) -> Date? {
            guard day >= 1, day <= today,
                  let d = cal.date(byAdding: .day, value: day - 1, to: monthStart),
                  let t = cal.date(bySettingHour: hour, minute: minute, second: 0, of: d),
                  t <= now else { return nil }
            return t
        }

        let rows: [(Int, Int, Double, SpendCategory, String)] = [
            (1, 10, 9000, .rent, "Rent"),
            (2, 13, 180, .food, "Lunch"),
            (3, 19, 260, .groceries, "Vegetables"),
            (4, 9, 140, .transport, "Auto rickshaw"),
            (5, 11, 1150, .bills, "Electricity bill"),
            (5, 20, 90, .food, "Tea & snacks"),
            (6, 13, 210, .food, "Biryani"),
            (7, 18, 120, .transport, "KSRTC bus"),
            (8, 12, 310, .groceries, "Milk & bread"),
            (9, 17, 1299, .shopping, "Shirt"),
            (9, 21, 60, .food, "Juice"),
            (10, 13, 190, .food, "Lunch"),
            (11, 8, 240, .fuel, "Petrol"),
            (12, 20, 280, .food, "Swiggy dinner"),
            (13, 17, 90, .transport, "Bus"),
            (14, 10, 250, .health, "Medicines"),
            (15, 19, 240, .groceries, "Supermarket"),
            (16, 19, 450, .fun, "Movie tickets"),
            (16, 18, 80, .transport, "Auto rickshaw"),
            (17, 21, 320, .food, "Swiggy dinner"),
            (17, 18, 60, .transport, "KSRTC bus"),
            (17, 11, 1240, .groceries, "Supermarket"),
            (18, 12, 180, .food, "Lunch"),
            (18, 13, 500, .fuel, "Petrol"),
            (18, 16, 40, .food, "Tea & snacks"),
            (20, 13, 220, .food, "Lunch"),
            (21, 18, 700, .shopping, "Shoes"),
            (22, 9, 500, .fuel, "Petrol"),
            (23, 20, 350, .food, "Dinner out"),
            (24, 12, 160, .transport, "Uber"),
            (25, 19, 900, .groceries, "Monthly groceries"),
            (26, 21, 499, .fun, "Netflix"),
            (27, 13, 200, .food, "Lunch"),
            (28, 10, 399, .bills, "Mobile recharge"),
            (29, 17, 150, .food, "Snacks"),
            (30, 13, 210, .food, "Lunch")
        ]

        for (day, hour, amount, category, note) in rows {
            if let date = at(day: day, hour: hour) {
                context.insert(Expense(amount: amount, category: category, note: note, date: date))
            }
        }
        // Make sure "today" has something too.
        let earlier = max(cal.component(.hour, from: now) - 1, 0)
        if let date = at(day: today, hour: earlier, minute: 0) {
            context.insert(Expense(amount: 120, category: .food, note: "Coffee", date: date))
        }
        try? context.save()
    }
}
