import SwiftUI
import AVFoundation

struct TunerInstrumentSelection: Equatable {
    let profile: TunerProfile
    let layout: TunerHeadstock?
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
    @AppStorage("tuner.confirmation") private var confirmation = true
    @State private var confirmedNote: Int?
    @State private var held: Int?
    @AppStorage("tuner.referenceToneNote") private var toneNote = 69
    @State private var referencePickerOpen = false
    enum Panel: String, Identifiable { case library, tuning, wireNote; var id: Self { self } }

    private var custom: [TunerProfile] { (try? JSONDecoder().decode([TunerProfile].self, from: customData)) ?? [] }
    private var profile: TunerProfile {
        if profileID == TunerProfile.chromatic.id { return .chromatic }
        return TunerProfile.catalog.first { $0.id == profileID } ?? custom.first { $0.id == profileID } ?? .chromatic
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
        guard let ranges = headstock?.wireRanges ?? regionalHeadstock?.wireRanges else { return strings }
        return zip(strings, ranges).flatMap { note, wires in Array(repeating: note, count: wires.count) }
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
        TunerZither.forInstrument(profile.instrumentName, stringCount: strings.count)
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
        guard !groups.isEmpty else { return nil }
        if let index = activeString, let group = groups.first(where: { $0.wires.contains(index) }) {
            return group.stringName(for: index)
        }
        return audio.reading == nil ? nil : tunerText("Choose a string")
    }

