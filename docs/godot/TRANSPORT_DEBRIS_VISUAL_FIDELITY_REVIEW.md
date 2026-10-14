# Transport debris visual fidelity review

Date: 2026-09-27. Scope: read-only source comparison for the future visual
integration seam. This review does not say that debris rendering is adopted or
wired into the live game.

## Frozen inputs

- `assets/maps/city_rebuild_v1/vehicle_damage.mjs`:
  `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`.
- `godot/mafiozi_walk/scripts/transport/transport_vehicle_debris.gd`:
  `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`.
- `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_debris_refresh.gd`:
  `d2a4453901465e9310033156baefc751fc74f889bb51a3402da27bf6f34b2479`.

The native files were inspected only. They were not edited or adopted.

## Source behavior that must remain exact

The source captures the authored materials at construction (`vehicle_damage.mjs`
61-64), but `detachParts()` does not prepare a visual copy then. On the explosion
update it first chars every non-transparent material to `#100f0e` with roughness
`.99`, calls `onExplosion`, hides glass, and only then calls `detachParts()`
(276). `copyPart()` is consequently a post-damage snapshot: it clones the
current render-source material for every copied mesh (102-107). The settled
debris owns those cloned resources; later reset of the chassis material cannot
recolour an already detached part.

The 32 paint/crater nodes start under `Vehicle_damage_effects` (59, 65-78).
`mark()` reparents a selected node below the hit mesh (184-187). `copyPart()`
explicitly rejects nodes in the mark pool, hidden nodes, transparent nodes,
lines, and render-batch proxies (102-107). Thus marks on a door are hidden with
the original door at detachment and are not cloned into its debris. This is an
intentional source result, not missing debris decoration.

## Finding 1: prepared native materials are stale at explosion

`transport_vehicle_debris.gd` duplicates each active material while configuring
the prepared body (249-258), which can occur long before any damage. Launch only
moves that already prepared visual and hides the source (193-205). It has no
post-burn material snapshot.

The dirty refresh candidate does not close this gap. It captures the private
material objects at configure, checks that their identities did not change, and
installs those same objects on every replacement geometry. Source material
colour, roughness, overrides, and material replacement are not copied or
revision-checked. A geometry refresh after the chassis burn would therefore
still launch an unburned prepared part.

This is a future integration blocker for visual fidelity, not an adopted runtime
regression: full debris rendering is not wired. Do not claim source-equivalent
debris until an explosion-frame material receipt is implemented and tested.

## Finding 2: mark reparenting conflicts with the frozen hierarchy guards

The native preparation and launch contracts treat every `Node3D` descendant as
structural state. `_descendant_node_count()` counts all descendants (288-293),
and launch rejects any count or visibility change (169-176). A source-equivalent
mark reparented below a door after configure adds a descendant and makes launch
fail with `hierarchy_changed`.

Pre-parenting the hidden mark pool below an assembly does not solve it:
`_copy_subtree()` rejects an invisible child as `assembly_invisible` before it
can skip the child (249-272). A visible transparent child is omitted from the
private copy by `_opaque_mesh()`, but remains in the saved state/count, so later
pool visibility or parent changes still invalidate launch. The dirty refresh
candidate inherits these guards and also pairs the source/copy hierarchy with a
filter that does not define mark identity.

## Required Root/transport seam

Root owns damage/explosion ordering, source material mutation, mark pool
lifetime, and the authoritative damage visual revision. Transport owns private
prepared resources and the launch transaction. Their integration needs this
bounded contract:

1. Keep pooled damage marks outside every detachable assembly subtree. Store the
   target assembly and exact local pose separately, or render through a sibling
   damage-effects root. At launch, hiding the source assembly must hide/remove
   its associated marks without inserting them in the debris clone.
2. If mark nodes must temporarily be descendants, introduce one explicit marker
   identity/tag and apply the same exclusion predicate to geometry discovery,
   `_copy_subtree()`, saved states, descendant counting, refresh pairing, and
   launch validation. The predicate must exclude marks before the invisible-node
   error. Generic transparency alone is insufficient because transparency is a
   material property that can change.
3. Add an atomic private-visual refresh before launch. Root first applies the
   source burn, then asks transport to stage all copied surface materials from
   the effective render-source material, then commits a monotonically advancing
   visual revision. No private material or revision may change if any source,
   surface layout, material, or prepared target is stale/invalid.
4. Launch must require the committed visual revision expected by Root. Committed
   private materials must be independent copies so source reset cannot recolour
   settled debris. Shared source materials must update every prepared binding,
   including bindings not listed as geometry-dirty.
5. Preserve the source explosion order: char source materials, run the explosion
   callback, hide glass, snapshot/commit debris visuals, then launch/hide the
   detachable originals. If the callback may mutate materials, its completion
   is part of the receipt boundary.
6. Reset must either retain a deterministic charred prepared snapshot for an
   identical later explosion or dispose/reconfigure and obtain a new visual
   receipt. It must never silently reuse a private snapshot from a different
   material revision.

## Acceptance proof for the future seam

A small headless scene can prove the contract without a GPU window:

- configure an opaque two-surface assembly plus an external hidden mark pool;
- mutate shared source colour/roughness after configure, attach/show a mark via
  the external association, and commit one visual revision;
- launch and assert that every private surface has the post-callback burn values,
  owns a distinct material resource, and contains no mark node;
- reset source materials and assert that launched/private material values do not
  change;
- inject a stale source material, missing surface, changed prepared material,
  duplicate/shared binding, and stale revision, and assert fully atomic failure;
- show/recycle/reparent all 32 marks before launch and prove that the structural
  receipt and launch remain valid while a real structural child change fails.

Until that proof passes, the frozen physical debris and dirty geometry refresh
remain useful CPU/physics components with an explicit unresolved visual seam.
