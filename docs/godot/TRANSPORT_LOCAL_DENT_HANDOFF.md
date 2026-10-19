# Local dent position core — functional, PERFORMANCE REJECTED

Frozen pure buffer provider transport_local_dent.gd SHA
883a4559323649b21315098ae4f6324566e9302bb25a8110a1b8c7dd7c93459e.
Exact files/SHA: TRANSPORT_LOCAL_DENT_MANIFEST.json. Original private dent closure
executed through in-memory module instrumentation; source files unchanged. Three180,
damage e029cb4a… and crash cceffb5b… asserted before fixture generation.
Two byte-identical exports; fixture790b7d5e… .87author/87parent checks PASS;
independent transaction18author+18parent PASS.

Retains Float32 base=current-old_dent_offset rebasing, separately rounded position
and offset writes, binary64 radial arithmetic, repeated bullet/collision dents,
.18/.40 cumulative caps, external cage edits, geometry replacement clearing offsets
while preserving cap. Full reset clears cap. Source coordinate buffers compare
byte-exact; native -X/-Z replay maps nonzero values exactly, initialized offset ±0
canonicalized only. Unit local normal is an explicit caller contract; zero-normal
source presentation no-op deliberately rejects before stage creation.

API configure(PackedFloat32Array xyz, generation>=1); apply(current_xyz,
PackedFloat64Array local_point, PackedFloat64Array unit_local_normal, damage,
{} for bullet or exact {impactSpeed} for collision, expected_generation).
Successful apply returns positions/base/offset/cap/affected/changed and opaque
stage_token without advancing committed dent state. Only one pending stage;
commit(stage_token) advances state after host success; abort(stage_token) preserves
committed state. Returned arrays are private copies. reset(new_xyz,new_generation,
full_reset=false) requires strictly increasing generation and invalidates tokens;
dispose also invalidates tokens. All rejected operations preserve committed state.
Maximum90000vertices/270000Float32values per provider, finite inputs and outputs.

ROOT SEAM: pure position core only. Host owns exact source subdivision, selecting
actual visible opaque non-wheel hit panel, world-to-local point and inverse-basis
normalized normal, trusted contact/event/vehicle/life authority and cooldown.
Before commit, host MUST verify that it installed the exact staged position bytes,
recomputed source normals/AABB/sphere and advanced actual mesh/resource revision.
Token proves stage identity only; it cannot attest the actual installed geometry.
If any resource step fails, abort and restore old mesh state. Notify deformation
adapter positions changed and invalidate debris/cargo evidence after success.
Multi-surface atomic host publication remains integration work. No HP/RNG/Nodes/
Resources/physics/marks/glass/fire/main/GPU/Git mutations by this component.

PERFORMANCE REJECTED for impact-frame adoption. Parent actual source-prepared
compact_sedan largest panel v0163,25752vertices,8warm+32samples: stage+commit
p50/p9516.969/21.899ms,max25.666ms. Independent repeat14.925/16.374ms,max17.145ms;
concurrent headless contention uncontrolled, neither is fullsceneFPS.
Bounded90000 all-inside synthetic p50/p95109.891/124.659ms,max126.204ms (independent
p95136.332ms). Authored11244vertex v0005~6.4–8.0ms is NOT subdivided impact cost.
18vertex10k fixture~31–33us/apply+commit is NOT actual vehicle performance.
Preparation/normals/bounds/render upload/dirty hull refresh excluded from costs.
No event deferral or geometry reduction adopted. Functional core is not lag-free
destruction or LIVE integration. Combined global WorkerThreadPool strong cage+72
physics stress already47.955–57.761ms (owner receipt VEHICLE_CRASH_COMPONENTS_REVIEW),
so future acceleration must include combined contention qualification.
