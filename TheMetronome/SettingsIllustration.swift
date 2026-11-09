import SwiftUI

/// Small physical objects, sharing the sound library's 80 × 64 drawing space.
struct SettingsIllustration: View {
    enum Kind { case practice, presets, pedal, setlists, songLibrary }
    let kind: Kind
    var body: some View {
        GeometryReader { g in
            Group {
                switch kind {
                case .practice: practice
                case .presets: disk
                case .pedal: Image("BluetoothFootPedal")
                case .setlists: Image("SetlistSheet")
                case .songLibrary: Image("SongLibraryCrate")
                }
            }.frame(width: 80, height: 64)
                .scaleEffect(min(g.size.width / 80, g.size.height / 64) * 0.82)
                .frame(width: g.size.width, height: g.size.height)
        }.accessibilityHidden(true)
    }
    private var graphite: LinearGradient {
        LinearGradient(colors: [Color(hex: 0xA09E90), Color(hex: 0x74766C)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    private var practice: some View {
        ZStack {
            Ellipse().fill(Color(hex: 0x64675E)).frame(width: 65, height: 43).offset(y: 8)
            Ellipse().fill(graphite).overlay(Ellipse().stroke(Color(hex: 0x85847A), lineWidth: 1))
                .overlay(Ellipse().stroke(.black.opacity(0.2), lineWidth: 0.7).padding(4))
                .frame(width: 65, height: 43).offset(y: 3)
            ForEach(0..<2) { i in
                HStack(spacing: -1) {
                    Ellipse().fill(Color(hex: 0xDFC191)).frame(width: 8, height: 5)
                    Capsule().fill(LinearGradient(colors: [Color(hex: 0xECD2AA), Color(hex: 0xAE8551)], startPoint: .top, endPoint: .bottom)).frame(width: 57, height: 3.5)
                }.rotationEffect(.degrees(i == 0 ? 25 : 35)).offset(x: 5, y: CGFloat(i * 9) - 4)
            }
        }.shadow(color: .black.opacity(0.12), radius: 1, x: 0, y: 2)
    }
    private var disk: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Color(hex: 0x62665D)).frame(width: 53,height: 57).offset(y: 2)
            RoundedRectangle(cornerRadius: 3).fill(graphite)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(hex: 0x77776C),lineWidth: 0.7)).frame(width: 53,height: 55)
            RoundedRectangle(cornerRadius: 1.5).fill(LinearGradient(colors: [Color(hex: 0xD2D0C4), Color(hex: 0x8F9189)],startPoint: .topLeading,endPoint: .bottomTrailing))
                .frame(width: 32,height: 19).offset(y: -18)
            Rectangle().fill(Color(hex: 0x333630)).frame(width: 8,height: 13).offset(x: 8,y: -18)
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xE6DCC5)).frame(width: 38,height: 23).offset(y: 13)
            VStack(spacing: 4) {
                ForEach(0..<3) { _ in Rectangle().fill(Color(hex: 0xB7AA8C).opacity(0.5)).frame(width: 29,height: 0.5) }
            }.offset(y: 13)
            ForEach([-1,1],id: \.self) { side in
                Rectangle().fill(Color(hex: 0x171B18)).frame(width: 4,height: 3).offset(x: CGFloat(side)*21,y: 23)
            }
        }
            .shadow(color: .black.opacity(0.12),radius: 1,x: 0,y: 2)
    }
    private func object(_ width: CGFloat, _ height: CGFloat, _ color: Color, radius: CGFloat = 3) -> some View {
        RoundedRectangle(cornerRadius: radius).fill(color).frame(width: width, height: height)
    }

}

struct BluetoothGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX,y: rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX,y: rect.height * 0.75))
        p.addLine(to: CGPoint(x: rect.midX,y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX,y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX,y: rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.minX,y: rect.height * 0.75))
        return p
    }
}

struct PedalDisplayStatus: View {
    @ObservedObject var pedal: PedalControl
    let p: InstrumentPalette
    let open: () -> Void
    @State private var pressed = false
    var body: some View {
        if pedal.bluetoothConnected {
            Button(action: open) {
                BluetoothGlyph().stroke(p.ink.opacity(pressed ? 1 : 0.65),style: StrokeStyle(lineWidth: 1.6,lineCap: .round,lineJoin: .round))
                    .frame(width: 10,height: 18).frame(width: 44,height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(L10n.text("Bluetooth pedal connected"))
                .accessibilityIdentifier("pedal-display-status")
                .task(id: pedal.pressRevision) {
                    guard pedal.pressRevision > 0 else { return }
                    pressed = true
                    do { try await Task.sleep(for: .milliseconds(140)) } catch { return }
                    withAnimation(.easeOut(duration: 0.15)) { pressed = false }
                }
        }
    }
}
