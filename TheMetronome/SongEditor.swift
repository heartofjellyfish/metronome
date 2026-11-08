import SwiftUI
import UIKit

@Observable private final class SongTextDraft {
    @ObservationIgnored private(set) var name: String
    private(set) var hasName: Bool
    func rename(_ value: String) {
        name = value
        let available = !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if hasName != available { hasName = available }
    }
    var notes: String
    init(_ song: SavedPreset) {
        name = song.name
        hasName = !song.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        notes = song.notes ?? ""
    }
}

/// UIKit keeps the insertion point and marked text locally. Only changes to name validity refresh Save.
private struct SongNameInput: UIViewRepresentable {
    let text: SongTextDraft
    let p: InstrumentPalette
    func makeCoordinator() -> Coordinator { Coordinator(text) }
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.text = text.name
        field.textColor = UIColor(p.ink)
        field.font = .preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.returnKeyType = .done
        field.accessibilityLabel = L10n.text("Song name")
        field.accessibilityIdentifier = "song-name"
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }
    func updateUIView(_ field: UITextField, context: Context) {
        field.textColor = UIColor(p.ink)
    }
    final class Coordinator: NSObject, UITextFieldDelegate {
        let text: SongTextDraft
        init(_ text: SongTextDraft) { self.text = text }
        @objc func changed(_ field: UITextField) { text.rename(field.text ?? "") }
        func textFieldShouldReturn(_ field: UITextField) -> Bool { field.resignFirstResponder(); return true }
    }
}

