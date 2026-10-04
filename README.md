# The Metronome

Native SwiftUI musician utility, matching the approved ivory / graphite instrument concept in `Design/metronome-concept.png`.

Open `TheMetronome.xcodeproj`, select the `TheMetronome` scheme and an iPhone, and Run. Requires Xcode 16+ and iOS 17+. The project uses the existing local development team for device signing; select your own team when working on another machine.

## Implemented

- Tactile tempo encoder, +/- adjustment, numeric entry, 20–300 BPM, tap tempo.
- 1–12 beats, /2, /4, /8 and /16 meters, simple 1–4 or compound 1/2/3/6 subdivisions, per-beat accent/normal/mute.
- Eight curated sounds with tap-to-preview: seven recorded percussion instruments and electronic CLICK. HI-HAT stays closed.
- Zero, one or two count-in bars; ascending/descending tempo ramp; repeating audible/silent bars.
- Ivory and graphite skins, control haptics, locally persisted settings and named presets.
- Background playback with other audio, lock-screen transport, headphone-disconnect and interruption handling.

6/8, 9/8 and 12/8 default to 2, 3 and 4 dotted-quarter pulses. BPM counts the displayed note unit; compound subdivisions offer one big beat, duplets, eighths and sixteenths (1/2/3/6 clicks). The meter panel also offers eighth-note counting. Older saved rhythms retain their original eighth-note BPM meaning. Beat numeral weight and ink tone express strong, secondary and weak metrical roles without extra marks. Recessed amber indicators reflect the same hierarchy in brightness. EVEN changes audio only: the visual meter hierarchy stays intact. The app is an initial functional build; purchasing and cross-app synchronization are not implemented.

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

## Meter audit (2026-10-03)

Cross-checked against [Open Music Theory: metric hierarchy](https://openmusictheory.github.io/protonotation.html), [compound meter](https://viva.pressbooks.pub/openmusictheory/chapter/compound-meters-and-time-signatures/), [asymmetric grouping](https://viva.pressbooks.pub/openmusictheorycopy/chapter/twentieth-century-rhythmic-techniques/) and [musictheory.net](https://classic.musictheory.net/15/accessibility).

- Simple 2, 3 and 4 beats: strong–weak; strong–weak–weak; strong–weak–secondary–weak. This applies to /2, /4, /8 and /16 note units. 2/2 covers cut time; 4/4 covers common time.
- Compound 6, 9 and 12 over /4, /8 or /16: 2, 3 and 4 dotted beats. Compound duple uses a secondary accent on the second group (the fourth note unit in 6/8), below the downbeat but above its subdivisions. In expanded note-unit counting, in-group divisions are lighter than main beats. In 12/8, the seventh eighth note is the secondary main beat; the fourth and tenth are weaker main beats. The clock is the only authority for sound strength; individual instruments do not re-infer accents.
- 5: selectable 3+2 or 2+3. 7: selectable 2+2+3, 2+3+2 or 3+2+2. Subsequent group starts receive secondary emphasis; these are selectable interpretations, not universal rules for every piece.
- Audio gains remain strong 1.00, secondary 0.34, weak 0.25, subdivision 0.18. These exact ratios are product choices, not music-theory prescriptions. EVEN is 0.60 for every audible hit; defaults remain ACCENT on.
- Numerators 1–12 and denominators 2/4/8/16 are selectable. This is not every possible meter: unusual additive groupings such as 8/8 = 3+3+2, 9/8 = 2+2+2+3, meters above 12, and alternating meters do not have dedicated grouping workflows yet. Other numerators retain a downbeat plus normal pulses/manual accents; no universal grouping is invented.
- Existing 6/4 and other pre-expansion presets retain their note-unit tempo instead of changing speed silently. New meter selections opt into the expanded compound semantics.

Tests enumerate simple and compound patterns, grouped vs expanded counting, all supported 5/7 groupings, audible strength, EVEN visual invariance, persistence and legacy tempo preservation. Rendered audio tests cover every acoustic instrument; UI tests check the hierarchy in EVEN, grouping, cut time and both skins.

### Simple first, expandable when needed

The home surface keeps the approved instrument layout: tempo, beat indicators, direct Meter and Division controls, graphite Play/Stop and ivory Tap. The original section labels and control proportions are retained. Sound choices are one level inside Settings. Practice and saved presets have their own entries; ramp and gap details appear only when enabled. Fresh rhythms start at 96 BPM, 4/4, ACCENT on, with no count-in or training enabled.

Common meters, division, count-in, ramp interval and increment apply in one tap. Custom meter edits apply immediately without a Set button; dismissing retains them. Numeric tempo entry keeps confirmation so partial digits never affect playback. Sound choices apply immediately and keep the library open for auditioning. Preset deletion keeps its confirmation.

## Full feature audit (2026-10-03)

Open [the 37-item audit](Design/Audit/2026-10-03/index.html) for first-principles judgments, primary sources, measured evidence and explicitly unverified hardware cases. Raw clock, rendered-audio, sample-attack and simulator results are alongside it.

Audit fixes: Tap now accepts the entire 20–300 BPM range; live meter/subdivision edits restart the current grid without replaying count-in or resetting training progress; sample-clock-limited previews emit exactly one bar and leave a tail; preset labels track the actual selected, modified or deleted state across launches; Now Playing follows the running ramp tempo; triplet/duplet glyphs include their tuplet numeral. Count-in length edits take effect on the next start. Ramp step text is neutral for ascending and descending practice.

The scheme now runs model integration tests as well as UI tests. The former use synthetic interruption and route-change notifications; lock-screen operation, background duration, real headphone/Bluetooth changes and physical haptics still require a phone pass. Remaining usability findings include single-pulse lamp behavior, visible manual-accent state, small touch targets and Dynamic Type. Shaker attack-envelope differences require listening before changing recordings.

To reproduce the sample-attack measurement (a signal envelope metric, not a perceptual onset judgment):

```sh
swiftc -parse-as-library -module-cache-path /tmp/metronome-swift-cache TheMetronome/Clock.swift TheMetronome/AcousticAudio.swift Tests/AttackAudit.swift -o /tmp/metronome-attack-audit
/tmp/metronome-attack-audit
```
