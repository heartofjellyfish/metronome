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

private struct SongSaveBar: View {
    let text: SongTextDraft
    let p: InstrumentPalette
    let cancel: () -> Void
    let commit: () -> Void
    var body: some View {
        let valid = text.hasName
        HStack(spacing: 12) {
            Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("cancel-song")
            Button(action: commit) { Text("Save").frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(HardwareButtonStyle(p: p, charcoal: true)).disabled(!valid).opacity(valid ? 1 : 0.45)
                .accessibilityIdentifier("save-song")
        }
    }
}

struct SongEditor: View {
    let model: MetronomeModel
    let initial: SavedPreset
    let p: InstrumentPalette
    let addToSetlist: (() -> Void)?
    let delete: (() -> Void)?
    let cancel: () -> Void
    let save: (SavedPreset) -> Void
    @State private var text: SongTextDraft
    @State private var customMeter = false
    @State private var draft = Rhythm()
    @Binding var picker: String?
    @Binding var divisionEditing: Bool
    private enum Input: Hashable { case notes }
    @FocusState private var typing: Input?
    static func title(for route: String) -> String {
        L10n.text(["tempo": "BPM", "meter": "METER", "division": "DIVISION", "sound": "SOUND LIBRARY", "custom": "Customize rhythm"][route] ?? "Edit song")
    }
    init(model: MetronomeModel, initial: SavedPreset, p: InstrumentPalette, picker: Binding<String?>, divisionEditing: Binding<Bool>, addToSetlist: (() -> Void)? = nil, delete: (() -> Void)? = nil, cancel: @escaping () -> Void, save: @escaping (SavedPreset) -> Void) {
        self.model = model; self.initial = initial; self.p = p
        _text = State(initialValue: SongTextDraft(initial))
        _draft = State(initialValue: initial.rhythm.performanceCopy)
        self._picker = picker; self._divisionEditing = divisionEditing
        self.addToSetlist = addToSetlist; self.delete = delete
        self.cancel = cancel; self.save = save
    }
    var body: some View {
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
                    HStack(spacing: 10) {
                        SongNameInput(text: text, p: p).frame(minHeight: 22).padding(15).insetPanel(p, radius: 10)
                        if let delete {
                            Button(action: delete) { Image(systemName: "trash").foregroundStyle(.red).frame(width: 46, height: 46) }
                                .buttonStyle(HardwareButtonStyle(p: p)).accessibilityLabel("Delete song")
                                .accessibilityIdentifier("editor-delete-song")
                        }
                    }
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
                        Label("Setlists", systemImage: "music.note.list").frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(HardwareButtonStyle(p: p)).accessibilityIdentifier("editor-add-to-setlist")
                }
                SongSaveBar(text: text, p: p, cancel: cancel) {
                    save(SavedPreset(id: initial.id, name: text.name, rhythm: draft.performanceCopy, notes: text.notes))
                }
                if model.listsContainingSong(initial.id) > 0 {
                    Text("Saving updates this song in every setlist that includes it.").font(.footnote).foregroundStyle(p.muted)
                }
            }
        }.onChange(of: picker) { _, _ in typing = nil; dismissTextInput() }

            .onDisappear { model.endSoundPreview() }
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
