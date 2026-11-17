import SwiftUI

struct RampDisplay: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    private var tempos: [Int] {
        let r = model.rhythm
        let direction = r.end >= r.start ? 1 : -1
        let count = Int(ceil(Double(abs(r.end-r.start)) / Double(max(1, r.increment))))
        // Large ramps remain legible without generating hundreds of bars.
        let indices = count <= 16 ? Array(0...count) : (0...16).map { Int(Double($0) * Double(count) / 16) }
        return indices.map { r.start + direction * min(abs(r.end-r.start), $0 * max(1, r.increment)) }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(model.playing && model.rhythm.ramp ? model.bpm : model.rhythm.start)").font(InstrumentType.display(46)).monospacedDigit()
                Text("BPM").technical(10, spacing: 1)
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(tempos.enumerated()), id: \.offset) { _, tempo in
                    let range = max(1, abs(model.rhythm.end-model.rhythm.start))
                    let height = 12 + 48 * Double(tempo - min(model.rhythm.start, model.rhythm.end)) / Double(range)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tempo == model.bpm && model.playing && model.rhythm.ramp ? InstrumentPalette.amber : p.ink.opacity(0.35))
                        .frame(maxWidth: .infinity).frame(height: height)
                }
            }.frame(height: 60, alignment: .bottom)
            HStack { Text("\(model.rhythm.start)"); Spacer(); Text("\(model.rhythm.end)") }.font(.caption).foregroundStyle(p.muted)
        }.padding(18).insetPanel(p, radius: 16).accessibilityIdentifier("ramp-preview")
    }
}

struct SilentBarsDisplay: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    private var total: Int { model.rhythm.audibleBars + model.rhythm.silentBars }
    private var active: Int? { model.playing && model.rhythm.gap && model.event?.countIn == false ? (model.event?.bar ?? 0) % total : nil }
    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(8, total)), spacing: 8) {
                ForEach(0..<total, id: \.self) { index in
                    let audible = !model.rhythm.isSilentBar(index)
                    Button {
                        let initial = model.rhythm.silentBarMask ?? (((1 << model.rhythm.silentBars) - 1) << model.rhythm.audibleBars)
                        model.rhythm.silentBarMask = initial ^ (1 << index)
                    } label: {
                    RoundedRectangle(cornerRadius: 5).fill(audible ? p.ink : p.muted.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(p.muted.opacity(audible ? 0 : 0.6), style: StrokeStyle(lineWidth: 1, dash: [3,3])))
                        .overlay { Image(systemName: audible ? "speaker.wave.2" : "speaker.slash").font(.system(size: 12)).foregroundStyle(audible ? p.body : p.muted) }
                        .overlay(alignment: .top) { if active == index { Capsule().fill(InstrumentPalette.amber).frame(height: 3).padding(4) } }
                        .frame(height: 48).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel("Bar \(index + 1)").accessibilityValue(audible ? "Sound" : "Silent")
                }
            }
            if let active {
                Text(L10n.format("%d / %d", active + 1, total)).font(.caption.monospacedDigit()).foregroundStyle(p.muted)
            }
        }.padding(18).insetPanel(p, radius: 16).accessibilityIdentifier("silent-bars-preview")
    }
}

