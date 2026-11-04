# Settings keys and Bluetooth display — 2026-11-04

Approved objects: practice pad, floppy disk (supersedes drawer), dual Bluetooth footswitch. Three equal keys reuse HardwareButtonStyle. Illustrations are native SwiftUI drawing, consistent with existing sound illustrations.

Home LCD: no icon when unconfirmed; monochrome Bluetooth symbol for an online, mapped MIDI source owned by Apple's Bluetooth MIDI driver. Presses briefly deepen the symbol. A 44-point rectangular target opens pedal setup without stopping playback. No glow, green dot, or perpetual animation.

Connection limitations: keyboard/media input does not reveal reliable Bluetooth pedal identity, so HID pedals can operate existing bindings but cannot assert this indicator. Unknown MIDI drivers also fail closed. Saved bindings alone never indicate a connection. Driver recognition and physical disconnect/press response still require a real BLE MIDI pedal; screenshots use an explicitly isolated DEBUG fixture, not proof of physical connectivity.

Validation: simulator 12 LiveModeTests passed; 3 existing LiveMode UI journeys passed. New settings/Bluetooth journey initially found a hit-area bug; after adding a rectangular target its rerun passed. Reviewed dark settings and connected fixture screenshots. Final Debug build succeeded and was installed on connected iPhone 14 Pro via devicectl. Physical lockscreen/background/headphone tests deferred.
