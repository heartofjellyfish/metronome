import SwiftUI

struct DivisionPanel: View {
    @Binding var rhythm: Rhythm
    @Binding var editing: Bool
    let playing: Bool
    let p: InstrumentPalette
    let stopPreview: () -> Void
    @State private var patternTab: Bool
    @State private var choosingFamily = false
    @State private var family: Int
    @State private var draft: Rhythm
    @State private var message: String?
    @State private var pendingGrid: Int?
    private var customSelected: Bool {
        rhythm.swingRatio > 0.5 || (rhythm.divisionMask != nil && ![2,3,4].flatMap(RhythmPattern.choices).contains { $0.count == rhythm.subdivision && $0.mask == rhythm.enabledMask })
    }
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    init(rhythm: Binding<Rhythm>, editing: Binding<Bool>, playing: Bool, p: InstrumentPalette, stopPreview: @escaping () -> Void) {
        _rhythm = rhythm; _editing = editing; self.playing = playing; self.p = p; self.stopPreview = stopPreview
        let value = rhythm.wrappedValue
        _patternTab = State(initialValue: value.divisionMask != nil || value.swingRatio > 0.5)
        _family = State(initialValue: [2,3,4].contains(value.subdivision) ? value.subdivision : 4)
        _draft = State(initialValue: value)
    }
    var body: some View {
        VStack(spacing: 18) {
            if editing { editor } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        tab("Even divisions", selected: !patternTab, id: "division-even") { patternTab = false }
                        tab("Patterns", selected: patternTab, id: "division-patterns") { patternTab = true }
                    }
                    VStack(spacing: 14) {
                        if patternTab { patterns } else { equalDivisions }
                    }.padding(12)
                }.insetPanel(p, radius: 14)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("division-browser")
                Button {
                    stopPreview(); draft = rhythm; pendingGrid = nil; message = nil; editing = true
                } label: {
                    HStack { Image(systemName: "pencil"); Text("Customize rhythm"); Spacer(); if customSelected { RhythmScore(rhythm: rhythm, color: p.ink).frame(width: 70, height: 30) }; Image(systemName: "chevron.right").font(.caption) }
                        .padding(.horizontal, 16).frame(height: 48)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 10)).accessibilityIdentifier("edit-rhythm").accessibilityAddTraits(customSelected ? .isSelected : [])
            }
        }.onDisappear { stopPreview() }
            .onChange(of: playing) { _, value in if editing && value { rhythm = draft } }
    }
    private func tab(_ title: String, selected: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button { stopPreview(); choosingFamily = false; action() } label: {
            VStack(spacing: 0) {
                Text(L10n.text(title)).font(.system(size: 15, weight: selected ? .semibold : .medium))
                    .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: .infinity, minHeight: 48)
                Rectangle().fill(selected ? p.ink : p.edge.opacity(0.25)).frame(height: selected ? 3 : 1)
                    .frame(height: 3, alignment: .bottom)
            }.foregroundStyle(selected ? p.ink : p.muted)
                .background(selected ? p.well.opacity(0.35) : p.body.opacity(0.8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: id == "division-even" ? 14 : 0, topTrailingRadius: id == "division-patterns" ? 14 : 0))
            .accessibilityIdentifier(id).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private var equalDivisions: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(1...8, id: \.self) { n in
                let value = withDivision(n)
                let selected = rhythm.subdivision == n && rhythm.divisionMask == nil && rhythm.swingRatio == 0.5
                scoreKey(value, selected: selected, id: "division-count-\(n)", label: L10n.format("%d clicks per beat", n), caption: n <= 4 ? L10n.text([1:"One per beat",2:"Two per beat",3:rhythm.usesCompoundPulse ? "Three per beat" : "Triplets",4:"Four per beat"][n]!) : L10n.format("%d per beat", n))
            }
        }
    }
    private var patterns: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Button { choosingFamily.toggle() } label: {
                    HStack {
                        Text(familyTitle(family)).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: choosingFamily ? "chevron.up" : "chevron.down").font(.system(size: 12, weight: .medium))
                    }.padding(.horizontal, 14).frame(height: 44)
                }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                    .accessibilityIdentifier("pattern-family-menu")
                    .accessibilityLabel(familyTitle(family))
                if choosingFamily {
                    VStack(spacing: 8) {
                        ForEach([2,3,4], id: \.self) { n in
                            Button { family = n; choosingFamily = false } label: {
                                HStack {
                                    Text(familyTitle(n))
                                    Spacer()
                                    if family == n { Image(systemName: "checkmark") }
                                }.font(.system(size: 14)).padding(.horizontal, 14).frame(height: 44)
                            }.buttonStyle(HardwareButtonStyle(p: p, radius: 8))
                                .accessibilityIdentifier("pattern-family-\(n)").accessibilityAddTraits(family == n ? .isSelected : [])
                        }
                    }.padding(10).insetPanel(p, radius: 10)
                }
            }
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(RhythmPattern.choices(family)) { pattern in
                    let value = pattern.applying(to: rhythm)
                    let selected = rhythm.subdivision == pattern.count && rhythm.enabledMask == pattern.mask && rhythm.swingRatio == 0.5
                    scoreKey(value, selected: selected, id: "pattern-\(pattern.id)", label: L10n.format("Rhythm pattern %@", pattern.id))
                }
            }
        }
    }
    private func familyTitle(_ n: Int) -> String {
        L10n.text(n == 2 ? "Eighths" : n == 3 ? "Triplets" : "Sixteenths")
    }
    private func scoreKey(_ value: Rhythm, selected: Bool, id: String, label: String, caption: String? = nil) -> some View {
        Button { apply(value) } label: {
            VStack(spacing: 5) {
                RhythmScore(rhythm: value, color: p.ink).frame(height: 45).padding(.horizontal, 15)
                if let caption { Text(caption).font(.system(size: 12)).foregroundStyle(p.muted) }
            }.frame(maxWidth: .infinity).frame(height: 100)
                .overlay(alignment: .topLeading) { LED(on: selected, color: InstrumentPalette.amber, size: 8).padding(14) }
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 11))
            .accessibilityIdentifier(id).accessibilityLabel(label).accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func step(_ number: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", number)).font(.system(size: 12, design: .monospaced)).foregroundStyle(p.muted)
            Text(L10n.text(title)).font(.system(size: 16, weight: .semibold))
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Parts per beat")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(1...8, id: \.self) { n in gridKey(n) }
                }
                if let n = pendingGrid {
                    VStack(spacing: 12) {
                        Text("Changing the grid replaces this pattern.").font(.subheadline)
                        HStack {
                            Button { pendingGrid = nil } label: { Text("Cancel").frame(maxWidth: .infinity, minHeight: 44) }
                            Button { changeGrid(n); pendingGrid = nil } label: { Text("Change").frame(maxWidth: .infinity, minHeight: 44) }
                        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9))
                    }.padding(14).insetPanel(p, radius: 12)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                step(2, "Choose which notes sound")
                Text("Tap to mute. Tap again to restore.").font(.system(size: 13)).foregroundStyle(p.muted)
                HStack(spacing: 5) {
                    ForEach(0..<draft.subdivision, id: \.self) { i in pulseKey(i) }
                }
                if let message { Text(message).font(.subheadline).foregroundStyle(p.muted) }
            }
            VStack(alignment: .leading, spacing: 12) {
                step(3, "Swing")
                HStack(spacing: 8) {
                    ForEach([0.5,2.0/3,0.75], id: \.self) { ratio in
                        Button { draft.swing = ratio; changedDraft() } label: {
                            Text(ratio == 0.5 ? L10n.text("Off") : ratio == 0.75 ? "3:1" : "2:1").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(HardwareButtonStyle(p: p, charcoal: abs(draft.swingRatio-ratio)<0.005, radius: 9))
                    }
                }.disabled(!draft.subdivision.isMultiple(of: 2)).opacity(draft.subdivision.isMultiple(of: 2) ? 1 : 0.45)
                if draft.subdivision.isMultiple(of: 2) {
                    Slider(value: Binding(get: { draft.swingRatio }, set: { draft.swing = $0; changedDraft() }), in: 0.5...0.75, step: 0.01).tint(p.ink).accessibilityLabel("Swing amount")
                } else { Text("Swing needs an even subdivision.").font(.system(size: 13)).foregroundStyle(p.muted) }
            }
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    RhythmScore(rhythm: draft, color: p.ink, explicitSlots: true).frame(maxWidth: .infinity).frame(height: 42)
                    if draft.swingRatio > 0.5 { Text(L10n.format("Swing %d%%", Int((draft.swingRatio*100).rounded()))).font(.caption).foregroundStyle(p.muted) }
                }.padding(.horizontal, 10).frame(height: 76).insetPanel(p, radius: 12)
                Button {
                    stopPreview(); rhythm = draft
                    patternTab = draft.divisionMask != nil || draft.swingRatio > 0.5
                    family = [2,3,4].contains(draft.subdivision) ? draft.subdivision : family
                    editing = false
                } label: { Text("Use").font(.system(size: 16, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8).frame(width: 100, height: 76) }
                    .buttonStyle(HardwareButtonStyle(p: p, charcoal: true, radius: 10)).accessibilityIdentifier("use-rhythm")
            }

        }
    }
    private func pulseKey(_ i: Int) -> some View {
        let enabled = draft.enabledMask & (1 << i) != 0
        return Button {
            let mask = draft.enabledMask ^ (1 << i)
            guard mask != 0 else { message = L10n.text("Keep at least one note."); return }
            draft.divisionMask = mask == (1 << draft.subdivision)-1 ? nil : mask
            message = nil; changedDraft()
        } label: {
            VStack(spacing: 8) {
                LED(on: enabled, color: InstrumentPalette.amber, size: 7)
                RhythmScore(rhythm: draft, color: enabled ? p.ink : p.muted, singleSlot: i).frame(height: 35)
            }.frame(maxWidth: .infinity).frame(height: 68)
        }.buttonStyle(HardwareButtonStyle(p: p, radius: 9)).accessibilityIdentifier("division-pulse-\(i)")
            .accessibilityLabel(L10n.format("Pulse %d", i+1)).accessibilityValue(L10n.text(enabled ? "Sound" : "Rest"))
    }
    private func gridKey(_ n: Int) -> some View {
        Button {
            if n != draft.subdivision && (draft.divisionMask != nil || draft.swingRatio > 0.5) { pendingGrid = n }
            else if n != draft.subdivision { changeGrid(n) }
        } label: { Text("\(n)").font(.system(size: 18, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(HardwareButtonStyle(p: p, charcoal: draft.subdivision == n, radius: 10))
            .accessibilityLabel(L10n.format("%d clicks per beat", n)).accessibilityIdentifier("editor-grid-\(n)")
            .accessibilityAddTraits(draft.subdivision == n ? .isSelected : [])
    }
    private func withDivision(_ count: Int) -> Rhythm { var value = rhythm; value.setDivision(count); return value }
    private func changeGrid(_ count: Int) { draft.setDivision(count); message = nil; changedDraft() }
    private func changedDraft() { stopPreview(); if playing { rhythm = draft } }
    private func apply(_ value: Rhythm) { stopPreview(); rhythm = value }
}
