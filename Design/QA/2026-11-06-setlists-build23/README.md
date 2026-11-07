# Build 23 — Song Library and setlist navigation

Version 1.0.2 (23). Implements approved Song Library A and setlist browse/footer-edit design.

## Behavior

- Root: all setlists, left whole-row drag, right navigation, New setlist. No root Edit or duplicated song-library entry.
- Browse: back explicitly says All setlists; title gets the full width; song count belongs to the recessed list; songs have ordinals. Tap a song for contextual Live View. Edit setlist stays at the bottom.
- Editor: cancellable list name/order/membership draft; pencil edits the shared song; minus removes only the membership. Delete setlist confirms that songs remain in the library.
- New list: no persisted empty object before Save. An explicitly named empty list is allowed, with Edit available to add songs.
- Library: tap song for standalone Live View; pencil for editor; no expanding inline actions. Search can dismiss an empty keyboard; filtered results hide reorder handles.
- Standalone: no stale setlist name/ordinal/next/previous; larger beat display; back returns to the library.
- Removing the playing song from a list, or deleting its list, retains the canonical song and clock in standalone context. Permanent song deletion stops that deleted song and removes all references.
- Reordering commits one published collection update. UIKit lifts the whole row; the drop commits once and the rows animate into order (0.2s; Reduce Motion respected). Live hover reordering was removed after reproducing unstable drop regions in hosting views.

## Interaction checks

Stopped selection enters Live View without starting playback. Playing selection changes the song and remains playing. Back, close, list management and cancelled drafts do not reset the clock. Repeated selection is tested through second and third songs, reopening and both navigation contexts.

The library editor keeps its field draft mounted while showing Add to setlist. Membership addition is an explicit immediate action; cancelling song edits does not undo that membership. Similarly, songs explicitly saved while making a list remain in the library if the list draft is cancelled. These are intentional shared-object boundaries.

## Validation environment

- iPhone 14 Pro simulator, iOS 26.5, Debug, Chinese/English, light/dark.
- Physical iPhone 14 Pro: Release build installed successfully (database sequence 5576). A subsequent launch request was denied because the phone was locked.
- Physical five-run launch-to-responsive measurement was attempted but blocked by lock screen. No new phone startup or first-play timing is claimed. Simulator first-play setup from the initial model run was approximately 0.296s; this is not a phone measurement.
- No audio decoding, downloads, catalog preparation, or network work was added to launch. Existing audio and interrupted-playback logic is unchanged.
- Physical pedal, background, lock-screen audio and headphone checks remain deferred, as instructed. The current physical limitation is launching the app for measurement, not installing it.

## Visual review

Inspected actual screenshots for browse/edit/new, independent and contextual Live View, long Chinese/Latin setlist and song names, and fixed-height library actions. Music metadata remains legible; long setlist titles wrap without shrinking. Screenshots are simulator captures, not generated mockups.

## Test evidence

Synthetic drag gestures include a 0.2s destination dwell and allow the native drop animation to settle before checking order. Zero-dwell automation sometimes cancelled before UIKit delivered a drop; fast physical drags have not been evaluated while the phone remains locked.

Detailed result bundles are local under `/tmp/metronome-build23-*.xcresult`. Final run and remaining limitations are recorded in the completion section below.

## Completion

- 42 model/audio tests passed in `metronome-build23-final-recheck2.xcresult`. The earlier mixed run exposed two tests that restored, but did not clear, pre-existing song defaults; their setup now isolates those defaults. Added coverage also verifies that saving a standalone song as a preset snapshot does not replace its current playback context.
- 22 distinct UI journeys passed: 21 in `metronome-build23-final-qa.xcresult`; the remaining library CRUD/delete-confirmation journey passed in `metronome-build23-delete-recheck.xcresult`. The original test expected a Cancel button, but iOS presented a dismissible popover; the corrected journey tests outside-tap cancellation and then confirmed deletion.
- Repeated drag test covers six alternating directions; separate journey covers browse, draft cancellation, setlist-root ordering and library ordering.
- Translation source/resource consistency verified for all 371 source keys across eight translated resources (plus English and shared unit keys).
- Final Release build succeeded; 1.0.2 (23) installed on the physical phone at 17:26:42. No fixture test was run on the physical phone; saved user data was preserved.
- Inspected long-name, settings-icon and dark-Live-View screenshots in addition to browse/editor/library states.
- Remaining physical checks: launch timing and fast drag feel, blocked by the locked phone. No claim of sub-second phone launch is made for this build.
