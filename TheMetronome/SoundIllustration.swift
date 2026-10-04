import SwiftUI

struct SoundIllustration: View {
    let index: Int
    let p: InstrumentPalette
    var body: some View {
        GeometryReader { g in
            ZStack {
                if index == 0 { wood }
                else if index == 1 { waveform }
                else if index == 2 { bell }
                else if index == 3 || index == 9 { hiHat }
                else if index == 7 {
                    ZStack {
                        Image(systemName: "hand.point.up.left.fill").font(.system(size: 44, weight: .light)).foregroundStyle(Color(hex: 0xCBA46E))
                        Image(systemName: "sparkle").font(.system(size: 16, weight: .light)).foregroundStyle(p.muted).offset(x: -23, y: -19)
                    }.shadow(color: .black.opacity(0.15), radius: 2, x: 1, y: 2)
                }
                else if index == 8 {
                    Image(systemName: "hands.clap.fill").font(.system(size: 46, weight: .light)).foregroundStyle(LinearGradient(colors: [Color(hex: 0xE4C18E), Color(hex: 0xAC8050)], startPoint: .topLeading, endPoint: .bottomTrailing)).shadow(color: .black.opacity(0.15), radius: 2, x: 1, y: 2)
                }
                else if index == 4 { shaker }
                else if index == 6 {
                    ZStack {
                        Capsule().fill(Color(hex: 0xCBA46E)).frame(width: 6, height: 68).rotationEffect(.degrees(43))
                        Capsule().fill(Color(hex: 0xDABB8D)).frame(width: 6, height: 68).rotationEffect(.degrees(-43))
                    }
                }
                else { rim }
            }.frame(width: 80, height: 64).scaleEffect(min(g.size.width / 80, g.size.height / 64)).frame(width: g.size.width, height: g.size.height)
        }.accessibilityHidden(true)
    }
    private var hiHat: some View {
        ZStack {
            Path { q in
                q.move(to: CGPoint(x: 40, y: 9)); q.addLine(to: CGPoint(x: 40, y: 55))
                q.move(to: CGPoint(x: 40, y: 49)); q.addLine(to: CGPoint(x: 23, y: 62))
                q.move(to: CGPoint(x: 40, y: 49)); q.addLine(to: CGPoint(x: 57, y: 62))
            }.stroke(Color(hex: 0x74756E), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ForEach(0..<(index == 9 ? 1 : 2)) { i in
                Ellipse().fill(LinearGradient(colors: [Color(hex: 0xB49145), Color(hex: 0xE2C87B), Color(hex: 0x8A692E)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Ellipse().stroke(Color(hex: 0x806027), lineWidth: 0.7))
                    .overlay(Ellipse().stroke(Color(hex: 0xF2DFA6).opacity(0.65), lineWidth: 0.5).padding(4))
                    .frame(width: 66, height: 15).position(x: 40, y: i == 0 ? 30 : 23)
            }
            Ellipse().fill(Color(hex: 0xCEAE63)).frame(width: 18, height: 9).position(x: 40, y: 20)
            Capsule().fill(Color(hex: 0x41453F)).frame(width: 4, height: 10).position(x: 40, y: 15)
        }.shadow(color: .black.opacity(0.16), radius: 2, x: 1, y: 2)
    }
    private var shaker: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13).fill(LinearGradient(colors: [Color(hex: 0xB3673C), Color(hex: 0xE6A473), Color(hex: 0x9F512B)], startPoint: .top, endPoint: .bottom))
                .frame(width: 62, height: 30)
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color(hex: 0x713B24), lineWidth: 0.7))
            ForEach(0..<7) { i in
                Rectangle().fill(Color(hex: 0x713B24).opacity(0.25)).frame(width: 0.8, height: 21).offset(x: CGFloat(i - 3) * 5)
            }
            Ellipse().fill(Color(hex: 0x693E2B)).overlay(Ellipse().stroke(Color(hex: 0xDE9F71), lineWidth: 1.5))
                .frame(width: 11, height: 29).offset(x: 26)
        }.rotationEffect(.degrees(-25)).position(x: 40, y: 34)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 3)
    }
    private var rim: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(LinearGradient(colors: [Color(hex: 0xA8674C), Color(hex: 0x6A382C)], startPoint: .top, endPoint: .bottom)).frame(width: 59, height: 25).position(x: 40, y: 38)
            Ellipse().fill(Color(hex: 0x7C7D73)).frame(width: 62, height: 17).position(x: 40, y: 49)
            ForEach(0..<4) { i in
                Capsule().fill(Color(hex: 0xB3B5AA)).frame(width: 3, height: 19).position(x: 18 + CGFloat(i) * 15, y: 40)
            }
            Ellipse().fill(Color(hex: 0xDDD9C9)).overlay(Ellipse().stroke(Color(hex: 0x74766D), lineWidth: 2))
                .overlay(Ellipse().stroke(.white.opacity(0.55), lineWidth: 0.8).padding(3))
                .frame(width: 64, height: 24).position(x: 40, y: 27)
            Capsule().fill(LinearGradient(colors: [Color(hex: 0xF0D2A4), Color(hex: 0xB08652)], startPoint: .top, endPoint: .bottom))
                .frame(width: 63, height: 4).rotationEffect(.degrees(index == 10 ? -8 : -28)).position(x: 40, y: index == 10 ? 28 : 20)
        }.shadow(color: .black.opacity(0.16), radius: 2, x: 1, y: 3)
    }
    private var wood: some View {
        ZStack {
            Path { q in q.addLines([CGPoint(x: 6, y: 29), CGPoint(x: 56, y: 9), CGPoint(x: 76, y: 17), CGPoint(x: 26, y: 40)]); q.closeSubpath() }
                .fill(LinearGradient(colors: [Color(hex: 0xB3946D), Color(hex: 0xD2B287)], startPoint: .top, endPoint: .bottom))
            Path { q in q.addLines([CGPoint(x: 26, y: 40), CGPoint(x: 76, y: 17), CGPoint(x: 76, y: 38), CGPoint(x: 26, y: 61)]); q.closeSubpath() }
                .fill(LinearGradient(colors: [Color(hex: 0x94734F), Color(hex: 0x6D5037)], startPoint: .top, endPoint: .bottom))
            Path { q in q.addLines([CGPoint(x: 6, y: 29), CGPoint(x: 26, y: 40), CGPoint(x: 26, y: 61), CGPoint(x: 6, y: 50)]); q.closeSubpath() }.fill(Color(hex: 0x94774F))
            Ellipse().fill(Color(hex: 0x3B2F21)).frame(width: 6, height: 9).rotationEffect(.degrees(-15)).position(x: 16, y: 44)
            Canvas { ctx, _ in
                for n in 0..<10 {
                    let offset = Double(n) * 1.6
                    var line = Path(); line.move(to: CGPoint(x: 28, y: 42 + offset)); line.addLine(to: CGPoint(x: 74, y: 20 + offset))
                    ctx.stroke(line, with: .color(Color(hex: 0x3B2F21).opacity(0.22)), lineWidth: 0.6)
                }
            }
        }.shadow(color: .black.opacity(0.18), radius: 2, x: 2, y: 3)
    }
    private var waveform: some View {
        Path { q in
            q.move(to: CGPoint(x: 4, y: 34))
            q.addCurve(to: CGPoint(x: 16, y: 37), control1: CGPoint(x: 10, y: 9), control2: CGPoint(x: 12, y: 57))
            q.addLines([CGPoint(x: 23, y: 19), CGPoint(x: 28, y: 53), CGPoint(x: 35, y: 6), CGPoint(x: 41, y: 56), CGPoint(x: 47, y: 17), CGPoint(x: 53, y: 44)])
            q.addCurve(to: CGPoint(x: 75, y: 33), control1: CGPoint(x: 61, y: 11), control2: CGPoint(x: 62, y: 52))
        }.stroke(p.muted.opacity(0.65), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
    private var bell: some View {
        ZStack {
            Ellipse().stroke(Color(hex: 0x5D5E5A), lineWidth: 2).frame(width: 6, height: 8).position(x: 41, y: 5)
            Circle().fill(Color(hex: 0x444641)).frame(width: 8, height: 8).position(x: 41, y: 59)
            BellShape().fill(LinearGradient(stops: [.init(color: Color(hex: 0x232421), location: 0), .init(color: Color(hex: 0x5F615B), location: 0.28), .init(color: Color(hex: 0x92948B), location: 0.39), .init(color: Color(hex: 0x353732), location: 0.61), .init(color: Color(hex: 0x171915), location: 1)], startPoint: .leading, endPoint: .trailing)).frame(width: 47, height: 49).position(x: 41, y: 31)
            Ellipse().fill(Color(hex: 0x242620)).overlay(Ellipse().stroke(Color(hex: 0x8A8B81), lineWidth: 0.8)).frame(width: 49, height: 7).position(x: 41, y: 54)
        }.shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 3)
    }
}
struct BellShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: 0, y: r.height))
        p.addCurve(to: CGPoint(x: r.width * 0.5, y: 0), control1: CGPoint(x: r.width * 0.35, y: r.height * 0.8), control2: CGPoint(x: r.width * 0.1, y: 0))
        p.addCurve(to: CGPoint(x: r.width, y: r.height), control1: CGPoint(x: r.width * 0.9, y: 0), control2: CGPoint(x: r.width * 0.65, y: r.height * 0.8))
        p.closeSubpath(); return p
    }
}
