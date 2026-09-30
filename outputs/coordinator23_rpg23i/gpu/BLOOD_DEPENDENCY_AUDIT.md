# Blast blood dependency finding (read-only)

The minimal candidate17 recipient intentionally omitted visible blast blood because a blast epicentre is not an anatomical hit. The latest Artist bridge now has a separate safe *kind* of presentation: completed-HP-gated,32-particle short burst at the victim; no bullet skin mark, no persistent wound/drip anchor. This can be added without severing or generic-body changes, but copying only the recipient call would invoke missing methods in accepted17.

Exact current read pins, `outputs/artist23_rpg_sever_bridge/stage/scripts/npc_visual/`:

- `npc_blood_adapter.gd`: `b7dbe62438da02582104db044e1e181e5a1a5d8f0909a3a86d79072ed368b68a`, adds `receive_blast(event_id, anchor, outward)`.
- `npc_blood_renderer.gd`: `fc80b06a46ee04fd06e2a52bb663d3079e240f2b89ff84e010bef58ca8edf9dc`, adds `accept_blast(anchor,outward,now)` using the existing fixed particle pool.
- Recipient now `70bf4a77b3bcb3e6bea223dc9a7e21f6fb3e00f4d53abadec46ac8cf0bc786c8`, with `blood.receive_blast(id,position,radial.normalized())` after applied HP, before `_publish_physical`. This differs from the older `d84c…` listed in HANDOFF; do not assume that older receipt covers the current files.

Accepted17 adapter is `ee76e46c2a6c044814f1971c62881bee6501cab969b54b1b10db1c49e0f5b591`; renderer `7821956ad9510ed62c55f022be03244301e675f1a79884b85056afeebef59d48`. Both lack their blast method.

One concrete placement defect in the latest Artist renderer: it unconditionally adds UP×height×0.42. Gate `target_position` means standing CharacterBody feet while IDLE, but means the actual pelvis-body world origin for ACTIVE bodies (`exit_ragdoll_body.snapshot().anchor_world`). The extra offset is valid only for standing feet; it floats the burst above a fallen pelvis. Proposed contract: adapter resolves current anchor semantics before physical activation, applies standing offset once, and passes the final world emission point to renderer with no additional offset. Never substitute epicentre or invent a skin intersection.

Root assigned the additive two-file blood proposal and native proof to `cargo_visual_audit`; no overlapping edits were made here. That agent confirmed exact IDLE/ACTIVE handling and requested recipient insertion before physical publication. Root owns recipient composition. Historical bridge800 checks are not proof of these new current dependencies; require the peer's new native receipt plus root render review.
