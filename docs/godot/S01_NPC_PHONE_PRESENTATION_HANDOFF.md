# NPC phone presentation — implementation, integration pending

Artist21 owns the new phone files only. Root21 owns resident placement, main,
physics/locomotion, event production, authority, export and LIVE testing.

`scripts/npc_visual/npc_phone_state.gd` is a main-thread RefCounted presentation
adapter. `bind(identity, admission_guard)` binds session_id, raw resident_N
actor_id, npc_resident_N bridge_id, life_generation and accepted source receipt
SHA256 once. The rejected historical384f receipt is denied. A well-formed SHA
is not proof of authority: the external guard must verify the actual current
accepted session/event/life and physical placement against the root owner.

`update(frame, delta, render_time)` requires those same identity fields, a
source-owned event_id, monotonic integer source_frame, finite nonnegative
source_now_ms, explicit Boolean visible/phone_blocked and raw source snapshot.
Raw id must match and `_npcInitialPlacementPending` must explicitly be false.
Admission is checked before and after consumption. Duplicate source frames are
idempotent; conflicting/stale frames and malformed data fail closed and hide
the phone. No IDs, reports, police, HP, deaths or source clocks are generated.

The raw source projection requires actual snitching/calling state with a live
deadline or a separate `_corpsePhoneCall.until` EMS deadline. Dead source actors
hide immediately. The caller must supply the original actor priority projection:
medical crawl, locked/fall, deep water, extraction, invisible actor, cowering,
surrendering or escaping hide; weapon, vehicle binding or cash offering block.
It must not derive a new death from low HP in this presentation adapter.

Output `presentation` is visible/phase/phase_time, source entry/raise/left
weights and chest/head additive rotation intents. Draw<.28s, raise<.78s,
hold, stow<.56s; delta clamps[0,.1]. A resumed call restarts draw. Render time
only drives the source gesture sinusoid; advancing presentation does not
advance report deadlines or manufacture an ACK. Weights are applied only while
visible, after the existing base pose by a single rig writer.

The source geometry exporter/data and `npc_phone_mesh.gd` pool are separate:
lease a private hidden node, bind it to an actual current rig hand/socket,
release on invisibility/identity loss/unload. Native reach-palm IK, actual
animated receiver-to-ear contact and root scene binding are still integration
gates. Merely attaching a phone to an idle hand does not establish pose fidelity.

The original source phone is geometry-only and unlit. Native RGBA8 vertex
palette quantization and tone mapping remain explicit visual fidelity limits;
CPU geometry tests do not establish GPU pixels or loaded-scene FPS.

Author actual headless state tests:65 checks PASS. Original source oracle:
190 checks PASS,9 scenarios, actual original createNpcPhoneVisual with pinned
THREE/dummy rig; source module ae866463e4ab393dd39243d68cbab7ddd7f18172a1b2c4c5e2d93cede3232997.
State frozen SHA61db2ce517b5423415a195d5f7cd01189dd2d85e993073392d2d46ea0b996f75.
Independent actual headless387PASS includes47 original source timed traces
and5 world deadline/death projections. Review is preserved in
`outputs/astra21_npc_phone_state_review/REVIEW.md` SHA
7c6469182c46e73a95d978a49db099fb62c7577b52baaec8a47ebcd720daf7f2.
Three-actor state update CPU p50/p95 .081/.101ms with plain guard, .087/.127ms
with representative identity guard (200 warmup/2000 samples); max .856ms
is retained. Input construction outside timing; deep copies/two guards inside.
These figures exclude physics/LOS/IK/mesh/reporting and do not establish FPS.
Mesh frozen SHA51eaecf9be06ae7e829b0a4f9c450dc61f2817575cbd97879d13cd5f036b37fb,
data SHAa8ba2f665f2a91645ee010a3d05cc4290d513a8a9e84fe0cd32f7b9e9dce4324.
Exact API/source/export/author2604 checks are documented in
`outputs/astra21_npc_phone_mesh/HANDOFF.md`. Final independent2705 geometry and
lifecycle checks plus11 atomic disposal/ownership checks PASS. All16 native
headless processes, including14 former diagnostic scenarios, now exit0 with
empty stderr. Owned render bindings are cleared after complete unknown-child
preflight; current surface count bounds override-slot cleanup. Retained foreign
mesh/material resources remain unchanged. Former dummy-renderer diagnostic,
freed-node, cross-lease override and intermediate mesh-null cleanup failures
are preserved as historical evidence, superseded by the exact final snapshot.
Final review: `outputs/astra21_npc_phone_dispose_review/REVIEW.md`, SHA
f0a68623f044098de14b0d51adcced1ae0e595923668eb742f6d9ec0e25f7440.
Pool acquire/release CPU p50/p95 .079/.101ms (20warm/200pairs; max.341ms), not FPS.
All native state fixtures are synthetic: no authenticated session, real phone
call, police dispatch, gameplay behavior, GPU or LIVE/FPS claim.

An actual gameplay reaction additionally requires source-owned perception/LOS,
continued session RNG, threat event, retreat intent through the resident mover,
source interruption/deadline policy and the correct existing report transport.
The source witness/EMS audit preserves these dependencies in
`outputs/astra21_npc_phone_source_audit/PHONE_SOURCE_HANDOFF.md`.

## Placement gate found during integration

Root's actual main checks found the three unchanged e926 initial centers on
road surfaces, which the ordinary source waypoint policy rejects. They remain
pending. Presentation binding cannot release that gate or clear source pending
flags. The current initial-placement evidence is
`outputs/astra21_npc_initial_placement_context/REVIEW.md`: exact288 ordinary rows
and original placement code, but not the complete post-startup pools/provider.
All skipped non-dead actors still obstruct source radial placement. Missing
named NPC, city patrol/prison staff, server pool/registration phase and dynamic
geometry must not be replaced by a three-row context or invented empty arrays.
That source reconstruction is a separate active dependency of the root host.
