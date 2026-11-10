# Live Mode launch · 1.0.2

## Message and order

Live Mode is the lead feature for this update. The first three screenshots independently cover large-beat Live View, Bluetooth pedals, and setlists, in that order. Each card shows one full real app screen. Preserve the broader musician audience: students, teachers, hobbyists and performers across instruments. Practice Routine is a future version and is not promoted here.

English subtitle: `Live Mode, Bluetooth, Setlists` (30 characters). No name change. No-ads messaging remains in promotional text, description and screenshot 4. Hidden keywords cover real musical features rather than slogans; no search-volume or difficulty estimates are claimed.

## Assets

- `metadata/`: nine language versions of subtitle, keywords, promotional text, description, release notes and eight screenshot captions.
- `screenshots/iphone/<language>/`: native UI captures plus eight 1284 × 2778 compositions.
- `screenshots/ipad/<language>/`: native iPad captures plus three 2064 × 2752 Live Mode compositions.
- `render.swift`: deterministic AppKit composition using the approved paper texture. UI captures are fitted proportionally and left intact.

Finished store files are high-quality JPEGs (96% quality); native PNG captures are retained locally under `raw/` and can be reproduced with `PerformanceUITests/testLiveLaunchAssetsEnglish`, `testLiveLaunchAssetsLocalized`, `testLiveLaunchPedalAssets`, `testTourSetlistLaunchAssets`, and `testFullTourSetlistLaunchAssets`. The raw directories are excluded from Git to avoid committing a second large copy of every screen.

The illustrative cover-band setlist is **2026 North America Tour**, with twelve songs: **Wish You Were Here**, **Creep**, **Come Together**, **Time**, **Karma Police**, **Here Comes the Sun**, **Comfortably Numb**, **No Surprises**, **Let It Be**, **Another Brick in the Wall**, **High and Dry**, and **Hey Jude**. The setlist fills the visible list with real songs and continues naturally below it. Names and example arrangement tempos are entered through the app UI; these do not imply endorsement or provide the songs’ audio. Pedal setup images use a debug fixture for a generic input device and a saved Return binding. These illustrate actual UI states, not validation of a specific physical pedal. No product brand, unsupported connection name or compatibility certification is asserted.

## Claims and evidence

Build 83 source and beta journeys support setlists, a shared song library, per-song tempo/meter/subdivision/sound/notes, manual next/previous navigation, temporary Live View Tap Tempo and six pedal assignments. The public description explains the foreground requirement for keyboard-style pedals and does not promise universal Bluetooth compatibility.

Do not claim zero latency, guaranteed uninterrupted calls/alarms, universal background/lock-screen pedal support, automatic song progression, cloud sync or future Practice Routines. Real pedal, call/alarm and long headphone sessions remain hardware validation tasks.

No free/price references in screenshot captions, subtitles or promotional text. The existing lifetime-free commitment is permitted in the description.

## Validation and publication

- Copy checked against Apple's 30-character subtitle, 170-character promo, 4,000-character description/release-note and 100-byte keyword limits.
- Apple sources: https://developer.apple.com/app-store/product-page/ and https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information
- Next-version draft only; App Store production release has not been submitted or published by this materials task.
- See `publication-audit.json` for the verified save/upload state.

Text and subtitles have been verified in all nine locales. New screenshots are **not uploaded**: the Chrome extension lacks file-URL access, and the native file picker is unavailable while the Mac is locked. The attempted Chrome extension-settings navigation was blocked by browser security policy and was not bypassed. The English Face ID large draft group was cleared in preparation for replacement; its original assets remain in the Asset Library. Other locale screenshot associations are still the prior campaign. Replace these with the finished files before submitting.

## Measurement

Owner: Qi. Visibility checkpoint: compare App Analytics search impressions and first-time downloads after release, by territory. Conversion checkpoint: compare product-page conversion after the Live Mode screenshots have run for at least two weeks, with traffic volume reported; no significance claim at low volume. Preserve the prior asset set for comparison.
