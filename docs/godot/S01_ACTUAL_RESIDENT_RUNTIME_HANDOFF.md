# Three actual source residents: runtime package

The corrected deterministic NEW_SESSION ordinary factory and native presentation assets are ready for root host integration. Residents are **pending physical placement**, not yet LIVE gameplay. No old save/session is imported.

All runtime assets are now copied with verified bytes under `godot/mafiozi_walk/assets/npc_visual/session/`. Complete exact file/size/SHA list: `outputs/astra21_npc_runtime_ready/DELIVERY_RECEIPT.json`. Include only referenced assets; older unreferenced/test files are not residents.

| Runtime file | Trusted SHA256 |
|---|---|
| e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096.json | e9262db60404e538636274565b9a1d6d79de487804af9c7ee99646209b58e096 |
| visual_manifest.json | 37d56f98aeaa3f5d1152a09cdf14744223ae697e7c56ad85ea75941b74552de6 |
| prepared/manifest.json | 3c07e72938a0918fa32de33ca442bf07cb50f21f0916b8b091b552473bd9aac0 |

| Original bridge ID | Descriptor SHA256 |
|---|---|
| npc_resident_72 | fb812a2fc447726dd30548edb34805295ac28e6970c2ca55a6abb18a5a4c39bd |
| npc_resident_169 | 95da9c8fd81bd5d0b9f68643a8b3309cff70bd9ec6989b8b2a49b97956a3d136 |
| npc_resident_252 | 63013b43b2210fd997d9a57fd8b1fa315312bd2ff3e1387e115f667e6db75b55 |

## Native API and ownership

Provider SHA `017d46e68a629516703cb9899169d1c688b29a4d3aa996d44c49bc1b01ac0efa`: `load_verified(packet_bytes, externally_trusted_sha, trusted_sources)` returns a pending provider. Candidate/session copies are private; first_admitted remains HOLD. The trusted source hash map must come from the independently accepted source/build receipts, not arbitrary self-declared input.

Cache SHA `16a29e700dc78d5006461d1ee509dc1894830ced1e67fd006e3a4207382bd4a7`: `load_verified(prepared_manifest_bytes, trusted_prepared_sha, bridge_id, exact_descriptor_sha, "res://assets/npc_visual/session/prepared")` returns `{ok,cache}`. `cache.instantiate_actor()` creates private visual/Skeleton/Mesh/Skin/material/metadata and returns descriptor/rig references. No scene insertion or physics. Caller owns visual.free; cache.dispose preserves live caller-owned actors.

Loader SHA `6e8f9c0c5e55ed0b18cdd590ad4e30141108fd73b96a93a078a70b16763bac54` also loads admitted GLBs. Float bridge and candidate shader are OFF in these prepared scenes. No rendering fidelity/FPS claim is made.

Root's separate `preview_resident_host.gd` scope is agreed: actual native body/support/collision/navigation admission, original identity/appearance preservation and host lifetime; root alone wires main and updates the one game. It must not use guessed ground Y or reinterpret pending flags as body-clear. Runtime session identity must be reconciled with root/transport; packet session is explicit source provenance.

## Evidence

- Corrected exporter own6427 checks and18 negative configs; independent151 checks plus separate process exact replay. `outputs/astra21_npc_bootstrap_review/v2/REVIEW.md` and source handoff `outputs/astra21_npc_preview_session/CORRECTED_HANDOFF.md`.
- Pending provider independent60 policy checks and46 actual corrected-packet checks. `outputs/astra21_npc_preview_provider_review/ACTUAL_PACKET_REVIEW.md`.
- Native cache independent2915 checks on the current helper, all19 original catalogue baselines/private mutation/negative policy. `outputs/astra21_npc_visual_cache_review/REVIEW.md`.
- Copied **three actual session** visuals/cache: parent43 actual Godot checks PASS/exit0, exact source descriptors/private28-bone rigs/no scene insertion/zero admitted bodies. `outputs/astra21_npc_runtime_ready/result.json`, reproducible test alongside. First instance observations4.866/5.259/5.233ms CPU; three observations are not FPS/percentile evidence.
- Independent final copied runtime package: 370 actual Godot checks PASS/exit0. All three GLB and current referenced native scene byte hashes, full-precision descriptors, fresh GLTF baseline arrays/transforms/material flags, private A/B/C mutation/free/disposal and metadata were checked. `outputs/astra21_npc_runtime_ready_review/result.json`. Bodies remain unadmitted; no scene/GPU changes.

## Precision defect and preserved rejection

The first resident prepared manifest `5ef1d368...` failed admission because default Godot JSON serialization rounded randomized height while descriptor_json retained original full precision. Prepare tool now uses `JSON.stringify(manifest,"\t",true,true)`, SHA `40abe34b3d9187c7166cd22bf3496cfaa29fbafed9a959e1efae80e9db89ff71`. Focused13 checks demonstrate default rejection and exact corrected acceptance; no tolerance, source descriptor or fingerprint was relaxed. Use only final prepared manifest `3c07e729...`. Initial failed evidence is retained in the runtime-ready output directory.

Historical source packet384f... remains rejected for missing source startup business collisions. Corrected source executes real business cache10/true, native null-traffic door initializer, renderer config assignment, source garden gatefalse and full MAP unchanged; explicitly records startup clock721 then authorized injected720 and RNG boundary BEFORE_ORDINARY_INIT_LOOP. It produces288 full residents before crop,6356 source RNG draws and three cropped IDs. Coincidentally unchanged roster bytes do not substitute for the corrected phase proof.

## Remaining gates

Root physical placement/main/controller and LIVE are still required. Agenda/budget/bank/hospital/service sellers/server rules/full-city behavior are not completed by this visual package. User entrance/exit trapping and curb stepping requests were delivered to root and Traversal owner for separate implementation.

Export owner must include these exact dynamically loaded resources and preserve Loader/Bridge original dependency byte receipts (or separately approved build-bound receipt mechanism). Compiled standalone cache admission remains untested. CPU/headless cannot replace LIVE or full-scene FPS.
