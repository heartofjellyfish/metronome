# Direct pedal assignment — 1.0.2 (6)

Supersedes the connection tab and input-readiness gate. Opening setup prepares media and MIDI input; keyboard listeners already exist. Learning is available without inferred device identity. The first press learns; saved mappings execute without an extra verification press. The optional MIDI picker remains. Assignment lamps indicate saved mappings, not transport connectivity. The home Bluetooth indicator still requires a mapped online Bluetooth MIDI source.

Stopped setup: learn, press, stay in setup. Active playback: settings remain open and playback continues; learning consumes its press. Repeated binding: cancel/reassign in place; close, reopen, and background transitions preserve saved mappings.

Validation: 13 LiveMode logic tests and 4 UI journeys passed on iOS 26.3 simulator. Checked Chinese bound/learning screenshots, plus automated English/German layouts, background cancellation, repeated choices and active playback. Fixture screenshots illustrate saved assignments, not a connected real pedal.

Debug build 1.0.2 (6) installed successfully on connected iPhone 14 Pro. Physical pedal, lock-screen and interruption tests remain unverified. TestFlight remains build 5 until a separate upload.
