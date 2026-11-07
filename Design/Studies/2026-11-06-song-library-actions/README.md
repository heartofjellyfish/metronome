# Song Library: three interaction proposals

A was selected and implemented in Build 23; B/C remain unused explorations. Based on user report that songs cannot open Live View and inline actions overlap neighboring rows.

## Confirmed source finding

`SetlistPanel.libraryRow` currently contains information, an ellipsis button and drag handle, but no song-opening action. Inline actions change the row's height inside a `WholeSongDrag` hosting wrapper. The missing navigation is confirmed from code; the exact overlap mechanism still requires reproduction and measurement before assigning a root cause.

## Shared behavior

- Tap song content to load that canonical song and enter standalone Live View, irrespective of its setlist memberships.
- Stopped: entering does not start sound. Playing: deliberate song selection updates its settings and keeps the transport active. Returning, searching, editing metadata, opening management or cancelling an action does not itself restart the transport.
- Repeated comparison: back returns to the library with search and scroll preserved; a second or third song can be opened without a stale setlist context.
- No inline expanding management content. Drag snapshots cover entire rows. Scrolling and typing must remain responsive; search is dismissible while empty.
- Long titles wrap; membership chips are read-only contextual information. Test zero/one/many memberships and large text.
- Delete is confirmed and states that the song is removed from the library and all setlists. Removing a setlist membership is a separate action.

## A — direct pencil (recommended)

Song body opens Live View. Pencil opens the existing editor directly. Quiet drag handle remains separate. Add to setlist and Delete are grouped in the editor, below musical fields; they do not expand the library row. Explicit Save/Cancel handles drafts. If a user adds a song to a setlist while the editor has unsaved edits, require an explicit save/discard decision rather than silently applying or losing the draft. Prefer keeping membership choice staged with the editor save if that flow stays clear.

Benefit: visible, familiar actions; no hidden gesture or extra management mode. Cost: adding to a setlist and deletion take one additional navigation step. Piano/music sound catalog is not affected.

## B — swipe actions

Song body opens Live View. Swipe reveals equal Edit/Add/Delete actions horizontally, preserving row height. Drag handle is an independent left-side target. Provide equivalent accessible actions and a long-press context menu; do not require VoiceOver users to discover swipe-only actions. Opening a row's actions closes another's. Editing opens the editor, Add opens membership selection, Delete opens confirmation. Horizontal row swipe must not compete with vertical reorder.

Benefit: cleanest resting list and quick frequent management. Cost: lower discoverability and potential gesture conflict; needs real-device interaction evaluation.

## C — management mode

Browsing rows only open Live View. Top Manage enters a distinct mode: selection circles and drag handles replace chevrons without changing row heights. Fixed bottom actions edit/add/delete; no in-row expansion. Edit enabled for exactly one selection; Add/Delete support multiple selected songs. Done exits management. Entering management never loads a song, stops playback or changes selection in the audio model. Search filters should not silently clear a hidden selection; either clear with explicit state feedback or surface total selections.

Benefit: supports large libraries and bulk actions. Cost: mode switching and more state; likely excessive for current small collections. Setlists root still has no Edit/Manage: this option applies only to the song library.

## Images

Built-in Image Gen concepts using the current app screenshot as material reference. Existing native controls and music notation remain the implementation source; these are not test screenshots. Prompts are saved alongside the proposals.

## Implementation note

The Add to setlist sheet keeps the Song Editor mounted, preserving unsaved musical fields. Adding a membership is an explicit immediate action; cancelling the editor discards field changes, not that membership. A regression journey edits tempo, adds membership, returns and saves without losing the tempo draft.
