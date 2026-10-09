import SwiftUI

/// Home screen card: a jar of liquid that fills with today's spending.
/// Over the daily limit it overflows, drips, glows and runs a ticker.
struct LimitCard: View {
    let plan: LimitPlan
    let monthLeft: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spent: Double { plan.todaySpent }
    private var limit: Double { plan.todayLimit }
    private var over: Bool { plan.isOverToday }
    private var ratio: Double { limit > 0 ? spent / limit : (spent > 0 ? 1.2 : 0) }
    private var overBy: Double { plan.overToday }

    private var tickerItems: [String] {
        var items = ["Over by \(overBy.inrWhole)", "Limit today \(limit.inrWhole)"]
        if let tomorrow = plan.tomorrowLimit {
            if plan.carryOver && plan.tomorrowCut > 0 {
                items.append("Rest of the week: \(tomorrow.inrWhole)/day (cut by \(plan.tomorrowCut.inrWhole))")
            } else {
                items.append("Tomorrow's limit \(tomorrow.inrWhole)")
            }
        }
        items.append("\(max(plan.weekLeft, 0).inrWhole) left this week")
        items.append("\(max(monthLeft, 0).inrWhole) left for the month")
        return items
    }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.5 : (sin(t * 2 * .pi / 2.4) + 1) / 2

            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    ZStack(alignment: .topTrailing) {
                    LiquidJar(
                        level: ratio,
                        front: over ? Theme.warn : Theme.accent,
                        back: over ? Theme.warnDeep : Theme.calmDeep,
                        fill: over ? Theme.warnBG : Theme.calmBG,
                        time: t,
                        drips: over,
                        label: "\(Int((ratio * 100).rounded()))%",
                        size: 96
                    )
                    if over {
                        SkullBadge(time: t)
                            .offset(x: 16, y: -12)
                    }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        if over {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .rotationEffect(.degrees(shakeAngle(t)), anchor: .top)
                                Text("DANGER · LIMIT CROSSED")
                            }
                            .font(.system(size: 12, weight: .heavy))
                            .kerning(0.7)
                            .foregroundStyle(Theme.warnText)
                            Text("\(overBy.inrWhole) over today")
                                .font(.system(size: 21, weight: .heavy))
                            Text("\(spent.inrWhole) spent of your \(limit.inrWhole) daily limit")
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: 0xC7B2AA))
                        } else {
                            Text("ON TRACK TODAY")
                                .font(.system(size: 12, weight: .heavy))
                                .kerning(0.7)
                                .foregroundStyle(Theme.accent)
                            Text("\(max(limit - spent, 0).inrWhole) left today")
                                .font(.system(size: 21, weight: .heavy))
                            Text(plan.todayCut > 0
                                 ? "Limit cut by \(plan.todayCut.inrWhole) to cover earlier days"
                                 : "\(spent.inrWhole) spent of your \(limit.inrWhole) daily limit")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.secondary)
                        }
                    }
                    .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, over ? 0 : 14)

                if over {
                    Ticker(items: tickerItems, time: t)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .card(26, tint: over ? Theme.warn.opacity(0.28) : nil)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Theme.warn.opacity(over ? 0.3 + 0.4 * pulse : 0), lineWidth: 1.2)
            }
            .shadow(color: Theme.warn.opacity(over ? 0.28 * pulse : 0), radius: 20)
        }
        .accessibilityElement(children: .combine)
    }

    /// A short wobble every 3 seconds.
    private func shakeAngle(_ t: Double) -> Double {
        let p = t.truncatingRemainder(dividingBy: 3) / 3
        guard p > 0.86 else { return 0 }
        let k = (p - 0.86) / 0.14
        return sin(k * .pi * 4) * 12 * (1 - k)
    }
}

/// Round jar with two animated waves. Above 100% the liquid rises past the
/// rim and drops fall from the bottom.
struct LiquidJar: View {
    var level: Double
    var front: Color
    var back: Color
    var fill: Color
    var time: Double
    var drips: Bool
    var label: String?
    var size: CGFloat = 64

