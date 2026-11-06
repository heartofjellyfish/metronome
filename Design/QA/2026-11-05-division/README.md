# Division refinement — 1.0.2 (16)

## User-visible changes

- Even and Patterns share two-column hardware cards and the same indicator positioning.
- The three pattern families are subordinate to Patterns, in a smaller recessed selector.
- Curated shelf: 2 eighth-note, 3 triplet and 6 sixteenth-note patterns; full even grids remain in Even.
- Corrected partial beams for sixteenth–eighth–sixteenth. Isolated notes use Bravura flags; connected groups use beams and straight partial beams.
- Tuplet layout reserves both bracket hooks and adjusts spacing before shrinking. Inspected six/seven tuplets in the home control and full-size picker.
- Customize rhythm has three numbered tasks: grid, audible slots, Swing. All 1–8 grid sizes are exposed. At least one slot must remain audible.
- Pattern replacement asks for confirmation when it would discard a custom mask/Swing. Selecting the current grid does not reset edits.
- Preview and Use share one row; the persistent app transport remains separate below.
- Existing saved rhythm format, audio engine and launch path are unchanged.

## Interaction contract

Stopped: picker choice applies and closes; Customize keeps a draft until Use. Back discards a stopped draft.
Playing: choices and edits apply immediately, picker stays open, Use returns from the editor without stopping playback.
Repeated comparisons: current selection updates, can switch families repeatedly, reopen after closing, and preserve custom settings. Song editing continues to edit a draft rather than the active performance.

## Validation

- Seven RedesignTests passed, including engraving semantics, six-slot custom-mask audio timing, persistence, swing timing, clock recovery and existing pedal/song tests.
- First UI pass: three tests passed for repeated choices, stopped draft/Use/Back, last-note guard, Chinese custom editing and dark pattern layout.
- Second UI pass: three tests passed, including song editing/import regression and repeated comparison after spacing changes.
- Final layout validation and device install result recorded below.
- Simulator: iPhone 17 Pro, iOS 26.5. Screenshots are real running UI, status-bar fixtures enabled.
- iPhone 14 Pro was unavailable to CoreDevice at the first installation attempt. No physical launch or acoustic latency measurement is claimed.

## Remaining design judgment

The shelf is curated rather than exhaustive. Other masks remain available through Customize. Swing applies to pairs on even grids; odd grids explain why Swing is unavailable. Compact 8-slot controls retain the left-to-right shape of one beat; smaller devices may scroll the page vertically.

Notation reference: [Humdrum kern beam/partial-beam representation](https://www.humdrum.org/rep/kern/index.html), [LilyPond beams](https://lilypond.org/doc/v2.26/Documentation/notation/beams).

## Final outcome

- Final Chinese/dark layout test passed on iPhone 17 Pro and again in the iPhone 14 Pro simulator, including the assertion that the entire Use button sits above the persistent transport.
- The first final repeated-selection run was interrupted by the Piano app taking foreground (explicitly recorded in the XCTest log). A separate simulator was then created. Its multi-test runner ended without a complete result bundle; the isolated repeated-selection test was rerun by itself and passed (23.256 s, zero failures).
- Final Release build succeeded, signed as 1.0.2 (16).
- Installation attempted: CoreDevice error 1011, device unavailable. A later device query still reported unavailable. Phone installation and physical verification remain pending.