/// Both rings use the same audio-clock cycle. No independently running UI timer.
struct PolyrhythmRings: View {
    static func color(_ lane: Int) -> Color { Color(hex: lane == 0 ? 0xAD6545 : lane == 1 ? 0x477D7B : 0x6D638F) }
    @ObservedObject var model: MetronomeModel
    let upper: Int
    let lower: Int
    let p: InstrumentPalette
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !model.playing)) { timeline in
        // Capture the scheduled frame time outside Canvas. Reading uptime only inside
        // Canvas lets SwiftUI reuse its drawing between audio-event updates.
        let frameTime = ProcessInfo.processInfo.systemUptime + timeline.date.timeIntervalSinceNow
        let event = model.event
        let sweep = model.playing && model.rhythm.crossCount > 0 ? event?.continuousSweep(at: frameTime) : nil
        let phase = sweep.map { $0.truncatingRemainder(dividingBy: 1) }
        let erasing = (sweep ?? 0) >= 1
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 18
            for lane in 0..<model.rhythm.polyCounts.count {
                let count = model.rhythm.polyCounts[lane]
                let radius = outer * (lane == 0 ? 1 : lane == 1 ? 0.70 : 0.40)
                context.stroke(Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2)), with: .color(p.muted.opacity(0.35)), lineWidth: 1)
                let accent = Color(hex: lane == 0 ? 0xE07326 : lane == 1 ? 0x22988B : 0x9376BC)
                // Keep the remaining colored arc during the erase revolution.
                if let phase {
                    var swept = Path()
                    swept.addArc(center: center, radius: radius, startAngle: .degrees(erasing ? phase * 360 - 90 : -90), endAngle: .degrees(erasing ? 270 : phase * 360 - 90), clockwise: false)
                    context.stroke(swept, with: .color(accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                for index in 0..<count {
                    let position = Double(index) / Double(count)
                    let angle = position * 2 * Double.pi - Double.pi/2
                    let point = CGPoint(x: center.x + cos(angle)*radius, y: center.y + sin(angle)*radius)
                    let intensity: Double = phase.map { (erasing ? $0 < position : $0 >= position) ? 1 : 0 } ?? 0
                    let radius: CGFloat = 6.5
                    let rect = CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2)
                    context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 1.2)), with: .color(.black.opacity(0.20)))
                    context.fill(Path(ellipseIn: rect), with: .linearGradient(
                        Gradient(colors: [Self.color(lane).opacity(0.82), Self.color(lane)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    context.fill(Path(ellipseIn: rect), with: .color(accent.opacity(intensity)))
                }
            }
            if let phase {
                let angle = phase * 2 * Double.pi - Double.pi / 2
                let direction = CGVector(dx: cos(angle), dy: sin(angle))
                let side = CGVector(dx: -direction.dy, dy: direction.dx)
                func point(_ length: CGFloat, _ width: CGFloat = 0) -> CGPoint {
                    CGPoint(x: center.x + direction.dx * length + side.dx * width,
                            y: center.y + direction.dy * length + side.dy * width)
                }
                // B: tapered graphite needle, short counterweight and a quiet bevel.
                var hand = Path()
                hand.move(to: point(-9, 0.9)); hand.addLine(to: point(0, 1.5))
                hand.addLine(to: point(outer + 7, 0)); hand.addLine(to: point(0, -1.5))
                hand.addLine(to: point(-9, -0.9)); hand.closeSubpath()
                context.drawLayer { shadow in
                    shadow.addFilter(.shadow(color: .black.opacity(0.2), radius: 0.8, x: 0, y: 1))
                    shadow.fill(hand, with: .color(p.ink))
                }
                var bevel = Path(); bevel.move(to: point(-8, -0.4)); bevel.addLine(to: point(outer + 5))
                context.stroke(bevel, with: .color(p.light.opacity(0.25)), lineWidth: 0.45)
                let hub = CGRect(x: center.x - 3.3, y: center.y - 3.3, width: 6.6, height: 6.6)
                context.fill(Path(ellipseIn: hub), with: .color(p.ink))
                context.stroke(Path(ellipseIn: hub.insetBy(dx: 0.6, dy: 0.6)), with: .color(p.light.opacity(0.25)), lineWidth: 0.5)
            }
            if phase == nil {
                context.draw(Text(model.rhythm.polyCounts.map(String.init).joined(separator: ":")).font(InstrumentType.value(32)).foregroundColor(p.ink), at: center)
            }
        }
        }.frame(height: 154).padding(14).insetPanel(p, radius: 16)
            .accessibilityLabel(L10n.format("%d over %d", upper, lower)).accessibilityIdentifier("polyrhythm-rings")
    }
}

struct CountInDisplay: View {
    @ObservedObject var model: MetronomeModel
    let p: InstrumentPalette
    private var counting: Bool { model.playing && model.event?.countIn == true }
    var body: some View {
        VStack(spacing: 18) {
            Text(L10n.text("Count-in")).font(.subheadline).foregroundStyle(p.muted)
            Text(counting ? "\((model.event?.beat ?? 0) + 1)" : model.rhythm.countIn == 0 ? L10n.text("Off") : L10n.bars(model.rhythm.countIn))
                .font(InstrumentType.display(counting ? 70 : 38)).monospacedDigit()
            HStack(spacing: 9) {
                ForEach(0..<model.rhythm.pulseCount, id: \.self) { beat in
                    Circle().fill(counting && model.event?.beat == beat ? InstrumentPalette.amber : p.muted.opacity(0.35)).frame(width: 9, height: 9)
                }
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 24).insetPanel(p, radius: 16)
    }
}
