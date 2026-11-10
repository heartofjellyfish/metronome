# Metronome localization — first release

## Next release · 1.0.2 · Live Mode

The nine canonical locale files now lead with Live Mode, Bluetooth pedals and setlists. The prior no-ads-first subtitle strategy below describes 1.0.1 and is superseded for this release. New promotional text, descriptions, keywords, release notes and subtitles have been saved and re-read in the 1.0.2 App Store Connect draft.

The versioned package is [`../Releases/1.0.2/`](../Releases/1.0.2/README.md): eight new iPhone cards and four iPad cards per locale, leading with instant, ad-free use followed by Live View, setlists, and Bluetooth pedals, using current native UI captures. Use its `render.swift` and `assemble.py`; the older renderer/capture folders below preserve the previous six-card campaign. `publication-audit.json` records the screenshot upload blocker separately from verified text saves. This materials task does not submit the production release.

Version 1.0.1 (2). English, Simplified Chinese, Traditional Chinese, Japanese, Korean, French, German, Spanish and Brazilian Portuguese.

The same features are available in all regions. App Store Connect showed all 175 territories Available on 2026-11-03. Language support and territory availability are separate settings.

## Sources

- App strings: `Localization/ui-translations.tsv`; generate and validate with `python3 Scripts/build_localizations.py`.
- Store text: one JSON file per App Store locale in this directory. English text remains in `AppStore/*-en-US.txt`.
- Real UI captures and composed artwork: `AppStore/Screenshots/Localized/<app-language>/`.
- Render with the compiled `AppStore/Screenshots/render-localized.swift` tool, passing the language directory as its first argument.

Identifiers, persisted sound values, musical notation, Italian tempo markings and user-entered preset names are kept separate from translated presentation. Native localization follows the device/app language and falls back to English. Nothing is downloaded at launch. Letter spacing is reduced for CJK labels; translated panel headers and longer values can fit their available width.

## Metadata decisions

Keep the brand name `metronome, just cleaner`. Lead subtitles with the local equivalent of No Ads. Use keywords for implemented needs: meter, subdivisions, triplets, accents, percussion, tempo changes, presets and silent-bar practice. The Chinese and Japanese fields also supply the local category noun, which the English brand name does not contain.

Keyword vocabulary was checked against localized product listings and maker documentation. These are relevance candidates, not measured search-volume or difficulty claims. Do not invent popularity numbers. The descriptions and screenshots explain how silent bars work; there is no claim that the app listens to or grades the player.

Primary references:
- https://developer.apple.com/help/app-store-connect/manage-app-information/localize-app-information
- https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations/
- https://developer.apple.com/documentation/swiftui/preparing-views-for-localization
- https://apps.apple.com/de/app/das-metronom-von-soundbrenner/id1048954353
- https://apps.apple.com/fr/app/le-m%C3%A9tronome-de-soundbrenner/id1048954353
- https://apps.apple.com/es/app/metroTune-finador-y-metr%C3%B3nomo/id6760752080
- https://music.sii.co.jp/hubfs/STH200_Web_J.pdf

## Validation and publication state

- All 153 translation rows validate across nine languages, including formatting placeholders.
- Nine language journeys passed in the first run. A second capture run passed eight; Portuguese was interrupted by another app taking over the simulator and passed on rerun in a separate simulator.
- All nine language journeys also passed on iPad Pro 13-inch (M5), iPadOS 26.3. Representative English, Chinese and German panel captures were inspected. Model and audio setup tests passed on the simulator. Platform-independent timing, meter, ramp, gap and preset tests passed.
- iPhone captures inspected for long labels and layout. Status bars use 6:27, full cellular/Wi-Fi signal and full battery without charging.
- Nine sets of subtitles, descriptions, promotional text and keywords saved in the 1.0.1 draft. This is not a published update.
- All eight new-language iPhone screenshot groups uploaded and checked: six images each, in order. All eight new-language iPad home images uploaded and checked. English iPhone assets retain the approved set; the English iPad image is also refreshed from this build. Upload audit JSON files are stored alongside this document.
- Xcode login restored. Apple Developer Program License Agreement was accepted on 2026-11-03; provisioning, the signed device build and Release archive now succeed. Build 1.0.1 (2) uploaded successfully and has been selected in the version draft. It was installed successfully on the connected iPhone 14 Pro (iOS 27.0.1). The physical-device smoke test did not complete (device lock/connection interruptions); the user explicitly deferred it and authorized submission first on 2026-11-03.
- The updated program agreement was authorized by the user at action time and the refreshed account confirms acceptance on 2026-11-03.

Do not mark the update submitted or installed until those actions are verified.

## Submission verified · 2026-11-03

Version 1.0.1 (2) submitted at 10:51 AM Pacific. App Store Connect displays **Waiting for Review**. Submission: https://appstoreconnect.apple.com/apps/6819347521/distribution/reviewsubmissions/details/4052f529-95b8-4743-95d7-03254784dd04

The missing Simplified Chinese privacy policy URL was filled with https://app.qi.land/metronome/privacy/; all other locale URLs were checked. Automatic release on approval remains selected. This update is submitted, not yet live.
