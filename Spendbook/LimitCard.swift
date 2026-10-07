import SwiftUI

/// Home screen card: a jar of liquid that fills with today's spending.
/// Over the daily limit it overflows, drips, glows and runs a ticker.
struct LimitCard: View {
    let spent: Double
    let limit: Double
    let monthLeft: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var over: Bool { spent > limit && spent > 0 }
    private var ratio: Double { limit > 0 ? spent / limit : (spent > 0 ? 1.2 : 0) }
    private var overBy: Double { spent - limit }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let pulse = reduceMotion ? 0.5 : (sin(t * 2 * .pi / 2.4) + 1) / 2

            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    LiquidJar(
                        level: ratio,
                        front: over ? Theme.warn : Theme.accent,
                        back: over ? Theme.warnDeep : Theme.calmDeep,
                        fill: over ? Theme.warnBG : Theme.calmBG,
                        time: t,
                        drips: over,
                        label: "\(Int((ratio * 100).rounded()))%"
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        if over {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .rotationEffect(.degrees(shakeAngle(t)), anchor: .top)
                                Text("DAILY LIMIT CROSSED")
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
                            Text("\(spent.inrWhole) spent of your \(limit.inrWhole) daily limit")
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
                    Ticker(items: [
                        "Over by \(overBy.inrWhole)",
                        "Limit today \(limit.inrWhole)",
                        "\(max(monthLeft, 0).inrWhole) left for the month",
                        "Skip one snack to get back on track"
                    ], time: t)
                }
            }
            .background(over ? Theme.warnCard : Theme.card,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Theme.warn.opacity(over ? 0.25 + 0.3 * pulse : 0), lineWidth: 1)
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
                        .font(.rounded(size * 0.23, .heavy))
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
