# The Metronome

Native SwiftUI musician utility, matching the approved ivory / graphite instrument concept in `Design/metronome-concept.png`.

Open `TheMetronome.xcodeproj`, select the `TheMetronome` scheme and an iPhone, and Run. Requires Xcode 16+ and iOS 17+. The project uses the existing local development team for device signing; select your own team when working on another machine.

## Implemented

- Tactile tempo encoder, +/- adjustment, numeric entry, 20–300 BPM, tap tempo.
- 1–12 beats, /4 and /8 meters, 1–4 subdivisions, per-beat accent/normal/mute.
- Six synthesized sounds with tap-to-preview: wood, click, bell, hi-hat, shaker and rim. Classic and Percussion banks share the same instrument cards. All synthesized hi-hat strokes stay closed, choking the previous tail over 3 ms.
- Zero, one or two count-in bars; ascending/descending tempo ramp; repeating audible/silent bars.
- Ivory and graphite skins, control haptics, locally persisted settings and named presets.
- Background playback with other audio, lock-screen transport, headphone-disconnect and interruption handling.

BPM refers to the notated beat: quarter note in /4, eighth note in /8. Compound meters currently expose their individual eighth-note pulses. The app is an initial functional build; purchasing, cross-app synchronization and professionally recorded sound packs are not implemented.

## Audio architecture

`SampleClock` advances in audio sample frames with fractional interval carry, preventing cumulative rounded-interval drift. `AVAudioSourceNode` renders preallocated overlapping click voices. Audio thread parameter/status exchange uses a nonblocking try-lock once per buffer; the UI timer only polls visual state. The visual pulse is buffer-level and is not calibrated to Bluetooth output latency.

## Validation

Run the platform-independent timing/voice tests:

```sh
swiftc -module-cache-path /tmp/metronome-swift-cache TheMetronome/Clock.swift TheMetronome/DialInteraction.swift Tests/main.swift -o /tmp/metronome-tests
/tmp/metronome-tests
```

Tests cover sub-sample cumulative timing error at fractional tempo/subdivision intervals, count-in, ramp target clamping, gap bars, muted beats, meter changes, live ramp disable, finite audio samples and codable persistence. Rotary tests cover the full sweep, both stops, angle wrapping, relative grabs and immediate reversal at endpoints.

Simulator build:

```sh
xcodebuild -project TheMetronome.xcodeproj -scheme TheMetronome -sdk iphonesimulator -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

## Interface conventions

The display uses Helvetica Neue Condensed Bold, selected by comparing the reference numerals against native font proofs. Shared `HardwareKeySurface` draws rounded key bevels, a thin contact seam, directional inset highlights and layered contact shadows without casting shadows from the labels. `InstrumentPanel` owns every numeric, choice, practice, preset and error overlay; there are no native menus, forms or numeric alerts. Only preset names use the platform text keyboard.

The tempo knob is a bounded 270° control: 20 BPM at −135°, 300 at +135°. Pointer, tick arc and relative drag share `TempoScale`; touching never jumps the value. The inner dead zone rejects unstable angles, crossing ±180° is continuous, and reversing at either stop responds immediately. A manual tempo edit exits automatic ramp mode.

UI regression tests cover numeric validation/cancel/reopen, meter and subdivision, settings panels during playback, dark mode, rotary gestures and preset save/delete:

```sh
xcodebuild -project TheMetronome.xcodeproj -scheme TheMetronome -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

## Curated sound library

Eight choices, with no duplicate synthetic/acoustic editions: CLASSIC woodblock, electronic CLICK, hand BELL, RIMSHOT, PEDAL hi-hat, STICK clicks, SHAKER and HI-HAT. All physical instruments use recordings; only CLICK uses synthesis. The first shelf recommends HI-HAT, CLASSIC and CLICK. The full library expands Acoustic and Classic sections without paging.

Virtuosity Drums supplies closed hats, pedal chick, shaker and true snare rimshot. VCSL supplies woodblock and handbell. Joseph SARDIN / BigSoundBank Drumsticks #4 supplies actual two-stick clicks (four hits extracted from the official MP3). All sources are CC0; bundled `AcousticSamples/Attribution.txt`, license files and `sources.json` record provenance and edits. STICK is no longer snare cross-stick. Raw sound IDs are stable; retired synth hat/closed/open selections migrate to HI-HAT, and synthetic shaker migrates to the existing acoustic SHAKER. Saved presets retain other settings.

The pedal recordings had main attacks roughly 30–37 ms apart despite earlier noise-threshold trimming. They now align at the dominant attack, detected with 1 ms RMS windows and 1 ms preroll, with a short fade to avoid clicks. `Scripts/prepare_acoustic.swift` includes the corrected pedal preparation rule.

ACCENT defaults on. 4/4 levels are 1.00 / 0.25 / 0.34 / 0.25, with quieter subdivisions; EVEN uses consistent articulation/level. Both modes respect mutes and gap practice. Acoustic attack levels are matched at load time, with timing driven only by the sample clock. All HI-HAT beats are closed. Count-in, mode changes and saved settings are supported. Stopped audition plays a bar; changing instruments does not silently change subdivision.

Validation / audition commands:

```sh
swiftc -parse-as-library -module-cache-path /tmp/metronome-swift-cache TheMetronome/Clock.swift TheMetronome/AcousticAudio.swift Tests/AcousticMain.swift -o /tmp/acoustic-tests
/tmp/acoustic-tests
swiftc -parse-as-library -module-cache-path /tmp/metronome-swift-cache TheMetronome/Clock.swift TheMetronome/AcousticAudio.swift Scripts/render_sound_auditions.swift -o /tmp/render-sound-auditions
/tmp/render-sound-auditions
```

Current four-bar 4/4, 96 BPM auditions are in `Design/Audio/curated-acoustic`. Earlier audition folders are historical iterations.
