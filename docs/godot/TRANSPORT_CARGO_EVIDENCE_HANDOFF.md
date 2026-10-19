# Actual visual cargo evidence

`scripts/transport/transport_cargo_evidence.gd` supplies the missing physical
evidence for `transport_cargo_admission.gd` without editing visual or player
files. Configure with the actual bound `vehicle_visual` and its configured
`vehicle_compartments`; only the exact companion visual SHA/lid binding is
accepted. Requires the visual root in the scene before `sample()`.

`configure(visual, compartments)` caches actual lid mesh vertices once and
finds cargo floor candidates by the exact source name predicate, excluding
the lid subtree. `sample()` transforms the cached vertices from each current
animated mesh into native vehicle-local coordinates and returns actual cargo
bounds, construction-time floor proof, lid AABB/visibility, amount, mode and visual SHA.
Floor ancestry visibility is checked within the visual during configuration;
later rendering/pooling visibility does not revoke source floor proof.
Actual GLTFDocument output has an identity AuxScene above the RY(pi) wrapper;
relative mesh transforms already include that basis conversion. A different
compartments instance rejects. Rear-lid positive-Z tests guard double conversion.
`dispose()` and `invalidate_geometry()`
remove the binding; subsequent samples return empty.

Call only for an actual placement attempt or invalidated geometry/pose revision.
It does no scene mutation, panel stepping, floor creation, inventory transfer,
item birth, source clock or vehicle authority write. Root supplies actor/item
lifetime and storage receipt separately. For detached/damaged panels, the
damage owner remains authoritative; this provider does not infer detachment.

Cached mesh replacement rejects automatically. An in-place vertex deformation
must call `invalidate_geometry()` before mutation, then configure a fresh
provider against settled current geometry. Reading a cached healthy lid after
an unreported in-place damage edit is unsupported. Bind provider lifetime to
the actual visual instance; do not reuse it across replacement vehicles.

Actual Godot4.7.2:156/156 checks,13 real imported profiles. Covers configuration,
actual floor, closed/open admission through source geometry helper, moving and
rolled local bounds, source construction floor proof, wrong controller binding,
native rear-lid frame and invalidated binding. Sample-only isolated CPU around
0.5-0.8ms median/1.2-1.5ms maximum across13 profiles; full-scene FPS unmeasured.
No GPU, Git, main/player/visual/physics edits. Native transport rev6 unchanged.
