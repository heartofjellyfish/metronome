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
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 18
            let phase = model.playing && model.rhythm.crossCount > 0 ? model.event?.cyclePosition : nil
            for lane in 0..<model.rhythm.polyCounts.count {
                let count = model.rhythm.polyCounts[lane]
                let radius = outer * (lane == 0 ? 1 : lane == 1 ? 0.70 : 0.40)
                context.stroke(Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2)), with: .color(p.muted.opacity(0.35)), lineWidth: 1)
                for index in 0..<count {
                    let position = Double(index) / Double(count)
                    let angle = position * 2 * Double.pi - Double.pi/2
                    let point = CGPoint(x: center.x + cos(angle)*radius, y: center.y + sin(angle)*radius)
                    let lit = phase.map { min(count - 1, Int(($0 * Double(count) + 0.0001).rounded(.down))) == index } ?? false
                    let radius: CGFloat = lit ? 9 : 6
                    let rect = CGRect(x: point.x-radius, y: point.y-radius, width: radius*2, height: radius*2)
                    if lit {
                        context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(Self.color(lane).opacity(0.55)), lineWidth: 2)
                    }
                    context.fill(Path(ellipseIn: rect.offsetBy(dx: 0, dy: 1.5)), with: .color(.black.opacity(0.20)))
                    context.fill(Path(ellipseIn: rect), with: .linearGradient(
                        Gradient(colors: [lit ? .white : Self.color(lane).opacity(0.8), Self.color(lane)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(lit ? 0.7 : 0.28)), lineWidth: 0.7)
                    context.fill(Path(ellipseIn: CGRect(x: point.x-3, y: point.y-4, width: 4, height: 2)), with: .color(.white.opacity(lit ? 0.65 : 0.28)))
                }
            }
            context.draw(Text(model.rhythm.polyCounts.map(String.init).joined(separator: " : ")).font(InstrumentType.value(model.rhythm.polyrhythmThird == nil ? 25 : 12)).foregroundColor(p.ink), at: center)
        }.frame(height: 200).padding(14).insetPanel(p, radius: 16)
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
