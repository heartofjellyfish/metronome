# Submission status · 2026-10-05

## Submitted

- App: metronome, just cleaner (6819347521).
- Version 1.0, build 1; bundle com.heartofjellyfish.themetronome.
- Status: Rejected / Unresolved Issues, verified in App Store Connect after Apple's October 5, 2026, 8:15 PM message.
- Reason: Guideline 2.1, Information Needed — New App Submission. Apple requests physical-device video plus purpose/audience, setup instructions, external services, regional differences and third-party material documentation. The message does not identify a specific functional defect.
- Answers 2–6 saved in App Review Notes and verified after reload; local copy: review-information-en-US.txt. No complete response sent or resubmission performed yet.
- Pending: submitted-build physical-device QA and video on latest OS, including device/OS/build facts. See physical-device-review-checklist.md. Once supplied, complete item 1 in Notes and send all six answers plus evidence to App Review.
- Submitted by Qi Liu on October 5, 2026 at 12:10 PM Pacific.
- Submission ID: 9fc94a7c-b5e7-4ac0-9c1d-120368902064.
- Release: automatically after approval.
- Price: free in all 175 pricing territories; all territories enabled after release.

## Completed

- Release archive and Apple upload succeeded; build processed and selected.
- Included latest user-selected icon and METRONOME instrument branding from main.
- Privacy manifest: no tracking or collected data; app-local UserDefaults CA92.1 and elapsed-time SystemBootTime 35F9.1.
- Export compliance: no non-exempt encryption.
- Age rating 4+ with regional equivalents; Music category; third-party content rights declared with user authorization and bundled CC0 provenance.
- App Privacy: Data Not Collected, published.
- Six iPhone screenshots in approved order: instant entry, percussion, design, accents, ramp, silent bars.
- One iPad 13-inch screenshot (2064 × 2752), captured from the actual iPad simulator and composed with approved marketing copy.
- Support: https://app.qi.land/metronome/
- Privacy: https://app.qi.land/metronome/privacy/
- Marketing: https://app.qi.land/
- Public HTTPS site deployed with Vercel and app.qi.land configured through Cloudflare.

## Verification and limitation

- Both release plists passed plutil validation.
- xcodebuild archive and App Store Connect upload succeeded; Apple accepted the final review submission.
- This release's physical iPhone installation was attempted but failed because CoreDeviceService could not locate the phone after the user left. No successful phone deployment is claimed for these release-declaration changes.
- Physical lock-screen, background and headphone tests remain deferred.

Proof: submitted-for-review.png.
