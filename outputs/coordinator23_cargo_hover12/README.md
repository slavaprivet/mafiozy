# World cargo hover12 — outputs only

Two guarded runtime replacements against accepted23g, paired with controls13 controller/UI. Exact before/after and dependency hashes: RECEIPT.json. Shared files rechecked unchanged when freezing this packet.

## Behavior

- Visible real stored weapon under aim receives a warm gold translucent overlay. Uses the original meshes and ordinary depth-tested StandardMaterial3D; no extra model nodes, triangle changes, collision changes or through-wall pass. This is a model tint, not a screen-space silhouette outline. Only selected item's visible mesh parts receive the overlay. Original material_overlay is saved/restored exactly; a later owner's override is not overwritten.
- Controller must call set_hover(fresh admitted aim_context) from existing .15s hint refresh and clear_hover in UI/control invalidation. Both calls are present in tested controls13. Renderer additionally clears immediately when selected row is removed/replaced/unbound/disposed and on update when its node becomes hidden/dead. No inventory/cargo authority lives in highlight.
- Picker keeps real triangle collision plus current vehicle-mesh and world collision checks. Direct ray wins. Assist radius grows from12 to18px at720, scaled with viewport height. Up to32 cached real triangle centroids per weapon fill gaps between original sparse rings; cache is created with existing BVH during placement, never during hover.
- Absolute ray cap25 equals original worst-case25; sample projections/sorting run only after direct aim fails. No whole scene traversal or new per-frame polling. If the cap is exhausted, selection fails closed.
- pick(camera, screen_point) optionally accepts viewport pixel coordinates. Omitted point stays center. Root's pointer integration must use that same pixel for aimed_trunk broad-phase/world ray; this package does not change input/cursor owner files.

## Exact native evidence

85 checks PASS,3.58s bounded headless actual main. All14 actual source weapons physically stored. Camera rays select TT/Nagan/AK; native Input.parse_input_event(E) through real routing takes exact UID, equips it, preserves finite original magazine/reserve and rejects stale repeats. No manufactured context or ammo. Real static wall blocks both context and highlight. Aim away, menu, lid close, control release and leaving range clear highlight. Materials restore and BVHs remain reused. Small-pistol assisted hit is real triangle3.3704px from requested ray,2probes; bounds18px verified.

120 same-camera direct picker calls each, headless component only: old median773us/p95 892us/max1025us; new821/1024/1278us. This includes original209 vehicle AABB tests and is not rendered frame time. An earlier implementation needlessly projected assist on exact hit; final fast path removed that work. Probe cap was reduced to original25 before final PASS.

## Remaining acceptance

Root must review visible tint and first-hover GPU/material cost in actual loaded game. Alpha overlay adds selected mesh passes; ordinary shared material avoids a custom shader but does not itself prove zero compilation hitch. No performance claim for the full game. NPCs were disabled only for this component fixture; camera was explicitly positioned to actual geometry, so it does not prove ordinary spring-arm framing or free-cursor UX. Ground support accepts admitted ground context, but this packet's new native E proof targets trunk items. Controls13 owns F contents, lid E fallback, take-close/capture and related UI changes.

Apply only listed2 files after guards pass; overlay controls13 separately under its own guards. Do not copy test stage or old_picker.gd into production. Earlier failed run log is preserved: its arbitrary pixel offsets still directly hit the pistol and did not exercise assist; later fixture required a real nonzero assisted hit without changing tolerance or geometry.
