import Combine
import SwiftUI
import GameController
import CoreMIDI
import CoreAudioKit

struct PedalBinding: Codable, Equatable {
    enum Kind: String, Codable { case keyboard, midiNote, midiCC, midiProgram, media }
    var kind: Kind
    var code: Int = 0
    var channel: Int = 0
    var source: Int32 = 0
    var label: String
    func matches(_ other: Self) -> Bool {
        kind == other.kind && code == other.code && channel == other.channel && source == other.source
    }
    var displayLabel: String {
        guard kind == .keyboard else { return label }
        let names = [40: "Return key", 44: "Space key", 79: "Right arrow", 80: "Left arrow", 81: "Down arrow", 82: "Up arrow", 75: "Page up", 78: "Page down"]
        return names[code].map(L10n.text) ?? label
    }
}

enum PedalAction: String, Codable, CaseIterable, Identifiable {
    case next, previous, faster, slower, toggle, tap
    var id: String { rawValue }
    var title: String {
        L10n.text(["next": "Next song", "previous": "Previous song", "faster": "BPM +1", "slower": "BPM −1", "toggle": "Play / stop", "tap": "Tap to set tempo"][rawValue]!)
    }
}

struct PedalProfile: Codable, Identifiable {
    var id: String
    var name: String
    var bindings: [PedalAction: PedalBinding]
    var displayName: String { id == "keyboard" ? L10n.text("Default profile") : name }
}

/// Learning consumes the press. Held keys and switch bounce cannot toggle twice.
struct PedalGate {
    var bindings: [PedalAction: PedalBinding] = [:]
    var learning: PedalAction?
    private var held = Set<String>()
    private var lastPress: [String: Double] = [:]
    enum Result: Equatable { case ignored, learned, perform(PedalAction) }
    mutating func clearHeld() { held.removeAll(); lastPress.removeAll() }
    mutating func assign(_ input: PedalBinding, to action: PedalAction) {
        bindings = bindings.filter { !$0.value.matches(input) }
        bindings[action] = input
    }
    mutating func receive(_ input: PedalBinding, down: Bool, at time: Double) -> Result {
        let id = "\(input.kind.rawValue):\(input.source):\(input.channel):\(input.code)"
        if !down { held.remove(id); return .ignored }
        guard held.insert(id).inserted else { return .ignored }
        guard time - (lastPress[id] ?? -.infinity) > 0.08 else { return .ignored }
        if let action = learning {
            assign(input, to: action)
            learning = nil; lastPress[id] = time
            return .learned
        }
        guard let action = PedalAction.allCases.first(where: { bindings[$0]?.matches(input) == true }) else { return .ignored }
        lastPress[id] = time
        return .perform(action)
    }
}

/// MIDI 1.0 byte-stream decoder. Running status survives packet boundaries;
/// realtime bytes do not disturb it. SysEx/system messages cannot become pedals.
struct PedalMIDIParser {
    private var status: UInt8 = 0
    private var data: [UInt8] = []
    mutating func feed(_ bytes: [UInt8], source: Int32) -> [(PedalBinding, Bool)] {
        var events: [(PedalBinding, Bool)] = []
        for byte in bytes {
            if byte >= 0xF8 { continue }
            if byte & 0x80 != 0 { status = byte < 0xF0 ? byte : 0; data.removeAll(); continue }
            guard status != 0 else { continue }
            data.append(byte)
            let type = status & 0xF0
            let size = type == 0xC0 || type == 0xD0 ? 1 : 2
            guard data.count == size else { continue }
            defer { data.removeAll(keepingCapacity: true) }
            let channel = Int(status & 0x0F)
            if type == 0xC0 {
                let input = PedalBinding(kind: .midiProgram, code: Int(data[0]), channel: channel, source: source,
                    label: "MIDI PC \(data[0]) · CH \(channel + 1)")
                events.append((input, true)); events.append((input, false))
            } else if type == 0x80 || type == 0x90 || type == 0xB0 {
                let kind: PedalBinding.Kind = type == 0xB0 ? .midiCC : .midiNote
                let down = type == 0xB0 ? data[1] >= 64 : type == 0x90 && data[1] > 0
                events.append((PedalBinding(kind: kind, code: Int(data[0]), channel: channel, source: source,
                    label: "MIDI \(kind == .midiCC ? "CC" : "NOTE") \(data[0]) · CH \(channel + 1)"), down))
            }
        }
        return events
    }
}

