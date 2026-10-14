# Deferred landmark owner-plan cache — frozen CPU candidate

Separate subclass `landmarks_cached_factory.gd` extends an unmodified SHA-verified copy of the frozen native resource factory. Original production/source/factory files remain unchanged. No browser/GPU/live scene/main/Git operation was performed.

## Why the old preview cost ~1.5 ms

Every bridge pointer preview scanned all 933 source parts, discarded other owners, decoded each matching world matrix twice, repeatedly looked up shared meshes/MultiMeshes, read immutable local AABBs, constructed per-part dictionaries in GDScript, and merged all visible bounds. The island preview similarly processed 741 matching parts. Immutable source frames, resource identity and local bounds do not change during owner movement; only the editor delta and deletion state do.

## What changed

- Build a small owner→part index once after inherited source SHA admission.
- Build each owner's private template only on its first requested plan: source frames, source visibility, detached dependencies, native local AABBs and affected resource keys.
- Warm previews duplicate immutable templates in native C++ and apply only the requested delta/deletion state. No repeated whole-inventory scan, source matrix decoding or native resource/AABB lookup.
- Recompute culling bounds with the **same per-part `delta × source_frame × local_AABB` operations and same ordered merges** as baseline. No enlarged aggregate-box shortcut, vertex omission, changed LOD or culling approximation is used.
- Source/material/raw upload arrays, existing SHA-based mesh sharing, transaction validation, checkpoints and bounded undo/redo are inherited unchanged.
- Changed resource keys still invalidate the affected owner plan. Public returned dictionaries cannot mutate cached source frames. Unrelated owner remains valid when a non-shared bridge-only resource changes. Dispose clears the deferred cache while retaining externally held native resource lifetime.

Two full-length canal seawalls remain detached from movable bridge ownership. All 38 texture and visual/authority gates remain HOLD. Installation still performs no scene mutation or fallback rendering.

## Comparable CPU results

One Godot 4.7.2 headless process, identical 933-part source and 267 shared meshes/22 original MultiMeshes, 120 warmed previews per owner, alternating measurement order; exact returned plans compared after each call.

| Scenario | Baseline p50 / p95 | Candidate p50 / p95 |
| --- | --- | --- |
| Bridge preview | 1,327 / 1,575 μs | 314 / 400 μs |
| Police/correctional island preview | 5,387 / 6,372 μs | 1,469 / 1,967 μs |

Bridge: approximately **4.2× / 3.9×** faster. Island: **3.7× / 3.2×** faster. An earlier comparable run confirmed bridge1425/2083→337/466 and island5647/7230→1608/2309 μs; scheduling varies.

Cold complete resource build 63,733→61,665 μs: effectively unchanged, not a startup-improvement claim. First bridge plan incurs deferred setup: 1,635→1,974 μs; subsequent plans avoid it. First island plan 5,250→1,699 μs. Only two private owner caches are created in the test, not rebuilt during movement. This is resource-plan CPU cost, **not GPU/FPS or full-game frame time**.

## Tests and staging

- Original native suite, with only preload switched to the subclass in the staged test copy: **353,646 checks PASS**. This includes all original submitted attribute/index/instance data, every visible vertex enclosure, shared identity/lifetime, owner metadata and safety checks.
- Independent baseline/candidate suite: **652 checks PASS**. Full dictionary/ordered-part/tight-AABB equality across 40 move/rotation/nonuniform-scale/delete operations for each owner, undo/redo/state parity, resource identities, 240 comparable warm calls, caller mutation protection and changed-resource invalidation.

`stage.mjs --check` is read-only; `--stage` writes only a new `outputs/map_editor_landmarks_perf_candidate` package and refuses changed existing target files or symlinks. Baseline source, native code and candidate files are SHA-locked. Staged tests:

`test_original_suite_optimized.gd`

`test_landmarks_cached_factory.gd`

The callback's external game atomicity remains the trusted owner's responsibility, exactly as documented for the frozen base resource factory. This candidate does not silently unlock or move the real police site.
