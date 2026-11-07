# Setlist navigation — implemented in Build 23

The latest approved browse design is `05-browse-footer-edit.png`: a full-width title, count inside the song container, fixed bottom Edit setlist, and direct song-to-Live View navigation. No Start-from-first-song or browse-level Add song. New lists open a cancellable draft; additions, rename and deletion live in the editor. The earlier proposal below is retained as design history and is superseded wherever it differs.

Implementation screenshots and validation: ../../QA/2026-11-06-setlists-build23/README.md

Based on Build 22 feedback. This proposal does not change the app or existing song data.

## Information hierarchy

- Settings → Setlists → one setlist → song Live View.
- Settings → Song Library → song Live View, without an implied setlist.
- Settings retains independent pedal and practice-preset entries.
- Browsing a list, reordering or renaming never loads a song or changes playback.

## Settings entry

Keep the approved taped-paper icon. Move its optical center down approximately 4 points inside its icon slot, closer to the label; check at actual phone scale. Preserve label baseline and equal tile bounds across all three entries. Do not enlarge the paper to compensate for alignment.

## All setlists

One recessed, content-sized list; each row has title, count, chevron and a quiet drag handle. A single New setlist key follows. Remove root Edit and Saved songs. Drag the entire row, not its handle. New lists stay inactive until a song is deliberately loaded.

Rename, duplicate and delete belong inside that setlist's Edit page, not in a permanent root toolbar. Deleting a setlist removes its ordering/membership only; songs stay in Song Library. Confirm deletion. No new search or filtering UI until collection size warrants it.

## Inside a setlist

Separate toolbar (back to Setlists, Edit, close) from a full-width title. Title may wrap for unusually long names rather than shrink or truncate; the supplied 2026 湾区巡演 should fit one line. Song count is secondary metadata. Preserve Start from first song, plain recessed song rows, and Add song outside the list.

Add song has two primary choices: New song and From Song Library. Proposed simplification: retain preset-to-song conversion in the preset's own actions instead of presenting two similar saved-content stores every time a user adds a song. This remains a proposal, not permission to delete presets or their import capability.

Songs hold name, BPM, meter, subdivision, sound and notes, and can belong to multiple lists. Practice presets also preserve tempo ramps, silent bars, count-in and polyrhythm. Current performanceCopy explicitly removes those practice effects. Keep the distinction in data and explain it through placement, not repeated help text.

## Live View contexts

Within setlist: control row; separate full-width setlist name without total count; song name with quiet ordinal; single BPM/meter/division/Notes row; dominant beat LCD; previous/next; Tap and Play/Stop.

Standalone: back to Song Library, Edit and close; full-width song name; same parameters and Notes; larger beat LCD; Tap and Play/Stop. No setlist title, ordinal, fake empty setlist, or disabled previous/next row. A song reached from Song Library is standalone even if it also belongs to some setlists.

Back returns to the actual origin. Close returns directly to the main instrument. Neither changes the clock. Paused selection stays paused; selecting another song while playing applies it and stays playing. Revisiting either context resolves the current canonical song, not a stale copy.

## Acceptance checks for future implementation

- Empty library/list; one song; first and last songs; very long Chinese and Latin titles; Dynamic Type.
- Root → list → song → back → root; library → standalone → back; close from each live context.
- Current song belongs to zero, one or several lists; no stale setlist title or pedal next/previous navigation leaks into standalone context.
- Reorder full-row preview; rename; deleting a list preserves songs; deletion of current context handled explicitly.
- Starting from first song is the only explicit list-level start action. Never imply automatic song-to-song playback.
- Notes do not reduce the beat display. All names stay readable; no count appended to long setlist headings.

Images are Image Gen layout proposals using the actual app as a material reference, not build screenshots. Musical notation and exact icon geometry must use existing native components in implementation.
