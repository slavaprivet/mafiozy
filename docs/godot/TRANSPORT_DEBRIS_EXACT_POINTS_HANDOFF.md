# Exact hull input duplicates — PERFORMANCE REJECTED

Frozen additive candidate bddce419c0a283e2ae45a9b31f09cf6d5c6a64d6f527b876bebccd5c557ce94e;
test83a5a3cd… .147author+147parent actualGodot PASS. Baseline dirtyrefresh d2a44539
and physical debris1cf791ea unchanged. Exact files in accompanying MANIFEST.

Removes only exact Dictionary Vector3-equal repeats from transformed hull input,
preserving first-occurrence order. No rounding/epsilon/native clean/simplification.
Same mathematical point set and support; full source/private visual mesh retained.
Tests compare exact deduplicated arrays per dirty mesh, support/current maxima,
body/shape/material identities, lifecycle rejection and actual collision/fall/
sleep301frames. No HP/RNG/authority/content deletion.

Actual strong source impact:2assemblies,14dirty meshes,26hulls,67239sourcevertices
become11367exact hull points,55872duplicates removed. Refresh itself still costly.
Author sequential baseline27.893ms/candidate25.864ms, smallpart p95sum2.569->2.718ms.
Independent parent fresh strictly sequential pair (each process joined before next):
baseline23.669ms/candidate26.349ms (+11.3% slower), smallpart p95sum2.388->3.980ms.
Initial overlapping parent pair was discarded for performance comparison.
Only one qualified parent pair; not robuststatisticalp95/fullsceneFPS. Correctness
PASS does not establish performance. Strong deformation35.003/36.628ms separately
excluded from refresh values; no normals/upload/frame/combined pool claim.

Status PERFORMANCE REJECTED / DO NOT ADOPT. Dictionary filtering savings do not
reliably outweigh its cost; physical current hull refresh remains unresolved.
API follows dirtyrefresh configure/refresh_geometry/launch/geometry_receipt; new
result hull_points/duplicates_removed and receipt point sets are diagnostic.
No Workers/main/GPU/Git/foreign runtime changes. No optimizer-loop retry planned
without a new justified implementation strategy or native acceleration dependency.