    private var notation: TunerPitchNotation {
        TunerPitchNotation(writtenOffset: profile.writtenOffset, prefersWritten: written)
    }
    private var stringDrawing: TunerStringDrawing {
        TunerStringDrawing(palette: p, liveState: audio.reading?.state, active: activeString,
                           completed: completed, stringCount: wireNotes.count)
    }
    private var concertNote: Int? { audio.reading?.note ?? held }
    private var referenceNote: Int { TunerReferenceControl.noteRange.contains(toneNote) ? toneNote : 69 }
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
        VStack(spacing: 14) {
            if profile == .chromatic { Spacer(minLength: 0) }
            if profile == .chromatic {
                TunerDial(p: p, reading: audio.reading,
                          targetNote: held ?? (audio.status == .tone ? referenceNote : nil), status: statusLabel) { pitch in
                    let center = concertNote ?? referenceNote
                    if let next = TunerReferenceControl.noteRange.filter({ $0 % 12 == pitch })
                        .min(by: { abs($0 - center) < abs($1 - center) }) {
                        chooseReference(next)
                    }
                }
                .frame(height: 350)
            } else {
                if let headstock {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing,
                                     centerX: headstock == .bass ? 172 : 180, select: selectString)
                } else if let headstock = regionalHeadstock {
                    StringTuningFace(p: p, layout: headstock, strings: strings, note: concertNote, reading: audio.reading,
                                     status: statusLabel, drawing: stringDrawing, select: selectString)
                } else if showsGuzheng {
                    TunerGuzhengFace(p: p, note: concertNote, reading: audio.reading, status: statusLabel,
                                     strings: strings, drawing: stringDrawing, groups: groups,
                                     groupIndex: min(stringGroupIndex, groups.count - 1),
                                     showsAll: stringListLayout == .all,
                                     soundingString: audio.status == .tone ? selectedString : nil,
                                     canPlay: eligible, chooseGroup: chooseGuzhengGroup,
                                     showOverview: showGuzhengOverview, select: selectString,
                                     audition: auditionGuzhengString)
                } else {
                    InstrumentTuningDisplay(profile: profile, p: p, note: concertNote, reading: audio.reading,
                                            status: statusLabel, notation: notation,
                                            strings: strings, drawing: stringDrawing,
                                            targetHeight: showsYangqin ? 44 : groups.isEmpty ? stringTargetHeight : selector.height,
                                            showsYangqin: showsYangqin, stringName: stringName(in: groups),
                                            select: selectString, openOptions: openTuning) {
                        if showsYangqin { yangqinTargets }
                        else if !groups.isEmpty { selector }
                        else if !strings.isEmpty { stringTargets }
                    }
                }
                tuningSelector
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
                TunerReferenceControl(p: p, note: referenceNote, held: held, playing: audio.status == .tone,
                                      canPlay: eligible, pickerOpen: $referencePickerOpen, choose: chooseReference) {
                    if audio.status == .tone { begin() }
                    else { audio.tone(note: referenceNote) }
                }
            }
        }
        .foregroundStyle(p.ink)
        .padding(.horizontal, 22)
        .padding(.bottom, profile == .chromatic ? 94 : 0)
        .preference(key: TunerInstrumentPreference.self,
                    value: .init(profile: profile, layout: preferredLayout(for: profile)))
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
            guard audio.status == .listening, let reading else { confirmedNote = nil; return }
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
            if index != nil, selectedString != nil, matches.count == 1 || stringGroups.isEmpty {
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
            else {
                referencePickerOpen = false
                audio.stop()
            }
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
    private var tuningSelector: some View {
        let title: String
        if useCustom {
            title = tunerText("Custom tuning")
        } else if showsYangqin {
            title = tunerText("Yangqin") + " · 410"
        } else if !strings.isEmpty {
            title = tunerText(profile.tuningName)
        } else {
            let instrument = tunerText(profile.instrumentName)
            title = held.map { instrument + " · " + TunerPitch.label($0 + notation.primaryOffset, flats: true) }
                ?? instrument
        }
        return Button(action: openTuning) {
            Text(title).font(.system(size: 20)).lineLimit(1).minimumScaleFactor(0.7)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.down").font(.system(size: 13, weight: .medium))
                        .padding(.leading, 9).alignmentGuide(.trailing) { $0[.leading] }
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 30).frame(minHeight: 44).contentShape(Rectangle())
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
                          emphasizeSelection: emphasizeSelection, accessibilityName: accessibilityName) { selectString(index) }
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
        if wasAuditioning { begin() }
    }

    private func showGuzhengOverview() {
        guard stringListLayout != .all else { return }
        stringListLayout = .all
        if audio.status == .tone { begin() }
    }

    private func auditionGuzhengString(_ index: Int) {
        guard eligible, strings.indices.contains(index) else { return }
        if audio.status == .tone, selectedString == index {
            begin()
        } else {
            selectedString = index
            held = strings[index]
            syncTarget(refreshPreview: false)
            // Stop listening during the sustained reference so it can't confirm its own pitch.
            audio.tone(note: strings[index])
        }
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
                Button { selectString(wire) } label: {
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
                .buttonStyle(.plain)
                .foregroundStyle(drawing.color(for: wire))
                .accessibilityLabel(pitch >= 0 ? TunerPitch.label(pitch) + ", \(offset + 1)" : tunerText("Other note"))
                .accessibilityValue(done ? tunerText("In tune") : "")
                .accessibilityAddTraits(drawing.active == wire ? .isSelected : [])
                .accessibilityIdentifier("tuner-yangqin-wire-\(offset)")
            }
        }
    }

    private func selectString(_ index: Int) {
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
        if selectedString == index { releaseTarget() }
        else { selectedString = index; hold(notes[index]) }
    }

    private func releaseTarget() {
        held = nil
        selectedString = nil
        syncTarget()
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
              let base = TunerProfile.catalog.first(where: { $0.id == id }) ?? custom.first(where: { $0.id == id })
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
                            Text(option.strings.map(TunerPitch.label).joined(separator: "  "))
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

    private var customTuningEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tunerText("Enter string notes in playing order, with octaves.")).font(.subheadline)
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

    private func chooseReference(_ pitch: Int?) {
        if let pitch { toneNote = pitch }
        held = pitch
        syncTarget()
        if let pitch, audio.status == .tone { audio.tone(note: pitch) }
    }

    private func hold(_ pitch: Int) {
        held = pitch
        syncTarget()
    }
    private func syncTarget(refreshPreview: Bool = true) {
        audio.reference = reference; audio.response = response; audio.targets = wireNotes.filter { $0 >= 0 }; audio.held = held
        audio.clearReading(preservingEnvelope: true)
        audio.tracksPlucks = ["Guitar & bass", "Plucked strings"].contains(profile.family)
            || ["Sitar", "Yangqin", "Guzheng", "Guqin", "Koto", "Shamisen", "Oud · Arabic"].contains(profile.instrumentName)
        #if DEBUG
        if refreshPreview, audio.status == .listening { _ = audio.previewReading() }
        #endif
    }
    private func begin() { syncTarget(refreshPreview: false); audio.listen() }
}
