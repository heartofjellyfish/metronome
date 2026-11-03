# Native app translations

Edit `ui-translations.tsv` (English lookup key followed by zh-Hans, zh-Hant, ja, ko, fr, de, es, pt-BR). Run `python3 Scripts/build_localizations.py` to validate completeness and printf arguments and generate the nine native `.lproj/Localizable.strings` resources.

Translate presentation, never storage identifiers. Keep sound raw values, preset IDs, control accessibility identifiers and user-entered preset names stable. Musical note symbols, BPM and conventional Italian tempo markings stay as written. Dynamic labels must explicitly call L10n.text; SwiftUI string literals use native localized lookup. Format numeric quantities through L10n.format/bars so localized text and placeholders remain together.

LocalizationUITests exercises each language: playback, repeated meter choices without dismissal during playback, repeated sound audition, count-in, ramp, silent-bar practice, both themes and reopening the app. Captures preserve the actual translated UI. Use an isolated simulator when another app is being developed in parallel.

The build pipeline loads only small bundled text resources. It adds no network services, startup setup, audio-file decoding or UI language download.
