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
    static let accent = Color(hex: 0xFACC15)
    static let accentSoft = Color(hex: 0xFFF1A8)
    static let onAccent = Color(hex: 0x1A1400)
    static let background = Color.black
    static let sheet = Color(hex: 0x0B0B0C)
    static let card = Color(hex: 0x1C1C1E)
    static let card2 = Color(hex: 0x2C2C2E)
    static let secondary = Color(hex: 0x98989F)
    static let tertiary = Color(hex: 0x636366)
    static let separator = Color(hex: 0x38383A)
    static let warn = Color(hex: 0xFF2D3D)
    static let warnDeep = Color(hex: 0x7A0A12)
    static let warnText = Color(hex: 0xFF5A66)
    static let warnTicker = Color(hex: 0xFF9AA2)
    static let warnBG = Color(hex: 0x2A0A0D)
    static let warnCard = Color(hex: 0x1A0709)
    static let calmDeep = Color(hex: 0x8A6D00)
    static let calmBG = Color(hex: 0x262000)
    static let ai = Color(hex: 0xE5C8FF)
    // Glowing blobs behind the glass
    static let orb1 = Color(hex: 0xCA8A04)
    static let orb2 = Color(hex: 0xEA580C)
    static let orb3 = Color(hex: 0xA16207)
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

/// Liquid Glass card used across screens: see-through, with the glowing
/// background blobs showing through it.
struct CardBackground: ViewModifier {
    var radius: CGFloat = 24
    var tint: Color? = nil
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(Color.black.opacity(0.18), in: shape)
            .glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
            .overlay(shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05), .white.opacity(0.12)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1))
    }
}

extension View {
    func card(_ radius: CGFloat = 24, tint: Color? = nil) -> some View {
        modifier(CardBackground(radius: radius, tint: tint))
    }
}

/// Black background with three slowly drifting glow blobs in the theme colours.
struct AmbientBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    Color.black
                    Circle().fill(Theme.orb1).frame(width: 340, height: 340)
                        .position(x: w * 0.1 + 50 * sin(t / 7), y: 220 + 35 * cos(t / 7))
                        .opacity(0.5)
                    Circle().fill(Theme.orb2).frame(width: 360, height: 360)
                        .position(x: w * 1.0 - 40 * sin(t / 9), y: h * 0.48 + 30 * sin(t / 9))
                        .opacity(0.38)
                    Circle().fill(Theme.orb3).frame(width: 320, height: 320)
                        .position(x: w * 0.3 + 30 * cos(t / 11), y: h * 0.95 - 50 * sin(t / 11))
                        .opacity(0.4)
                }
                .blur(radius: 80)
                .overlay(RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .top,
                                        startRadius: 0, endRadius: h))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
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
