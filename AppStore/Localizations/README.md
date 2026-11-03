# Metronome localization — first release

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
- Model and audio setup tests passed on the simulator. Platform-independent timing, meter, ramp, gap and preset tests passed.
- iPhone captures inspected for long labels and layout. Status bars use 6:27, full cellular/Wi-Fi signal and full battery without charging.
- Nine sets of subtitles, descriptions, promotional text and keywords saved in the 1.0.1 draft. This is not a published update.
- Simplified and Traditional Chinese iPhone screenshots uploaded. Remaining screenshot uploads pending browser coordination.
- Physical-device build/install blocked: Xcode has no signed-in account and no matching development provisioning profile. An existing App Store profile is present, but the available signing identities are development identities. User asked to sign into Xcode.
- A new Developer Program agreement was shown on the Business page. If it blocks uploading or submission, accepting it requires the user's action-time authorization.

Do not mark the update submitted or installed until those actions are verified.
