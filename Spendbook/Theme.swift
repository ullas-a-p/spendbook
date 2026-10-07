import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Dark palette taken from the Spendbook design canvas.
enum Theme {
    static let accent = Color(hex: 0x3DD9A4)
    static let accentSoft = Color(hex: 0x9AF5D3)
    static let onAccent = Color(hex: 0x04140E)
    static let background = Color.black
    static let sheet = Color(hex: 0x0B0B0C)
    static let card = Color(hex: 0x1C1C1E)
    static let card2 = Color(hex: 0x2C2C2E)
    static let secondary = Color(hex: 0x98989F)
    static let tertiary = Color(hex: 0x636366)
    static let separator = Color(hex: 0x38383A)
    static let warn = Color(hex: 0xFF7A45)
    static let warnDeep = Color(hex: 0x8A3414)
    static let warnText = Color(hex: 0xFF9466)
    static let warnTicker = Color(hex: 0xFFB08F)
    static let warnBG = Color(hex: 0x2B1610)
    static let warnCard = Color(hex: 0x1F1411)
    static let calmDeep = Color(hex: 0x1F6E55)
    static let calmBG = Color(hex: 0x0F2A21)
    static let ai = Color(hex: 0xE5C8FF)
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

let indiaLocale = Locale(identifier: "en_IN")

extension Double {
    /// ₹1,23,456.5 style (Indian grouping, up to 2 decimals).
    var inr: String {
        formatted(.currency(code: "INR").locale(indiaLocale).precision(.fractionLength(0...2)))
    }
    /// ₹1,23,457 (no decimals).
    var inrWhole: String {
        formatted(.currency(code: "INR").locale(indiaLocale).precision(.fractionLength(0)))
    }
    /// ₹180 or ₹1.6k for tight spaces like calendar cells.
    var inrCompact: String {
        if self >= 1000 {
            return "₹" + (self / 1000).formatted(.number.precision(.fractionLength(0...1))) + "k"
        }
        return inrWhole
    }
}

extension Date {
    var dayMonth: String { formatted(.dateTime.day().month(.abbreviated)) }
    var monthYear: String { formatted(.dateTime.month(.wide).year()) }
    var monthName: String { formatted(.dateTime.month(.wide)) }
    var weekdayDayMonth: String { formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }
    var time: String { formatted(date: .omitted, time: .shortened) }

    /// "Today", "Yesterday" or "Wed 16 Sep".
    var relativeDayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return weekdayDayMonth
    }
}

/// A rounded coloured square holding a category's symbol.
struct CategoryTile: View {
    let category: SpendCategory
    var size: CGFloat = 34
    var corner: CGFloat = 10

    var body: some View {
        Image(systemName: category.symbol)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(category.iconColor)
            .frame(width: size, height: size)
            .background(category.color, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Solid dark card used across screens.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        content.background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(_ radius: CGFloat = 24) -> some View { modifier(CardBackground(radius: radius)) }
}

/// Thin horizontal progress bar.
struct ProgressLine: View {
    let fraction: Double
    var color: Color = Theme.accent
    var height: CGFloat = 8
    var track: Color = Theme.card2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: geo.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: height)
    }
}
