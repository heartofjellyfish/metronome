import SwiftUI
import AVFoundation
import CoreText

struct TunerInstrumentSelection: Equatable {
    let profile: TunerProfile
    let layout: TunerHeadstock?

    func usesSculptedConsole(_ skin: ControlSkin) -> Bool {
        skin == .sculpted && layout?.supportsRelief == true
    }
}

struct TunerInstrumentPreference: PreferenceKey {
    static let defaultValue: TunerInstrumentSelection? = nil
    static func reduce(value: inout TunerInstrumentSelection?, nextValue: () -> TunerInstrumentSelection?) {
        value = nextValue() ?? value
    }
}

private struct TunerSetupMemory: Codable {
    struct Instrument: Codable {
        let presetID: String
        let usesCustomTuning: Bool
        let noteGroup: String?
    }

    var lastInstrumentID: String?
    var instruments: [String: Instrument] = [:]
}

struct TunerView: View {
    let p: InstrumentPalette
    @ObservedObject var model: MetronomeModel
    @Binding var sheet: Panel?
    let exposed: Bool
    let rememberLastSetup: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.controlSkin) private var design
    @StateObject private var audio = TunerAudio()
    @State private var profileID: String = {
        #if DEBUG
        if let instrument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--tuner-instrument=") }) {
            return String(instrument.dropFirst("--tuner-instrument=".count))
        }
        #endif
        return TunerProfile.chromatic.id
    }()
    @AppStorage("tuner.reference") private var reference = 440
    @AppStorage("tuner.custom") private var customData = Data()
    @AppStorage("tuner.written") private var written = true
    @AppStorage("tuner.response") private var response = TunerResponse.balanced
    @AppStorage(ChromaticTuningRange.preferenceKey) private var chromaticRange = ChromaticTuningRange.standard
    @AppStorage("tuner.confirmation") private var confirmation = true
    @State private var confirmedNote: Int?
    @State private var held: Int?
    enum Panel: String, Identifiable { case library, tuning, wireNote; var id: Self { self } }

    private var custom: [TunerProfile] { (try? JSONDecoder().decode([TunerProfile].self, from: customData)) ?? [] }
    private var profile: TunerProfile {
        if profileID == TunerProfile.chromatic.id { return .chromatic }
        return TunerProfile.availableCatalog.first { $0.id == profileID } ?? custom.first { $0.id == profileID } ?? .chromatic
    }
    @AppStorage("tuner.instrumentTunings") private var savedTuningData = Data()
    @AppStorage(SessionMemory.tunerSetupKey) private var savedSetupData = Data()
    @State private var restoredSetup = false
    @State private var useCustom = false
    @AppStorage("tuner.inlineGuitar") private var inlineGuitar = false
    @AppStorage("tuner.inlineGuitarSeven") private var inlineGuitarSeven = false
    @AppStorage("tuner.headlessGuitar") private var headlessGuitar = false
    @AppStorage("tuner.headlessGuitarSeven") private var headlessGuitarSeven = false
    @AppStorage("tuner.pairedBass") private var pairedBass = false
    @AppStorage("tuner.bassHeadstock") private var bassHeadstock = ""
    @State private var draft = ""
    @State private var editingTuning = false
    @State private var checkGroupIndex = 0
    @State private var tuningDetent = PresentationDetent.large
    @State private var selectedString: Int?
    @State private var completed = Set<Int>()
    @AppStorage("tuner.stringListLayout") private var stringListLayout = TunerStringListLayout.grouped
    @State private var stringGroupIndex = 0
    @State private var yangqinCourse = TunerYangqin.courses.firstIndex { $0.bridge == 4 } ?? 0
    @State private var pendingYangqinWire: Int?
    @AppStorage("tuner.yangqinCourseNotes") private var yangqinCourseNoteData = Data()
    private var savedTunings: [String: [Int]] {
        (try? JSONDecoder().decode([String: [Int]].self, from: savedTuningData)) ?? [:]
    }
    private var instrumentID: String { profile.instrumentID }
    private var strings: [Int] { useCustom ? savedTunings[instrumentID] ?? profile.strings : profile.strings }
    private var headstock: TunerHeadstock? {
        guard let layout = preferredLayout(for: profile),
              layout.positions.count == strings.count else { return nil }
        return layout
    }
    private var regionalHeadstock: TunerRegionalHeadstock? {
        TunerRegionalHeadstock.forInstrument(profile.instrumentName, stringCount: strings.count)
    }
    private var showsYangqin: Bool {
        profile.instrumentName == "Yangqin" && (!useCustom || strings.count == TunerYangqin.courses.count)
    }
    private var yangqinCourseNotes: [Int: Int] {
        (try? JSONDecoder().decode([Int: Int].self, from: yangqinCourseNoteData)) ?? [:]
    }
    private var wireNotes: [Int] {
        if showsYangqin {
            let overrides = yangqinCourseNotes
            return TunerYangqin.courses.enumerated().flatMap { index, course in
                let pitch = useCustom ? strings[index] : overrides[index] ?? course.pitch ?? -1
                return Array(repeating: pitch, count: course.wires.count)
            }
        }
        if let headstock { return headstock.physicalPitches(for: strings) }
        return regionalHeadstock?.physicalPitches(for: strings) ?? strings
    }

    private func preferredLayout(for profile: TunerProfile) -> TunerHeadstock? {
        guard profile.family != "Custom tuning",
              let standard = TunerHeadstock.standard(for: profile.instrumentName) else { return nil }
        if standard == .guitar {
            if headlessGuitar { return .headlessGuitar }
            if inlineGuitar { return .inlineGuitar }
        }
        if standard == .guitarSeven {
            if headlessGuitarSeven { return .headlessGuitarSeven }
            if inlineGuitarSeven { return .inlineGuitarSeven }
        }
        if standard == .bass {
            // Read the selection saved by earlier preview builds.
            if bassHeadstock == "stingRayBass" { return .threePlusOneBass }
            if let saved = TunerHeadstock(rawValue: bassHeadstock), standard.options.contains(saved) { return saved }
            return pairedBass ? .pairedBass : .bass
        }
        return standard
    }
    private var stringColumns: Int { min(7, strings.count) }
    private var stringRows: Int {
        guard stringColumns > 0 else { return 0 }
        return min(3, (strings.count + stringColumns - 1) / stringColumns)
    }
    private var zither: TunerZither? {
        TunerZither.forInstrument(profile.instrumentName, strings: strings)
    }
    private var showsGuzheng: Bool {
        profile.instrumentName == "Guzheng" && strings.count == TunerGuzhengArtwork.stringCount
    }
    private var stringTargetHeight: CGFloat { CGFloat(stringRows) * 44 }
    private var stringGroups: [TunerStringGroup] {
        TunerStringGroup.groups(for: profile.instrumentName, stringCount: strings.count)
    }

    private func selectLayout(_ layout: TunerHeadstock) {
        switch layout {
        case .guitar, .inlineGuitar, .headlessGuitar:
            headlessGuitar = layout == .headlessGuitar
            if !headlessGuitar { inlineGuitar = layout == .inlineGuitar }
        case .guitarSeven, .inlineGuitarSeven, .headlessGuitarSeven:
            headlessGuitarSeven = layout == .headlessGuitarSeven
            if !headlessGuitarSeven { inlineGuitarSeven = layout == .inlineGuitarSeven }
        case .bass, .pairedBass, .threePlusOneBass: bassHeadstock = layout.rawValue
        default: break
        }
    }
    private var activeString: Int? {
        if let selectedString { return selectedString }
        guard let pitch = audio.reading?.note else { return nil }
        let notes = wireNotes
        let matches = notes.indices.filter { notes[$0] == pitch }
        return matches.count == 1 ? matches.first : nil
    }
    private func focusStringGroup(for string: Int) {
        if let group = stringGroups.firstIndex(where: { $0.wires.contains(string) }) {
            stringGroupIndex = group
        }
    }

    private func stringName(in groups: [TunerStringGroup]) -> String? {
        if zither?.isKoto == true {
            return activeString.map { String(format: tunerText("String %d"), $0 + 1) }
                ?? (audio.reading == nil ? nil : tunerText("Choose a string"))
        }
        guard !groups.isEmpty else { return nil }
        if let index = activeString, let group = groups.first(where: { $0.wires.contains(index) }) {
            return group.stringName(for: index)
        }
        return audio.reading == nil ? nil : tunerText("Choose a string")
    }

    private var notation: TunerPitchNotation {
        TunerPitchNotation(writtenOffset: profile.writtenOffset, prefersWritten: written)
    }
    private var instrumentSelection: TunerInstrumentSelection { .init(profile: profile, layout: headstock) }
    private var showsRelief: Bool { instrumentSelection.usesSculptedConsole(design) }
    private var stringDrawing: TunerStringDrawing {
        TunerStringDrawing(palette: p, liveState: audio.reading?.state, active: activeString,
                           completed: completed, stringCount: wireNotes.count, relief: showsRelief, auditioning: audio.referenceTone?.wire)
    }
    private var concertNote: Int? { audio.referenceTone?.note ?? audio.reading?.note ?? held }
    private var eligible: Bool { exposed && sheet == nil && scenePhase == .active && !model.playing && !model.interrupted }
    private var statusLabel: String {
        if model.playing { return "Click playing" }
        if model.interrupted { return "Interrupted" }
        if let reading = audio.reading { return reading.state.label }
        switch audio.status {
        case .denied: return "Microphone off"
        case .tone: return "Reference tone"
        case .unavailable: return "Input unavailable"
        case .permission: return "Microphone access"
        default: return showsYangqin && held == nil ? "Strike a note"
            : held == nil ? profile.playingPrompt(hasStrings: !strings.isEmpty) : "Play target note"
        }
    }
    var body: some View {
        let groups = stringGroups
        let selector = groupedStringTargets(groups)
        let chromaticStyle = ChromaticDialStyle.current(dark: p.dark)
        VStack(spacing: 14) {
            if profile == .chromatic { Spacer(minLength: 0) }
            if profile == .chromatic {
                TunerDial(style: chromaticStyle, reading: audio.reading, status: statusLabel,
                          referenceNote: audio.referenceTone?.note, referenceInk: p.tunerReferenceInk,
                          audition: auditionNote)
                    .frame(height: 350)
            } else {
                if let headstock {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing,
                                     centerX: headstock == .bass ? 172 : 180, select: auditionString) {
                        consoleControls
                    }
                } else if let headstock = TunerChineseHeadstock.forInstrument(instrumentID, stringCount: strings.count) {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing, prefersFlats: profile.prefersFlatStringNotes,
                                     select: auditionString) { EmptyView() }
                } else if let headstock = TunerRuanHeadstock.forInstrument(instrumentID, stringCount: strings.count) {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing, select: auditionString) { EmptyView() }
                } else if let headstock = regionalHeadstock {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing, prefersFlats: profile.prefersFlatStringNotes,
                                     select: auditionString) { EmptyView() }
                } else if showsGuzheng {
                    TunerGuzhengFace(p: p, note: concertNote, reading: audio.reading, status: statusLabel,
                                     strings: strings, drawing: stringDrawing, groups: groups,
                                     groupIndex: min(stringGroupIndex, groups.count - 1),
                                     showsAll: stringListLayout == .all,
                                     soundingString: audio.referenceTone?.wire,
                                     canPlay: eligible, chooseGroup: chooseGuzhengGroup,
                                     showOverview: showGuzhengOverview, select: auditionString)
                } else {
                    InstrumentTuningDisplay(profile: profile, p: p, note: concertNote, reading: audio.reading,
                                            status: statusLabel, notation: notation,
                                            strings: strings, drawing: stringDrawing,
                                            targetHeight: showsYangqin ? 44 : groups.isEmpty ? stringTargetHeight : selector.height,
                                            showsYangqin: showsYangqin, stringName: stringName(in: groups),
                                            select: auditionString, auditionNote: strings.isEmpty ? auditionNote : nil,
                                            previewingNote: audio.referenceTone != nil, openOptions: openTuning) {
                        if showsYangqin { yangqinTargets }
                        else if !groups.isEmpty { selector }
                        else if !strings.isEmpty { stringTargets }
                    }
                }
                if !showsRelief { tuningSelector }
            }
            if model.playing || audio.status == .denied || audio.status == .unavailable {
                Button {
                    if model.playing { model.stop() }
                    else if audio.status == .denied { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    else { begin() }
                } label: {
                    Text(tunerText(model.playing ? "Pause click to tune" : audio.status == .denied ? "Open Settings" : "Retry microphone"))
                        .frame(maxWidth: .infinity).frame(height: 44)
                }.buttonStyle(HardwareButtonStyle(p: p))
            }
            if profile == .chromatic {
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(p.ink)
        .padding(.horizontal, 22)
        .padding(.bottom, profile == .chromatic ? 32 : 0)
        .preference(key: TunerInstrumentPreference.self, value: instrumentSelection)
        .onAppear {
            if !restoredSetup {
                restoredSetup = true
                restoreSetup()
            }
            let controller = audio
            model.releaseTunerAudio = { [weak controller] in controller?.stop() }
            if eligible { begin() }
        }
        .onReceive(audio.$reading) { reading in
            guard audio.status == .listening, audio.referenceTone == nil, let reading else {
                confirmedNote = nil
                return
            }
            guard reading.isFresh, reading.state == .centered || reading.confirmedReplayDetuning else { return }
            let notes = wireNotes
            let matches = notes.indices.filter { notes[$0] == reading.note }
            let index = selectedString.flatMap { matches.contains($0) ? $0 : nil }
                ?? (matches.count == 1 ? matches.first : nil)
            if reading.confirmedReplayDetuning {
                if let index { completed.remove(index) }
                return
            }
            let newlyTuned = index.map { completed.insert($0).inserted }
                ?? (notes.isEmpty && confirmedNote != reading.note)
            confirmedNote = reading.note
            if newlyTuned, confirmation, model.haptics {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // Equal pitches cannot disambiguate physical strings. Keep an explicit
            // target in that case until the player selects or releases it.
            if index != nil, selectedString != nil, matches.count == 1 {
                // Resume automatic targeting without discarding the centered reading.
                selectedString = nil
                held = nil
                audio.held = nil
            }
        }
        .onChange(of: reference) { _, _ in completed.removeAll() }
        .onChange(of: activeString) { _, index in
            if !showsGuzheng, let index { focusStringGroup(for: index) }
        }
        .onChange(of: checkGroupIndex) { _, _ in rememberSetup() }
        .onChange(of: rememberLastSetup) { _, _ in rememberSetup() }
        .onDisappear { model.releaseTunerAudio = nil; audio.stop() }
        .onChange(of: eligible) { _, active in
            if active { begin() }
            else { audio.stop() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)) { note in
            guard eligible, let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw),
                  reason == .oldDeviceUnavailable || reason == .newDeviceAvailable else { return }
            begin()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .receive(on: DispatchQueue.main)) { _ in
            if eligible { begin() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)
            .receive(on: DispatchQueue.main)) { notification in
            if eligible, audio.ownsGraph(notification.object) { begin() }
        }
        .sheet(item: $sheet) { panel in
            ZStack {
                InstrumentBody(p: p).ignoresSafeArea()
                if panel == .library {
                    TunerLibrary(p: p, selected: instrumentID, selectedProfile: useCustom ? nil : profileID,
                                 custom: custom, preferredLayout: preferredLayout) { choice, layout in
                        if let layout { selectLayout(layout) }
                        if choice.family == "Custom tuning" && !custom.contains(where: { $0.id == choice.id }) {
                            customData = (try? JSONEncoder().encode(custom + [choice])) ?? customData
                        }
                        if choice.id == instrumentID && choice.family != "Custom tuning" { sheet = nil }
                        else {
                            applyRememberedSetup(for: choice)
                            rememberSetup()
                            sheet = nil
                        }
                    } close: { sheet = nil }
                } else {
                    tuningPanel
                }
            }
            .foregroundStyle(p.ink)
            .presentationDetents(panel == .library ? [.large] : [compactTuningDetent, .large],
                                 selection: panel == .library ? .constant(.large) : $tuningDetent)
        }
    }
    private var tuningTitle: String {
        if useCustom { return tunerText("Custom tuning") }
        if showsYangqin { return tunerText("Yangqin") + " · 410" }
        if !strings.isEmpty { return tunerText(profile.tuningName) }
        let instrument = tunerText(profile.instrumentName)
        return held.map { instrument + " · " + TunerPitch.label($0 + notation.primaryOffset, flats: true) }
            ?? instrument
    }

    @State private var instrumentKeyPressed = false
    @State private var tuningKeyPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceKeyMotion

    private var consoleControls: some View {
        let instrumentWidth = TunerConsoleMetrics.width * (140.0 / 332.0)
        let tuningWidth = TunerConsoleMetrics.width - instrumentWidth
        let keyFaceHeight: CGFloat = 50
        let sweepWidth = SweptInstrumentKey.sweepWidth(for: keyFaceHeight)
        return HStack(spacing: -sweepWidth) {
            instrumentSelection.pickerButton(p: p, width: instrumentWidth + sweepWidth / 2, height: 54,
                                             iconOffset: -sweepWidth / 4) { sheet = .library }
                .buttonStyle(TunerConsoleKeyPress(p: p, instrument: true, faceHeight: keyFaceHeight,
                                                  pressChanged: { instrumentKeyPressed = $0 }))
                .zIndex(1)
            Button(action: openTuning) {
                TunerKeyLegend(title: tuningTitle, p: p)
                    .padding(.horizontal, 12)
                    .padding(.leading, sweepWidth / 2)
                    .frame(width: tuningWidth + sweepWidth / 2, height: 54)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(tuningTitle)
            .accessibilityIdentifier("tuner-tuning")
            .buttonStyle(TunerConsoleKeyPress(p: p, instrument: false, faceHeight: keyFaceHeight,
                                               pressChanged: { tuningKeyPressed = $0 }))
        }
        .background {
            TunerKeyFace(p: p, seamCenter: instrumentWidth, instrumentPressed: instrumentKeyPressed,
                         tuningPressed: tuningKeyPressed)
                .frame(height: keyFaceHeight)
                .animation(reduceKeyMotion ? nil : TunerConsoleKeyPress.animation(pressed: instrumentKeyPressed),
                           value: instrumentKeyPressed)
                .animation(reduceKeyMotion ? nil : TunerConsoleKeyPress.animation(pressed: tuningKeyPressed),
                           value: tuningKeyPressed)
                .allowsHitTesting(false)
        }
    }

    private var tuningSelector: some View {
        let compact = headstock?.supportsRelief == true
        return Button(action: openTuning) {
            Text(tuningTitle)
                .font(compact ? InstrumentType.value(16) : .system(size: 20))
                .foregroundStyle(compact ? p.ink.opacity(0.84) : p.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: compact ? 8 : 13, weight: .semibold))
                        .foregroundStyle(compact ? p.muted : p.ink)
                        .padding(.leading, compact ? 6 : 9)
                        .alignmentGuide(.trailing) { $0[.leading] }
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, compact ? 19 : 30)
                .frame(height: compact ? 29 : 44)
                .frame(minWidth: 44, minHeight: 44, alignment: .top)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(profile.hasStringSetup ? "tuner-tuning" : "tuner-note-options")
    }

    private var stringTargets: some View {
        let notes = strings
        let drawing = stringDrawing
        let numbered = zither == .guqin || notes.count > 7
        let numberSize: CGFloat = zither == .guqin ? 11 : 10
        return ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: stringColumns), spacing: 0) {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, pitch in
                    let showsNumber = numbered || notes.lazy.filter { $0 == pitch }.prefix(2).count > 1
                    stringTarget(index, pitch: pitch, number: showsNumber ? index + 1 : nil,
                                 numberSize: numberSize, drawing: drawing)
                }
            }
        }.scrollBounceBehavior(.basedOnSize)
            .frame(height: stringTargetHeight)
            .accessibilityIdentifier("tuner-targets")
    }

    private func groupedStringTargets(_ groups: [TunerStringGroup]) -> TunerStringSelector {
        let notes = strings
        let drawing = stringDrawing
        return TunerStringSelector(p: p, groups: groups, layout: stringListLayout,
                                   groupIndex: min(stringGroupIndex, max(0, groups.count - 1)), completed: completed,
                                   chooseLayout: { layout in
            guard layout != stringListLayout else { return }
            if layout == .grouped, let index = activeString { focusStringGroup(for: index) }
            stringListLayout = layout
        }, chooseGroup: { stringGroupIndex = $0 }) { index, group in
            stringTarget(index, pitch: notes[index], number: group.number(for: index),
                         numberSize: 11, drawing: drawing, emphasizeSelection: true,
                         accessibilityName: group.kind == .sympathetic ? group.stringName(for: index) : nil)
        }
    }

    private func stringTarget(_ index: Int, pitch: Int, number: Int?, numberSize: CGFloat, drawing: TunerStringDrawing,
                              emphasizeSelection: Bool = false, accessibilityName: String? = nil) -> TunerStringTarget {
        TunerStringTarget(drawing: drawing, index: index, pitch: pitch, number: number, numberSize: numberSize,
                          emphasizeSelection: emphasizeSelection, accessibilityName: accessibilityName,
                          prefersFlats: profile.prefersFlatStringNotes) { action in
            auditionString(index, action: action)
        }
    }

    private func chooseGuzhengGroup(_ index: Int) {
        let groups = stringGroups
        guard groups.indices.contains(index),
              index != stringGroupIndex || stringListLayout == .all else { return }
        let wasAuditioning = audio.status == .tone
        stringGroupIndex = index
        stringListLayout = .grouped
        if let target = activeString, !groups[index].wires.contains(target) {
            selectedString = nil
            held = nil
            syncTarget(refreshPreview: false)
        }
        if wasAuditioning { audio.finishReference() }
    }

    private func showGuzhengOverview() {
        guard stringListLayout != .all else { return }
        stringListLayout = .all
        if audio.status == .tone { audio.finishReference() }
    }

    private func auditionNote(_ note: Int, action: TunerReferenceAction) {
        if action == .release || action == .cancel {
            if let tone = audio.referenceTone, tone.wire == nil, tone.note == note,
               tone.sustained || action == .cancel {
                audio.finishReference()
            }
        } else if eligible {
            audio.audition(.init(note: note, sustained: action == .hold))
        }
    }

    private func auditionString(_ index: Int, action: TunerReferenceAction) {
        if action == .release || action == .cancel {
            if let tone = audio.referenceTone, tone.wire == index, tone.sustained || action == .cancel {
                audio.finishReference()
            }
            return
        }
        let notes = wireNotes
        guard notes.indices.contains(index) else { return }
        guard eligible else {
            if model.playing && action == .tap { selectString(index, refreshPreview: false) }
            return
        }
        let pitch = notes[index]
        if pitch < 0 {
            selectString(index)
            return
        }
        #if DEBUG
        if !audio.playsReferenceInPreview {
            selectString(index)
            return
        }
        #endif
        if audio.referenceTone?.wire != index {
            selectString(index, refreshPreview: false, toggle: action == .tap)
        }
        audio.audition(.init(note: pitch, wire: index, sustained: action == .hold))
    }

    private var yangqinTargets: some View {
        let course = TunerYangqin.courses[yangqinCourse]
        let drawing = stringDrawing
        let notes = wireNotes
        return HStack(spacing: 10) {
            Menu {
                ForEach(TunerYangqin.courses.indices, id: \.self) { index in
                    let item = TunerYangqin.courses[index]
                    Button {
                        releaseTarget()
                        yangqinCourse = index
                    } label: {
                        let pitch = notes[item.wires.lowerBound]
                        let label = item.name + (pitch >= 0 ? " · " + TunerPitch.label(pitch, flats: true) : "")
                        if drawing.isConfirmed(item.wires) { Label(label, systemImage: "checkmark") }
                        else { Text(label) }
                    }
                    .accessibilityIdentifier("tuner-yangqin-course-\(index)")
                }
            } label: {
                HStack(spacing: 6) {
                    Text(course.name).font(InstrumentType.value(13)).lineLimit(1).minimumScaleFactor(0.78)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .medium))
                }
                .frame(minHeight: 44)
            }
            .accessibilityIdentifier("tuner-yangqin-course")
            Spacer(minLength: 0)
            ForEach(Array(course.wires.enumerated()), id: \.offset) { offset, wire in
                let pitch = notes[wire]
                let done = completed.contains(wire)
                Button { auditionString(wire, action: .tap) } label: {
                    VStack(spacing: 3) {
                        Text(pitch >= 0 ? TunerPitch.label(pitch, flats: true) : "—")
                            .font(InstrumentType.value(15))
                        HStack(spacing: 3) {
                            Text(String(offset + 1)).font(.system(size: 10, weight: .medium, design: .monospaced))
                            if done { Image(systemName: "checkmark").font(.system(size: 8, weight: .semibold)) }
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TunerReferenceButtonStyle { auditionString(wire, action: $0 ? .hold : .release) })
                .foregroundStyle(drawing.color(for: wire))
                .accessibilityLabel(pitch >= 0 ? TunerPitch.label(pitch) + ", \(offset + 1)" : tunerText("Other note"))
                .accessibilityValue(done ? tunerText("In tune") : "")
                .accessibilityAddTraits(drawing.active == wire ? .isSelected : [])
                .accessibilityIdentifier("tuner-yangqin-wire-\(offset)")
            }
        }
    }

    private func selectString(_ index: Int, refreshPreview: Bool = true, toggle: Bool = true) {
        let notes = wireNotes
        guard notes.indices.contains(index) else { return }
        focusStringGroup(for: index)
        if showsYangqin, let course = TunerYangqin.courseIndex(of: index) {
            yangqinCourse = course
            if notes[index] < 0 {
                pendingYangqinWire = index
                tuningDetent = .large
                sheet = .wireNote
                return
            }
        }
        if toggle, selectedString == index {
            releaseTarget(refreshPreview: refreshPreview)
            return
        }
        let pitch = notes[index]
        // Two physical strings can share a pitch. A ringing tail belongs to the previous target.
        let samePitchIsRinging = (held == pitch || audio.reading?.note == pitch)
            && notes.indices.contains { $0 != index && notes[$0] == pitch }
        selectedString = index
        held = pitch
        syncTarget(refreshPreview: refreshPreview, waitsForStringAttack: samePitchIsRinging)
    }

    private func releaseTarget(refreshPreview: Bool = true) {
        held = nil
        selectedString = nil
        syncTarget(refreshPreview: refreshPreview)
    }

    private func openTuning() {
        pendingYangqinWire = nil
        editingTuning = useCustom
        let saved = savedTunings[instrumentID]
        let notes = saved.flatMap { profile.strings.isEmpty || $0.count == strings.count ? $0 : nil } ?? strings
        draft = notes.map(TunerPitch.label).joined(separator: " ")
        tuningDetent = editingTuning ? .large : compactTuningDetent
        sheet = .tuning
    }

    private var compactTuningDetent: PresentationDetent {
        let groups = profile.checkGroups
        guard let largest = groups.map(\.notes.count).max() else { return .large }
        let rows = CGFloat((largest + 3) / 4)
        let rowHeight: CGFloat = notation.hasTransposition ? 65 : 51
        let groupSelectorHeight: CGFloat = groups.count > 1 ? 27 : 0
        let customEditorButtonHeight: CGFloat = profile.hasStringSetup ? 56 : 0
        return .height(256 + rows * rowHeight + groupSelectorHeight + customEditorButtonHeight)
    }

    private func applySelection(_ choice: TunerProfile, custom: Bool) {
        if choice.instrumentName != profile.instrumentName {
            checkGroupIndex = 0
            stringGroupIndex = 0
        }
        profileID = choice.id
        useCustom = custom
        held = nil
        selectedString = nil
        completed.removeAll()
    }

    private func choose(_ choice: TunerProfile, custom: Bool, dismiss: Bool = true) {
        applySelection(choice, custom: custom)
        rememberSetup()
        if dismiss { sheet = nil }
    }

    private var remembersSetup: Bool {
        guard rememberLastSetup else { return false }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--tuner-test-remember-setup") { return true }
        if arguments.contains("--mode-tuner") || arguments.contains(where: { $0.hasPrefix("--tuner-instrument=") }) {
            return false
        }
        #endif
        return true
    }

    private var setupMemory: TunerSetupMemory {
        (try? JSONDecoder().decode(TunerSetupMemory.self, from: savedSetupData)) ?? .init()
    }

    private func restoreSetup() {
        guard remembersSetup, let id = setupMemory.lastInstrumentID, id != TunerProfile.chromatic.id,
              let base = TunerProfile.availableCatalog.first(where: { $0.id == id }) ?? custom.first(where: { $0.id == id })
        else { return }
        applyRememberedSetup(for: base)
    }

    private func applyRememberedSetup(for base: TunerProfile) {
        let remembered = remembersSetup ? setupMemory.instruments[base.instrumentID] : nil
        let choice = remembered.flatMap { saved in base.tunings.first { $0.id == saved.presetID } } ?? base
        let customNotes = savedTunings[base.instrumentID]
        let usesCustom = remembered?.usesCustomTuning == true && customNotes?.isEmpty == false
            && (choice.strings.isEmpty || customNotes?.count == choice.strings.count)
        applySelection(choice, custom: usesCustom)
        if let title = remembered?.noteGroup, let index = choice.checkGroups.firstIndex(where: { $0.title == title }) {
            checkGroupIndex = index
        }
    }

    private func rememberSetup() {
        guard remembersSetup else { return }
        var saved = setupMemory
        let groups = profile.checkGroups
        saved.lastInstrumentID = instrumentID
        saved.instruments[instrumentID] = .init(presetID: profileID, usesCustomTuning: useCustom,
                                                noteGroup: groups.indices.contains(checkGroupIndex) ? groups[checkGroupIndex].title : nil)
        if let data = try? JSONEncoder().encode(saved) { savedSetupData = data }
    }

    private func chooseCheckNote(_ pitch: Int?) {
        if sheet == .wireNote, let wire = pendingYangqinWire, let course = TunerYangqin.courseIndex(of: wire) {
            pendingYangqinWire = nil
            if let pitch {
                var notes = yangqinCourseNotes
                notes[course] = pitch
                if let data = try? JSONEncoder().encode(notes) { yangqinCourseNoteData = data }
                completed.subtract(TunerYangqin.courses[course].wires)
                selectedString = wire
                held = pitch
            }
            sheet = nil
            return
        }
        if useCustom { choose(profile, custom: false, dismiss: false) }
        held = pitch
        if !model.playing { sheet = nil }
    }

    private var parsedDraft: [Int]? {
        guard let notes = TunerProfile.parseNotes(draft, maximumCount: 88),
              profile.strings.isEmpty || notes.count == profile.strings.count else { return nil }
        if regionalHeadstock == .baglama,
           !TunerRegionalHeadstock.baglama.physicalPitches(for: notes).allSatisfy({ (20...108).contains($0) }) {
            return nil
        }
        return notes
    }

    private var tuningPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text(tunerText(profile.instrumentName)).font(InstrumentType.value(24)).lineLimit(1)
                Spacer()
                Button { sheet = nil } label: {
                    Image(systemName: "xmark").frame(width: 44, height: 44)
                }
                .buttonStyle(HardwareButtonStyle(p: p))
                .accessibilityLabel(L10n.text("Close"))
                .accessibilityIdentifier("tuner-close-options")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let hint = profile.tuningHint {
                        Text(tunerText(hint)).font(.subheadline)
                            .foregroundStyle(p.ink.opacity(0.75))
                            .padding(.horizontal, 8)
                    }
                    if profile.hasStringSetup && sheet != .wireNote {
                        Button {
                            if !editingTuning { tuningDetent = .large }
                            withAnimation(.easeInOut(duration: 0.18)) { editingTuning.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text(tunerText("Custom tuning")).font(InstrumentType.value(16))
                                Spacer()
                                Image(systemName: editingTuning ? "chevron.up" : "chevron.down")
                                    .font(.caption).accessibilityHidden(true)
                            }.padding(.horizontal, 12).frame(height: 46)
                        }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: useCustom))
                        .accessibilityIdentifier("tuner-edit-custom")

                        if editingTuning { customTuningEditor }
                    }
                    if !profile.strings.isEmpty {
                        ForEach(profile.tuningSections) { section in
                            if let title = section.title {
                                Text(tunerText(title))
                                    .font(InstrumentType.value(13))
                                    .foregroundStyle(p.ink.opacity(0.75))
                                    .padding(.horizontal, 8).padding(.top, 4)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            presetRows(section.options)
                        }
                    } else if !profile.checkGroups.isEmpty {
                        TunerNotePicker(p: p, groups: profile.checkGroups, groupLabel: profile.checkGroupLabel,
                                        groupIndex: $checkGroupIndex,
                                        notation: notation,
                                        selected: held, automatic: !useCustom, choose: chooseCheckNote) {
                            tuningDetent = .large
                        }
                    }
                }.padding(2)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }.padding(22)
    }

    private func presetRows(_ options: [TunerProfile]) -> some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                if option.id != options.first?.id {
                    Rectangle().fill(p.edge.opacity(0.5)).frame(height: 0.5).padding(.horizontal, 9)
                }
                let selected = option.id == profileID && !useCustom
                Button {
                    if selected {
                        if !model.playing { sheet = nil }
                    } else {
                        editingTuning = false
                        choose(option, custom: false, dismiss: !model.playing)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(tunerText(option.tuningName)).font(InstrumentType.value(16))
                            Text(presetNotes(option))
                                .font(.caption).monospacedDigit()
                        }
                        Spacer()
                        if selected { Image(systemName: "checkmark").accessibilityHidden(true) }
                    }.padding(.horizontal, 11).padding(.vertical, 6).frame(minHeight: 50)
                }
                .buttonStyle(InstrumentSelectionButtonStyle(p: p, selected: selected))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("tuning-" + option.id)
            }
        }.padding(4).insetPanel(p, radius: 14)
    }

    private func presetNotes(_ option: TunerProfile) -> String {
        guard option.instrumentName == "Bağlama" else {
            return option.strings.map { TunerPitch.label($0, flats: option.prefersFlatStringNotes) }.joined(separator: "  ")
        }
        let layout = TunerRegionalHeadstock.baglama
        let wires = layout.physicalPitches(for: option.strings)
        return layout.wireRanges.map { range in
            Set(wires[range]).sorted().map(TunerPitch.label).joined(separator: "/")
        }.joined(separator: "  ")
    }

    private var customTuningEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tunerText(regionalHeadstock == .baglama
                           ? "Enter one note per course, for example A3 G3 D3. The tuner adds the octave strings."
                           : "Enter string notes in playing order, with octaves.")).font(.subheadline)
            TextField("E2 A2 D3 G3 B3 E4", text: $draft)
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .padding(12).insetPanel(p, radius: 9)
                .accessibilityIdentifier("tuner-custom-notes")
            Button {
                guard let notes = parsedDraft else { return }
                var saved = savedTunings
                saved[instrumentID] = notes
                if let data = try? JSONEncoder().encode(saved) { savedTuningData = data }
                choose(profile, custom: true, dismiss: !model.playing)
            } label: {
                Text(L10n.text("Save")).frame(maxWidth: .infinity).frame(height: 44)
            }
            .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
            .disabled(parsedDraft == nil)
        }
    }

    private func hold(_ pitch: Int) {
        held = pitch
        syncTarget()
    }
    private func syncTarget(refreshPreview: Bool = true, waitsForStringAttack: Bool = false) {
        let chromatic = profile == .chromatic
        audio.reference = reference
        audio.response = chromatic ? .balanced : response
        audio.targets = wireNotes.filter { $0 >= 0 }
        audio.held = held
        audio.isChromatic = chromatic
        audio.chromaticRange = chromaticRange
        audio.clearReading(preservingEnvelope: true, waitsForStringAttack: waitsForStringAttack)
        audio.tracksPlucks = ["Guitar & bass", "Plucked strings"].contains(profile.family)
            || profile.family == TunerProfile.middleEasternFamily
            || ["Sitar", "Yangqin", "Guzheng", "Guqin", "Koto", "Shamisen"].contains(profile.instrumentName)
        #if DEBUG
        if refreshPreview, audio.status == .listening { _ = audio.previewReading() }
        #endif
    }
    private func begin() { syncTarget(refreshPreview: false); audio.listen() }
}