@MainActor
final class PedalControl: ObservableObject {
    @Published private(set) var bindings: [PedalAction: PedalBinding] = [:]
    @Published private(set) var learning: PedalAction?
    // GCKeyboard merges physical and virtual keyboards. MIDI endpoints can be
    // virtual or wired. Neither is evidence that a Bluetooth pedal is connected.
    @Published private(set) var keyboardDetected = false
    @Published private(set) var lastDirectInput: PedalBinding.Kind?
    @Published private(set) var midiInputNames: [String] = []
    var inputAvailable: Bool { keyboardDetected || lastDirectInput != nil || !midiInputNames.isEmpty }
    var hasBindingForDetectedInput: Bool {
        bindings.values.contains { binding in
            switch binding.kind {
            case .keyboard: return keyboardDetected || lastDirectInput == .keyboard
            case .media: return lastDirectInput == .media
            case .midiNote, .midiCC, .midiProgram: return activeMIDISourceIDs.contains(binding.source)
            }
        }
    }
    @Published private(set) var unassignedPress = false
    var setupVisible = false {
        didSet { if !setupVisible { clearUnassignedPress() } }
    }
    private func clearUnassignedPress() {
        if unassignedPress { unassignedPress = false }
    }
    @Published private(set) var bluetoothConnected = false
    @Published private(set) var pressRevision = 0
    private var bluetoothMIDISourceIDs = Set<Int32>()
    @Published var problem: String?
    @Published private(set) var profiles: [PedalProfile] = []
    @Published private(set) var profileID = "keyboard"
    @Published private(set) var connectedName: String?
    @Published private(set) var conflict: PedalAction?
    private var pendingBinding: PedalBinding?
    private var sourceNames: [Int32: String] = [:]
    var profileName: String { profiles.first { $0.id == profileID }?.displayName ?? L10n.text("Default profile") }
    var isMIDIProfile: Bool { profileID.hasPrefix("midi:") }
    let actionPresses = PassthroughSubject<PedalAction, Never>()
    var perform: ((PedalAction) -> Void)?
    private var gate = PedalGate()
    private var observers: [NSObjectProtocol] = []
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var sources = Set<MIDIEndpointRef>()
    private var parsers: [Int32: PedalMIDIParser] = [:]
    private weak var attachedKeyboard: GCKeyboard?
    private var activeMIDISourceIDs = Set<Int32>()
    private var editing = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pedal-ui-test") {
            let isolated = UserDefaults(suiteName: "Metronome.PedalUITests")!
            isolated.removePersistentDomain(forName: "Metronome.PedalUITests")
            self.defaults = isolated
        } else { self.defaults = defaults }
        #else
        self.defaults = defaults
        #endif
        bindings = self.defaults.data(forKey: "pedalBindings").flatMap { try? JSONDecoder().decode([PedalAction: PedalBinding].self, from: $0) } ?? [:]
        if let data = self.defaults.data(forKey: "pedalProfiles"), let saved = try? JSONDecoder().decode([PedalProfile].self, from: data), !saved.isEmpty {
            profiles = saved
            profileID = self.defaults.string(forKey: "pedalProfileID") ?? saved[0].id
            bindings = saved.first { $0.id == profileID }?.bindings ?? [:]
        } else {
            let legacy = bindings
            profiles = [PedalProfile(id: "keyboard", name: L10n.text("Saved controls"), bindings: legacy.filter { [.keyboard, .media].contains($0.value.kind) })]
            for source in Set(legacy.values.filter { ![.keyboard, .media].contains($0.kind) }.map(\.source)) {
                profiles.append(PedalProfile(id: "midi:\(source)", name: "MIDI", bindings: legacy.filter { $0.value.source == source && ![.keyboard, .media].contains($0.value.kind) }))
            }
            if profiles[0].bindings.isEmpty, let midi = profiles.dropFirst().first { profileID = midi.id }
            bindings = profiles.first { $0.id == profileID }?.bindings ?? [:]
        }
        gate.bindings = bindings
        for name in [NSNotification.Name.GCKeyboardDidConnect, .GCKeyboardDidDisconnect, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.resetInputSession()
                    self?.attachKeyboard()
                    self?.refreshSources()
                }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.resetInputSession() }
        })
        for name in [UITextField.textDidBeginEditingNotification, UITextView.textDidBeginEditingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.editing = true } })
        }
        for name in [UITextField.textDidEndEditingNotification, UITextView.textDidEndEditingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.editing = false; self?.gate.clearHeld() } })
        }
        attachKeyboard()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pedal-fixture-bound") {
            learn(.toggle)
            receive(PedalBinding(kind: .keyboard, code: 40, label: "RETURN"), down: true)
            receive(PedalBinding(kind: .keyboard, code: 40, label: "RETURN"), down: false)
        }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pedal-ui-test"),
           ProcessInfo.processInfo.arguments.contains("--pedal-fixture-bluetooth") {
            updateMIDISources([120], bluetooth: [120], names: [120: "Stage pedal"])
            learn(.toggle)
            receiveMIDI([0x90, 60, 100, 0x80, 60, 0], source: 120)
            return
        }
        #endif
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--pedal-ui-test"),
           ProcessInfo.processInfo.arguments.contains("--pedal-fixture-input") {
            updateMIDISources([121], physical: [121])
        }
        #endif
        // CoreMIDI starts only after opt-in, never on the first launch path.
        if bindings.values.contains(where: { $0.kind == .midiCC || $0.kind == .midiNote || $0.kind == .midiProgram }) { Task { @MainActor [weak self] in self?.enableMIDI() } }
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
    }
    /// Invalidate transient input on device/lifecycle changes, preserving saved mappings.
    func resetInputSession() {
        cancelLearning()
        lastDirectInput = nil
        gate.clearHeld()
        parsers.removeAll()
    }
    func learn(_ action: PedalAction) { cancelLearning(); gate.clearHeld(); gate.learning = action; learning = action }
    func cancelLearning() { clearUnassignedPress(); gate.learning = nil; learning = nil; conflict = nil; pendingBinding = nil }
    func resolveConflict(replace: Bool) {
        guard let input = pendingBinding, let action = learning else { cancelLearning(); return }
        conflict = nil; pendingBinding = nil
        if replace {
            gate.assign(input, to: action)
            learning = nil; persist()
        } else { cancelLearning() }
    }
    func selectProfile(_ id: String) {
        guard profiles.contains(where: { $0.id == id }), id != profileID else { return }
        cancelLearning(); gate.clearHeld(); profileID = id
        gate.bindings = profiles.first { $0.id == id }!.bindings
        persist(); updateConnectedName()
    }
    private func selectInputProfile(_ input: PedalBinding) {
        let target = [.keyboard, .media].contains(input.kind) ? (isMIDIProfile ? "keyboard" : profileID) : "midi:\(input.source)"
        guard target != profileID else { return }
        let assignment = learning
        if !profiles.contains(where: { $0.id == target }) { profiles.append(PedalProfile(id: target, name: sourceNames[input.source] ?? "MIDI", bindings: [:])) }
        selectProfile(target)
        if let assignment { learn(assignment) }
    }
    private func updateConnectedName() {
        guard isMIDIProfile, let source = Int32(profileID.dropFirst(5)), activeMIDISourceIDs.contains(source) else { connectedName = nil; return }
        connectedName = sourceNames[source] ?? profileName
    }
    func clear(_ action: PedalAction) {
        cancelLearning(); gate.bindings.removeValue(forKey: action); persist()
    }
    func clearAll() { cancelLearning(); gate = PedalGate(); persist() }
    private func persist() {
        bindings = gate.bindings
        if let index = profiles.firstIndex(where: { $0.id == profileID }) { profiles[index].bindings = bindings }
        defaults.set(profileID, forKey: "pedalProfileID")
        saveProfiles()
        refreshBluetoothStatus()
        if let data = try? JSONEncoder().encode(bindings) { defaults.set(data, forKey: "pedalBindings") }
    }
    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) { defaults.set(data, forKey: "pedalProfiles") }
    }
    @discardableResult func receive(_ input: PedalBinding, down: Bool, at time: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        if conflict != nil {
            // Keep the latch in sync while the user considers the move. Suppress actions.
            _ = gate.receive(input, down: down, at: time)
            return true
        }
        if down { selectInputProfile(input) }
        if down && (input.kind == .keyboard || input.kind == .media) {
            if lastDirectInput != input.kind { lastDirectInput = input.kind }
        }
        if down, let action = learning, let other = bindings.first(where: {
            $0.key != action && $0.value.matches(input)
        })?.key {
            gate.learning = nil
            _ = gate.receive(input, down: true, at: time)
            conflict = other; pendingBinding = input; return true
        }
        switch gate.receive(input, down: down, at: time) {
        case .ignored:
            if down && setupVisible && learning == nil && !unassignedPress &&
                !bindings.values.contains(where: { $0.matches(input) }) {
                unassignedPress = true
            }
            return false
        case .learned:
            learning = nil; persist(); noteBluetoothPress(input); return true
        case .perform(let action):
            clearUnassignedPress()
            noteBluetoothPress(input)
            perform?(action)
            actionPresses.send(action)
            return true
        }
    }
    /// Media presses have no release callback. Keep their debounce window, but release the latch.
    func media(_ code: Int, label: String) -> Bool {
        let input = PedalBinding(kind: .media, code: code, label: label)
        let assigned = setupVisible || learning != nil || bindings.values.contains { $0.kind == .media && $0.code == code }
        receive(input, down: true); receive(input, down: false)
        return assigned
    }
    func updateKeyboardPresence(_ detected: Bool) {
        if keyboardDetected != detected { keyboardDetected = detected }
        if !detected && lastDirectInput == .keyboard {
            lastDirectInput = nil
        }
    }
    private func attachKeyboard() {
        attachedKeyboard?.keyboardInput?.keyChangedHandler = nil
        attachedKeyboard = GCKeyboard.coalesced
        var detected = attachedKeyboard != nil
        #if DEBUG
        let flags = ProcessInfo.processInfo.arguments
        if flags.contains("--pedal-ui-test") {
            if flags.contains("--pedal-fixture-keyboard") { detected = true }
            if flags.contains("--pedal-fixture-offline") { detected = false }
        }
        #endif
        updateKeyboardPresence(detected)
        attachedKeyboard?.keyboardInput?.keyChangedHandler = { [weak self] _, _, key, down in
            Task { @MainActor in
                guard let self, UIApplication.shared.applicationState == .active, !self.editing else { return }
                let code = key.rawValue
                // Ignore modifier-only presses; preserve normal typing in text fields.
                guard !(224...231).contains(code) else { return }
                let names = [40: "RETURN", 44: "SPACE", 79: "→", 80: "←", 81: "↓", 82: "↑", 75: "PAGE UP", 78: "PAGE DOWN"]
                self.receive(PedalBinding(kind: .keyboard, code: code, label: names[code] ?? "KEY \(code)"), down: down)
            }
        }
    }
    func enableMIDI() {
        #if DEBUG
        // A simulator discovery callback must not replace the injected test topology.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--pedal-ui-test") &&
            !Set(arguments).isDisjoint(with: ["--pedal-fixture-bluetooth", "--pedal-fixture-input",
                                             "--pedal-fixture-keyboard", "--pedal-fixture-offline"]) { return }
        #endif
        guard client == 0 else { refreshSources(); return }
        var result = MIDIClientCreateWithBlock("Metronome Pedal" as CFString, &client) { [weak self] _ in
            Task { @MainActor in self?.refreshSources() }
        }
        guard result == noErr else { problem = L10n.text("Could not connect MIDI. Try again."); return }
        result = MIDIInputPortCreateWithBlock(client, "Pedal Input" as CFString, &port) { [weak self] list, context in
            let source = MIDIEndpointRef(UInt(bitPattern: context))
            var uniqueID: Int32 = 0
            MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &uniqueID)
            var packet = UnsafeRawPointer(list).advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \.packet)!).assumingMemoryBound(to: MIDIPacket.self)
            var bytes: [UInt8] = []
            for _ in 0..<list.pointee.numPackets {
                let data = UnsafeRawPointer(packet).advanced(by: MemoryLayout<MIDIPacket>.offset(of: \.data)!).assumingMemoryBound(to: UInt8.self)
                bytes.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(packet.pointee.length)))
                packet = UnsafePointer(MIDIPacketNext(packet))
            }
            let copied = bytes; let identifier = uniqueID
            Task { @MainActor in self?.receiveMIDI(copied, source: identifier) }
        }
        if result != noErr { MIDIClientDispose(client); client = 0; problem = L10n.text("Could not connect MIDI. Try again."); return }
        refreshSources()
    }
    func receiveMIDI(_ bytes: [UInt8], source: Int32) {
        guard activeMIDISourceIDs.contains(source) else { return }
        var parser = parsers[source] ?? PedalMIDIParser()
        let events = parser.feed(bytes, source: source); parsers[source] = parser
        for (input, down) in events { receive(input, down: down) }
    }
    func updateMIDISources(_ identifiers: Set<Int32>, bluetooth: Set<Int32> = [], physical: Set<Int32> = [], names: [Int32: String] = [:]) {
        if identifiers != activeMIDISourceIDs { resetInputSession() }
        activeMIDISourceIDs = identifiers
        bluetoothMIDISourceIDs = bluetooth.intersection(identifiers)
        let physicalMIDISourceIDs = physical.union(bluetooth).intersection(identifiers)
        sourceNames = names
        var namesChanged = false
        for index in profiles.indices {
            guard profiles[index].id.hasPrefix("midi:"),
                  let source = Int32(profiles[index].id.dropFirst(5)),
                  let name = names[source], !name.isEmpty, profiles[index].name != name else { continue }
            profiles[index].name = name
            namesChanged = true
        }
        if namesChanged { saveProfiles() }
        let onlineNames = identifiers.sorted().map { id in
            names[id] ?? profiles.first { $0.id == "midi:\(id)" }?.name ?? "MIDI"
        }
        if midiInputNames != onlineNames { midiInputNames = onlineNames }
        if physicalMIDISourceIDs.count == 1, let source = physicalMIDISourceIDs.first {
            selectInputProfile(PedalBinding(kind: .midiNote, source: source, label: ""))
        }
        updateConnectedName()
        refreshBluetoothStatus()
    }
    private func refreshBluetoothStatus() {
        // A live Bluetooth transport AND an assignment to that source are required.
        // HID keyboards/media commands intentionally cannot assert Bluetooth identity.
        bluetoothConnected = bindings.values.contains {
            [.midiCC, .midiNote, .midiProgram].contains($0.kind) && bluetoothMIDISourceIDs.contains($0.source)
        }
    }
    private func noteBluetoothPress(_ input: PedalBinding) {
        if bluetoothConnected && bluetoothMIDISourceIDs.contains(input.source)
            && [.midiCC, .midiNote, .midiProgram].contains(input.kind) { pressRevision &+= 1 }
    }
    private func refreshSources() {
        guard port != 0 else { return }
        let current = Set((0..<MIDIGetNumberOfSources()).map { MIDIGetSource($0) }.filter { endpoint in
            guard endpoint != 0 else { return false }
            var offline: Int32 = 1
            // Do not treat an unreadable property as a successful connection.
            return MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyOffline, &offline) == noErr && offline == 0
        })
        for source in sources.subtracting(current) { MIDIPortDisconnectSource(port, source) }
        var connected = sources.intersection(current)
        for source in current.subtracting(sources) {
            if MIDIPortConnectSource(port, source, UnsafeMutableRawPointer(bitPattern: UInt(source))) == noErr { connected.insert(source) }
            else { problem = L10n.text("Could not connect MIDI. Try again.") }
        }
        if sources != connected { resetInputSession() }
        sources = connected
        var identifiers = Set<Int32>()
        var bluetooth = Set<Int32>()
        var physical = Set<Int32>()
        var names: [Int32: String] = [:]
        for endpoint in connected {
            var identifier: Int32 = 0
            guard MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &identifier) == noErr,
                  identifier != 0 else { continue }
            identifiers.insert(identifier)
            var display: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &display) == noErr, let name = display?.takeRetainedValue() as String?, !name.isEmpty { names[identifier] = name }
            var entity = MIDIEntityRef()
            var device = MIDIDeviceRef()
            if MIDIEndpointGetEntity(endpoint, &entity) == noErr, entity != 0,
               MIDIEntityGetDevice(entity, &device) == noErr, device != 0 {
                physical.insert(identifier)
            }
            // Read the owning system driver, never the user-editable device name.
            // Unknown drivers fail closed rather than guessing from “Bluetooth” text.
            var owner: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDriverOwner, &owner) == noErr,
               let name = owner?.takeRetainedValue() as String?,
               name == "com.apple.AppleMIDIBluetoothDriver" {
                bluetooth.insert(identifier)
            }
        }
        updateMIDISources(identifiers, bluetooth: bluetooth, physical: physical, names: names)
    }
}

struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CABTMIDICentralViewController { CABTMIDICentralViewController() }
    func updateUIViewController(_ controller: CABTMIDICentralViewController, context: Context) {}
}