struct SongEditor: View {
    let model: MetronomeModel
    let initial: SavedPreset
    let isNew: Bool
    let p: InstrumentPalette
    let addToSetlist: (() -> Void)?
    let delete: (() -> Void)?
    let cancel: () -> Void
    let save: (SavedPreset) -> Void
    @State private var text: SongTextDraft
    @State private var customMeter = false
    @State private var draft = Rhythm()
    @State private var picker: String?
    @State private var divisionEditing = false
    private enum Input: Hashable { case notes }
    @FocusState private var typing: Input?
    static func title(for route: String) -> String {
        L10n.text(["tempo": "BPM", "meter": "METER", "division": "DIVISION", "sound": "SOUND LIBRARY", "custom": "Customize rhythm"][route] ?? "Edit song")
    }
    init(model: MetronomeModel, initial: SavedPreset, p: InstrumentPalette, isNew: Bool = false, addToSetlist: (() -> Void)? = nil, delete: (() -> Void)? = nil, cancel: @escaping () -> Void, save: @escaping (SavedPreset) -> Void) {
        self.model = model; self.initial = initial; self.p = p
        _text = State(initialValue: SongTextDraft(initial))
        _draft = State(initialValue: initial.rhythm.performanceCopy)
        self.isNew = isNew
        self.addToSetlist = addToSetlist; self.delete = delete
        self.cancel = cancel; self.save = save
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let picker {
                    Button {
                        model.endSoundPreview()
                        if divisionEditing { divisionEditing = false } else { self.picker = nil }
                    } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Back")
                        .accessibilityIdentifier("song-picker-back")
                    Text(Self.title(for: divisionEditing ? "custom" : picker)).font(.headline)
                    Spacer()
                } else {
                    Button(action: cancel) { Text("Cancel").padding(.horizontal, 12).frame(minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("cancel-song")
                    Text(L10n.text(isNew ? "New song" : "Edit song")).font(.headline)
                        .frame(maxWidth: .infinity)
                    Button {
                        dismissTextInput()
                        save(SavedPreset(id: initial.id, name: text.name, rhythm: draft.performanceCopy, notes: text.notes))
                    } label: { Text("Save").padding(.horizontal, 12).frame(minHeight: 44) }
                        .buttonStyle(HardwareButtonStyle(p: p, charcoal: true))
                        .disabled(!text.hasName).opacity(text.hasName ? 1 : 0.45)
                        .accessibilityIdentifier("save-song")
                }
            }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
            GeometryReader { space in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        fields.fixedSize(horizontal: false, vertical: picker == nil)
                            .frame(minHeight: picker == nil && delete != nil ? max(0, space.size.height - 20) : nil, alignment: .topLeading)
                        if picker == nil, let delete {
                            Divider()
                            Button(action: delete) {
                                Label("Delete song", systemImage: "trash")
                                    .foregroundStyle(p.dark ? Color(hex: 0xFFABA0) : Color(hex: 0x91362C))
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                            }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("editor-delete-song")
                        }
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively)
                    .id(picker)
            }
        }.onChange(of: picker) { _, _ in typing = nil; dismissTextInput() }
            .onDisappear { model.endSoundPreview() }
    }
    private var fields: some View {
        @Bindable var fields = text
        return VStack(alignment: .leading, spacing: 20) {
            if let picker {
                if picker == "division" {
                    DivisionPanel(rhythm: $draft, editing: $divisionEditing, playing: false, p: p, stopPreview: model.endSoundPreview)
                } else if picker == "sound" {
                    SoundFamilies(selectedSound: draft.sound, p: p) { sound in
                        draft.sound = sound
                        model.previewRhythm(draft)
                    }
                } else if picker == "tempo" {
                    TempoKeypad(initial: draft.bpm, title: "SET TEMPO", p: p, feedback: model.tickFeedback) { bpm in
                        draft.bpm = bpm
                        self.picker = nil
                    }
                } else {
                    MeterPicker(rhythm: $draft, customMeter: $customMeter, p: p,
                                feedback: model.tickFeedback, finishSelection: {})
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Song name").font(.footnote).foregroundStyle(p.muted).accessibilityHidden(true)
                    SongNameInput(text: text, p: p).frame(minHeight: 22).padding(15).insetPanel(p, radius: 10)
                }

                VStack(spacing: 0) {
                    field("BPM", value: String(draft.bpm), route: "tempo")
                    Divider()
                    field("METER", value: "\(draft.beats)/\(draft.denominator)", route: "meter")
                    Divider()
                    settingRow("DIVISION", route: "division") {
                        RhythmScore(rhythm: draft, color: p.ink, alignsTrailingInk: true).frame(width: 90, height: 40)
                    }
                    Divider()
                    field("SOUND", value: InstrumentSound(rawValue: draft.sound)?.title ?? "", route: "sound")
                }.insetPanel(p, radius: 12)
                Text("Notes").font(.footnote).foregroundStyle(p.muted).accessibilityHidden(true)
                TextField("", text: $fields.notes, axis: .vertical).accessibilityLabel("Notes").lineLimit(2...5).padding(15).insetPanel(p, radius: 10).accessibilityIdentifier("song-notes").focused($typing, equals: .notes)
                if let addToSetlist {
                    Button(action: addToSetlist) {
                        Label("Choose setlists", systemImage: "music.note.list").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("editor-add-to-setlist")
                }
                if !model.listsContainingSong(initial.id).isEmpty {
                    Text("Saving updates this song in every setlist that includes it.").font(.footnote).foregroundStyle(p.muted)
                }
            }
        }
    }
    private func field(_ title: String, value: String, route: String) -> some View {
        settingRow(title, route: route) { Text(value).font(.system(size: 17, weight: .medium)) }
    }
    private func settingRow<Value: View>(_ title: String, route: String, @ViewBuilder value: () -> Value) -> some View {
        Button { dismissTextInput(); picker = route } label: {
            HStack {
                Text(L10n.text(title)).font(.subheadline)
                Spacer()
                value()
                Image(systemName: "chevron.right").font(.caption)
            }.padding(.horizontal, 16).frame(height: 46).contentShape(Rectangle())
        }.buttonStyle(InsetRowButtonStyle(p: p)).accessibilityIdentifier("song-\(route)")
    }

}