/// Center the printed ink on the key face, including descenders and localized glyphs.
private struct TunerKeyLegend: View {
    let title: String
    let p: InstrumentPalette

    var body: some View {
        Canvas { context, size in
            let font = CTFontCreateWithName(InstrumentType.valueFontName as CFString, 17, nil)
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: title, attributes: [
                .font: font, NSAttributedString.Key(kCTForegroundColorFromContextAttributeName as String): true
            ]))
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            guard bounds.width > 0 else { return }
            let scale = min(1, size.width / bounds.width)
            context.withCGContext { cg in
                cg.translateBy(x: size.width / 2, y: size.height / 2)
                cg.scaleBy(x: scale, y: -scale)
                cg.textMatrix = .identity
                let bevel: CGFloat = 0.65
                // Center both ink passes on the top face, above the lower bevel.
                let faceCenterLift: CGFloat = 0.5
                let origin = CGPoint(x: -bounds.midX, y: -bounds.midY + bevel / 2 + faceCenterLift / scale)
                cg.setFillColor(UIColor.white.withAlphaComponent(p.dark ? 0.12 : 0.78).cgColor)
                cg.textPosition = CGPoint(x: origin.x, y: origin.y - bevel)
                CTLineDraw(line, cg)
                cg.setFillColor(UIColor(Color(hex: p.dark ? 0xC4C2B9 : 0x595852)).cgColor)
                cg.textPosition = origin
                CTLineDraw(line, cg)
            }
        }
    }
}

