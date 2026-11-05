import SwiftUI

struct DivisionPanel: View {
    @Binding var rhythm: Rhythm
    let playing: Bool
    let p: InstrumentPalette
    let stopPreview: () -> Void
    let close: () -> Void
    @State private var patternTab: Bool
    @State private var family: Int
    @State private var editing = false
    @State private var draft: Rhythm
    @State private var moreGrid = false
    @State private var swingExpanded = false
    @State private var message: String?
    @State private var pendingGrid: Int?
    init(rhythm: Binding<Rhythm>, playing: Bool, p: InstrumentPalette, stopPreview: @escaping () -> Void, close: @escaping () -> Void) {
        _rhythm = rhythm; self.playing = playing; self.p = p; self.stopPreview = stopPreview; self.close = close
        let value = rhythm.wrappedValue
        _patternTab = State(initialValue: value.divisionMask != nil || value.swingRatio > 0.5)
        _family = State(initialValue: [2,3,4].contains(value.subdivision) ? value.subdivision : value.subdivision == 6 && value.enabledMask == 17 ? 3 : 4)
        _draft = State(initialValue: value)
    }
    var body: some View {
        VStack(spacing: 18) {
            if editing { editor } else {
                HStack(spacing: 10) {
                    tab("Even divisions", selected: !patternTab, id: "division-even") { patternTab = false }
                    tab("Patterns", selected: patternTab, id: "division-patterns") { patternTab = true }
                }
                if patternTab { patterns } else { equalDivisions }
            }
        }.onDisappear { stopPreview() }
            .onChange(of: playing) { _, value in
                if editing && value { rhythm = draft }
            }
    }
    private func tab(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button { stopPreview(); action() } label: {
            Text(L10n.text(title)).font(.system(size: 15, weight: selected ? .semibold : .medium)).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity, minHeight: 44)
        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: selected, radius: 10))
            .accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var equalDivisions: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(1...8, id: \.self) { n in
                let value = withDivision(n)
                let selected = rhythm.subdivision == n && rhythm.divisionMask == nil && rhythm.swingRatio == 0.5
                Button { apply(value) } label: {
                    VStack(spacing: 5) {
                        RhythmScore(rhythm: value, color: p.ink).frame(height: 45).padding(.horizontal, 16)
                        Text(n <= 4 ? L10n.text([1:"One per beat",2:"Two per beat",3:rhythm.usesCompoundPulse ? "Three per beat" : "Triplets",4:"Four per beat"][n]!) : L10n.format("%d per beat", n))
                            .font(.system(size: 12)).foregroundStyle(p.muted)
                    }.padding(.top, 23).padding(.bottom, 10).frame(maxWidth: .infinity)
                        .overlay(alignment: .topLeading) { LED(on: selected, color: InstrumentPalette.amber, size: 8).padding(14) }
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
                    .accessibilityIdentifier("division-count-\(n)").accessibilityLabel(L10n.format("%d clicks per beat", n))
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
    private var patterns: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach([2,3,4], id: \.self) { n in
                    tab(n == 2 ? "Eighths" : n == 3 ? "Triplets" : "Sixteenths", selected: family == n, id: "pattern-family-\(n)") { family = n }
                }
            }
            ForEach(RhythmPattern.choices(family)) { pattern in
                let value = pattern.applying(to: rhythm)
                let selected = (rhythm.subdivision == pattern.count && rhythm.enabledMask == pattern.mask || rhythm.subdivision == 6 && rhythm.enabledMask == 17 && pattern.count == 3 && pattern.mask == 5) && rhythm.swingRatio == 0.5
                HStack(spacing: 12) {
                    Button { apply(value) } label: {
                        RhythmScore(rhythm: value, color: p.ink).frame(height: 40).padding(.top, 18).padding(.bottom, 10).frame(maxWidth: .infinity)
                            .overlay(alignment: .topLeading) { LED(on: selected, color: InstrumentPalette.amber, size: 8).padding(14) }
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 11)).accessibilityIdentifier("pattern-\(pattern.id)")
                        .accessibilityLabel(L10n.format("Rhythm pattern %@", pattern.id)).accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            Button { stopPreview(); draft = rhythm; editing = true } label: {
                HStack { Image(systemName: "pencil"); Text("Edit rhythm"); Spacer(); Image(systemName: "chevron.right").font(.caption) }.padding(.horizontal, 16).frame(height: 48)
            }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("edit-rhythm")
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { stopPreview(); editing = false; message = nil } label: { Label("Patterns", systemImage: "chevron.left").font(.system(size: 15, weight: .medium)).frame(minHeight: 44) }
                .buttonStyle(.plain).accessibilityIdentifier("editor-back")
            HStack(spacing: 8) {
                ForEach([2,3,4], id: \.self) { n in gridKey(n) }
                Button { moreGrid.toggle() } label: { Image(systemName: "ellipsis").frame(width: 44, height: 54) }.buttonStyle(HardwareButtonStyle(p: p, charcoal: moreGrid, radius: 10)).accessibilityLabel("More subdivisions")
            }
            if moreGrid { HStack(spacing: 8) { ForEach([1,5,6,7,8], id: \.self) { n in gridKey(n) } } }
            if let n = pendingGrid {
                VStack(spacing: 12) {
                    Text("Changing the grid replaces this pattern.").font(.subheadline)
                    HStack {
                        Button { pendingGrid = nil } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }
                        Button { changeGrid(n); pendingGrid = nil } label: { Text("Change").frame(maxWidth: .infinity, minHeight: 44) }
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                }.padding(14).insetPanel(p, radius: 12)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(4,draft.subdivision)), spacing: 10) {
                ForEach(0..<draft.subdivision,id: \.self) { i in
                    let enabled = draft.enabledMask & (1 << i) != 0
                    Button {
                        let mask = draft.enabledMask ^ (1 << i)
                        guard mask != 0 else { message = L10n.text("Keep at least one note."); return }
                        draft.divisionMask = mask == (1 << draft.subdivision)-1 ? nil : mask
                        message = nil; changedDraft()
                    } label: {
                        RhythmScore(rhythm: draft, color: enabled ? p.ink : p.muted, singleSlot: i).frame(height: 45).padding(.top, 28).padding(.bottom, 12).frame(maxWidth: .infinity)
                            .overlay(alignment: .topLeading) { LED(on: enabled, color: InstrumentPalette.amber, size: 8).padding(14) }
                    }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("division-pulse-\(i)")
                        .accessibilityLabel(L10n.format("Pulse %d", i+1)).accessibilityValue(L10n.text(enabled ? "Sound" : "Rest"))
                }
            }
            Button { swingExpanded.toggle() } label: {
                HStack { Text("Swing"); Spacer(); Text(draft.swingRatio == 0.5 ? L10n.text("OFF") : "\(Int((draft.swingRatio * 100).rounded()))%") .foregroundStyle(p.muted); Image(systemName: swingExpanded ? "chevron.up" : "chevron.down").font(.caption) }.padding(.horizontal,16).frame(height:48)
            }.buttonStyle(HardwareButtonStyle(p: p,radius:10)).accessibilityIdentifier("swing-options")
            if swingExpanded {
                if draft.subdivision.isMultiple(of: 2) {
                    Slider(value: Binding(get: { draft.swingRatio }, set: { draft.swing = $0; changedDraft() }), in: 0.5...0.75, step: 0.01).tint(p.ink).accessibilityLabel("Swing amount")
                    HStack { ForEach([0.5,2.0/3,0.75],id: \.self) { ratio in
                        Button { draft.swing = ratio; changedDraft() } label: { Text(ratio == 0.5 ? "1:1" : ratio == 0.75 ? "3:1" : "2:1").frame(maxWidth:.infinity,minHeight:44) }.buttonStyle(HardwareButtonStyle(p:p,charcoal:abs(draft.swingRatio-ratio)<0.005,radius:9))
                    } }
                } else { Text("Swing needs an even subdivision.").font(.subheadline).foregroundStyle(p.muted) }
            }
            HStack(spacing: 15) {
                VStack(spacing: 5) {
                    RhythmScore(rhythm: draft, color: p.ink).frame(maxWidth: .infinity).frame(height: 55)
                    if draft.swingRatio > 0.5 { Text(L10n.format("Swing %d%%",Int((draft.swingRatio*100).rounded()))).font(.caption).foregroundStyle(p.muted) }
                }
            }.padding(20).insetPanel(p, radius:14)
            if let message { Text(message).font(.subheadline).foregroundStyle(p.muted) }
            if !playing {
                HStack(spacing:12) {
                    Button { stopPreview(); editing = false } label: { Text("Cancel").frame(maxWidth:.infinity,minHeight:48) }.buttonStyle(HardwareButtonStyle(p:p,radius:10))
                    Button { apply(draft) } label: { Text("Use").frame(maxWidth:.infinity,minHeight:48) }.buttonStyle(HardwareButtonStyle(p:p,charcoal:true,radius:10)).accessibilityIdentifier("use-rhythm")
                }
            }
        }
    }
    private func gridKey(_ n: Int) -> some View {
        Button {
            if n != draft.subdivision && (draft.divisionMask != nil || draft.swingRatio > 0.5) { pendingGrid = n }
            else { changeGrid(n) }
        } label: {
            RhythmScore(rhythm: withDivision(n, from:draft),color:draft.subdivision == n ? Color(hex:0xF4F0E5) : p.ink).frame(height:40).padding(7).frame(maxWidth:.infinity)
        }.buttonStyle(HardwareButtonStyle(p:p,charcoal:draft.subdivision == n,radius:10)).accessibilityLabel(L10n.format("%d clicks per beat",n)).accessibilityIdentifier("editor-grid-\(n)")
    }
    private func withDivision(_ count:Int,from:Rhythm?=nil) -> Rhythm { var value=from ?? rhythm; value.setDivision(count); return value }
    private func changeGrid(_ count:Int) { draft.setDivision(count); changedDraft() }
    private func changedDraft() { stopPreview(); if playing { rhythm=draft } }
    private func apply(_ value:Rhythm) { stopPreview(); rhythm=value; if !playing { close() } }
}
