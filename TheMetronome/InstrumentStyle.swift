import SwiftUI

struct InstrumentPalette {
    var dark: Bool
    var body: Color { Color(hex: dark ? 0x343635 : 0xE5E0D5) }
    var ink: Color { Color(hex: dark ? 0xEEE5D1 : 0x262622) }
    var muted: Color { Color(hex: dark ? 0xA8AAA2 : 0x77786F) }
    var edge: Color { Color(hex: dark ? 0x101210 : 0xA9A292) }
    var top: Color { Color(hex: dark ? 0x414240 : 0xEBE6DB) }
    var bottom: Color { Color(hex: dark ? 0x303230 : 0xDDD7CB) }
    var well: Color { Color(hex: dark ? 0x222422 : 0xD5CFBF) }
    var light: Color { .white.opacity(dark ? 0.10 : 0.65) }
    static let amber = Color(hex: 0xE7A51B)
    static let orange = Color(hex: 0xF5792B)
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
extension View {
    func technical(_ size: CGFloat = 10, spacing: CGFloat = 2) -> some View {
        font(.system(size: size, weight: .medium, design: .monospaced)).tracking(spacing)
    }
    func insetPanel(_ p: InstrumentPalette, radius: CGFloat = 21) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius).fill(p.well
                .shadow(.inner(color: .black.opacity(p.dark ? 0.8 : 0.36), radius: 4, x: 2, y: 4))
                .shadow(.inner(color: p.light, radius: 2, x: -1, y: -2)))
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(p.light, lineWidth: 1).padding(0.5))
    }
}
enum InstrumentType {
    // Compared against the reference: curved 6/9 terminals and condensed bold proportions.
    static func display(_ size: CGFloat) -> Font { .custom("HelveticaNeue-CondensedBold", size: size) }
    static func value(_ size: CGFloat) -> Font { .custom("HelveticaNeue-Medium", size: size) }
}

