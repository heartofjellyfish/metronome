# App Store screenshots · English (U.S.) · 2026-10-05

Six marketing cards, revised for direct benefit headlines, 1284 × 2778 pixels. Current captures from iPhone 17 Pro / iOS 26.3 simulator, taken from the existing project UI journeys on 2026-10-05. This export size matches a size accepted by the current App Store Connect 6.5-inch screenshot slot. An iPad 13-inch card was prepared and submitted separately (see below).

## Order

1. Open. Play. No pop-ups. — Free forever. Ad-free forever.
2. Studio-grade percussion. — Real instruments. Played by real people.
3. Beautifully simple. — Minimalism in every detail.
4. Hear accents. Feel the groove. — Strong beats and lighter beats. Find your feel.
5. Build speed. Step by step. — Start slow. Let the tempo ramp do the nudging.
6. Practice with silent bars. — The click takes a break. You keep playing.

Headline hierarchy: large type communicates one concrete reason to download; supporting text adds mechanism, specifics or permanent promises. Avoid abstract slogans that require explanation. The third card highlights elegant, minimal instrument design using the genuine graphite interface. Its emotional benefit is a more enjoyable practice ritual, not a promised mental-health outcome. The first card communicates direct entry without startup interruptions. It does not claim a measured zero-delay launch. “Just you and the beat” remains usable as supporting brand copy rather than the headline.

`en-US/` contains upload-size PNGs; `overview.png` is the contact sheet. `raw/` preserves app captures. `render.swift` composes editable text and native image layers without synthesizing app UI. Source images are fitted proportionally, with only the outer corners clipped. No stock imagery or generative app mockups.

Build renderer with `swiftc -module-cache-path /private/tmp/metronome-store-swift-cache AppStore/Screenshots/render.swift -o /private/tmp/metronome-store-render`; run it with the absolute Screenshots directory as its argument.

## Validation and remaining work

- Viewed the actual sound library, ramp and silent-bar source captures, plus the complete six-card overview after correcting the renderer coordinate orientation.
- Captions match implemented functions. The groove card shows ACCENT enabled in Settings; it is the weakest visual demonstration of groove and could be replaced by an active beat close-up in a subsequent creative variant.
- Four existing UI capture tests ran: three passed; `testPercussionLibrarySelectionAndPlayback` failed its selected-state assertion for a Classic sound at InstrumentUITests.swift:191, after the sound-library screenshot had been saved. This is an unresolved selection/persistence or UI-test state issue; do not treat the capture run as a clean release gate.
- Result bundle: `/private/tmp/metronome-store-captures-20261005.xcresult`; log: `/private/tmp/metronome-store-captures.log`. These temp files are not permanent release evidence.
- These are design drafts, not uploaded screenshots. App Store price must still be configured to Free. No app source was changed; no physical-device install or performance test was performed in this asset-only task.

Reference: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

Future-proof creative: sound headlines have no fixed catalog count; the design headline names no fixed skin count or exclusive palette. Actual recordings and current skins remain shown in screenshots.

## Status-bar recapture · 6:27

All six raw captures and marketing exports were refreshed. Visually checked each status bar in `status-bars.png`: 6:27, four cellular bars, full Wi-Fi, 100% battery, with no charging symbol. Captured using Simulator status-bar overrides, rather than retouching the screenshots.

```sh
xcrun simctl status_bar 0A15A174-B773-4963-9A5A-20E2CFABFD92 override --time '6:27' --dataNetwork wifi --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
```

The final recapture run passed all four selected UI tests (68.364 seconds, zero failures): simple home, new percussion selection, settings/dark playback, and gap controls. Result: `/private/tmp/metronome-store-627-final.xcresult`; log: `/private/tmp/metronome-store-627-final.log`. The earlier Classic selection assertion failure above was not rerun or resolved by this asset task. The ZIP contains only the six updated upload images.

Layout revision: removed the repeated brand eyebrow from every card, moved headlines up 70 pixels, and enlarged the intact UI from 1018 to 1068 pixels wide. Outer bottom margin is now approximately 26 pixels; native in-app spacing is preserved. Visually reviewed all six cards together.

Breathing-room revision: headline y=138, supporting text y=405, intact screenshot y=500 and width=1036. Restored 70 pixels of upper space while retaining an approximately 26-pixel outer bottom margin. Reviewed the regenerated six-card overview.

Readability revision: supporting text increased from 37 to 48 pixels on every card. Screenshot y=540, width=1024, leaving approximately 12 pixels below the full native capture. Card 2 uses the user-requested “Studio-grade percussion” positioning and real-player provenance from bundled Attribution.txt (including Austin McMahon); studio-grade is a qualitative positioning phrase, not a measured certification. Electronic CLICK remains synthesized; the real-player line refers to the pictured percussion recordings. Future skin additions are not promised in current screenshots. All six revised cards were visually reviewed.

Material revision: warm uncoated-paper texture generated deterministically in the native renderer from fine grain and soft multiscale tonal variation. Texture is drawn behind text and the intact app captures, never over app UI. Saved reusable paper-texture.png. Reviewed first full-size card and six-card overview; unchanged copy, layout, status bars and 1284 × 2778 dimensions. Updated upload ZIP.

## iPad submission asset

`ipad/en-US/01-open-play.png` (2064 × 2752) was captured from iPad Pro 13-inch (M5), iOS 26.3, using the actual light interface with 6:27, full cellular/Wi-Fi and 100% battery. `ipad/render.swift` composes the approved first-card headline and supporting copy over the paper texture; the app capture is scaled proportionally. Visually checked and uploaded to the iPad 13-inch slot before submission on 2026-10-05.
