# Input readiness and quieter settings icons

The practice pad, floppy disk and dual pedal are upright, 18% smaller, warm grey and softly shadowed. The original sound illustrations and key surfaces remain unchanged.

Assign controls remains browsable without a device. Only its six binding keys are disabled and faded; saved labels stay visible, assignment lamps are unlit, and a localized connection hint plus Connect pedal button leads back to connection setup. Model-level learning also requires available input.

Readiness is separate from the stricter Bluetooth LCD indicator. Online physical MIDI endpoints can enable a first assignment without any existing mapping. HID/media input requires a received press in the current input session; coalesced keyboard presence alone never enables controls. Device/lifecycle changes clear transient verification and learning while preserving mappings. First verification press in setup is consumed including repeats until release; media verification also suppresses default playback. Audio-session preparation occurs only through explicit setup opt-in, not at launch.

Limits: generic keyboard/media APIs cannot prove a particular pedal's Bluetooth identity. Their readiness reflects a received input, not a Bluetooth connection claim. True pedal disconnect/lockscreen/background/headphone testing still requires physical hardware.

Validation: 13 logic tests passed, including initial assignment, virtual endpoint rejection, disconnect/reset, held verification press and unassigned media consumption. All 4 LiveMode UI journeys passed after replacing the test's transient input fixture with a persistent physical-endpoint fixture. Final model guard/media changes passed the logic suite and six-action UI journey again. Light/dark settings and disabled-binding screenshots reviewed. Final disabled-view cosmetic verification and iPhone installation recorded in session.
