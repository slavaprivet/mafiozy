# Transport external damage mark pool — frozen handoff

Дата: 27 сентября 2026. Статус: **frozen bounded runtime component**.

Компонент создаёт один внешний sibling-root и 32 `MeshInstance3D` на машину.
Узлы следов не становятся детьми дверей, крышек или других отделяемых сборок.
Пул переиспользует две приватные mesh/material пары из frozen geometry factory;
попадание не создаёт новых Resource и не удаляет контент по TTL.

## Frozen files

- `godot/mafiozi_walk/scripts/transport/transport_damage_mark_pool.gd` —
  `b8b095037f80867f8ec168b75d8a76e0458b1b32b750d9e5e06bb3cc6cc7af0b`
- `godot/mafiozi_walk/scripts/tests/test_transport_damage_mark_pool.gd` —
  `06f6d01eca1e24b5fd0bd2e7105efa26f7ac5ba9fb930a8dcb103ddb6fa58a02`
- `godot/mafiozi_walk/scripts/tests/test_transport_damage_mark_pool_debris_seam.gd` —
  `43aa1f2830c06d3a25f0db578f6cc255225e93da9f4d96f06927dda95ea1ee4e`

Frozen runtime dependencies:

- mark geometry factory `314c6d0483b67b600025f96d3194c8ec334532ab2ce73f9fbecd93f0ada72461`
- required geometry JSON `d05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0`
- mark planner `bac706d5449155814667bf7677c7ae5364b8b95d10cf364d3104799c25d6b42c`
- raw pose composer `6e8032efe2612e4d70bdad1208a15d633d3b292b903e6705648e935e8d03e5b2`
- physical debris component used by the seam test
  `1cf791ea4890c844b8c1072cdccca647b3b8255cec718afa7e96f80b9c2bba8f`

Root export must explicitly include
`res://data/transport/damage_mark_geometry.json`.

## Public API

```gdscript
var pool := TransportDamageMarkPool.new()
pool.configure(vehicle_root, external_parent, target_bindings, generation)
pool.commit(target_mesh, source_id, planner_receipt, generation)
pool.reconcile_targets(generation)
pool.reset(new_generation)
pool.snapshot()
pool.get_slot_node(slot) # inspection/integration only
pool.dispose()
```

`configure` requires `external_parent == vehicle_root.get_parent()` and a bounded
map of at most 4096 unique `source_id -> actual MeshInstance3D` bindings. It
prepares resources and creates all 32 nodes. The created effects root is a sibling
of `vehicle_root`, outside every detachable assembly.

`commit` accepts a receipt from the frozen planner in the target mesh's exact
local frame. It verifies generation, cursor transition, physical slot type,
binding identity, target ancestry/visibility, pose, root invertibility and slot
resource identity before mutation. It assigns a `Transform3D` directly; it never
decomposes or normalizes the raw quaternion/shear. Cursor advances last.

`reconcile_targets` is an explicit bounded 32-slot hook. For every active valid
target it recomputes:

```text
effects_root.global_transform.affine_inverse()
  * target.global_transform
  * stored_raw_local_pose
```

All transforms are staged and validated before node mutations. Invalid, hidden,
freed or reparented targets hide every associated mark without deleting it.

## Required host order

1. Configure once during vehicle preparation/load.
2. Build the source planner receipt from the current pool cursor.
3. Commit only after the authoritative hit/contact path accepts the event.
4. Call `reconcile_targets()` whenever vehicle/target transforms or visibility
   change.
5. On structural detachment, call `reconcile_targets()` in the same frame after
   the source becomes hidden/reparented and before presenting the launched body.
6. Call monotonic `reset(new_generation)` for a new vehicle lifetime; call
   `dispose()` when ownership ends.

The binding map and planner receipt validation are integrity checks, not proof of
authoritative damage. The host remains responsible for event authority, source
IDs, raycasts, contact reprojection, HP and damage rules.

## Integrity and ownership

- Prepared meshes/materials are private pool resources. External in-place
  resource changes trip connected `Resource.changed` fences and make the pool
  fail closed. Mesh replacement, surface material replacement,
  `material_override`, overlay, queued/free slot nodes and hidden effects root
  also fail closed.
- The signal fence covers mutations that emit `Resource.changed`. A same-ID
  private-resource mutation that bypasses this signal is outside the proved
  contract; callers must treat all prepared resources as immutable. The pool
  deliberately does not deep-hash 32 rendered resources on every update.
- `dispose()` disconnects all four resource signals before clearing ownership;
  externally retained resources cannot retain or call the disposed helper.
- `get_slot_node()` and returned node/root references are for integration and
  inspection. Their transforms and visibility may be rewritten by reconciliation;
  resource or hierarchy mutation is unsupported.
- `snapshot().visible` counts local `node.visible` flags. It is a logical pool
  count, not a substitute for renderer `is_visible_in_tree()` or GPU evidence.
- There is no `_process`, TTL, per-hit resource allocation, HP, RNG, raycast or
  hidden content removal.

## Verification

Commands:

```powershell
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_damage_mark_pool.gd -TimeoutSeconds 60
tools/godot/run_transport_test.ps1 -Resource res://scripts/tests/test_transport_damage_mark_pool_debris_seam.gd -TimeoutSeconds 60
```

Pool test:

- author: **37/37 PASS**
- parent: **37/37 PASS**
- independent reviewer: **37/37 PASS**

Physical seam test with frozen debris:

- author: **14/14 PASS**
- parent: **14/14 PASS**
- independent reviewer: **14/14 PASS**

The seam confirms that a mark remains external, the original source hides on
launch, the mark hides after reconciliation, and the prepared rigid body contains
only its private visual and collision children.

Qualified sequential parent measurements, taken after the independent run ended:

- configure, including JSON/resources/32 nodes: **2.326 ms/car**
- 1000 planner+commit operations: **75.193 ms = 75.193 µs/event**
- 1000 full 32-slot reconciliations: **123.991 ms = 123.991 µs/reconcile**

The earlier 131.309 µs reconciliation result is discarded because its CPU window
could overlap another run. These are isolated headless CPU measurements, not FPS,
GPU, LIVE or full-scene acceptance.

The inherited exact Three `polygonOffset` limitation remains unresolved and needs
later GPU/LIVE visual validation. This component makes no full-render claim.
