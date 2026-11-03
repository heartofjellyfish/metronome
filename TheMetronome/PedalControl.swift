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
}

enum PedalAction: String, Codable, CaseIterable, Identifiable {
    case next, previous, faster, slower, toggle, tap
    var id: String { rawValue }
    var title: String {
        L10n.text(["next": "Next song", "previous": "Previous song", "faster": "BPM +1", "slower": "BPM −1", "toggle": "Play / stop", "tap": "Tap tempo"][rawValue]!)
    }
}

/// Learning consumes the press. Held keys and switch bounce cannot toggle twice.
struct PedalGate {
    var bindings: [PedalAction: PedalBinding] = [:]
    var learning: PedalAction?
    private var held = Set<String>()
    private var lastPress: [String: Double] = [:]
    enum Result: Equatable { case ignored, learned, perform(PedalAction) }
    mutating func clearHeld() { held.removeAll(); lastPress.removeAll() }
    mutating func receive(_ input: PedalBinding, down: Bool, at time: Double) -> Result {
        let id = "\(input.kind.rawValue):\(input.source):\(input.channel):\(input.code)"
        if !down { held.remove(id); return .ignored }
        guard held.insert(id).inserted else { return .ignored }
        guard time - (lastPress[id] ?? -.infinity) > 0.08 else { return .ignored }
        func matches(_ binding: PedalBinding) -> Bool {
            binding.kind == input.kind && binding.code == input.code && binding.channel == input.channel && binding.source == input.source
        }
        if let action = learning {
            bindings = bindings.filter { !matches($0.value) }
            bindings[action] = input; learning = nil; lastPress[id] = time
            return .learned
        }
        guard let action = PedalAction.allCases.first(where: { bindings[$0].map(matches) ?? false }) else { return .ignored }
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
    @Published private(set) var midiSources = 0
    @Published var problem: String?
    var perform: ((PedalAction) -> Void)?
    private var gate = PedalGate()
    private var observers: [NSObjectProtocol] = []
    private var client = MIDIClientRef()
    private var port = MIDIPortRef()
    private var sources = Set<MIDIEndpointRef>()
    private var parsers: [Int32: PedalMIDIParser] = [:]
    private var editing = false
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bindings = defaults.data(forKey: "pedalBindings").flatMap { try? JSONDecoder().decode([PedalAction: PedalBinding].self, from: $0) } ?? [:]
        gate.bindings = bindings
        for name in [NSNotification.Name.GCKeyboardDidConnect, .GCKeyboardDidDisconnect, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.gate.clearHeld(); self?.attachKeyboard() }
            })
        }
        observers.append(NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.cancelLearning(); self?.gate.clearHeld() }
        })
        for name in [UITextField.textDidBeginEditingNotification, UITextView.textDidBeginEditingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.editing = true } })
        }
        for name in [UITextField.textDidEndEditingNotification, UITextView.textDidEndEditingNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.editing = false; self?.gate.clearHeld() } })
        }
        attachKeyboard()
        // CoreMIDI starts only after opt-in, never on the first launch path.
        if bindings.values.contains(where: { $0.kind == .midiCC || $0.kind == .midiNote || $0.kind == .midiProgram }) { Task { @MainActor [weak self] in self?.enableMIDI() } }
    }
    deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        if port != 0 { MIDIPortDispose(port) }
        if client != 0 { MIDIClientDispose(client) }
    }
    func learn(_ action: PedalAction) { gate.clearHeld(); gate.learning = action; learning = action }
    func cancelLearning() { gate.learning = nil; learning = nil }
    func clear(_ action: PedalAction) {
        cancelLearning(); gate.bindings.removeValue(forKey: action); persist()
    }
    func clearAll() { cancelLearning(); gate = PedalGate(); persist() }
    private func persist() {
        bindings = gate.bindings
        if let data = try? JSONEncoder().encode(bindings) { defaults.set(data, forKey: "pedalBindings") }
    }
    @discardableResult func receive(_ input: PedalBinding, down: Bool, at time: Double = ProcessInfo.processInfo.systemUptime) -> Bool {
        switch gate.receive(input, down: down, at: time) {
        case .ignored: return false
        case .learned: learning = nil; persist(); return true
        case .perform(let action): perform?(action); return true
        }
    }
    /// Media presses have no release callback. Keep their debounce window, but release the latch.
    func media(_ code: Int, label: String) -> Bool {
        let input = PedalBinding(kind: .media, code: code, label: label)
        let assigned = learning != nil || bindings.values.contains { $0.kind == .media && $0.code == code }
        receive(input, down: true); receive(input, down: false)
        return assigned
    }
    private func attachKeyboard() {
        GCKeyboard.coalesced?.keyboardInput?.keyChangedHandler = { [weak self] _, _, key, down in
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
    private func receiveMIDI(_ bytes: [UInt8], source: Int32) {
        var parser = parsers[source] ?? PedalMIDIParser()
        let events = parser.feed(bytes, source: source); parsers[source] = parser
        for (input, down) in events { receive(input, down: down) }
    }
    private func refreshSources() {
        guard port != 0 else { return }
        let current = Set((0..<MIDIGetNumberOfSources()).map { MIDIGetSource($0) }.filter { $0 != 0 })
        for source in sources.subtracting(current) { MIDIPortDisconnectSource(port, source) }
        var connected = sources.intersection(current)
        for source in current.subtracting(sources) {
            if MIDIPortConnectSource(port, source, UnsafeMutableRawPointer(bitPattern: UInt(source))) == noErr { connected.insert(source) }
            else { problem = L10n.text("Could not connect MIDI. Try again.") }
        }
        if sources != connected { gate.clearHeld(); parsers.removeAll() }
        sources = connected; midiSources = connected.count
    }
}

struct BluetoothMIDIPicker: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CABTMIDICentralViewController { CABTMIDICentralViewController() }
    func updateUIViewController(_ controller: CABTMIDICentralViewController, context: Context) {}
}