    var body: some View {
        ZStack(alignment: .top) {
            Canvas { ctx, sz in
                let rect = CGRect(origin: .zero, size: sz)
                ctx.clip(to: Path(ellipseIn: rect))
                ctx.fill(Path(rect), with: .color(fill))

                let clamped = min(max(level, 0), 1.15)
                let surface = sz.height * (1 - min(clamped, 1)) - (clamped > 1 ? sz.height * 0.08 : 0)

                func wave(phase: Double, amplitude: CGFloat, length: CGFloat) -> Path {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: sz.height))
                    var x: CGFloat = 0
                    while x <= sz.width {
                        let y = surface + amplitude * CGFloat(sin(Double(x / length) * 2 * .pi + phase))
                        path.addLine(to: CGPoint(x: x, y: y))
                        x += 2
                    }
                    path.addLine(to: CGPoint(x: sz.width, y: sz.height))
                    path.closeSubpath()
                    return path
                }

                if clamped > 0 {
                    ctx.fill(wave(phase: -time * 1.7, amplitude: 3.5, length: sz.width * 0.9), with: .color(back))
                    ctx.fill(wave(phase: time * 2.4, amplitude: 3, length: sz.width * 0.7), with: .color(front))
                }

                // Moving shine
                let shineX = CGFloat((time / 4.5).truncatingRemainder(dividingBy: 1)) * sz.width * 2.4 - sz.width * 0.7
                let shine = Path(CGRect(x: shineX, y: 0, width: sz.width * 0.35, height: sz.height))
                ctx.fill(shine, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0)]),
                    startPoint: CGPoint(x: shineX, y: 0),
                    endPoint: CGPoint(x: shineX + sz.width * 0.35, y: 0)))
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(front.opacity(0.45), lineWidth: 1.5))
            .overlay {
                if let label {
                    Text(label)
                        .font(.rounded(size * 0.28, .black))
                        .foregroundStyle(Color(hex: 0x1A0A05))
                        .monospacedDigit()
                }
            }
            .padding(.top, 8)

            Capsule()
                .fill(.white.opacity(0.6))
                .frame(width: size - 12, height: 2)
                .padding(.top, 6)

            if drips {
                ForEach(0..<2, id: \.self) { i in
                    let p = ((time + Double(i) * 0.9).truncatingRemainder(dividingBy: 1.8)) / 1.8
                    let opacity = p < 0.15 ? p / 0.15 : (p > 0.7 ? (1 - p) / 0.3 : 1)
                    Ellipse()
                        .fill(front)
                        .frame(width: i == 0 ? 7 : 5, height: i == 0 ? 9 : 7)
                        .scaleEffect(1 - p * 0.5)
                        .offset(x: i == 0 ? size * 0.22 : -size * 0.28, y: size + 4 + 26 * p)
                        .opacity(opacity)
                }
            }
        }
        .frame(width: size, height: size + 14, alignment: .top)
        .accessibilityHidden(true)
    }
}

/// Endless scrolling strip of short messages.
struct Ticker: View {
    let items: [String]
    let time: Double
    @State private var width: CGFloat = 1

    var body: some View {
        let row = HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Text(item)
                    Circle().fill(Theme.warn.opacity(0.7)).frame(width: 4, height: 4)
                }
                .padding(.trailing, 20)
            }
        }
        .fixedSize()

        HStack(spacing: 0) {
            row.onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = max(newWidth, 1)
            }
            row
        }
        .offset(x: -CGFloat((time * 28).truncatingRemainder(dividingBy: Double(width))))
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Theme.warnTicker)
        .padding(.vertical, 8)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.warnBG)
        .clipped()
        .accessibilityHidden(true)
    }
}


