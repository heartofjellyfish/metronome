# Song library and setlist proposals

Five code-native icon candidates per family, sharing the app's material palette and key surfaces. Qi selected L4 (cassette collection) and S2 (taped stage list); both are implemented in Build 21.

- Song library: L1 record sleeve, L2 song index box, L3 score pages, L4 cassette collection, L5 open score.
- Setlists: S1 clipboard, S2 taped stage list, S3 ordered cards, S4 spiral list, S5 numbered cue cards.
- Layout proposal: direct pencil entry plus permanent drag handle, uniform song parameter entries, plain setlist rows. Direct pencil vs the retained overflow actions remains a design choice; the shipping fix keeps all three secondary actions discoverable together.

Render with macOS SwiftUI ImageRenderer:

```
swiftc -parse-as-library Style.swift Study.swift -o /tmp/metronome-library-design
/tmp/metronome-library-design "$PWD"
```

These are proposals, not screenshots of the running app. The accompanying QA images are captured from the actual app.
