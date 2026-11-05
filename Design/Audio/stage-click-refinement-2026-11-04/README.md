# Stage Click refinement — 2026-11-04

Feedback: the stage sound was too piercing; give its sound card a distinct illustration.

## Sound

| Parameter | Before (build 8) | After (build 9) |
| --- | --- | --- |
| Normal hit fundamental | 3,200 Hz | 2,300 Hz |
| Downbeat fundamental | 4,320 Hz | 2,760 Hz |
| Second harmonic amplitude relative to fundamental | 0.22 | 0.08 |
| Attack | 0.8 ms | 1.2 ms |
| Exponential decay constant | 95/s | 125/s |
| Maximum duration | 45 ms | 40 ms |

The intent is a less piercing, shorter click that still has presence above the ordinary Click. Sound ID 16, meter dynamics, gain scale and preset references remain compatible. No new audio asset or work on the launch path. This is a synthesis adjustment, not a claim that every headphone/stage mix will sound comfortable or cut through live drums.

`before.wav` and `after.wav` use the actual old/new Swift ClickVoice and SampleClock: 120 BPM, 4/4, two bars, 48 kHz mono PCM16. No loudness normalization. `audition.swift` is the rendering harness; compile it with L10n.swift and the corresponding Clock.swift. Before source is commit 375d899.

Measured file peak: 0.5280 before / 0.5182 after. First downbeat RMS over the first 50 ms: 0.1205 / 0.1108. This confirms the change is not just a large reduction in level. Listening preference and real-stage masking still need the drummer's feedback.

## Illustration

A face-on miniature electronic click box: warm grey casing, inset pulse display, grille and small brass dial. Uses the existing native SwiftUI drawing system and shared hardware button surface; no new bitmap in the app. Ordinary Click retains its waveform. `icon-preview.png` renders the production illustration and button components for comparison in light/dark themes. The two full screenshots are actual simulator UI captures.

## Verification

- Simulator iPhone 17 Pro Max, iOS 26.3: all four StageFeatureTests and the Stage Click interaction UI test passed.
- Audio regression covers 44.1, 48 and 96 kHz, all five audible strength levels, finite/bounded samples, silence after the short tail, and matched-window pitch comparison with ordinary Click. Accented Stage Click remains below 3 kHz.
- UI: Stage → Click → Stage; close/reopen preserves selection; change sounds repeatedly during playback and remain playing; inspect English/light and Chinese/dark screenshots.
- Physical iPhone 14 Pro: debug 1.0.2 (9) built, signed and successfully installed via devicectl. Launch/first-play performance run could not start because the phone was locked; waiting test was cancelled. No fresh physical timing or headphone/listening claim.
- TestFlight was not updated by this change.