private struct TunerConsoleKeyPress: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let p: InstrumentPalette
    let instrument: Bool
    let faceHeight: CGFloat

    var pressChanged: ((Bool) -> Void)?

    static func animation(pressed: Bool) -> Animation {
        .easeOut(duration: pressed ? 0.065 : 0.14)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(p.ink)
            .contentShape(TunerKeyHitShape(instrument: instrument, faceHeight: faceHeight))
            .offset(y: configuration.isPressed && !reduceMotion ? 2 : 0)
            .animation(reduceMotion ? nil : Self.animation(pressed: configuration.isPressed),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in pressChanged?(pressed) }
            .onDisappear { pressChanged?(false) }
    }
}

private struct TunerKeyFace: View {
    let p: InstrumentPalette
    let seamCenter: CGFloat
    let instrumentPressed: Bool
    let tuningPressed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(p.dark ? Color(hex: 0x20211F) : Color(hex: 0xAFA99F))
                .offset(y: 1)
                .shadow(color: .black.opacity(p.dark ? 0.45 : 0.24), radius: 2, y: 2)
                .shadow(color: .black.opacity(0.12), radius: 4, y: 4)
            ZStack {
                cap(instrument: false, pressed: tuningPressed)
                cap(instrument: true, pressed: instrumentPressed)
                    .shadow(color: .black.opacity(p.dark ? 0.5 : 0.30),
                            radius: instrumentPressed ? 0.45 : 0.95, x: 0.75, y: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func cap(instrument: Bool, pressed: Bool) -> some View {
        let shape = TunerKeyCap(seamCenter: seamCenter, instrument: instrument)
        let top = instrument ? (p.dark ? 0x454744 : 0xEFEBE5) : (p.dark ? 0x40413F : 0xE8E3DB)
        let bottom = instrument ? (p.dark ? 0x353734 : 0xE2DDD5) : (p.dark ? 0x313331 : 0xD8D2C9)
        return shape.fill(LinearGradient(colors: [Color(hex: UInt32(top)), Color(hex: UInt32(bottom))],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
            .shadow(.inner(color: .white.opacity(p.dark ? 0.19 : 0.85), radius: 1.3, x: 0.5, y: 1.4))
            .shadow(.inner(color: .black.opacity(p.dark ? 0.45 : 0.24), radius: 1.8, x: -0.9, y: -1.6)))
            .overlay { shape.fill(.black.opacity(pressed ? 0.075 : 0)) }
            .offset(y: pressed && !reduceMotion ? 2 : 0)
    }
}

private struct TunerKeyCap: Shape {
    let seamCenter: CGFloat
    let instrument: Bool

    func path(in rect: CGRect) -> Path {
        let sweep = SweptInstrumentKey.sweepWidth(for: rect.height)
        let end = CGPoint(x: rect.minX + seamCenter + sweep / 2, y: rect.maxY)
        var seam = Path()
        seam.move(to: CGPoint(x: end.x - sweep, y: rect.minY))
        SweptInstrumentKey.addSeam(to: &seam, endingAt: end, height: rect.height)
        var side = seam
        let edge = instrument ? rect.minX : rect.maxX
        side.addLine(to: CGPoint(x: edge, y: rect.maxY))
        side.addLine(to: CGPoint(x: edge, y: rect.minY))
        side.closeSubpath()
        let outline = RoundedRectangle(cornerRadius: 22, style: .continuous).path(in: rect)
        return outline.intersection(side).subtracting(seam.strokedPath(.init(lineWidth: 1.25, lineCap: .round)))
    }
}

private enum SweptInstrumentKey {
    static func sweepWidth(for height: CGFloat) -> CGFloat { height * 1.64 }

    static func addSeam(to path: inout Path, endingAt end: CGPoint, height: CGFloat) {
        let middleX = end.x - sweepWidth(for: height) / 2
        path.addCurve(to: end, control1: CGPoint(x: middleX, y: end.y - height),
                      control2: CGPoint(x: middleX, y: end.y))
    }
}

private struct TunerKeyHitShape: Shape {
    let instrument: Bool
    let faceHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let sweep = SweptInstrumentKey.sweepWidth(for: faceHeight)
        let endX = instrument ? rect.maxX : rect.minX + sweep
        let startX = endX - sweep
        let edgeX = instrument ? rect.minX : rect.maxX
        let top = rect.midY - faceHeight / 2
        var path = Path()
        path.move(to: CGPoint(x: edgeX, y: rect.minY))
        path.addLine(to: CGPoint(x: startX, y: rect.minY))
        path.addLine(to: CGPoint(x: startX, y: top))
        SweptInstrumentKey.addSeam(to: &path, endingAt: CGPoint(x: endX, y: top + faceHeight), height: faceHeight)
        path.addLine(to: CGPoint(x: endX, y: rect.maxY))
        path.addLine(to: CGPoint(x: edgeX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
