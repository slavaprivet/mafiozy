# Independent candidate10 trunk review

Read-only review; no engine/GPU/Git or candidate/shared edits. All seven overlay files match candidate10 byte-for-byte. No new UID/ammo transaction blocker found in the reviewed paths; this is not a replacement for root GUI/render acceptance.

## Material findings

1. **Keyboard navigation is disabled by the modal interceptor.** `preview_weapons.gd:199` handles every modal key before GUI dispatch; `preview_weapon_cargo.gd:603` returns true for every InputEventKey. Consequently Tab cannot traverse focus, Enter/Space cannot activate the focused take/store/close button, and keyboard scrolling does not reach the ScrollContainer. Mouse buttons and wheel still reach GUI. Minimal correction if keyboard navigation is required: handle E/Q/Esc/G early, suppress gameplay actions in the existing controls_blocked paths, but allow the GUI navigation/accept keys to reach controls; retain the late unhandled modal guard. Do not simply allow Space into the gameplay jump path. Native143 emits button.pressed directly, so it does not cover keyboard GUI dispatch.

2. **The advertised 400px / two-column layout is not actually bounded to that width.** `walk_trunk_window.gd:37–46` requests a 400px panel minimum, while footer buttons alone require 220+160px, two 14px HBox gaps and 40px panel inset (>=448px before held text). The bottom help Label at line36 is one non-wrapping line; empty-state and card-name labels likewise retain content minimum widths. Container minimum sizes can therefore expand the panel beyond the requested size, while centering uses the requested width. The grid disables horizontal scrolling. Wrap the help/name/empty labels and switch footer to vertical on narrow width, then test final panel/card/button rectangles after container layout at narrow viewport ratios. Project canvas_items stretch starts from1280x720, so ordinary proportional window reduction may hide this problem rather than exercise the two-column branch. Native143 only checks card minimum width at default size; no resize/actual bounds assertion.

## Guard and cost findings

- Real bridge transfer still reserves both concrete owners, checks selected UID + modal epoch + unchanged physical access evidence, validates both reservations, then commits without callbacks/await between mutations. Taking preflights the model and restores presentation on failure. No new ammo minting or duplicate UID path found.
- Opening/closing cancels pending weapon inputs; modal action release and player controls_blocked checks prevent movement/jump/fire. E/Q close without opening competing arsenal, Esc releases logical capture, blur closes through release_controls.
- Cards/textures rebuild only when cargo revision changes; full cargo snapshots are revision/transfer-bound. Per-frame window work is a viewport-size equality check. Access refresh at150ms is **not purely scalar**: evidence.sample iterates cached lid vertices to compute current bounds; this already existed in the evidence path, but README wording must not imply zero geometry sampling. No measured new cost claim made.
- Automatic invalidation uses close_window(false), leaving mouse visible while logical _free_mouse_look can remain true; manual E/Q/close captures normally and Esc/blur clears logical capture. Root can check cursor/camera consistency after externally closing/moving the vehicle. This is a usability edge, not a transaction bypass.

Exact reviewed candidate10 SHA map is in REVIEW_INPUTS.json. No rollout decision is implied beyond the source review.
