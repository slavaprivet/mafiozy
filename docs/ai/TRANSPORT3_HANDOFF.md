## 30 September — direct user route and vehicle damage experiment

New parking-access background preloader **READY FOR ROOT SEAM / NOT LIVE**: `scripts/transport/transport_parking_access_preloader.gd` SHA-256 `c5c35f52bb2f0127dbf1a47fb830ef1847474ec6e042c893bcc7bc191dc3d5f4`, test `scripts/tests/test_transport_parking_access_preloader.gd` SHA-256 `b3bbe35d2e0d30dc71f65b12728c57948ad2ed936feb274424679940288f3fa8`. It invokes the existing exact source/ID/collision admission loader in a low-priority Godot Thread, returns the validated immutable `Parking` object only after `poll()` joins; missing file fails closed, concurrent `begin()` is BUSY, `close()` explicitly joins an unfinished worker. The already-loaded catalog must remain unchanged until READY/ERROR, and the caller must close before dropping an unfinished preloader. Actual Godot4.7.2 headless **10/10 PASS** with all 39 lots/59 bays/57 sign colliders. Main-thread `begin` 81µs, max `poll` 16µs, READY after27.802ms/8 polls in isolated run; total worker CPU and loaded-scene contention are not reduced or proven. Root integration can call `begin` during scene setup and collect READY on later frames, without placing the previous 25–30ms synchronous parse/validation on a gameplay frame. No root runtime wiring, GPU, full-city FPS, or user-visible adoption claim.

Follow-up admission hardening supersedes the provider/parking-loader pins below: `scripts/transport/transport_access_provider.gd` SHA `d0386f508fbfedf5c9a73035ff7716d26ca02e4160bd0c7bc8d62291c1db887b` resets reused shape-query motion before the start-overlap test; actual physics15/15 and runtime25/25 PASS, 500 isolated supported exit probes16.549ms. `scripts/transport/transport_parking_access.gd` SHA `d8199c2040c5a3df586bee24472b05cc42c07af375a06e9d5918a89984a1ac53`, test `scripts/tests/test_transport_parking_access.gd` SHA `a9aa098de8be367a7c18961774a260ae3e16ed5efa3429e63261985604c57cc2` now require the full 57 source sign/collider pairs and exactly 39 parking/18 yield sign kinds; a paired omission is rejected. Godot4.7.2 parking31/31 and real sign physics6/6 PASS, isolated load30.122ms under concurrent host activity. Data SHA and external source authority remain unchanged. No LIVE/full-city acceptance or foreign runtime/Git/GPU edit.

Scoped boarding/exit physics allocation fix in existing `scripts/transport/transport_access_provider.gd` SHA-256 `f337118f0c2e1dcf7f89ccd2ed14d9cda424e54d81b6a59147627a0a25175e15`, test `scripts/tests/test_transport_access_physics.gd` SHA-256 `a96dfd72b67cdebc999cba546c2ba75458da8d0b6d72d2fcd257b20974f36d3a`. A provider now reuses its private capsule and shape-query objects across same-size main-thread probes; dimension changes create a fresh shape with valid radius/height assignment, and nonfinite dimensions fail closed. Every original real PhysicsDirectSpaceState3D wall/overlap/floor/water/Area test plus new small/large/nonfinite tests passed Godot4.7.2 **15/15**; actual `test_transport_runtime.gd` **25/25** passed. Identical isolated 500 supported exit probes were 22.123ms before, 17.362–18.447ms after across runs, a directional reduction only; root full-city/LIVE frame-time and memory remain unmeasured. Caching ray-query objects showed no benefit and was reverted. No source collision rule, radius, support probe count, or foreign runtime changed.

Parking signs/collision geometry package **SOURCE-EXACT DATA + ISOLATED PHYSICS / NOT LIVE**: exporter `tools/godot/export_transport_descriptors.mjs` SHA-256 `4cf42867544a9126d33e412d80e217c0ecd09cd931687940bb2033de1196b22e`, sidecar `godot/mafiozi_walk/data/transport/parking_access.v1.json` SHA-256 `fabdc783fa84ba4e97885741bc13ddf0ef100b16cb2229c23e595d9668c452f9`, loader `scripts/transport/transport_parking_access.gd` SHA-256 `b8025d2c61717b00874be11332b44d75b5c459137c0af7c1820c1e14762d18cd`, route test `scripts/tests/test_transport_parking_access.gd` SHA-256 `b3cb8cf5ca9f01b6cbefa6951786ced51179148cb09abb06fa10dff0ad4515cf`, physical sign test `scripts/tests/test_transport_parking_sign_collision.gd` SHA-256 `aa895c6d38addae4b3c54c3a66b9243fe8905d325c5d3caf8707c60633f2af27`. Export retains all 57 source parking/yield signs and their 57 eight-vertex grid polygons (456 contour points), 0–2.9m height and 0.15m footprint, with original IDs and source 4.1m/grid conversion. Independent Node comparison to actual 2026-09-19 browser worker snapshot matched all source sign/collider objects exactly. Godot4.7.2 headless route/identity/mutation **30/30 PASS**, real static ConvexPolygonShape3D physics **6/6 PASS**; 57 collision bodies built in isolated test ~3.7ms, source sign top ray 2.899716m within native physics precision, space outside 0.15m octagon remains open. Full loader ~25.4ms and +4.76MB static memory, so load/shape creation must happen before gameplay frame. Existing descriptor and bootstrap factory hashes remain byte-identical `99d328bc...` / `482aca7e...`. API `sign(id)` and `sign_colliders_native()` exposes source geometry for host; root world collision, visible signs, occupancy and road priority remain unwired. No duplicate LIVE collision or FPS claim, no foreign runtime/Git/GPU/HQ action. This supersedes all older parking-access loader/export/test pins below.

Parking-access coverage admission follow-up: `godot/mafiozi_walk/scripts/transport/transport_parking_access.gd` SHA-256 `6aff98ae9ece914f6eccbd85847cc2800bea60526679caa82cfb103dc96a8a7b`, test `godot/mafiozi_walk/scripts/tests/test_transport_parking_access.gd` SHA-256 `02b3d13e87a34ae4afca69727ce9e4e1ab938b9c225cad0e7245d9eefd83bd5e` supersede loader/test pins in the next paragraph. Actual Godot4.7.2 headless **25/25 PASS**. The loader now rejects duplicate/foreign served-building coverage, route-distance mismatch, missing walking-route ownership, or changed crosswalk/driveway priority rules before publishing any parking data. Five new mutation cases cover those failures. Isolated load18.328ms, static memory +4,467,308 bytes, 10k surface probes6.450ms; still preload outside gameplay frame. This remains LOAD ONLY / NOT LIVE; no occupancy/collision/AI authority or GPU/full-city claim.

New source parking-access data package **LOAD ONLY / NOT LIVE**: exporter `tools/godot/export_transport_descriptors.mjs` SHA-256 `24bcf8b7d02ec8fdb1392c1609f5b718d454ddc2480b08f4b93d2e03f54f05e5`, sidecar `godot/mafiozi_walk/data/transport/parking_access.v1.json` SHA-256 `7ec07916dd8dd2b2e0fc3b838b1de8ab3789b881efaec10e76c2188305d5e7b6`, loader `godot/mafiozi_walk/scripts/transport/transport_parking_access.gd` SHA-256 `827383bb1a5e58746dff4dacf8f2cc5596dd230e17dc76b284e1aee8bf0d5eaa`, test `godot/mafiozi_walk/scripts/tests/test_transport_parking_access.gd` SHA-256 `a863991fb31e92406f94927dc8c2ef2781f4de98cdcdd93ce2ce4ce29eda7982`. The exporter derives from tracked Walk parking plan and preserved existing descriptor SHA `99d328bc...` and bootstrap SHA `482aca7e...` byte-for-byte. Sidecar has all existing 39 lot IDs/59 bay IDs, 3,129 source entry points in original paths, 46 entrance walks and 78 surface rectangles, plus source SHA pins. Independent Node comparison with 2026-09-19 actual-browser worker snapshot matched every lot ID/bay ID/path/rect and all walking/surface arrays. Actual Godot4.7.2 loader **20/20 PASS**, including all 3,129 native yaw/position conversions and eight malformed receipt/ID/geometry rejects; isolated load 17–27ms, static memory +4.47MB, 10,000 surface probes ~6.4ms total. The one-time load is too large for a gameplay frame; preload outside LIVE frame before adoption. No occupancy, road-yield AI, physical collision/fit or LIVE/full-scene FPS claim. Root/runtime/Git/GPU/HQ untouched.

Parking descriptor admission tightened in own transport scope: `godot/mafiozi_walk/scripts/transport/transport_descriptor_catalog.gd` SHA-256 `9a6923c3eeab011946667449b8ccad1085651c0e8ee4ec86fff62fb971868f52`, new `godot/mafiozi_walk/scripts/tests/test_transport_parking_catalog_contract.gd` SHA-256 `f30e54c6805763d2cd145cc5712768dbb1f57b49d94f0c9ef0ebf936f98d0f5b`. Canonical accepted `vehicle_descriptors.v1.json` already exports **39 lots / 59 bays** (not historical61; current source snapshot 2026-09-19 agrees). Catalog now checks v1 native4.1 scale, exact 39/59 count, lot/building/bay ID relationship and consistent hospital/residential kind counts, finite pose/dimensions, positive slot size and source yield rule; malformed data fails before exposing any parking entry. Actual Godot4.7.2 headless existing descriptor17/17 + new mutation12/12 PASS; ten full loads ~32–39ms isolated total, not frame/FPS. This validates only static exported bays. Full lot entry routes, 59-bay occupancy, physical fit/collision and actual scene acceptance remain host-owned/unwired. No source content removal, foreign runtime/Git/GPU/HQ edits.

Further exact-visual-ray indexed experiment **HOLD / NOT ADOPTED**: `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_visual_triangle_ray_indexed.gd` SHA-256 `b38f0d273b386ab63bcd2eb68aac0cc8e3d2882504209fb3263119ca318e9c78`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_visual_triangle_ray_indexed.gd` SHA-256 `99a918b3ab46738e856fb0ef18e82d6a2d21786f5798a2d1424099c6adcb4d52`. Author/parent actual Godot4.7.2 headless **27/27 PASS**; real hatch 268 meshes/122,194 source visual triangles, 60 transformed radial rays identical to frozen revised native candidate by object/surface/triangle/point/normal/distance. Private copied vertices/indices and 32-triangle AABB chunks are prepared in 936 bounded steps, with explicit trusted-host invalidate-before-write and fail-closed until rebuilt. Parent total prewarm60.561ms spread over steps, step p95 .154ms/max .404ms (isolated), indexed fallback p50/p95 2.831/3.515ms versus revised4.151/5.441ms; panel3.155/3.814ms versus revised4.631/5.823ms; static memory +8,644,968 bytes/car. A single real mesh edit rebuild .297ms; source-distance changed 2.04852→2.10102m. **Still too expensive to enable:** 3–4ms per contact, 8.6MB/car, and 936 steps need a loaded-scene schedule; no independent Three.js collision oracle or LIVE/full-city budget. No triangle/content/collision deletion, root runtime/Git/GPU untouched.

Revision-bound visual-triangle ray optimization remains **HOLD / NOT ADOPTED**: `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_visual_triangle_ray_revised.gd` SHA-256 `8fe4013861bfd5aa381ab38065877fd249820ac7e6e7d501d155db830b3570db`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_visual_triangle_ray_revised.gd` SHA-256 `afe739b6d91504d6c7f9e87b4c41d6ab911cabcd18448ee1f9015d0b7d2638b7`. Author/parent actual Godot4.7.2 headless **25/25 PASS**: real hatch268 meshes/122,194 triangles, correct same-ArrayMesh in-place edit changes ray distance 2.14154→2.19154m, replacement/hidden/material/forged revision/two-car isolation. Host must call `begin_geometry_change` *before* any mesh write, blocking queries, then `finish_geometry_change` to build private current vertex/index snapshots; no physics hull or stale AABB substitution. Parent full prewarm38.001ms and one-mesh rebuild.186ms, cached fallback3.498ms and contact4.262ms per ray in isolated hatch; author prewarm44.075ms and query3.897/4.385ms. Initial 38–44ms prewarm spike and ~4ms contact are still too costly to declare safe in the loaded game; no incremental prewarm, complete source material/mark host attestation, loaded-scene/LIVE budget or source triangulation tie proof. Unannounced same-resource vertex mutation cannot be cheaply detected, so explicit trusted-host invalidation is mandatory. Frozen baseline and root runtime untouched.

