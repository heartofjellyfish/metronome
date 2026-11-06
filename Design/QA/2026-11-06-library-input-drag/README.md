# Build 21 — library input and drag QA

## Changes
- Empty search, song name, notes and numeric tempo have a visible keyboard-dismiss key.
- BPM, meter, division and sound share the same physical entry style. Child pickers have one back control; drafts survive repeated navigation.
- Library drag handles are permanent outside search. Library ordering does not modify setlist ordering.
- Whole song rows provide UIKit full-size drag previews; edit actions travel with the row. Repeated up/down drags verified.
- Setlist browsing rows use quiet press feedback. Page swaps do not crossfade text and shadows.
- User selected L4 cassette collection and S2 taped stage list. Both are installed artwork, not proposals.

## Validation
19 distinct model/UI checks passed across this iteration (12 model, 7 UI), including keyboard escape, CRUD/search, membership, independent ordering, repeated reorder, nested editor draft preservation and editing during playback. After introducing the native full-size drag source, direct library entry and both reorder journeys passed again; keyboard and reorder received a final regression run.

Screenshots captured from iPhone 14 Pro simulator, iOS 26.5. UI-test fixture data is simulator-only. Inspected recorded lift/move/drop frames, including original-size row preview in flight. Final phone installation uses normal launch, preserving the user's catalog.

## Limits
Typing latency is not measured on the physical phone. A successful installation/launch is not a responsiveness benchmark. Physical pedal, background, lock-screen and headphone tests are deferred. Direct pencil on the library row remains a design proposal; current rows retain overflow with equal pencil/add/delete actions.
