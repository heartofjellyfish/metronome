# Division hierarchy, notation and persistent selection

Version 1.0.2 (19), 2026-11-06.

## Interaction

- Even divisions and Patterns are top-level tabs attached to one recessed content container. Only the selected tab's content is present.
- Patterns owns a subordinate category selector. It expands within the panel into physical buttons, then collapses when a category is chosen. This deliberately costs one extra tap compared with a second, visually ambiguous tab row.
- Selecting a division or pattern stays open when stopped or playing. Consecutive selections show current state immediately. Close/back is explicit.
- Custom rhythm Use returns to the division browser. Song-editor division selection also stays open, with an explicit return to Edit song.

## Engraving and catalog

- Tuplet bracket hooks align to the outer stems, or the visible rest edges. The number is centered between those endpoints.
- Isolated flags use the SMuFL glyph origin at the stem tip, rather than fitting/centering the flag inside a generic rectangle.
- Eighth, triplet and sixteenth catalogs cover all nonempty, not-all-on masks in those single-beat grids (2, 6, 14 choices). Familiar mixed durations and dotted figures appear first. This is not an exhaustive catalog of multi-beat music rhythms; custom higher divisions and Swing remain available.
- Added reverse long/short triplet and sixteenth–dotted-eighth notation. Existing sixteenth–eighth–sixteenth notation retains the two inward partial beams.

References:
- [SMuFL flag registration and stem anchors](https://smufl.formats.music/latest/specification/glyphswithanchors.html)
- [LilyPond tuplet bracket placement](https://lilypond.org/doc/v2.24/Documentation/internals/tupletbracket)
- [Kyle Coughlin: sixteenth groupings and dotted rhythms](https://www.rhythm-in-music.com/lesson-09-sixteenth-note-groupings-dotted-eighth-notes.html)

## Verification

- Eight RedesignTests passed, including every catalog mask: engraved note/rest durations total one beat and printed onsets equal the actual sample-clock events (quarter-note beat). Shared partial-beam and custom swing timing tests passed.
- Five UI journeys passed: stopped/playing/repeated selection, reopen current selection, custom Use/cancel, Chinese/dark presentation, and song-editor cancel/save while playback continues.
- The additional expanded-category/lower-catalog visual journey passed (six UI journeys total).
- Actual screenshots inspected on iPhone 14 Pro simulator, iOS 26.5, including home seven-tuplet at its smaller display size. Screenshots are actual app output; overview is only a montage.
- Release build succeeded; installed successfully on connected iPhone 14 Pro. Automatic launch was blocked by the locked phone; unlock and open manually. Physical background/pedal/audio-interruption testing and startup timing were not part of this UI change.