Visual-triangle ray candidate **HOLD / DO NOT ADOPT**: `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_visual_triangle_ray.gd` SHA-256 `1955a06d918b191e166843124404691afe0b7f29b096837d572e273a9640f305`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_visual_triangle_ray.gd` SHA-256 `056ab55e7a0b8931d5c280616048ef277b7ae7b6c4400e31a3efe8cc37b673d9`. Author/parent actual Godot4.7.2 headless **14/14 PASS**, real hatch + deformed synthetic mesh and mode-specific source filters (fallback recursive then direct visible/nontransparent, contact ancestor/wheel/effects exclusions, source material-array edge). It reads current visual ArrayMesh triangles each call, so no stale deformed bounds, and never substitutes a physics hull. Performance is unacceptable: author hatch fallback/contact ~24.8/21.4ms per ray, parent ~47.1/24.4ms; 4,540 triangles reached in fixture after fresh bounds scan. Source-GLB triangulation/ties and material/mark host attestation also remain unresolved. This candidate is intentionally isolated; there is no integrated contact raycast or LIVE/FPS claim. Never use a stale native mesh AABB to present a fast but incorrect damaged-car ray.

New isolated source collision fallback helper, **NOT WIRED / NOT LIVE**: `godot/mafiozi_walk/scripts/transport/transport_vehicle_collision_fallback.gd` SHA-256 `7c6ced1dc03193dda5d4c67d8911bfce56252ca4837a651f31a9513b00f344db`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_collision_fallback.gd` SHA-256 `60d82998fa52532e6d02be8a10f490ebbad0fb5a95f8a2ed68804965062e886f`. Author and parent Godot4.7.2 headless **23/23 PASS** with actual hatch visual transform; parent 5,000 plan+empty-raycast-resolve cycles63.367ms (~12.7µs each) isolated CPU. `plan()` preserves source `collision(before,after)` bumped/direct-contact branches, speed-loss and reverse sign, nullish travelYaw→yaw→source local rotation.y, full localToWorld(0,.75,0), source +Z normal and origin=center+normal*4, ray direction=-normal and far5; `resolve_raycast()` selects first ordered visible, directly nontransparent hit, else center+normal*2, then returns source contact for the admission gate. Actual recursive geometry raycast is host-owned and was represented by synthetic hits in this test; no damage/HP or full-city/LIVE claim. Host must supply a trustworthy ordered source-equivalent hit list and same-pose transform. Native finite typed motion fields deliberately narrow JS coercion. No foreign runtime/Git/GPU/HQ edit or message.

