# Transport vehicle debris static-settle experiment

Status: **PERFORMANCE PASS / POST-SETTLE INTERACTION HOLD / DO NOT ADOPT**.

Source `vehicle_damage.mjs` stops updating a detached part after it settles and
keeps its real visual assembly in the wreck. This isolated candidate preserves
the frozen provider's ten bodies, 76 exact compound convex shapes, all private
visual Mesh/material resources and collision layers. Only after every launched
body reaches native sleep, `freeze_settled_static()` atomically sets
`freeze_mode = FREEZE_MODE_STATIC` and `freeze = true`.

The method fails before mutation when any body is missing, awake, already
frozen, reparented, has changed collision layers/masks, or has a changed/hidden
private visual. `static_receipt()` detects later tampering. No geometry, shape,
material, transform or content is removed.

## Actual Godot 4.7.2 results

Fresh actual city-hatch headless runs:

| Providers | Bodies / hulls | Sleeping p50 / p95 | Static p50 / p95 | Static memory delta | Settle frame |
|---:|---:|---:|---:|---:|---:|
| 1 | 10 / 76 | 1.520 / 1.626 ms | 0.1395 / 0.167 ms | -57,236 B | 291 |
| 3 | 30 / 228 | 1.030 / 1.724 ms | 0.2335 / 0.366 ms | -167,180 B | 291 |
| 10 | 100 / 760 | 2.765 / 3.976 ms | 0.780 / 1.371 ms | -552,096 B | 301 |

The 1/3/10 suites pass **25/25**, **50/50** and **155/155**. They verify:

- exact ten bodies and 76 hulls per provider;
- all 76/228/760 private Mesh instances remain visible in the tree;
- ray and sphere shape queries still hit static wreck bodies;
- collision layers and masks remain active;
- body transforms remain fixed under an applied impulse;
- reset restores source assemblies and clears static state;
- the same provider can relaunch after reset, settle and freeze again;
- `retire_wreck()` frees all ten bodies and leaves stripped originals hidden.

Awake measurements contained host/process-monitor spikes and are not used for
acceptance. `Performance.MEMORY_STATIC` is Godot heap only. The consistent
negative transition delta suggests dynamic physics state is released, but it is
not attributable Jolt/process/GPU memory.

## Interaction blocker

A sleeping `RigidBody3D` can wake and move when another vehicle or explosion
hits it. A frozen static body cannot; it becomes an immovable collision object.
The test intentionally proves this by applying an impulse and requiring the
transform to remain fixed.

This matches the source renderer's irreversible settled update, but it changes
the existing native physical extension's post-settle response. Ray/shape hits
alone do not prove equivalent interaction. Adoption therefore requires one of:

1. an explicit game-rule decision that settled wreck parts are permanently
   static for the rest of the wreck lifetime; or
2. an authoritative, bounded thaw contract for later vehicle/blast contacts,
   with the real incoming motion transferred before unfreezing and performance
   retested. An approximate proximity wakeup or polling every hull is not
   acceptable.

Until that decision, keep the candidate isolated. No frozen runtime,
orchestrator, production integration, Git, GPU window or LIVE scene changed.