/// Monday–Sunday strip: what each day spent, and what the days ahead are allowed.
struct WeekStrip: View {
    let plan: LimitPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This week").font(.system(size: 15, weight: .semibold))
                Spacer()
                if plan.carryOver, plan.tomorrowCut > 0, let t = plan.tomorrowLimit {
                    Text("Next days \(t.inrWhole)/day")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.warnText)
                } else {
                    Text("\(plan.daily.inrWhole)/day")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
            }
            HStack(spacing: 6) {
                ForEach(plan.days) { day in
                    let over = !day.isFuture && day.spent > day.allowance && day.spent > 0
                    let fill = day.isFuture ? 0 : min(day.spent / max(day.allowance, 1), 1)
                    VStack(spacing: 5) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6).fill(Theme.card2)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(over ? Theme.warn : Theme.accent)
                                .frame(height: 54 * fill)
                            if day.isFuture && day.allowance < plan.daily {
                                // A shorter outline shows the reduced allowance for days ahead.
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Theme.warnText.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                                    .frame(height: 54 * min(day.allowance / max(plan.daily, 1), 1))
                            }
                        }
                        .frame(height: 54)
                        .overlay {
                            if day.isToday {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white, lineWidth: 1.5)
                            }
                        }
                        Text(day.letter)
                            .font(.system(size: 11, weight: day.isToday ? .heavy : .medium))
                            .foregroundStyle(day.isToday ? .white : Theme.secondary)
                        Text(day.isFuture ? day.allowance.inrCompact : day.spent.inrCompact)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(day.isFuture ? Theme.tertiary : (over ? Theme.warnText : Theme.accentSoft))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.isFuture
                        ? "\(day.date.weekdayDayMonth), allowed \(day.allowance.inrWhole)"
                        : "\(day.date.weekdayDayMonth), spent \(day.spent.inrWhole)")
                }
            }
        }
        .padding(16)
        .card(22)
    }
}


/// Floating danger skull shown over the jar when today's limit is crossed.
/// It bobs and tilts, its eyes glow, and a red halo pulses behind it.
struct SkullBadge: View {
    let time: Double
    var size: CGFloat = 42

    var body: some View {
        let bob = sin(time * 2 * .pi / 2.2)
        let pulse = (sin(time * 2 * .pi / 1.1) + 1) / 2

        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.warn.opacity(0.7), Theme.warn.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: size * 0.7))
                .frame(width: size * 1.4, height: size * 1.4)
                .scaleEffect(0.9 + 0.3 * pulse)
                .opacity(0.4 + 0.4 * pulse)

            ZStack {
                // Cranium and jaw
                VStack(spacing: -size * 0.06) {
                    Ellipse()
                        .fill(Color(hex: 0xF4F1EA))
                        .frame(width: size * 0.9, height: size * 0.78)
                    RoundedRectangle(cornerRadius: size * 0.08)
                        .fill(Color(hex: 0xF4F1EA))
                        .frame(width: size * 0.5, height: size * 0.22)
                        .overlay(
                            HStack(spacing: size * 0.08) {
                                ForEach(0..<2, id: \.self) { _ in
                                    Rectangle().fill(Color(hex: 0x1A0306)).frame(width: 1.5)
                                }
                            }
                        )
                }
                // Eyes with glowing pupils
                HStack(spacing: size * 0.14) {
                    ForEach(0..<2, id: \.self) { _ in
                        Ellipse()
                            .fill(Color(hex: 0x1A0306))
                            .frame(width: size * 0.22, height: size * 0.25)
                            .overlay(Circle().fill(Theme.warn).frame(width: size * 0.08)
                                .opacity(0.35 + 0.65 * pulse)
                                .shadow(color: Theme.warn, radius: 3))
                    }
                }
                .offset(y: -size * 0.06)
                // Nose
                Triangle()
                    .fill(Color(hex: 0x1A0306))
                    .frame(width: size * 0.12, height: size * 0.12)
                    .offset(y: size * 0.12)
            }
            .shadow(color: Theme.warn.opacity(0.9), radius: 6)
            .shadow(color: .black.opacity(0.6), radius: 3, y: 3)
            .offset(y: -4 - 4 * bob)
            .rotationEffect(.degrees(7 * bob))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Danger: over the daily limit")
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