Later isolated contact-to-damage bridge **CANDIDATE / NOT ADOPTED**: `godot/mafiozi_walk/scripts/transport/candidates/transport_vehicle_contact_bridge.gd` SHA-256 `4ac35830899ea3f150edea4523f468620247c07e3a3f45808a71265f8fef7c3d`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_contact_bridge.gd` SHA-256 `b599c00b5d15a8d8980022ca6ed02f7da523438e31ca26ce03dab0a07ba9395c`. Author and parent actual Godot4.7.2 real-hatch headless **34/34 PASS**: 10 assemblies/76 exact hulls, source .25s contact cooldown, 1000 zero-damage scrapes with no HP/revision change, damaging contacts HP240→239, repeated severe contact floors at HP1 with no crash autoexplosion. API `configure(shared_host_capability,id,generation,gate,orchestrator)`, `advance_clock`, `begin_contact`, `finish_raycast`, `cancel_pending`, `dispose`. Parent real-hatch configure116.526ms; 1000 clock+bridge scrape cycles49.944ms (~49.9µs/receipt), isolated memory 64.95→70.28MB. Host still must execute actual panel raycast then crash→trunk→dent/mark callbacks synchronously and supply trustworthy status/event IDs. A failed orchestrator HP commit after gate cooldown commit is reported as non-atomic `hp_commit_failed`, so this candidate **cannot be adopted** until a host transaction/recovery contract and source callback proof exist. No full-city/LIVE FPS proof; frozen orchestrator unchanged.

New isolated crash-contact admission gate, **NOT WIRED / NOT LIVE**: `godot/mafiozi_walk/scripts/transport/transport_vehicle_contact_admission.gd` SHA-256 `2b5dce94fcf4e2f3f7e4288b144ba6e9fb9560a9e1a4ceb525b0683e130c3971`, test `godot/mafiozi_walk/scripts/tests/test_transport_vehicle_contact_admission.gd` SHA-256 `c9fc22ec8a785d478468f6a3797c94145740bf2e17cad7397f0ddb831fac4ac8`. Source `assets/maps/city_rebuild_v1/vehicle_damage.mjs` SHA-256 `e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92`. Actual Godot 4.7.2 author and parent headless **43/43 PASS**. API `configure(host_capability,id,generation)`, `advance_clock(authoritative_dt_receipt)`, `begin_contact(authoritative_contact_receipt)` returns one-use ticket without changing cooldown, then `finish_raycast(authenticated_raycast_receipt)` commits lastCrash before source crash/trunk/dent callbacks. `cancel_pending()` aborts prior to that source assignment. Exact 0.25s source clock gate; zero-damage slide >=1.5m/s consumes cooldown after completed raycast even when no panel hit and source returns false; collision never autoexplodes. Parent isolated 5,000 full clock/begin/finish receipts 92.593ms (~18.5µs each), 100k pure damage calls 36.366ms. Host must provide same-pose center/status, actual collision raycast and callbacks synchronously. Current damage orchestrator still rejects zero-damage collisions, so there is no combined transaction or full-city/LIVE performance proof. Native boundary requires finite numeric speed fields rather than JavaScript string/boolean coercion. No root/main/Git/GPU/HQ edit or message for this packet under the later direct user instruction to fix locally.

Later clean-profile cache audit (isolated, **NOT ADOPTED**): shared shape candidate `transport_vehicle_debris_clean_profile_pack.gd` SHA `4dd38acbaafa237f767d642b01f573b1b1045bbad6b9534890983efbaad65499`, test `d60fb8365e5386fbd1a2e5b55c7b9603e39018a9f67813613f6875b6f6056284`; private shape candidate `transport_vehicle_debris_clean_profile_private.gd` SHA `07d571398884404ea68cf82be5f8326883627394047b2f0425f5da6b94505e14`, test `9260d678a54b8a6f0b0c2a7f0a2591f6988ca7c486181b668b16da54ebec14d9`. Parent actual Godot 4.7.2 real BodyFactory/yaw/visual replay shared 174/174, private 184/184 PASS. Clean rigid-layout world collision deviation <10µm; nonrigid ancestry and dirty revision fail closed. Shared cache reduced ten-car configure 1.143→.286s (parent), but shared Shape margin/solver properties can mutate after launch without reliable `changed` signal, affecting other active cars; **REJECT**. Private per-car shapes preserve alias isolation, but parent ten-car configure 1.037→.938s (~9.5% gain) still leaves ~88–107ms per car; **HOLD**. Production host also lacks explicit authoritative GLB-SHA/CLEAN-revision receipt. No full-city/GPU proof; frozen provider remains untouched.

Independent immutability diagnostic `test_transport_convex_immutable_hooks.gd` SHA `9b425714f202fc577370c4f085ccd2b107c02ff17ddd0c500ca6851ab7daf0fe`, parent actual Godot 4.7.2 2 diagnostic checks PASS: subclass `_set` intercepts direct assignments but `shape.set("margin", .37)` still mutates native margin, `duplicate(true)` loses seal, and `PhysicsServer3D.shape_set_data(RID, ...)` mutates physics data without changing Resource.points. Thus GDScript cannot enforce shared-shape immutability. No shared-shape adoption.

Latest own scoped static-settle optimization (still **NOT LIVE / NOT ADOPTED**): `transport_vehicle_wreck_debris.gd` SHA-256 `14c32a46c80980b6a1e24298521ab44a19633673b42054a99bd1f934b8c7b0dc`, `transport_vehicle_damage_orchestrator.gd` SHA-256 `5651a985bd59b95c36b834640740ce245c2c8fab5721b169c0cf95580838b810`, tests `test_transport_vehicle_wreck_settle.gd` SHA `41b5c8825e54c81fbf602c47c46b4427004eb6e0a4c02afcffa69d682ab52e5c` and `test_transport_vehicle_damage_orchestrator_settle.gd` SHA `9e98686e2a70ab27d0a692232d005e9d4821a860d4cd104348905f7779f5a5cc`. Parent actual Godot 4.7.2 headless: real-hatch orchestrator 131/131, dynamic skip regression 128/128, ten-car static settle 155/155 PASS. `settle_wreck()` only accepts all naturally sleeping native bodies, then keeps every real mesh and all 76 compound hulls per car with static collision; ray and shape contacts still hit. Parent ten-car sleep→static physics p95 2.787→1.302 ms in isolated headless fixture, with 760 visible meshes and zero missing collision shapes; author separate ten-car p95 5.973→1.059 ms. Source analytic debris stops motion permanently after settling, so later impulse immobility is intentional source-style behavior. Full-city/GPU acceptance and configure spike (~100–120 ms per car) remain open. This newer SHA supersedes the earlier dynamic-skip file pins in the next paragraph.

Later same-day isolated dynamic-skip correction supersedes the earlier orchestrator hashes below. Current `transport_vehicle_damage_orchestrator.gd` SHA-256 `ce269fec7c5578ce26a26a5e9dc95c25e2416f20a500a48923816f871ef2ba35`; `transport_vehicle_wreck_debris.gd` SHA-256 `5354759dcf6d828c58a842beb458d87b0e7fe3507be94bfc8530d4ba56cae776`; dynamic real-hatch test `test_transport_vehicle_damage_dynamic_skip.gd` SHA-256 `a661924280e92d75575f3c9bd741a081c38aacdaa89d18a0cf9bdf34fbf1a42e`. Parent actual Godot 4.7.2 **128/128** dynamic and **129/129** all-copy PASS. Post-callback host phase receipt selects original source indices [1,2,3,6,7,8,9] when roots 0/4/5 are hidden/transparent/ineligible; skipped roots consume zero draws, each accepted root receives its own seven draws and speed/heading. Invalid late draw/forged phase fail before any source hide. Seven physical bodies fall, clean up with zero orphan nodes; explicit respawn restores only copied roots, leaving pre-hidden and otherwise skipped roots unchanged. Parent dynamic configure 125.045 ms / subset launch 1.600 ms in isolated hatch fixture; no full-scene FPS. **NOT ADOPTED:** source char→callback→glass→recursive current copy, current geometry/material after callback, true host event/cooldown/RNG transaction remain unwired. The phase test uses host attestation rather than actual source callback; ten simultaneous all-copy blasts had 10.689–15.688 ms physics p95 across separate headless runs, not proven safe in the loaded game.

The user explicitly told Transport3 to fix the issue here rather than report it to General HQ, and to run needed tests ourselves. This supersedes the historical HQ-only reporting instruction for this transport work. Root23 still owns main/player/project/export/LIVE/Git; Transport3 owns only transport files and does not launch a GPU game.

New isolated, **NOT ADOPTED** damage/explosion orchestrator: `godot/mafiozi_walk/scripts/transport/transport_vehicle_damage_orchestrator.gd` SHA-256 `8d32ffcce8a96ed8489005406303abb68cebae854409a735f50cfa78c6d5cf16`, physical wreck lifecycle subclass `transport_vehicle_wreck_debris.gd` SHA-256 `b717eea488012d8d451c416994b2971c9f57967beec6039160ffed951b884d82`; real-hatch behavior test `test_transport_vehicle_damage_orchestrator.gd` SHA-256 `970cd44c379e954236281a6d7908de5915b27cef399a01478c43ce51c0463692`, scale test `test_transport_vehicle_damage_orchestrator_scale.gd` SHA-256 `ed25fe9e56a882753a78aa77be7ec8366e34f9a1e67cc23adc6a65f92d581230`. Parent independently ran actual Godot 4.7.2: behavior 129/129 PASS; scale 1, 3, 10 cars PASS. One real hatch has 10 assemblies, 76 convex hulls, 142,948 visual vertices. Collision never autoexplodes; authenticated host-receipt blast uses seven supplied RNG draws per copyable original index; 10 real rigid bodies fly/fall. Explicit `invalidate_geometry()` rejects a stale hull after an in-place mesh edit. `retire_wreck()` frees flying copies yet keeps source parts hidden; `reset_for_respawn()` restores only by explicit reset.

Parent fresh headless scale physics p95 awake: 1 car 1.652 ms, 3 cars 3.234 ms, 10 cars 10.689 ms; 10 settled 5.563 ms, retired .111 ms. Ten-car static memory 26.57 MB before, 246.72 MB awake, 186.13 MB after retiring copies. Ten-car configure total 1.139 s, max single-car 118.97 ms, prewarm 87 frames. Thus the component is **not safe to enable yet** under the user's optimize-before-adoption requirement. Full-city/LIVE FPS is untested; host event/cooldown authority, source char/glass callback order, dynamic skip, structural detachment, and deformation integration remain. `invalidate_geometry()` currently retires the prepared provider; a fresh provider from current deformed geometry is required before a later blast. Do not claim this candidate is visible in the accepted game.

Rejected optimizations kept isolated: transactional incremental preparation candidate SHA `9fa78d83544ee84d2a33a810ef3577ee8542db5355f363f322d1fc7e0d4e5dd5` actual parent Godot 201/201 PASS but 76 steps p95 3.853 ms, total CPU 144.662 ms versus monolithic 114.575 ms, ~507 ms readiness; prebuilt-hull reuse actual parent 21 PASS but warm 165.618 ms versus baseline 124.608 ms; exact duplicate-point removal reduced 142,948 to 27,298 collision points but failed natural physical settle and was rejected. Frozen production debris provider remains unchanged.

Shallow Mesh duplication was independently replayed as a memory optimization: ten real-hatch provider copies retain 60,274,768 bytes in frozen and 60,274,848 bytes in shallow (each Godot 33 checks PASS); effectively zero savings, so the shallow candidate remains rejected. This is Godot static heap only, not whole-process/GPU memory.

## 30 September — current Transport3 packages and ownership

New frozen **LOAD ONLY / NOT ADOPTED** debris material-pool optimization delivered to HQ only: candidate `scripts/transport/candidates/transport_debris_material_pool_unique_source.gd` SHA `38b1d664ea8d8943ba9d4ad93933e59d12eb270aa85ec33aaa88ba4485762aca`, test `594ca850e902ca8e0d9640720167542f04980e6d22eeb78e51a21e8299bfcff4`, `docs/godot/TRANSPORT_DEBRIS_MATERIAL_POOL_UNIQUE_SOURCE_HANDOFF.md` SHA `d72c22570b0824bd88d435247ca6c2843889f8bbff4d5e5023fa4e403f018e34`, manifest `50e65bf8aea48c91ee47dea1b799b4ff00c77483523a3dccff992b485f47ad62`. Godot4.7.2 author200 correctness +240 full PASS, parent fresh240/240 PASS, independent final static NO BLOCKER. Actual compact72 ordered surfaces/29 exact source IDs/72 independent private; call-local unique source signatures reduce validation by ~28–33% without dropping any per-surface admission check. Author baseline/candidate final median45.991→32.846ms, receipt44.967→31.839ms, take45.351→32.802ms; parent final49.393→35.192ms, receipt48.996→33.646ms, take49.878→33.433ms. Still ~31–35ms cost and only isolated load phase; no event/frame/streaming/LIVE/FPS claim, production pool c29037 unchanged. Future event authority and validation spike remain blockers for physical flying parts.

Latest direct user handoff: **Кординатор23** `01a0ef87-7a4d-7f73-93c9-8c643602aa04` owns root/main/player/project/export/LIVE/Git, superseding Root22; read `docs/ai/COORDINATOR_23_HANDOFF.md` and current `AGENTS.md` before any coordination. All future author package reports go **only** to existing General HQ `01a0df67-44d3-79c0-b243-fa6a9b891fde`; do not message either root coordinator directly. Root23 first priority is visible weapon/trunk candidate03 TT-first-equip LIVE failure. Old Root22 CPU QUIET was released on handoff; Root23 controls new GPU/CPU measurement windows. Transport3 ownership and no foreign runtime/Git/GPU boundary persist. Unique-source debris material-pool optimization currently an isolated static candidate awaiting bounded Godot correctness and cost; no adoption or LIVE claim.

Urgent fired/reloaded cargo correction supersedes Store276f94: current `scripts/transport/trunk/transport_trunk_cargo_store.gd` SHA `007e935a06253510db21fbf84a8ead3fd92239dc06a69943ed2833a297309afe`; test `6d7778b97b85b66d2701866ad3cbe228a8af15914d19e57facc71a6b865f8e2b`; handoff `docs/godot/TRANSPORT_TRUNK_CARGO_STORE_HANDOFF.md` SHA `fcc26718313281e7ce838c65f9a18018f6967c31089d2079bca12c911587194a`; manifest `e4debb4fceaffe313052f9d617dcc5ad0a3a14bcf2b8fbfbee94c5093dcd3595`. Root actual weapon smoke found prior Store rejected all13 fired weapons because source Fire.step whole-float sequence; source reload yields whole-float ammo. Store now validates exact intlike finite whole and source bounds (magazine profile, reserve9999, sequence JS-safe), preserves numeric variant/ammo, rejects invalids. Godot4.7.2 5384/5384 PASS including all14 Fire/Inventory/Store fired and reload numeric paths; reload test replicates Root `_inventory_state` clamp of only expired negative cooldown, without changing ammo. Populated100 isolated p50/p95 1091.5/3061us, not FPS. Runtime/test/docs/manifest frozen and sent Root22/HQ once. Root owns LIVE/candidate02/03 and negative-cooldown host seam.

Debris material-pool exact-comparator experiment is **PERFORMANCE REJECTED / DO NOT ADOPT**. Isolated candidate `scripts/transport/candidates/transport_debris_material_pool_exact_compare.gd` SHA `6d76e4b40b4fc7a2e7e48f039eebbc4f56f24ac0ccfadecfb41ce52323ef1fc3`; test `178bbce693ea13b529bd24a4e3c84b33bcc6acf01df3df4668355d3a8dea871c`; `docs/godot/TRANSPORT_DEBRIS_MATERIAL_POOL_EXACT_COMPARE_HANDOFF.md` SHA `50abc96b7d72cfb9cae0a03ff8b699e6962a1b8ae95656631e8a27a801307182`; manifest `376b5bd9699ceea7c1f256ad76175461f4810047c4a306c5459020f6f3b88f3a`. Godot4.7.2 232/232 PASS, but 20 alternating actual72/29 pairs baseline final/receipt/take median 48.677/48.055/48.273ms vs candidate 197.642/191.448/193.637ms. Production/frozen baseline unchanged; debris pool remains LOAD ONLY and cost blocker. Root22/HQ received negative result once. No GPU/LIVE/full-city proof.

Root22 `01a0eec3-2733-7130-9aea-c289c76574af` owns main/player/project/export, one LIVE game and Git. Transport3 owns `scripts/transport` and own source exporters/tests/docs; no foreign runtime/GPU/Git edits. Latest user cargo correction overrides all older AK15 rules: **AK15 was only an example**. Root owns a measured-volume all14 catalog with larger model→larger units and all14 one each within100, renderer/inventory/UI/ground bridge and LIVE. Current own trunk Store is `CANDIDATE_DO_NOT_ADOPT`: `godot/mafiozi_walk/scripts/transport/trunk/transport_trunk_cargo_store.gd` SHA `276f94cf96c241a4f6c30dc76d76ebc2f996209ae37f502c598dc8d4022c25fb`, test `b12dd6d64ff4a8e957a550fab60a72affb5066c92f3a0e7b81f34ccb7041b0aa`, handoff `88e1849eeb0799bb7ce50ad6b7847a4abb5fe2f9b697f7206b9cb3db21769f7e`, manifest `e49a725b998c6dfe7e20c5481d996788a63485fcb6a2f9523c79302328437168`. Author+parent actual Godot4.7.2 **5122/5122 PASS**, independent delta no blocker, manifest pins parent checked. Store accepts positive 1..100 units from Root trusted catalog, total100, corpse100 exclusive; physical evidence/5mm slots, UID/fireState, revocable validation seal, callback-free paired commits and two-phase destruction. Parent isolated populated100 transaction p50/p95 1130/3292us,max3820us; no full-city FPS. Old store SHA28f22 and old bridge receipt withdrawn. Sent new package Root22/HQ once. Foreign docs `docs/game-design/TRUNK_WEAPON_CARGO_20260930.md:7` and `docs/ai/COORDINATOR_22_MEMORY.md:39` still mention obsolete AK15; Root notified.

New test-only executed-source debris copy-event oracle sent Root22/HQ: exporter `tools/godot/export_transport_debris_copy_event_oracle.mjs` SHA `bc7cf288fd898335cfd4c39ec6916710314f5bcbaf41167ddb023cd8e1a51d98`, fixture `godot/mafiozi_walk/data/transport/source_debris_copy_event.json` SHA `5c748173306afb6b6acd1136f84749fe0f3196465e841849db415e76a4c59281`, Godot test `660709c9396c3083b2e5fe8c261bca0b5377c58e78541b499f9135e2128e9a4c`, handoff `9b8071fee05652205d3f09472bbc38842a8e88e978842d66bd7bc2984fb43b79`, manifest `eab651568a73048607009733eae3382d9b61d590b39b5cf8e2b792350db954d0`. Two author + parent fresh Node exports byteidentical, author+parent actual Godot4.7.2 **3540/3540 PASS**, independent static final no blocker, parent manifest pins verified. All13 actual fleet factory, 18 cases,7464 events/157 accepted roots; skipped original root0 takes no hide/RNG/state, later indexes1..9 preserved; exact postcallback/glass recursive copy/getter→hide→2 RNG→state→5 RNG; callback throw partial char. Test fixture only; no event authority/native launch/LIVE/FPS. Runtime explosion still blocked on exact event/lifetime ownership and expensive prewarm validation.

Car→NPC user request coordinated with Artist22/Physics12-13/Root22. Existing `transport_logical_host.vehicle_record(ref)` and `.driver(ref)` suffice for vehicle/seat identity; Artist requests no new Host adapter before Root freezes accepted event schema. Current preview roster contains player only. Native wheels are RayCast3D, not colliders; physics has chassis-only proposal `vehicle_npc_contact_receipt.gd` and NPC identity still needs Root acceptance/Artist ragdoll, plus underbody/no-trap LIVE proof. Exact source `vehicle_pedestrian_contact.mjs` swept capsule and .45m/s contact,1.65m/s fall,900ms pair cooldown are not wired to production NPC. No claim of ready run-over.

## 29 September — source-exact water exit surface component

Next water doorway spatial helper READY: `transport_water_doorway_pose.gd` SHA `fb61223de23c81c4317e2cf934815d9d45182aa2fc0b41d1f8ff5a2d133b03c3`, test `911796b05ff4099b59cc254677b3f81eda8f7ba119f8f1c5fc10c467e3d97a21`, handoff `docs/godot/TRANSPORT_WATER_DOORWAY_POSE_HANDOFF.md` SHA `c0a2f6d8f52521331f651e5110f7bc2040313f23387a4d205ca72e9cdfc5c3b6`, manifest `6203ef243cc1f677d8c63f9dce41b926f79ffa6cfd1e8af6c30e53ab67e7984c`. Parent hashes verified, author70+parent70 actual Godot4.7.2 PASS, independent adversarial no blockers. All exported profiles/seats both 1.9/2.4m, full pitch/roll/sink Transform3D, source exit smooth blend and fixed local seat Y. Quiet author pure 20k calls p50/p95 13.452/13.618us; parent12.6645/12.857us block means, NOT FPS. Scope spatial projection only, not full source presentation pose, physical actor or collision/seat/swim authority. Root22/HQ received once. Root22 direct next assignment: isolated candidate wet-exit authority branch because current dry Host `_receipt_valid` requires support_clear and cannot admit water without forging. Own candidate in `scripts/transport/candidates/` underway; preserve dry runtime bytes/behavior, no fake ground receipt, Root supplies real water/ground/capsule callbacks and eventual Host internal branch. Existing LIVE43120 Root-only.

New isolated `godot/mafiozi_walk/scripts/transport/transport_water_exit_surface.gd` SHA `cc72286766429bfa9942961bd85f1f26457342a2981d087bbe1af93265c0f200`, test `ee423ae3fbaadc804aa462d7e1bc3fa822e2b12647d240bf63005538de19e6e3`, handoff `docs/godot/TRANSPORT_WATER_EXIT_SURFACE_HANDOFF.md` SHA `a2e5f720bd2b5259f5bf1f435d95fd38b3bf803f3d7f5749b484b897cea5b70c`, manifest `54539fc7fbdfbaba42947b918b3cb668a2f07bcc9c6758b9777bb623e22abe20`. Source pins `vehicle_water_exit.mjs` `531fc5b0` and `walk_preview.mjs` `e80ebf4b`. Actual Godot4.7.2 author21+parent21 PASS; independent adversarial static review no blockers. Parent host-supplied real capsule provider active-ascent block-mean p50/p95 27.4/32.26us and settled25.93/36.26us (20 blocks x100 calls; not FPS). Exact source water depth>0 (+Infinity accepted, NaN rejected), finite level, .12m ascent/horizontal and .08m vertical probes, dt<=.1, rise .9m/s, dry descent, blocked/grounded. Root22/HQ received once. NOT wired to Root/player/swim; actual Root collider parity/LIVE/full-city FPS unverified. Root must choose authoritative water exit, adapt result-wrapped positional update/floor callbacks, finish only body.done && grounded && !blocked, then swim handoff. No foreign runtime/Git/GPU touched.

## 29 September — corrected post-factory geometry and load-only material pool

New read-only event seam audit `docs/godot/TRANSPORT_DEBRIS_EVENT_SEAM_GAP_AUDIT.md` SHA `0437c974262a713b437cedb9a03522c619d9f228e50444f52b94405d6ec05525`, 11858 bytes, source-file pins parent verified and independent subagent cross-check. It records actual char -> synchronous callback -> glass hide -> per-admitted-part copy/hide/launch order, exact seven shared RNG draws per accepted original index, callback-throw partial mutation, and missing authenticated cause/generation, postcallback identities/revisions, batch getter phase, ordered roots/skip reasons, assembly ownership, transforms and commit receipts. Delivered Root22/HQ once. Read-only dependency, NOT implemented event seam or FPS proof.

Coordinator ownership changed by direct user instruction: Root22 `01a0eec3-2733-7130-9aea-c289c76574af` owns main/player/project/export/LIVE/Git, superseding Root21. Current `docs/ai/COORDINATOR_22_MEMORY.md` and `docs/ai/AGENT_HUB.md` take precedence. No old PID or GPU-window status should be reused. The two finished packages below were sent directly to Root22; HQ already indexed both. Own transport scope and no-foreign-runtime/Git/GPU boundary unchanged.

FINAL correction package: exporter `89c99fea75a818b7b2636080261fd1fc7803e7855fee04a313e37f4120a22fb1`, fixture `15c89bac33c5051766fa40ed6c39b7b09d8d5da703ec98a0bd08c7c4fc8aeebd`, handoff `425e5b6164b6ce291e6bd56ba0ea0c5c0e045d6de8e9b6adcc397de327ee36aa`, manifest `8099f1cbc24d8ed6632888e735a7e3e29754dfab5cb00e55fa60af706ad402d0`. Two author runs plus parent fresh Node replay byte-identical; independent adversarial review PASS. All seven contested original input GLB meshes had triangles, but actual factory clipping empties their geometry before export; the raw visual GLB already contains empty nodes without mesh or children. All seven materialRest identities remain captured. Earlier alias-census export/import LOSS interpretation is false; do not restore original unclipped triangles. Root and HQ received final correction. Historical counts remain true, historical LOSS claim superseded.

Load-only material pool READY and sent HQ/Root: `transport_debris_material_pool.gd` `c29037e98c71cc9bed733784adf107edd58417439d721680c0a43ca0ace329d0`, test `1c778b9021a19f1f7967001e48f2f9ae1395f129429578f79ddf1fbbeacfd6ea`, handoff `3b0f1302b93f499503b4a53009b635718f37efa2db8927c8ba1c0cf899d1d1d8`, manifest `19a00b96e0c858e4ecfb71f44a5ee78917585eb8c095a5f1755dbdc6e1d32e11`. Author, parent and independent actual Godot 4.7.2 tests 187/187 PASS each. 72 independent private materials across 72 surfaces/29 source IDs. Parent ordinary prewarm median 0.802ms, but final validation 49.191ms, receipt 49.581ms, take 46.991ms; independent final validation 47.117ms. One-copy step limits allocations only. No event/per-frame/streaming adoption, no burn callback/source authority, no full-scene FPS or LIVE claim. Runtime/Git/GPU unchanged. Transition agent now audits next source copyPart event seam read-only.

## 27 September — source burn identity and native coverage dependency

URGENT CORRECTION03:43Z: prioraliascensus docs labelled7missingnodes export/import
coverageLOSS basedon ORIGINAL INPUT GLB216/324,96/132 counts. Parent parsedSHA-
pinned RAWvisualGLBs all7v-nodes haveNOmesh BEFOREGodot; matching actualpostfactory
raworacles all7position.values=[] indicesnull groups[]. Sourcefactory clipsgeometry
beforeexport (fleet_models182/193). ORIGINALnonempty alone DOESNOTprovefactory
rendercontentloss. Root/HQ warned: doNOTrestoreoriginalunclippedcontent. Oracle
NEWexecuted7postfactorygeometryproof nowsoleCPU, freezes correctionfixture/docs;
oldalias packages retainedhistorical butLOSS conclusion withdrawn pendingproof.

Poolauthor187+parent187actualGodotPASS joined. Parent72/29/72private independent:
ordinarymin730us trueStepMedian801.5us, LAST/max49.191ms,readyreceipt49.581ms,
take46.991ms. Strictallproperty/metadata signaturevalidation expensive LOADONLY;
onecopy boundsResourcealloc only, notCPUbudget. No event/frame/streaming readiness
orburnadoptionclaim. Independentpool helduntiloraclegeometryCPUjoined.
Fallback0575ebe6/4342dcb0 parentreplay byteequaljoined, independentstaticno blocker;
4freshcompactcases affected1/53/1/1 withexactupdatedWeakMap/getter/retainedresources.
Sourcefallbackfreeze908b8d10/001c2ea9 deliverypending listedpinsverification.

Next bounded native component assignedtransition: NEWtransport_debris_material_pool.gd
andtest_transport_debris_material_pool.gd, load-only prewarm oneindependent
privateStandardMaterial per surface perstep (72/29actualcompact). generation/
revision/lifetime/source&privatechange/nestedguards, one-shot take_prepared
transfers readyownership anddisconnectswatchers, dispose cannotdestroycaller
transferredRefs. No burn/callback/HP/eventfastacceptance/binder/adoptionclaim;
nestedtexture semantics unsupportedmustfence notsilentlysubstitute. CODEONLY
until oraclefallback authorCPUjoined. Frozenexistinghelpers remainuntouched.

FINAL cachedexperiment manifest480f582f/HANDOFF6f209851 all11pinsparentverified,
author/parent/independent46+60PASS. Root/HQ deliveredonce PERFREJECT/NOADOPT.
Source toggle/dispose proof FINAL exporter56e460d2/fixture32ebd8a1 (9924084B),
HANDOFF007069e9/MANIFEST6acc4ba0;2author+parentreplay byteequal, independentstatic
signoff, alllistedpinsparentverified, HQ deliveredonce. All13 initial/body rows
exact49a; off1438persist(340canonicalcurrent/1098hidden),on originalreceipts
restore,dispose0registrations/0proxiesunder car,291savedproxiesunparented.
Noadoption; wheel/fallback/callback/copy/proxygeometry/membermapping pending.
Oracle nextNEW freshcompact fallback cases (replacement/sharedhiddenmutation/
geometryreplacement/reparent) executing sequentially, no otherownCPU. Shared
hiddenmutation may affectmultiplemembers; exactidentity receipts required.

Root recoveryGPU window RELEASED, soleinteractive43848; own CPU workallowed.
Independentcached46+inherited60PASS joined, helper574260744b3fff8c363c3c798e4306bb82a9a7474bfb4dafb980ebabf508116c,
testc57698ee3f7c7b8131e903c17187adbf96462293ec3ec8fb1d85d8a58052a307,
inherited2728b75d8f862aed8be4b7018a0de02e021a92e3b5e15a719b1e8246aa993c03.
Reportingcorrection: test event_median_us is UPPER MIDDLE of8, notaveragedmedian.
Parent TRUE medians57.7845→47.5305ms; independent59.566→49.4945ms. Rawarrays
retained, smallNnotp95/FPS. Worst72distinct mixedvariance, parent+1.035ms remains
observedregression. StillPERFREJECT/NOADOPT. Authortransition docfreezepending.
Oracle nowsoleCPU2sequential NEWtoggleoff/on/disposeexports afterindependentjoined;
parentreplay afteroraclejoined. No concurrent ownbenchmarks.

03:33Z heartbeat completed sourcebatch package: exportera39eb6f5,fixture49a0342f
(5152798B),HANDOFF4f6c94cf,MANIFESTc8c658a7. Author2+parent fresh replay
byteidentical; independentstatic signoff. Exact1438body registrations/123hidden/
291proxies13profiles; no preupdates, damage→roll→tyres→body sequence pinned.
ParentalllistedfileSHAverified. Root/HQ deliveredonce. Exact13source/visual
emissiveIntensitydiffs explicitly unresolvednativebaseline, no mIDwaiver.
Next NEW toggleoff/on/dispose all13proof assignedoracle; codeonlyduringCPUhold.

Cachedsnapshot author46+60,parentfresh46+60PASS joined. Parent8alternatingpairs
baseline event min/median/max57.359/57.984/69.125ms vs cached46.945/47.537/54.540ms;
72distinct singlepair58.324→59.359ms regression. STILL PERFORMANCE REJECTED /
DO NOT ADOPT. Private72independent/resources+allbyte/nestedguards intact.
Authortransition freezesdocs; independentrev4 NOT STARTED, heldbyRootnew2min
exclusiveGPUrecoverywindow. NoownCPU active; rootnotified exactclearstatus.
AwaitEXPLICITrootrelease thenindependent46+60; no rerunsotherwise.

Cachedsnapshot implementation WIP now NEW
candidates/transport_vehicle_debris_material_snapshot_cached.gd,
test_transport_debris_material_snapshot_cached.gd and inherited60case harness
test_transport_vehicle_debris_material_snapshot_cached_inherited.gd (onlypreload
diff vsfrozen60case suite). Rev4 staticreview no blocker; NOactualGodotrun yet.
Authortransition mustwait oraclejoinedCPUrelease, then8alternating-order actual
compact72/29 plus72distinct comparison. Parentreplay afterward, independentlast;
report median/min/max forsmallN, no robustp95/FPS, no adoptionunlessactualcostsafe.
Oracle pending sourcebodyreceipt outputs13 emissiveIntensitydiffs vsvisualrecipe:
actualconstructor1.6199999141693127 vsvisual.5, oneexactmaterialperprofile. Burn
doesnotwriteemissiveIntensity; sourceevent/nativepreparedstate needrealrevision
writer, same mID alone cannotwaive propertydifference. Frozenpackageawaitauthor.

27 September heartbeat03:23Z: preallocation audit completed+parent sourcechecked,
docs/godot/TRANSPORT_DEBRIS_MATERIAL_PREALLOCATION_AUDIT.md
SHA97d01d982b2cb2a272831211c2718b70d04a57314977075f02bdcbebb133fd9f,
HQ deliveredonce. Actualcompact76candidate slots minus4glass gives72copied
surfaces/29authoredIDs, but source72independentmaterialclones mustremain72private
resources. Frozen0e performs432signature/216graphwalk operations (NOTnewtiming).
Transition_review NEWperphase exactsourceidentity signaturecache candidate/test
assigned; retains allprivate byte/nested/lifecycle/atomicguards, no crossphase
stalecache, no sharingdebrisresources. CPU tests hold while oracle author ownsCPU.
Oracle batchexport WIP revised: actualfleet no precontrollerupdate; constructor
roll/tyres added sceneoutsidecar; sourcepropertydifferences vs visualrecipe must
be explicit unresolvednativebaseline, never equalmIDproperty waiver. Independent
rev4 found sequence and missingproxygeometryreceipt gaps, author fixing.

Root GPU window completed by directmessage: sole interactive35668 melee20;
CPU/headless/source allowed, no newGPU. Oracle_review sole ownCPU authorproof
for NEWbatch exporter; parent/independent replay onlyafter joinedconfirmation.
Parent WIP review requested exact step1 descriptors/sourcepins/UUIDaliasgraph,
phaseobservation afteractualdamage, source roll/tyre order and parentphase proof;
do not claim outputready until fixed+executed. Rev4 read-only review assigned.
Root seam updated to constructiongapresolved/native7nonempty loss stillHOLD.

Next completed read-only source audit:
docs/godot/TRANSPORT_BURN_BATCH_CANONICAL_SOURCE_AUDIT.md
SHA91a375b242b3696efbe56f29f999576aa57f8edfdd97405084f096ed57b96d73.
Parent+independent sourceinspection pins/order/getter/callback verified; HQ
delivered once. Body registration persists with canonicalcurrent when detail
disabled; getteralone cannotprove membership. Currenttransparency checked before
canonicalgetter. Absentgetter requires actual copyPart entry receipt, never
inferred traversal. Oracle_review implementing NEW batchidentity exporter/fixture,
frozenstep1 untouched; CPU execution remains held for RootGPU completionnotice.
Transition_review audits preallocation avoiding rejected57ms materialcopy.

FINAL delivered Root/HQ once: identity exporter8bd2a6d3/fixture38d37079,
HANDOFFe15527e4/MANIFEST96656538; independent source review no correctnessbugs.
Alias author89+parent89+independent89 actualGodotPASS; frozen test9ebd6840,
CENSUSff32550a/HANDOFFfc793e73/MANIFESTcd6fa1d2; all10pins verified.
Seven NONEMPTY geometry loss receipts included. Batch canonical source audit
continues offline oracle_review. Root exclusive melee20 GPU window requested;
all own CPU/headless/import/benchmark runs stopped until completion notice.

Parent executed source exporter replay matches frozen fixture
38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38:
13 profiles,3283 scalar slots,757 captured identities,197 construction glass
nodes,117 BasicMaterial undefined roughness identities. Batch canonical receipt
and event/current identity remain PENDING; no runtime binder/adoption.

Parent fresh actual Godot native alias census89PASS, load-only1836398us;
no fullsceneFPS. Source3283slots/757IDs vs native3276/754. Seven lost native
mesh surfaces have NONEMPTY indexed actual source geometry: hatch v0008/v0009,
wagon v0007/v0008,SUV v0009/v0010 taillamps m0003 each216positions/324indices;
van v0002 CargoDoorSplit m0000 96positions/132indices. Imported visible childless
Node3D is not a fidelity waiver. Foreign visual importer/export owner dependency
sent Root once. Exact source geometry docs and independent source review pending
final package; no foreign edits/Git/GPU. Next own bounded audit is actual source
batch/canonical registration callorder and receipt, assigned oracle_review.
# Автомобили — продолжение 3, 23 сентября 2026

## 27 September — exact source burn plan complete

Identitygap audit FINAL3647900de3fe180c4cbbc10264663c96b00a6d264d565364c1f9477d7e5f6bbc,
docs/godot/TRANSPORT_BURN_MATERIAL_IDENTITY_GAPS.md all9evidencepinsreverified
afterstaleburnhandoff pinfixed toc0dd. Root/HQ notifiedonce. Oracle_review nowowns
NEW executedsource proofexporter tools/godot/export_transport_burn_identity.mjs
and data/transport/source_burn_identities.json (WIP notfrozen): actual13factory
construction+mIDalias/descriptormatchbeforecapture proof; in-memory sourceclosure
materialRest/glass observation, scalar/arrayoriginalkind/capturedrestF64/material
order. Batchcanonical receipt nextcomponentifnotincluded; no binderadoptionbefore
allrequiredidentity/sourcephase receipts. ExtraRootapproval notneeded for newown
tool/fixture underuserauthorization; foreign/globalexport/main/GPU remainRoot.

Helper2fd5d2f947d0bc24719292321a759ba2a6d9d808a53afd65238442f713881c70,
test6f0db4a5a4e0853fc6b37318e8f7441f2fb02b436dbf054a24501894d51898f1,
actualsourceoracle625040555e6a4dcab21491e1ec6d0267e25a1db65a852a82f2da3f7019a0df9c,
exporterb03fb1e4cca7f9c5f38794e3dcc5436ad74510e09c5c828b1ce9bfafccf5cc2a.
47author+47parent+47independent GodotPASS,7exactF64LEnumeric/8actualsource
semantics including bothtransparenttoggles. Localimmutabletargetbytes avoid
GDScriptdecimalconstant1ULP mismatch. NoHDR/negativeclamp, sourcecurrentlinear
channel +=(target-channel)*.94,roughness.99,alpha/nativeconversionhostonly.
Eligibility exactcaptureidentity+hasColor+CURRENT!transparent; constructionglass
list remainsseparate. Callbackmutation/throw andarray/replacement observedsource.
Parent100k375.289ms3.75289us/query PURECPU,not57msmaterialcopy/native/FPS proof.
HANDOFFc0ddfcbc01f7653c2515349feb922511c6daf6fb5fcf3cb3c029d09136f9cd35,
MANIFESTd0f2ceb0dd75957c290dce2387c51c2fcc99ed68f764da30179a71462ec8b064;
parentfinal7listedfiles/depsSHA verified, Root/HQ deliveredonce. RuntimeJSONnone;
fixturetestonly. BurnpreparationAUDIT nowaa714ae4247bea63188021e5b147b633ded3dcfc307f75fd3c93df5cbd58887d
supersedesce9 withcurrenttransparent/glasscaptureclarification. Noforeign/Git/GPU.

Next source/native capturedmaterialidentity gaps audit byoracle_review found
current13profilevisualaliasgraph useful butmissing scalar-vs-array/capturedMap/
glassmembership/batchcanonical/eventrevision. Parentfoundone staleburnHANDOFF
pin whileauditwaswritten; ownerfixingalltableSHA beforedelivery. Actual-profile
loadpreparedburnvariant remainsFAILCLOSED untilrealidentityreceipt, no names/
color/index guesses. Root globalexport remainsRoot; own NEWsource receipt exporter
may be prepared withoutchangingforeignvisualexporter orproductionJS.

## 27 September — cache experiment rejected; exact burn source correction

Cached775dadce790a49536e0f5a005d26541c79585ac6d437f41cddfd7d488a9ed122,
testfb2184eca6c79b195d1c9657b025f706570f57e8c7ea298823eca9fd00746eb9;
155author+155parent+155independent GodotPASS, baseb8b unchanged.24alternating
blocks25calls each statistics are BLOCKMEAN p50/p95, noteventtail/FPS. Parent
2targetmoving183.28/270.76→90.28/134.48us;32distinctmoving168.12/199.20→
182.88/219.12us/static172.52/259.36→187.76/277.12us (~9%meanregression).
PERFORMANCE REJECTED / DO NOT ADOPT. Actualsourcepaneldistribution unmeasured.
LinearO32² precursoralso rejected; finalDictionarylookupdoesn'tsolveworstcase.
TRANSPORT_DAMAGE_MARK_POOL_CACHED_HANDOFF76a5f04a…/MANIFEST534c9dd4… verified
and deliveredRoot/HQ once. No more cacheloop withoutnew justifiedstrategy.

Sourceaudit TRANSPORT_DEBRIS_BURN_PREPARATION_AUDIT.md ce9e21d819a87b1a55c5a19e6e1ef042f499c20adb69309c9aee37f9095244dc:
sourcee029line276 burn CURRENTlinearColor.lerp(ThreeColor('#100f0e'),.94),
roughness=.99 — fixedtargetisNOTfinalcolor! Supersedes earlier visualreview
simplifiedwording; currentmaterialsnapshot onlycopiesactualsuppliedmaterial,
syntheticliteralburnfixture isnotactualsourceburnproducer. materialRest captured
scalaridentitiesfixedatconstruction, arrays/replacements notautomaticallycharred.
Pinnedproductioncallbacksleaveopaque unchanged butgenericcallbackcanmutate/throw;
taillampemissive dynamic. Loadburnvariant needsexactcurrentallpropertyidentity
receipt/invalidation, unconditionalpresetnotadmissible. Root/HQ correctedonce.
Transition_review nowowns NEWpureexactburnplan+actualsourceoracle/exporter/test,
noResources/Nodes/authority/57ms solutionclaim. No foreignmain/Git/GPU edits.

## 27 September — external 32-mark runtime complete

Frozen HANDOFF5848f88dd20f8eaa6a413ccd0702557b1e5e23106ffdd964a88bacf56c170f94
and MANIFESTbacf563f9d9afffb9a9ffb6b5b6cefee9dc9749be071b53cefdb4e97ee8c0833:
docs/godot/TRANSPORT_DAMAGE_MARK_POOL_*. Parentall9files/depsSHA+bytesverified;
Root/HQ notified once withAPI/sameframehostreconcile/exportJSON/limits. Cached
oracle candidate next requires2target/32marks ANDworst32distincttargets static/
moving parity+cost, alternatingblocks toreduceorderdrift. Cachelinearlookup can
regressworstcase; do not adopt by2targetcostalone. Frozenb8b unchanged.

Poolb8b095037f80867f8ec168b75d8a76e0458b1b32b750d9e5e06bb3cc6cc7af0b,
test06f6d01eca1e24b5fd0bd2e7105efa26f7ac5ba9fb930a8dcb103ddb6fa58a02,
physicalseam43aa1f2830c06d3a25f0db578f6cc255225e93da9f4d96f06927dda95ea1ee4e.
37author+37parent+37independent actualGodotPASS;14author+14parent+14independent
frozen1cf actualbody/hull launch seamPASS. Externalvehicle sibling33nodes,
32reusedMeshInstances/2private meshes/2materials; no marksunderassembly orcloned.
Exact targetGlobal*rawLocal follows movingtargets through explicitboundedreconcile.
Cursor commits afterpose install; WeakRef actualbindings/max4096/monotonicgen/
reset/dispose/queueddelete/singularinverse/override/resourceidentity safeguards.
FourResource.changed watchers disconnectedondispose, retainedmaterialtestPASS.
Qualified fresh parent AFTERindependentcompleted1000plan+commit75.193us avg,
32active reconcile123.991us avg,prepare2326us LOADONLY. Earlier possibleoverlap
metrics discarded. No robustp95/fullcityFPS/GPU/rasterbias ormainadoption claim.
Host mustprovideactual sourceIDs/contact/ray/reprojection/authority andcall
reconcile aftermovement/deactivation. Private resourcecontents immutablecontract;
silentlymutatingResource content is outsideproof. PolygonOffset remainslimit.
Nextoracle_review separatecachedreconcilecandidate awaitsfinaldocfreeze; no
baseedits, exact unchangedwrites only/noepsilon/contentcut.

## 27 September — post-burn material snapshot finished, impact cost rejected

Frozen candidate0e000ba7c30c463fae5ff6390323f1bb36d87c138ebd4673bdd5465102627001.
60author+60parent+8independent+8parent GodotPASS: actual postcallback materials,
per-surface independent copies, source reset isolation, atomic lifecycle/content/
nestedGradient/hierarchy/queueddelete/launch/revision guards. Parent realcompact
10assemblies72meshes72surfaces stage29.559ms+commit27.958ms=57.517ms;
author55.246ms, configure99.819ms LOADONLY excluded. PERFORMANCE REJECTED /
DO NOT ADOPT. Earlier schema allocation272ms reduced withoutweakening checks,
but current coststillreject. No more optimization loop withoutnewstrategy.
Exactfiles/source/baseSHA/API/order/limits docs/godot/TRANSPORT_DEBRIS_MATERIAL_SNAPSHOT_HANDOFF.md
SHA1407bffc… and outputs/transport_debris_material_snapshot/manifest.json50252f88…;
parentalllistedSHAverified, deliveredRoot/HQ once. StandardMaterial3D only;
resourcegraph boundeddepth8/256; silentnestedmutations outsideproof. Callback
authority remainshost. Frozen1cf/d2a untouched; no main/Git/GPU/LIVE edits.

Externalmarkpool current32author+32parent/14parentphysicalseamPASS; finalcheap
materialoverride guards/reviewer pending. Parent32active reconcile120.715us,
plan+commit64.369us,configure2.989ms. Source externalmarks remainoutside actual
frozenprepareddebris, launch succeeds andhidesmarkassociations, no clonedmarks.

## 27 September — mark geometry resource freeze and debris material seam

02:19UTC heartbeat continuation: oracle_review owns NEWmaterial snapshot candidate
and actual compactGLB cost; rev4_adversarial independent lifecycle/content review.
Parent found stale same-ID material content, reparent/queueddelete and reset receipt
holes; author adding signatures/resource graph guards and final launch checks.
Candidate not frozen/adopted yet. Transition_review owns NEW external32markpool;
parent requires reconcile moving target transforms (source child marks follow car),
effectsRoot inverse finite/nonsingular, rawpose preserved, no perimpact resources.
Host still owns actualcontact/raycast/event authority. Material/mark tests run
sequentially; no secondGPU or foreignruntime/Git edits.

Factory314c6d0483b67b600025f96d3194c8ec334532ab2ce73f9fbecd93f0ada72461;
source runtimeJSONd05b5114ef6ada70e8690f99752052ac00121aaf774ac6a1bae874c1edd46bf0.
Actual private source32-slot extraction; scratch4/crater108 vertices, original
Float32 positions/normals/colors/UV/index retained, native triangle indices swap
b/c once for Godot CW fronts. Linear source albedo converts to native sRGB
property; vertexcolors stay linear. Two private meshes+two materials percar.
39author+39parent+39independent GodotPASS. Qualified parent sequential100prepare
106.056ms=1.06056ms/car after independent completion; earlier possibly overlapping
96.959ms discarded for cost. Load-only; noNodepool/main/authority/GPU/FPS claim.
Exact polygonOffset raster bias remains unresolved native rendering limitation.
Root must explicitly include runtimeJSON on future export adoption.

New visual audit TRANSPORT_DEBRIS_VISUAL_FIDELITY_REVIEW.md a8585991… delivered
Root/HQ once: source chars opaque materials, callback, hideglass, then copies
post-burn effective materials. Current prepared1cf/d2a materials stale until
separate atomic visual snapshot; local oracle_review implements NEWcandidate.
Source copyPart excludes markpool: external effects sibling association preferred,
no mark cloning into debris. All structural copy/count guards must exclude any
tagged marker consistently if reparenting adopted. Material candidate WIP parent
review requires same-resource in-place mutation fencing, lifecycle/reset stale
receipts, refresh-before-material order and final private snapshot validation.
Frozen base and foreignruntime/main/Git/GPU untouched.

## 27 September — raw marker pose ready, exact hull dedup rejected

Pose6e8032efe2612e4d70bdad1208a15d633d3b292b903e6705648e935e8d03e5b2,
actualThree180fixture98b31923… authoritativeDoubleLEinputs/expectedbytes.
52author+52parent+52independent/34independent+34parentPASS; no1ULPJSONdecimal
ambiguity, nonunitrawq/explicitcolumns/sameframe/parentonce. Nativeoverflow and
positive scale underflow fenced. Parent100k655.775ms6.558us/query. Exactfiles/
API/seams/tests/limits TRANSPORT_SOURCE_MARK_POSE_MANIFEST/HANDOFF. NotNodes/LIVE.

Exacthulldedupbddce419c0a283e2ae45a9b31f09cf6d5c6a64d6f527b876bebccd5c557ce94e,
147author+147parentPASS; all67239sourcevertices retained, hullinput11367exact
uniquepoints55872repeatsremoved, physicalcollision/fall/sleep301framesPASS.
Parentfreshstrictlysequentialbaseline23.669ms/candidate26.349ms, smallpartp95sum
2.388->3.980ms: PERFORMANCE REJECTED/DO NOT ADOPT. Initialoverlappedparentpair
discarded; exactsourcegeometrynotreduced. Files/costs/limits TRANSPORT_DEBRIS_EXACT_POINTS_*.
Frozen1cf/d2a/883/bacunchanged. Next actualmarkergeometry/material source exporter
and load-only resourcefactory assignedtransition_review; noNodepool/main yet.

Newphysicsownerbridgeauditblocks directcurrentcontactwiring: native normal ONself
vsoutward, aggregatemidpoint/normalnotcoherentpeak, missingfrozenrootframe/
selfpoint/obstaclerole. Peerdamage usesdirecteddeltaVA/B notJ/m orclosing; canonical
event/lives/targetorder/cooldowns absent. Recordedtop TRANSPORT_DAMAGE_ROOT_SEAM.
60Hzcombined72/8worker parentp50/max39.776/42.955ms,78checks/8samples, native
finishesbeforedeformation8/8; rejectedfullsurface dominant, no60Hzcontention/FPS
claim. Different.1stressmustnotbemislabeled60Hz. Noforeign/main/Git/GPU edits.

## 27 September — frozen source paint mark planner

Plannerbac706d5449155814667bf7677c7ae5364b8b95d10cf364d3104799c25d6b42c;
actualprivate mark/publiccontactoracle85762dbd…9rows/twoidenticalexports.
85author+85parent+85independentGodotPASS; parent100k778.141ms7.781us/query.
32poolcursor/physicalslotkind/wrap/default24/2.399afterincrement/sourcequaternion
order preserved. Input/outputSAMEactualpanellocalframe; NOextraX/Zflip.
Source nonuniformscratch axes dot=.212544, qlength=.980638 intentionallyNOTunit;
Rootmustnotnormalize/orthogonalize, geometryXY/+Z. Host actualcurrenthit/ray/
reprojection/localtangentfallback/poolNodes/cursor/authority remainintegration.
Exactfiles/API/rootseam/tests/limits TRANSPORT_DAMAGE_MARK_PLAN_MANIFEST/HANDOFF.
Not main/LIVE/fullvisualcrash/FPS. Next dirtyhull exactduplicatepoint experiment
assignedoracle_review, newcandidate only; d2a/1cf frozen untouched. Dedup exact
positions ONLY, no rounding/simplify/contentcut; compareactualstrongrefresh cost.
No foreignruntime/Git/GPU changes.

## 27 September — copy-cost experiment closed, rejected

Candidatef565b993324f10f19fe6643d541e963fcc0f35b86007d998c57507ab6a89af31:
88author+88parent and19independent+19parent finite/transaction checks PASS.
Fullpassfusion20–32%slower, rejected/notretained. Finalcopyownershipchanges
source-faithful, but parentsequentialactual25752baselinep50/p9515.951/18.351ms
vs candidate16.152/17.494ms;90k98.251/104.502 vs99.326/109.368ms.
No stable speedgainclaim; PERFORMANCE REJECTED/DO NOT ADOPT, production883
unchanged. Exactfiles/tests/costs/limits TRANSPORT_LOCAL_DENT_COST_MANIFEST/HANDOFF.
NoWorkers, so this pureCPUcost is not poolcontention. Normals/bounds/upload/hulls
excluded. Next independent source32-slot paintmark/scratch pureplan assigned to
transition_review; source contactray/reprojection/authority remainhost dependency.
No foreignruntime/Git/GPU changes.

## 27 September — frozen local dent position core, performance rejected

Core883a4559323649b21315098ae4f6324566e9302bb25a8110a1b8c7dd7c93459e.
Actualsourceinstrumentedprivateclosure/Three180; oracle790b7d5e… twoidenticalexports.
87author+87parentFloat32source/cumulative/cage/replacement/nativeaxis/lifecycle
PASS;18independent+18parenttransactionPASS. configure/applystage/commit/abort/
monotonicreset/dispose, max90000vertices; sourcecaps.18/.40, current-oldoffset.
Rootmustverifyactualstagedbytes+normals/bounds/sphere/resourcerevision BEFORE
commit opaque token; tokenonlyprovesprivate stage identity, noactualgeometryproof.
Purepositioncore NOTfullvisual/mechanicaldamage. Preparation/normals/bounds/
upload/hull/authority integration remainhostwork. Actualpreparedv0163 25752verts
stage+commitparentp50/p9516.969/21.899ms,max25.666;90kallinsidep95124.659ms.
PERFORMANCE REJECTED/DO NOT ADOPT, noLIVE/fullsceneFPS. CombinedWorkerThreadPool
strongcage+72physicsowneractualstress47.955–57.761ms17checksPASS, notp95/FPS;
seeVEHICLE_CRASH_COMPONENTS_REVIEW. Files/API/seams/tests/limits preserved in
TRANSPORT_LOCAL_DENT_MANIFEST/HANDOFF. Next separatecostcandidate assigned to
oracle_review, frozen883 untouched; fusepasseswithfiniteguards and exactparity,
noeventdeferral/geometrycuts. Noforeignruntime/main/Git/GPU changes.

## 27 September — bounded preparation blueprint cache

Frozen additive cache74b6fc31d7d2a7e702d96f104554fa3606a0aadc050d9b223a218139688f1f7a,
test372b4203fc8c1a38a104ac7851214ef200cfa026410f60d0955c74623fa39a9a.
54author+54parent actualGodotPASS. Actualcompact121meshes726759verts:
first3919.085ms/HIT77.456ms (50.60x), estimatedimmutablepayload44,995,412B.
Bounded16entries/128MiB estimatedpayload/4096livebindings; failedadmission
retainsnothing, deadWeakRefspruned, noeviction. Per-instance unique mutable
buffers/meshes/current materials, source frame/provenance/fingerprint preserved.
Root/HQ delivered TRANSPORT_DEFORMATION_BLUEPRINT_CACHE_MANIFEST/HANDOFF.
Preparation-only separate provider NOT integrated adapter/main/LIVE; HIT77ms
notimpactframe-safe. Allocator/temp/perinstanceoutput memory excludedestimate.
Does not solve deformation34–38ms/dirtyhull~22ms rejected costs.

## 27 September — source boundary correction, current deformation candidate

Actual source LEFT-cell/blend1 boundary semantics now retained by adapter
74e5f0f2d1973674d497edfec89803b61270eed93d700d3527185b95339e7ddd and
transport_deformation_cell_binding.gd a2a62049ae7197e8ff556d76bdab7138a54446ac9f403cab648078958247f35e.
710author+710parent source helper PASS;655author+655parent actual108mesh
adapter cache checks PASS; max weight error1.11e-16. Previous normalized-floor
binding mismatched94/115 boundary masks.6178parent+two independent6178 deformation
checks PASS, strong apply33.610/35.326/37.807ms STILL PERFORMANCE REJECTED.
Do not adopt this as lag-free damage. Root/HQ received exact updated
TRANSPORT_VEHICLE_DEFORMATION_MANIFEST/HANDOFF once. Native kernel header
4d1ce750a4acfc2fdacf287df3e41aa9eb6542c4629d7f33d380350757540edb has
384sourcevertices/81supports; JS buffer comparison only, C++ not compiled.
Blueprint cache remains separate preparation-only candidate under memory-bound
review; no main/physics/Git/GPU changes. Runtime canonical damage_assemblies.json
requires explicit future Root export inclusion; physics18b excludes test data.

## Actual cargo evidence — latest additive package

transport_cargo_evidence.gd closes real floor/lid data seam using SHA-bound
actual imported visual+same compartments instance.156/156 actual Godot13profile
PASS; construction-time source floor proof, cached actual lid vertices/current
pose, native AABB, closed/open admission, roll and hidden render state.
Actual GLTF root is identity AuxScene ABOVE RY(pi); extra conversion is wrong
and is guarded by native rear-lid sign tests. Damage owner must call
invalidate_geometry before in-place mesh/topology edit and rebuild provider.
No inventory/authority/item creation; Root binds lifetime and load receipt.
Manifest/handoff TRANSPORT_CARGO_EVIDENCE_*. Sample p50 546us/max709us isolated;
full scene performance unmeasured. No foreign runtime/Git/GPU changes.

## Cargo geometry admission — latest additive package

transport_cargo_admission.gd ports source acceptsItem geometry, floor/opening
and .85 lid gate, native Z aperture,8-corner world AABB conversion.319 Godot
checks PASS on13 profiles; independent source review confirmed equations and
identified test gaps, now covered by analytic nonzero yaw+roll box oracle,
lid invisibility, availability and tolerance boundaries. Pure query only;
no storage identity/inventory transfer. Root must supply actual floor evidence,
current lid AABB/detached/visible/available; companion bounds alone insufficient.
Manifest/handoff docs/godot/TRANSPORT_CARGO_ADMISSION_*. Frozen rev6 unchanged.
10000 queries11-15.3ms CPU, full-scene performance unmeasured.

## Service access query — 27 September, latest additive package

transport_service_access.gd exposes pure source-compatible hood/trunk admission
from exact companion access_profile, actual vehicle transform, signed speed and
external actor/damage context. 553 checks PASS across13 profiles/3 yaws; source
planar ranges/sectors/height/repair gates retained. No authority/identity mutation,
no repair/inventory/debris commit. Root binds lifetime/profile and routes E/R.
Projected forward handles pitch/roll; degenerate transforms reject. Returned
sector_anchor_m is admission-only, not the actual trunk handle/cavity center.
Manifest docs/godot/TRANSPORT_SERVICE_ACCESS_MANIFEST.json; 10k queries60.7ms
isolatedCPU, full-scene performance unmeasured. Frozen native rev6 unchanged.
Root LIVE13 now has hood/trunk model controls; query helper is additive pending
Root adoption. Exact companion423c09c2/sourceoracle274 verified independently.

## Godot transport — 27 September, current handoff

Native revision 6 was delivered to Root21 and HQ: manifest
`docs/godot/TRANSPORT_NATIVE_MANIFEST.json`, SHA
`ca32e094c3b7d58ff14b6a781a11d70d2c63d1e308551f7c84d89d577ea76170`.
19 exact files; 137 scoped checks + 14 actual main checks, independently verified.
User override: boarding 1.2s, shared transport_timing host/provider contract.
Moving EXIT uses source tumble >15km/h and actual inherited velocity; no body
braking writes. EXIT-only support seam corrects query start <=5cm while preserving
actual from_m; walls/deep overlap/landing checks remain. Root-owned seated 6DOF
binding/controller/LIVE/Git are separate. Stale BLOCKED diagnostic reported Root.

Next delivered helper: transport_panel_motion.gd exact source critically damped
hood/trunk motion; 14 actual Godot checks, source numeric vectors and 20/30/60/120/144
FPS/reversal. Isolated 10000 calls 13310us; full scene performance not measured.
Separate manifest TRANSPORT_PANEL_MOTION_MANIFEST.json; Root visual/control
integration pending. Do not mutate frozen revision 6 for this additive helper.

Water exit audit remains dependency-gated: actual terrain/water/swim sampler,
vehicle prediction and swim handoff are needed. Current water dry-only admission
is explicit; no water readiness claim. Git/GPU remain Root-owned.


## Terrain authority — read-only boundary

`docs/ai/PEDESTRIAN_VEHICLE_TERRAIN_AUTHORITY23_CONTRACT.md`: pedestrian
walk/scramble/climb физика отделена от vehicle road/parking/driveway/service
authority. `roadsOnly:false` не означает произвольный off-road; без authored
access identity гора/трава/пешеходный путь запрещены машине. Production0 до
checkpoint; после него первым остаётся driver-not-ready lifetime fix.

## Следующая итерация hijack — read-only contract

`docs/ai/NPC_VEHICLE_HIJACK_CONTACT23_CONTRACT.md`: Transport3 + Художник21
согласовали additive stages grab/extract/release/fall/settle, source timestamps,
двухручные actual-rig anchors, explicit door openness и отложенный protest до
settle. Владельцы файлов разделены; production0 до checkpoint, fire/E/floor не
трогались. Driver-wait candidate остаётся первым малым NPC fix после публикации.

## Остаточный near-vehicle follow probe

`docs/ai/MERC33_NEAR_VEHICLE_FOLLOW23_PROBE.md`: после принятого физического
выхода merc33 остался `source_blocked` в 3.16 м от follow goal и 3.19 м от
центра остановленной Kingswell; bodyDepth0, остальные4 arrived. Машина —
правдоподобный, но ещё не доказанный blocker. Сохранён точный следующий
read-only probe; production0, collision radius/teleport не менялись.

## Последний пакет: blocked-route lifetime

`docs/ai/TRANSPORT_BLOCKED_ROUTE_LIFETIME23_HANDOFF.md`: по разрешению
Координатора20 добавлен cancel старого lane job перед delete плана при
длительном препятствии, helper + mirror world. Old FAIL / new PASS,
cancel exactly once, другая ready поездка не вытесняется orphan-результатом.
Смежные lease/control tests PASS. Runtime после пакета снова FROZEN.
LIVE/FPS этого исправления не проверены. Squad transport уже принят root
в LIVE, evidence `SQUAD_CATCHUP_TRANSPORT_LIVE23.md`.

## Squad transport production — пакет для LIVE

`docs/ai/SQUAD_TRANSPORT23_HANDOFF.md`: после lock на main272d12c внедрены
source+localfleet bridge, exact seats/reservations, physical board/ride/exit,
pending unsafeexit безfallback, sharedbudget finalcheck, reserved-only safe
transportcatchup65m6s/10sstuck20scooldown.23actual-hosttestsPASS и обновлённый
existing long-follow route-clear testPASS. Own runtime hunks завершены,
firing/ownsUpdate уchildvehicle, catchup geometry уchildgang, UIhandlers уroot.
Производительность общей сцены не проверена; root принимает LIVE однойигрой.

## Новый приоритет — транспорт банды

Пользователь через coordinator20 переключил на squad boarding/free seats/
ride/exit/fire. Trip17 test-only передан в
`docs/ai/TRANSPORT_TRIP17_LIFECYCLE23_PAUSED.md`: actual worker READY1763,
затем approach-blocked release, no teleport, slot/registry освобождены;
полная requested matrix не завершена. Runtimefreeze сохраняется до rootSHA.
Общий mercworld не редактировать до точного lock; safeplacement/teleport у child.

## QA history candidate — runtime freeze

`docs/ai/TRANSPORT_LANE_QA23_CANDIDATE_HANDOFF.md`: готов неприменённый кандидат
истории первого actual lane rejection до перезаписи trace. Только npcqa/
npctransportqa, max16, exact validated shape без новых geometrycalls, штатный
JSON download. 18 actual producer/cache/roundtrip checks PASS; five-file patch
и SHA256 manifest в outputs/transport_lane_qa23_candidate*. Runtime НЕ менялся.
Применение только после нового опубликованного root SHA и сверки кандидата.

## После общего reload — read-only аудит

`docs/ai/TRANSPORT_TRIP17_RETRY23_AUDIT.md`: выбран реальный resident2/car17.
В LIVE125260ms: planning52.007s, текущий fallback request лишь2.1727s,
expanded7/pending — не terminal failure. Actual producer audit: один NPC/одна
поездка может породить48failed jobs;100polls одного retainedjob даютfailed1.
Exactfrom — perpendicular bay1 woodland_crosswing; static с двумя явно
неподтверждёнными LIVE профилями: exit645/lane1763READY, fallbackblocked11.
Исходная LIVE lane-rejection причина/shape/lotIds ещё отсутствуют. Точный
следующий capture-сценарий сохранён; runtime после reload НЕ расширялся.

## Результат первого scoped patch

Второй patch по свежему LIVE export: `docs/ai/TRANSPORT_EXIT_RESUME23_HANDOFF.md`.
Точная поза car18 — середина авторского reverse exit. Исправлен отказ
`parking_exit_unavailable` при его продолжении: теперь 43 оставшиеся точки,
full hull + gear + route ID сохранены. Actual regression FAIL→PASS, начало/
середина/конец/барьер/чужая позиция проверены. Подробности и пределы — в передаче.
Полный actual-source async цикл с этой точной стартовой позы: PASS287.336м,
подход/посадка/reverseвыезд/поездка/парковка/выход/визит/следующеезанятие.
Оба transport patches READY для единого reload координатора20; LIVE ещё нет.

Передача: `docs/ai/TRANSPORT_PARKING_LEASE23_HANDOFF.md`.
Исправлена потерянная бронь парковки при истечении lease и перестроении
маршрута; actual source regression до FAIL / после PASS. Геометрические циклы
248.413 м и 901.275 м (async worker + остановка перед другой машиной) PASS.
World/helper изменены только в `_civilianTripMaintainLane`. LIVE у координатора20,
off-road причина отдельно не установлена; запрошены отсутствующие route diagnostics.
Производительность общей сцены не проверена. Подробные цифры и ограничения —
в передаче выше. Ниже исходное поручение, сохранено для продолжения.

Пользователь попросил заменить зависшие Автомобили — продолжение2
(01a0cb0a-d013-79b1-a979-1612fdaa27bc). Старую задачу архивировали, не будить.
Это чистая задача с короткой передачей, не fork огромной истории.

Общий каталог C:/Users/Слава/Desktop/Мафиози. Main31f8ea6c6e52c44e1c545b1fecef843355415c94
опубликован координатором20 (01a0bc08-cb3e-7181-be11-a53aaee54535).
Работать прямо с текущей общей сборкой, не reset/clean/stash/add-all.
Читать актуальную шапку COORDINATOR_20_MEMORY.md, NPC19_TEAM_BOARD.md,
AMBULANCE_LOADING_OWNERSHIP20.md, NPC_VEHICLE_DOOR_FLEET20.md,
VEHICLE_ENTRY23_READONLY_AUDIT.md. Исторические рекомендации сверять с кодом.

Первая конкретная задача: один end-to-end NPC trip: подход к машине →
посадка → реальное движение → парковка → выход → следующее занятие.
В root actual export .git/ai-pipeline-local/live23/npc-inspection-checkpoint23.json
у car4 startBlocked off-road, 27 jobs/1 completed/20failed. Позднее LIVE:
64jobs/5completed/180failed, local_vehicle_23 startBlocked off-road
(r14.78486 c153.69443) и pending ambulance. Это счётчики, не доказательство
конкретной причины. Разобрать actual parking access/route producer и lifecycle,
выбрать один воспроизводимый отказ, узко исправить и измерить стоимость.
Не обходить коллизии, не телепортировать машину и не выдавать дорогу на карте
за подключённый AI. Сохранять владельцев, места в машине, source IDs.

Посадка/выход игрока — удержание E0.3с, четыре двери/места, левый руль.
Root исправил poll sourceVehicleAccess перед active-gate: pending после
exit/interrupt больше не застревает; CPU3casesPASS, LIVE цикл ещё требуется.
Holdclock23 отдельный кандидат не интегрирован. Astra6 пакет door/boarding
у Проверщика2 — сначала согласовать пересечение.

Твои файлы: civilian_parking_trip_source.js и соответствующий world block,
npc_vehicle_hijack_source.js, ambulance_transport.js, vehicle access/pose,
native driving/parking routing. Перед общим world/walk edit — сообщить root
точный блок. Не переписывать общие файлы целиком и не трогать чужие hunks.

Координатор сейчас владеет water-follow и moving intimidation (уже WIP),
mercenary_world/core/pose, телефон его субагент. Художник21 — NPC agenda/nav.
Весь perf и8Астра — Проверщик ЧАТОВ2 01a0bbdc-edb1-7cc3-9cda-1160f3bc057b;
не дублировать optimization diff. Новую игровую вкладку не открывать:
единственная18538 у root. Согласовать конкретный LIVE сценарий и дождаться
его evidence, параллельно проводить actual source regression.

Первое сообщение: коротко подтвердить старт и назвать выбранный bounded
дефект/файлы. При технической блокировке сразу сообщить её root. После
каждого patch сохранять handoff: механизм, проверки, CPU стоимость,
LIVE ограничения. Не объявлять город живым без настоящего браузерного прогона.

## Civilian planning trip registry,27September
Additive transport_civilian_trip_registry.gd,41author+41independent actualGodotPASS. Separate planning reservation,16limit, exact actor/car life, stale incarnation cancellation guard. Manifest/handoff TRANSPORT_CIVILIAN_TRIP_REGISTRY_*. Full admitted same-session rosters/intention/access needed; no driver/seat authority.10kcycles143–197ms isolated, fullscene unmeasured. Source mapping independently reviewed. Frozenrev6/Git/GPU untouched.

## Direct user crash/blast migration active
User explicitly requested realphysicallyflying/fallingparts+no lag. Sourceaudit/doc TRANSPORT_VEHICLE_DAMAGE_HANDOFF.md; purelocalstate18076PASS/launch14PASS. Debris childactualGLBnaturalSleep54PASS butperformance firstactivation415ms REJECTED; prewarmcachedbody readiness optimization active, noadoption/LIVEclaim. Physicsownermutablesolver/contactauthority dependency, Rootmain/Git/GPU. Movingexit candidate6aa6b4fe separatelyauthor37+636PASS; old6a4deepdropfalsegrounded revoked/finalindependentreviewpending. Frozenproductionrev6untouched.

Root adoptedmovingexit finalc9ed byteexact production afterindependent168PASS+rootactualmain14PASS. Authorcandidate stayedstable; rootnowownstiming/hop/releaseblend/LIVE. Historicalrev6 productionhash no longerlatest; do notrestoreoldfile. Main/Git/LIVEstillrootexclusive.


## Physical debris frozen1cf791ea
Actual264PASS twoGLBs/20parts naturalcollisions/sleep persistent. Launch0.508ms afterboundedprewarm62us p95; configure115.9ms load-only, notliveframe. Handoff/manifest TRANSPORT_VEHICLE_DEBRIS_*. FullsceneFPS unmeasured. Inplacedeformation invalidatespreparedcache; reprepareoutsideevent andsinglepartownership/rootauthoritativeevent required. No completecrash/blastLIVEclaim.


Damage source kit frozen: TRANSPORT_VEHICLE_DAMAGE_MANIFEST.json, bindings cca8f5c8 actual497+497PASS, state18081+independentPASS, launch15+15PASS. Canonical per-row receipt rejects coherent tampering. Main/authority/LIVE not integrated; deformation adapter independently being completed by oracle_review. Exact subdivisionf923e74115586+15586PASS handoff deliveredHQ/Root. No Git/GPU changes.

Structural launch frozen2a5dea8c,88author+88parent actualGodotPASS, exactsource12IDs/binary64seed/6sines zero sharedRNG. Handoff TRANSPORT_STRUCTURAL_LAUNCH_HANDOFF.md. Detachedgeometryrefresh benchmark next; no runtimeauthority/spawn/main/LIVE claim.

Deformation reference d4f3113c6178author+6178parentPASS, PERFORMANCE REJECTED: actual68meshes/436044verts94.7-109.3ms apply, worstprep121-154ms. Handoff TRANSPORT_VEHICLE_DEFORMATION_HANDOFF.md. Builtin native stage optimization candidate underway; no timing/content changes/main adoption.

Worker candidate final82be0a376178author+6178parentPASS36.330ms parent,stillPERFORMANCE REJECTED/noadoption. Manifest TRANSPORT_VEHICLE_DEFORMATION_MANIFEST.json lists exactcurrentfiles/sourcekernel. PureC++kernelheaderaf7809ec/cppfbe5ed67/READMEfc11ca5e: source-onlycompileblocked, finiteoverflow/stagingboundscontract fixed. No toolchaininstall/registration/GPU/main/Git. Dirtydebrisrefresh candidate stillbeingmeasured onactualsubdivided damagedgeometry.

Partownership frozen d6194d3a,10038author+10038parentPASS,23.2806us/cycle parent. Strictactualroot metadata/life/tree, atomicleases,sourceNodealiases dedup acrossstructural/trunk/blast. TRANSPORT_PART_OWNERSHIP_HANDOFF.md deliveredRoot/HQ. Purehelper only no visual/physics/HP/event/authority mutation.

Exactdirtydebrisrefresh candidate d2a44539,145author+145parentPASS butactual67k/14dirty/26hulls22.880ms parent PERFORMANCE REJECTED. Nativeclean246measurementPASS verdictREJECT(44.503vs26.408ms+all14supportfidelityfailmax0.1172mm). Frozen1cf791ea unchanged. TRANSPORT_DEBRIS_REFRESH_HANDOFF.md. Nativekernelcompiledependency remainsRoot; noresthull/timing/content shortcuts.

27Sep heartbeat: kernel standalone reproduciblefixture added (export_fixture.mjs/kernel_fixture_data.h/kernel_fixture_test.cpp),384vertices/81supports. Two JS generations byteidenticaldd6b2b82; executed JS Float32-contract positionerror1.192e-7/normal1.445e-6. C++ NOTcompiled/run; noheader/toolchaininstall. Deformationmanifest updatednewREADME+3reprofiles; old82be/headeraf7809ec/cppfbe5ed67 untouched. Subagentsworkingdata-onlyimmutableblueprintcache andexactsourceboundarybinding; no main/GPU/Git changes.

Final standalonefixture header4d1ce750 (supersedesdd6;selfcontainedcstdint andbothsourceSHAs). Twicebyteidentical; JSerrorsunchanged. C++harness also hasinvalidnode andfinite-overflow-output gate; nevercompiled/run. Future damagebindingsadoption requires explicit packedruntime damage_assemblies.json inclusion (currentRoot18b includesonly descriptors/bootstrap; don'teditexport presetsourselves).
## 30 September — isolated wet-exit authority candidate delivered

Frozen `godot/mafiozi_walk/scripts/transport/candidates/transport_wet_exit_authority.gd` SHA `e9b017eb9a9c98f23cc896c69c25d229c730cfa73b304509e4d6eb991a48b241`; correctness test `0c276fd4ce00920a2c23c0f15b825dfd2bd4c76b86d09f9a015a8af06fa52e74`, cost test `72ad623344728d4d1c110f9e8851f24d34d2de472e97217ce174b71c4d3d5fbc`, branch audit `f58a3db8aa7ed7b616f24ada9d6c64cd6f8abe2416b1ce52326f45d8061caa01`, candidate handoff `aa25b6aec264bd36a901d325a9e81dd4af5820fa9c2cc7a125edbb58191b717e`, manifest `b1fbf47f97bb4f4911186ba4a203250765a4fe5c0e7c33a2d3dc8ada24611112`. Author and parent actual Godot 4.7.2 correctness42/42, cost100/100 PASS; independent static review no blocker. Parent isolated Jolt begin-hold p50/p95 772.6/856 us, **not** city FPS. Proof-only pending receipt, no Host occupancy mutation/swim or LIVE claim; Root22 must wire authoritative providers and Host wet branch. Sent Root22 and HQ once. Dry runtime unchanged.

Trunk cargo candidate FROZEN and sent Root22/HQ: `godot/mafiozi_walk/scripts/transport/trunk/transport_trunk_cargo_store.gd` SHA `28f22d9682a653f1d6907d77d5a247d7ae5eb27c20476de7dbd99ceee1075c80`, test `cce2e3fbb22b71e6f3f88e312ec269b1a24fa16f1e9d6a1fa68fa15a37faa895`, `docs/godot/TRANSPORT_TRUNK_CARGO_STORE_HANDOFF.md` `55e0724d8e815926917d4b126835c43e0afeb40bbe86140dd9b902ee0dc4efca`, manifest `1fee8e4016e4526810b5838d0cc05103c5de04a72daca67f3eb117541ecda456`. Author+parent actual Godot4.7.2 5121/5121 PASS; independent final static no blocker; manifest3+8 source pins verified. Parent isolated populated100 transaction p50/p95 1408/3463us max4342us, NOT city FPS. Root bridge isolated actual14 fixture 528/528 PASS, log SHA `a2ac09d50a9dcb251c0c2cf8f0ec65f285c3162c7e823c5e40c0d349c4cff891`; non-AK cost table developer-chosen. Candidate has capacity100, AK15, future corpse100 exclusive reservation, actual target-open+physical-lid evidence, per-item 5mm AABB slots, stable UID/fireState, sealed validation then callback-free paired commits, two-phase destruction retaining cargo until ground reservation, and same-event replay. **CANDIDATE / DO NOT ADOPT** until Root freezes trusted all14 cost/model catalog, renderer/ground pickups/inventory/input bridge and checks loaded scene. Source trunk supplied geometry but no storage; cargo policy is user extension. No foreign runtime/Git/GPU changed.

**Superseding cargo policy, later 30 September:** user clarified that AK15 was only an example. All 14 weapon costs now come from actual model volume, larger models cost more, and one of each totals capacity100. The store removed `AK74_UNITS` and every weapon-specific unit check; Root's catalog is the sole cost authority while the store retains positive1..100 validation and physical non-overlap. Current candidate runtime SHA `276f94cf96c241a4f6c30dc76d76ebc2f996209ae37f502c598dc8d4022c25fb`, test `b12dd6d64ff4a8e957a550fab60a72affb5066c92f3a0e7b81f34ccb7041b0aa`, handoff `88e1849eeb0799bb7ce50ad6b7847a4abb5fe2f9b697f7206b9cb3db21769f7e`, manifest `e49a725b998c6dfe7e20c5481d996788a63485fcb6a2f9523c79302328437168`. Author Godot4.7.2 5122/5122 PASS; isolated costs empty p50/p95 `120.019/126.082us`, populated100 p50/p95/max `1119.5/3029/3352us`, summary `24us`, destruction prepare/validate/commit `1017/21/1163us`. The old bridge receipt is withdrawn because it used the superseded policy. Observed Root catalog `weapon_cargo_sizes.gd` SHA `b1fa3deb908c9c24614b77ce8171f0708324c6779e5d37e540204bd9be244cfe`; Root still owns its bridge/renderer validation and loaded-scene acceptance.

