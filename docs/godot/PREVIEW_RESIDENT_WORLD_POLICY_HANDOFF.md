# Ordinary resident source policy and support

27 September 2026. New production file `scripts/npc_visual/preview_resident_world_policy.gd` supplies the two callbacks consumed by `PreviewResidentHost`. Only this module, its independent test and this handoff were changed in this task. Main/population/host/provider/packets remain owned by their respective authors.

**Actual corrected candidates are still pending.** Their source birth cells `(r9.5,c76.5)`, `(r4.5,c106.5)`, `(r12.5,c104.5)` all project to current native tile 0 / roadMask 1. The actual floor exists, but source ordinary resident navigation excludes roads. All three therefore receive false admission / NAN support. The earlier resident-host movement test used an explicitly permissive TEST source gate: it proves physical engine motion, not permission to place these pending residents on roads. Do not promote that test result to production placement. Root has identified the real source initial-placement resolver as the next dependency; its full-roster `.55` spacing context is required.

## Exact caller API

```gdscript
configure(scene, packet_rows: Array, owners: Dictionary,
          trust: Dictionary, access: Dictionary) -> Dictionary
callbacks() -> Dictionary # source_admit and support_height Callables
source_admit(point: Vector3, source_id: String, generation: int,
             radius: float, purpose: String) -> bool
support_height(point: Vector3, source_id: String, generation: int) -> float
update_access(version: int, states: Dictionary) -> bool
access_version() -> int
dispose() -> void
```

Trust fields: `accepted:true`, packet SHA `e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096`, block SHA `1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e`, session ID `godot-preview-new-session-20260927-01`. The exact runtime packet bytes are pinned and caller rows must equal them, including original pending coordinates, source identities and looks. Historical `384f...` and unreceipted moved coordinates are refused. `owners` must contain the same three canonical `Queue.Owner(source_id,1)` records used by the resident host. No owner or generation is created here.

Initial `access` is `{version:1,states:{resident_72:"ordinary_outdoor",resident_169:"ordinary_outdoor",resident_252:"ordinary_outdoor"}}`. This state selects the constrained, verified source ordinary outdoor rule below; it does not grant blanket traversal. Missing state, `unknown` and `deny` refuse. Boolean true, unknown IDs and invented roles such as staff refuse configuration/update. Updates require a strictly increasing version. Root must invalidate the NavigationHost with the same version before further physical steps. Dead/mismatched owners are rejected, and an observed dead owner cannot be revived under the same lifetime.

The current real main properties are `_block.surface` and `_origin`; there is no `_source_surface`. Source block bytes and parsed current `_block` must agree. Scene must be the identity root. Policy adds zero scene nodes. `dispose()` clears references and is also connected to scene exit; root should call it explicitly from population teardown.

## Source rules retained

- `native_pedestrian_surface.mjs:nativePedestrianLand`: walkable mask OR numeric policeMask==1 on tile9. Boolean true does not become the numeric police exception.
- `world.html:npcPassable` and `npcWaypointOk`: the native resolver's land is usable, road is refused for ordinary residents. Water is always refused by this dry-only slice, independently of player traversal admission. In particular **main's player `_jump_surface_cells` includes road/water and must not be used as this policy**.
- `_npcBodyPassable`: centre and four square corners at `.18 source cells = .738 m`. Shrinking the requested radius to the navigation capsule radius .36 is rejected.
- Source row/column world limits and the accepted half-open crop are enforced. The immutable known crop r[0,31),c[76,107) is disjoint from source arena c[61,71], prison r>=55.65 including margin, lair r>=100, and pit corridor r>=156. This finite-crop proof is not a general port of those distant systems.
- Source building exterior envelopes remain excluded, indexed by their overlapping source cells. The exported method explicitly subtracts authored public-approach exterior corridors; these gaps remain intact. Opening a native door does not delete the source envelope or grant interior visitation. This policy has no service/staff/private permission override. An actual printshop publicInside probe is refused. A future authoritative visit package needs its own admitted extension, not an `allow=true` switch.
- This is the known native outdoor branch: legacy beach-only restrictions do not replace source native land semantics. No source agenda, vehicle, health or combat decisions are synthesized.

## Support and dynamic geometry

Support uses the source palette height as its reference and casts only from Y+.30 to Y-.30 in the existing physics world, collision mask 1. It does not scan down from the sky or accept an unrelated roof. At configure, the exact 169 current main ground strips are matched against source grid runs, positions and Box shapes; duplicate source floor identities fail. A support hit must match one of those admitted RIDs, current parent/transform/shape/size/enabled state, upward normal>=.70 and source height within .0001 m. Removed/moved/replaced floors and unknown platforms return **NAN**, never zero.

No support result is memoized. A low temporary physical platform at source height+.20 is rejected; removing it restores the real ground query immediately. Areas cannot fabricate a floor, and water is denied before physics. The resident/navigation host separately proves current square clearance, ceiling and swept body movement; this policy does not replace those checks.

Source grid, exterior envelopes and floor identity are a static lease for this accepted block. Dispose/reconfigure before changing topology or accepted static geometry. Door bodies and other live physics remain fresh in the resident/navigation collision checks. Access snapshots are explicitly versioned and do not require a geometry rebuild.

## Verification

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_preview_resident_world_policy.gd
```

Godot 4.7.2, current real main: **44 checks PASS**. Includes accepted source hashes/rows; owner/generation/role negatives; all three original road cells pending; current water; square-corner refusal with clear centre; crop/nonfinite checks; actual printshop interior refusal; real source support; dynamic low roof, removed and moved floor; duplicate floor; access revocation/staleness; owner death; disposal. No NPC is born or relocated by this test.

Positive **point probes only**, not replacements for the pending residents: actual clear dry pair `(-73.8,0,-38.95)` and `(-71.8,0,-38.95)`, two metres apart. Both pass source, support and full test body overlap clearance. These points are not an initial-placement result and must not be copied into the roster.

CPU, 1,000 current-scene queries: source admission p50 **8 us**, p95 **13 us**, max **37 us**; support p50 **18 us**, p95 **37 us**, max **92 us**. Configure **7.918 ms**, once at startup. Five source probes use cached immutable cells and a small spatial index; physics answers remain current. No GPU launched. Full visible-scene performance is not checked by this CPU test.

Next blocking dependency: exact source `NPC_NATIVE_INITIAL_PLACEMENT` search plus full same-session spacing context for all NPC/cop records. Never resolve the road mismatch by granting road access, inventing an arbitrary nearby birth position, or dropping source identity.
