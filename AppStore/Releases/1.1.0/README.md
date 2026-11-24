# Metronome and Tuner 1.1.0 (124)

Use the existing App Store record 6819347521 and bundle ID `com.heartofjellyfish.themetronome`. The existing version is 1.0.3. The proposed listing name is **Metronome and Tuner**. Check its availability in App Store Connect.

## Launch catalog

- Chromatic and custom tunings
- 6-, 7-, and 12-string guitar
- 4-, 5-, and 6-string electric bass
- Standard and baritone ukulele
- Violin, viola, cello, and double bass
- 5-string banjo and mandolin

The standard presets, alternate tunings, and headstock choices for these instruments are available. Regional instruments, winds, keyboards, pitched percussion, and other dedicated pitch-check pages are deferred. Existing catalog identifiers and saved tuning data are preserved.

## Store package

- `metadata/` contains proposed listing copy and release notes for the nine existing locales.
- `review-notes.txt` gives the reviewer the Tuner, Guitar, Chromatic, and Metronome walkthrough.
- Screenshot order is guitar, then metronome. The capture script uses the app's own interface with a simulated tuned E₂ for Guitar and a stopped 96 BPM for Metronome. Each locale has iPhone 17 Pro and 13-inch iPad Pro captures. See [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
- [Privacy page source](../../website/metronome/privacy/index.html) documents on-device microphone analysis. Publish and verify the public privacy page before submitting 1.1.0.

## Automated checks

iPhone 17e simulator, iOS 27.2. All 47 tuner unit tests and nine selected UI journeys passed. They cover the release picker, a hidden profile falling back to Chromatic, sustained pitch feedback, flat and relief appearance, 7- and 12-string layouts, mandolin courses, saved and custom tuning, and repeated preset choices during playback.

The full unit run had 98 passing cases out of 100. Both failing cases also reproduced on the pre-merge `origin/main` commit `8d28953` in an iPhone 17e simulator. They cover interruption/idle-timer behavior and zero-accent polyrhythm. Check the corresponding physical behavior before App Store submission.

## Acceptance before submission

- Xcode Release archive built and its development signature verified. App Store distribution export reported `No Accounts` and no matching App Store provisioning profile. Sign in to the team's Apple Developer account in Xcode, retry App Store Connect distribution, and verify the processed TestFlight build.
- The Release Tuner Preview built with its independent bundle ID. Device install returned CoreDevice error 4016 while the iPhone 14 Pro was unavailable.
- On the signed candidate, complete the [physical device checklist](../../physical-device-review-checklist.md) and the [tuner release checks](../../../Design/Tuner/release-scope.md). Check launch time on iPhone, microphone permission and real string pickup, and data preservation after an in-place upgrade from the public build.
- Load the localized metadata, screenshots and review notes in App Store Connect. After TestFlight passes, submit the update from the existing record.
