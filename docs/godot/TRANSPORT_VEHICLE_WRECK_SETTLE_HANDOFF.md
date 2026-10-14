# Transport vehicle wreck static settlement

Status: **ADDITIVE PROVIDER + ORCHESTRATOR API VERIFIED / ROOT INTEGRATION PENDING**.

Actual source `assets/maps/city_rebuild_v1/vehicle_damage.mjs` SHA-256
`e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`
permanently stops updating each detached part after its settled condition. The
user's requested behavior covers physical flight, fall and persistent wreck
parts; it does not require later reactivation.

`transport_vehicle_wreck_debris.gd` now exposes additive `settle_wreck()`.
It succeeds only after all launched bodies naturally sleep and after the whole
wreck validates atomically. It then sets every body to
`FREEZE_MODE_STATIC`/`freeze=true`. All real private visual meshes, materials,
ten bodies, exact 76 compound convex hulls, collision layers and masks remain.
Nothing is hidden, removed, simplified or merged.

`settled_receipt()` validates the retained static wreck. Existing `reset()`
restores originals and clears settlement so the provider can relaunch.
Existing `retire_wreck()` frees the copies while leaving the stripped originals
hidden. `transport_vehicle_damage_orchestrator.gd` exposes the same operation as
`settle_wreck()` and grants no new event or damage authority.

## Actual Godot 4.7.2 verification

| Providers | Checks | Bodies / hulls | Sleeping p50 / p95 | Static p50 / p95 | Static memory delta | Natural settle |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 25/25 | 10 / 76 | 1.309 / 1.411 ms | 0.145 / 0.170 ms | -57,236 B | 291 frames |
| 3 | 50/50 | 30 / 228 | 0.145 / 1.796 ms* | 0.3265 / 0.490 ms | -167,180 B | 291 frames |
| 10 | 155/155 | 100 / 760 | 2.697 / 5.973 ms | 0.590 / 1.059 ms | -552,096 B | 301 frames |

`*` The physics monitor updates coarsely in isolated headless runs; use the p95
and the 10-provider direction rather than the anomalously low three-provider
sleeping median. Awake samples also contained large host/monitor spikes and are
not acceptance evidence.

The full real-hatch orchestrator regression plus settlement passes **131/131**:
10 assemblies, 76 hulls, 142,948 vertices; all ten parts fall; natural sleep at
frame 290; `settle_wreck()` retains the complete exact wreck; later explicit
retirement still frees all bodies.

Additional receipts prove:

- ray and sphere-shape queries continue to hit the static wreck;
- all 76/228/760 private Mesh instances remain visible in-tree;
- applied impulses cannot move a source-style settled part;
- settlement rejects awake, changed, missing, reparented or already-settled
  bodies without partial mutation;
- reset restores originals, relaunch works, and retire leaves originals hidden.

## Cost and boundaries

The static transition itself allocates no replacement geometry or visual
content. `Performance.MEMORY_STATIC` decreases by roughly 55 KB per provider in
these samples, but this is Godot heap rather than attributable Jolt/process/GPU
memory. Configure remains the existing ~100–120 ms load cost and is not solved
here.

After settlement the wreck is intentionally immovable, matching source's
permanent settled state. It remains a collision/query target. A future game rule
that explicitly requires later debris reactivation needs a separate
authoritative thaw/impulse contract; this API must not approximate one by
proximity polling.

No frozen base provider, Root scene, Git, GPU window or LIVE game was changed.
Root still owns gameplay scheduling of `settle_wreck()` after natural sleep.