struct HardwareButtonStyle: ButtonStyle {
    var p: InstrumentPalette
    var charcoal = false
    var green = false
    var radius: CGFloat = 10
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(green ? Color(hex: 0x243326) : charcoal ? Color(hex: 0xF5F0E2) : p.ink)
            .background { HardwareKeySurface(p: p, charcoal: charcoal, green: green, radius: radius, pressed: configuration.isPressed) }
            .offset(y: configuration.isPressed ? 1.6 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

struct HardwareKeySurface: View {
    let p: InstrumentPalette
    var charcoal = false
    var green = false
    var radius: CGFloat = 10
    var pressed = false
    private var r: CGFloat { max(4, radius) }
    private var dark: Bool { !green && (charcoal || p.dark) }
    var body: some View {
        let outline = RoundedRectangle(cornerRadius: r, style: .continuous)
        ZStack {
            // A narrow contact seam, not a thick extruded shelf beneath the key.
            outline.fill(dark ? Color(hex: 0x0A0C0B) : Color(hex: 0x9A9587))
                .offset(y: pressed ? 0 : 0.8)
                .shadow(color: .black.opacity(dark ? 0.65 : 0.24), radius: pressed ? 0.6 : 2.1, x: 0.6, y: pressed ? 0.4 : 2.1)
                .shadow(color: .black.opacity(dark ? 0.25 : 0.13), radius: pressed ? 1 : 5, x: 1.3, y: pressed ? 1 : 4)
            outline
                .fill(LinearGradient(colors: green ? [Color(hex: 0xAFC7A1), Color(hex: 0x8DA97D)] : dark
                    ? [Color(hex: 0x3D3F3D), Color(hex: 0x303230)]
                    : [Color(hex: 0xEAE6DD), Color(hex: 0xDDD9CE)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .shadow(.inner(color: .white.opacity(dark ? 0.16 : 0.85), radius: 1.6, x: 1.4, y: 1.8))
                    .shadow(.inner(color: .black.opacity(dark ? 0.5 : 0.20), radius: 2.5, x: -1.7, y: -2.3)))
                .overlay(MaterialGrain().opacity(dark ? 0.065 : 0.035).blendMode(.overlay).clipShape(outline))
                .overlay {
                    outline.strokeBorder(LinearGradient(stops: [
                        .init(color: .white.opacity(dark ? 0.21 : 0.9), location: 0),
                        .init(color: .white.opacity(dark ? 0.08 : 0.35), location: 0.38),
                        .init(color: .black.opacity(dark ? 0.65 : 0.28), location: 1)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: max(3, r - 2.6), style: .continuous)
                        .stroke(LinearGradient(colors: [.white.opacity(dark ? 0.10 : 0.60), .white.opacity(0)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                        .padding(2.6).blur(radius: 0.4)
                }
                .padding(0.65)
        }
    }
}

struct LED: View {
    var on: Bool
    var color = InstrumentPalette.orange
    var size: CGFloat = 7
    var intensity: Double = 1
    var body: some View {
        let light = on ? min(1, max(0, intensity)) : 0
        ZStack {
            // A recessed socket, tinted diffuser and tiny reflected highlight.
            Circle().fill(LinearGradient(colors: [Color.black.opacity(0.65), Color.white.opacity(0.28)], startPoint: .top, endPoint: .bottom))
            Circle().fill(Color(hex: 0x65513A)).padding(size * 0.12)
            Circle().fill(color.opacity(on ? 0.80 + light * 0.20 : 0.12)).padding(size * 0.12)
            Circle().fill(RadialGradient(colors: [Color(hex: 0xFFF5C6).opacity(light * 0.96), .clear], center: .center, startRadius: 0, endRadius: size * 0.54)).padding(size * 0.14)
            Ellipse().fill(.white.opacity(0.25 + light * 0.25))
                .frame(width: size * 0.30, height: size * 0.15).offset(x: -size * 0.13, y: -size * 0.20)
        }
        .frame(width: size, height: size)
        .shadow(color: color.opacity(light * 0.62), radius: size * 0.38)
        .shadow(color: color.opacity(light * 0.20), radius: size * 0.85)
        .accessibilityHidden(true)
    }
}
struct SectionLabel: View {
    let text: String
    let p: InstrumentPalette
    var body: some View {
        HStack(spacing: 14) {
            Text(text).technical(9, spacing: 2).fixedSize()
            Rectangle().fill(p.edge.opacity(0.65)).frame(height: 0.5)
        }.foregroundStyle(p.ink)
    }
}
struct TempoDial: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    @State private var interaction = DialInteraction()
    var angle: Double { TempoScale.angle(for: model.bpm) }
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                DialTicks(p: p, knurl: false)
                VStack {
                    Spacer()
                    HStack {
                        Text("20"); Spacer(); Text("300")
                    }.font(InstrumentType.value(10)).foregroundStyle(p.muted).padding(.horizontal, 28)
                }.padding(.bottom, 3)

                Circle().fill(p.edge).padding(9).offset(y: 4)
                    .shadow(color: .black.opacity(p.dark ? 0.5 : 0.24), radius: 5, x: 3, y: 7)
                Circle().fill(LinearGradient(colors: [p.top, p.bottom], startPoint: .topLeading, endPoint: .bottomTrailing)).padding(9)
                    .overlay { DialTicks(p: p, knurl: true) }
                Circle().fill(LinearGradient(colors: [p.top, p.bottom], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .padding(15).overlay(MaterialGrain().opacity(p.dark ? 0.028 : 0.015).blendMode(.overlay).clipShape(Circle()).padding(15)).overlay(Circle().stroke(p.light, lineWidth: 0.75).padding(15))
                VStack(spacing: 0) {
                    Capsule().fill(InstrumentPalette.amber).frame(width: 4, height: 15)
                    Capsule().fill(p.ink).frame(width: 4, height: 10)
                    Spacer()
                }.padding(.top, 17).padding(.bottom, 17).rotationEffect(.degrees(angle))

            }.frame(width: side, height: side)
                .contentShape(Circle())
                .gesture(DragGesture(minimumDistance: 2).onChanged { value in
                    let dx = value.location.x - side / 2
                    let dy = value.location.y - side / 2
                    guard hypot(dx, dy) > side * 0.18 else { interaction.end(); return }
                    let current = Double(atan2(dx, -dy)) * 180 / .pi
                    if !interaction.isTracking { interaction.begin(at: current, bpm: model.bpm) }
                    else if let bpm = interaction.move(to: current), bpm != model.bpm { model.setBPM(bpm) }
                }.onEnded { _ in interaction.end() })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tempo")
                .accessibilityIdentifier("tempoDial")
                .accessibilityValue("\(model.bpm) beats per minute")
                .accessibilityAdjustableAction { direction in model.setBPM(model.bpm + (direction == .increment ? 1 : -1)) }
        }.aspectRatio(1, contentMode: .fit)
    }
}

struct DialTicks: View {
    let p: InstrumentPalette
    let knurl: Bool
    var body: some View {
        Canvas { context, size in
            let count = knurl ? 150 : 57
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius: Double = Double(min(size.width, size.height)) / 2 - (knurl ? 11 : 2)
            for n in 0..<count {
                let degrees: Double = knurl ? Double(n) / 150 * 360 : TempoScale.startAngle + Double(n) / 56 * 270 - 90
                let theta: Double = degrees * Double.pi / 180
                let major = !knurl && n % 6 == 0
                let length: Double = knurl ? 4 : major ? 5 : 3
                let start = CGPoint(x: Double(center.x) + cos(theta) * (radius - length), y: Double(center.y) + sin(theta) * (radius - length))
                let end = CGPoint(x: Double(center.x) + cos(theta) * radius, y: Double(center.y) + sin(theta) * radius)
                var path = Path(); path.move(to: start); path.addLine(to: end)
                let color = knurl ? p.edge.opacity(0.6) : p.ink.opacity(major ? 0.9 : 0.6)
                context.stroke(path, with: .color(color), lineWidth: major ? 1.1 : 0.7)
            }
        }
    }
}

struct InstrumentBody: View {
    let p: InstrumentPalette
    var body: some View {
        ZStack {
            LinearGradient(colors: p.dark ? [Color(hex: 0x444643), Color(hex: 0x303231), Color(hex: 0x262827)] : [Color(hex: 0xE9E4DA), Color(hex: 0xE5E0D5), Color(hex: 0xDDD8CB)], startPoint: .topLeading, endPoint: .bottomTrailing)
            MaterialGrain().opacity(p.dark ? 0.025 : 0.015).blendMode(.overlay)
        }
    }
}
struct MaterialGrain: View {
    private static let texture: CGImage = {
        let side = 192
        var bytes = [UInt8](repeating: 0, count: side * side)
        var seed: UInt64 = 73
        for i in bytes.indices { seed = seed &* 6364136223846793005 &+ 1; bytes[i] = UInt8((seed >> 32) & 255) }
        let data = Data(bytes) as CFData
        let provider = CGDataProvider(data: data)!
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }()
    var body: some View { Image(decorative: Self.texture, scale: 2).resizable(resizingMode: .tile).allowsHitTesting(false).accessibilityHidden(true) }
}
