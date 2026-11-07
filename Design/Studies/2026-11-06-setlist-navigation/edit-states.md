# Follow-up: setlist browsing and editing

Proposal following approval of Song Library A, not an implemented app change.

- Root has only list navigation, whole-row drag ordering and New setlist; no root Edit or Saved songs. One row when only one list, no empty padded well. Empty state offers New setlist.
- Detail toolbar is separate from full-width title. Browsing song rows open Live View. Start from first song explicitly starts; tapping a row while stopped does not start. Navigation never resets an active clock.
- Edit changes the surface into a draft: full-width name field, songs with pencil/remove/drag affordances, Add song, Delete setlist. No navigation to Live View from an edit row. Save applies title/order/membership together; Cancel discards those setlist draft changes. Song content editing is a separate shared-object edit with its own save: make clear that it updates the song everywhere rather than promising outer Cancel undoes it.
- Row removal is removal from this setlist, not permanent song deletion. Deleting a setlist requires confirmation and retains the canonical song library.
- Preview shows all required actions; formal implementation should measure at actual phone widths. Three trailing edit controls may need a more compact arrangement at large text sizes, without reducing touch targets or expanding a row over its neighbors.
- Test first, second and third row actions, cancelling, reopening, whole-row drag, a long list name, long song names, empty lists, and ongoing playback. Reorder must preserve current song by ID. Removing or deleting the current playing context must have an explicit behavior (retain current song as standalone rather than silently switch songs).
- Existing and previously proposed designs should not be interpreted as a new automatic continuous-play feature.

## Revision after user feedback

Supersedes the browse-state reorder and toolbar placement above. Use one combined back key “‹ 全部歌单”, with X at opposite edge. Full-width setlist title below. Put Edit on the count metadata row, not in navigation toolbar. Browsing and editing both have left drag grips and fixed-width ordinal columns (01/02/03); edit has only pencil and minus on right. Browsing has chevrons on right.

Browse reorders apply immediately and retain active song by ID. Edit uses a draft for title/order/memberships; Save commits, Cancel discards those draft changes. Both update displayed ordinals after movement; drag the whole row. Playback is not restarted by sorting.

Remove browse Add song. Create opens the same editor in a new-list state; no persisted empty list before Save. Name is required, songs optional (a named empty list can be saved). Initial Save disabled until a nonblank name exists. Cancel discards unsaved list draft. New-song creation remains a separate explicitly saved library object: discarding the list does not silently delete a song the user already saved. No delete action in new-list mode. After Save show the new list in browse mode, not Live View; never auto-play. Empty browse state offers Edit as the route to add songs, no redundant direct Add action.

Pending design judgment: actual large-text phone layout must keep all three edit-row controls and numbering readable; compact metadata or wrap it before reducing hit areas. Generated image is illustrative, not a final pixel specification.
