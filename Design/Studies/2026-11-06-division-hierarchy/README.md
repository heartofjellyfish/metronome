# Division hierarchy proposals

Generated with built-in Image Gen; exact prompts are in prompts.json. A/B/C are proposals, not approved implementation. No app code changed for this exploration.

- A: one large mode rocker, distinct smaller physical family keys inside the pattern well. Wide notation area, familiar hardware language; still two conceptual levels.
- B: one scrolling catalog with visible headings; three direct pattern-family anchors scroll to sections. No hidden tabs, but finding distant content requires scrolling. Anchors must stay reachable in implementation.
- C: one vertical selection rail; Even is a destination, Patterns is a group heading with three child destinations. One tap changes family without a second tab row; costs horizontal notation space, which must be checked at actual phone size.

Generated notation has errors and is NOT a music engraving master. Evaluate material, spatial hierarchy and density from these images. The implementation must use the existing Bravura-based score renderer with verified durations, beams and tuplets, not copy the generated notes.

## Tuplet research

For a quarter-note pulse in simple meter, one consistent spelling is: 3 eighths at 3:2; 5 sixteenths at 5:4; 7 sixteenths at 7:4; 9 thirty-seconds at 9:8. These are not universal spellings independent of beat unit. Ratios and nominal duration together determine the group duration. A dotted-quarter pulse changes the relationship (three eighths then form an ordinary subdivision).

- Dorico's ratio and duration examples: https://www.steinberg.help/r/dorico-se/6.2/en/dorico/topics/write_mode/write_mode_note_input/write_mode_tuplets_popover_r.html
- Dorico's tuplet semantics: https://www.steinberg.help/r/dorico-pro/6.2/en/dorico/topics/notation_reference/notation_reference_tuplets/notation_reference_tuplets_c.html
- LilyPond supports numeral-only fully beamed groups and brackets when grouping is not otherwise clear; brackets may be above/below, and older curved variants exist: https://lilypond.org/doc/v2.26/Documentation/notation/writing-rhythms#tuplets
- Sibelius reference, printed p.275: bracket positioning accounts for notehead boundaries and stem clearance, so exact stem-to-stem alignment is not a universal rule: https://resources.avid.com/SupportFiles/Sibelius/2018.6/Sibelius_Reference_2018.6.pdf

Recommended app rule: numeral only for an unambiguous fully beamed tuplet; bracket + numeral when mixed values/rests obscure the group; number optically centered, hooks complete and visible, no collision with stems/flags. For our stem-up rhythmic glyphs, place above consistently. This is a proposed house style, not a claim every publication follows it.

Current code audit: DivisionPanel offers 1–8 even choices; RhythmScore's simple-meter tuplet labels cover 3/5/6/7, not 9. Adding nine subdivisions later must update model limits, duration calculation, notation and tests together. Current exact stem-aligned bracket was a design choice; do not present it as the sole correct notation rule.
