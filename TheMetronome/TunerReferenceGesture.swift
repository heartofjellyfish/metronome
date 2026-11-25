import SwiftUI

enum TunerReferenceAction {
    case tap, hold, release, cancel
}

// The button's default action also gives VoiceOver and keyboard users a short preview.
struct TunerReferenceButtonStyle: PrimitiveButtonStyle {
    var playsOnTouchDown = false
    var cancel: (() -> Void)? = nil
    let hold: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(TunerReferenceGesture(playsOnTouchDown: playsOnTouchDown) { action, _ in
                switch action {
                case .tap: configuration.trigger()
                case .hold: hold(true)
                case .release: hold(false)
                case .cancel: cancel?()
                }
            })
            .accessibilityAction { configuration.trigger() }
    }
}

struct TunerReferenceGesture: ViewModifier {
    var playsOnTouchDown = false
    let action: (TunerReferenceAction, CGPoint) -> Void
    @GestureState private var touching = false
    @State private var origin: CGPoint?
    @State private var press: Task<Void, Never>?
    @State private var sustained = false
    @State private var moved = false

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .updating($touching) { _, touching, _ in touching = true }
                .onChanged { value in
                    if origin == nil {
                        let point = value.startLocation
                        origin = point
                        if playsOnTouchDown { action(.tap, point) }
                        press = Task { @MainActor in
                            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                            sustained = true
                            action(.hold, point)
                        }
                    }
                    if !moved, hypot(value.translation.width, value.translation.height) > 14 {
                        moved = true
                        press?.cancel()
                        if let origin {
                            if sustained { action(.release, origin) }
                            else if playsOnTouchDown { action(.cancel, origin) }
                            sustained = false
                        }
                    }
                }
                .onEnded { _ in finish(tap: !moved) }
        )
        .onChange(of: touching) { _, touching in
            guard !touching else { return }
            // Let onEnded handle a successful release before cleaning up cancellations.
            Task { @MainActor in if !self.touching { finish(tap: false) } }
        }
        .onDisappear { finish(tap: false) }
    }

    private func finish(tap: Bool) {
        guard let origin else { return }
        press?.cancel()
        press = nil
        self.origin = nil
        if sustained { action(.release, origin) }
        else if !moved {
            if tap && !playsOnTouchDown { action(.tap, origin) }
            if !tap && playsOnTouchDown { action(.cancel, origin) }
        }
        sustained = false
        moved = false
    }
}
