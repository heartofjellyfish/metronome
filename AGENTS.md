# Repository workflow

- Default to working on `main` and pushing to `origin/main` when publishing changes.
- The user prefers direct commits to main; do not create pull requests or require code review unless explicitly requested.
- Continue running checks appropriate to the change before publishing.

# Interaction acceptance checks

- Before changing a control, identify the user's next action in three states: stopped setup, active playback, and repeated comparison/audition. Do not equate immediate application with automatic dismissal.
- During playback, Division, Meter and preset choices apply immediately and stay open for comparison. Explicit close remains available. Stopped one-off choices return to the instrument; sound auditions stay open in either state.
- A persistent picker must show the current model selection after every change, not its initial selection. Verify multiple consecutive choices, closing, reopening and playback remaining active.
- Give each visible datum one job. Remove decorative option numbers and synonymous subtitles when the icon/title already communicates the same fact. Preserve useful units, grouping and musical distinctions.
- Settings owns the three recommended sounds. The full sound library lists each instrument once, without another copy of the recommendation shelf.
- For UX work, inspect the resulting screenshots and test user journeys, including the second and third action. Functional assertions alone do not establish interaction quality. Explain any remaining judgment call rather than claiming all UX is correct.
