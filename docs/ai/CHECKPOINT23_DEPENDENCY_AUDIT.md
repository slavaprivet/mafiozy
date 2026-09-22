# Checkpoint 23 — dependency audit

Date: 2026-09-23. Base HEAD: `527e9c0928d4773b023a62b2e5c655340b37b8df`.
Read-only production audit; only this report was created. No staging, commit,
push, backend import, credential access, database access, or browser launch.

## Result and scope

The current delta needs **25 modified tracked runtime files plus 14 new runtime
dependencies: 39 production paths total**. This is the minimal complete file
set for preserving ALL currently modified runtime behavior, not a claim that
all changes have passed gameplay acceptance. Existing tracked transitive
dependencies and models are already present at HEAD and need no additional
staging solely for this checkpoint.

Static traversal covered literal local ESM import/export/import(), script src,
and Python local-module imports. Added resource/loader lines were inspected
separately; they introduce no new image/model/JSON/wasm asset. Bare
`three/addons/` imports are resolved by the existing import map, not missing
repository files. The SkeletonUtils import example in a vendor comment is not
an executable dependency. Computed runtime URLs and network availability are
outside a static closure guarantee.

**Do not use `git add .` for this set.** Old outputs, candidates and unrelated
tools are not production dependencies.

## Exact modified tracked production paths (25)

```text
_preview_ws_server.py
assets/maps/city_rebuild_v1/ambulance_transport.js
assets/maps/city_rebuild_v1/artist14/wet_clothing.mjs
assets/maps/city_rebuild_v1/blast_response.mjs
assets/maps/city_rebuild_v1/civilian_parking_trip_source.js
assets/maps/city_rebuild_v1/hero_artist14_surface.mjs
assets/maps/city_rebuild_v1/hero_walk.mjs
assets/maps/city_rebuild_v1/npc_actor.mjs
assets/maps/city_rebuild_v1/npc_combat_session.js
assets/maps/city_rebuild_v1/npc_contact_ray.mjs
assets/maps/city_rebuild_v1/npc_melee_contact.mjs
assets/maps/city_rebuild_v1/npc_phone_visual.mjs
assets/maps/city_rebuild_v1/npc_population.mjs
assets/maps/city_rebuild_v1/npc_runtime_inspection.mjs
assets/maps/city_rebuild_v1/npc_social_pose.mjs
assets/maps/city_rebuild_v1/npc_source_lifecycle.mjs
assets/maps/city_rebuild_v1/npc_vehicle_hijack_source.js
assets/maps/city_rebuild_v1/npc_vehicle_pose.mjs
assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs
assets/maps/city_rebuild_v1/walk_preview.mjs
assets/maps/city_rebuild_v1/weapon_effects.mjs
assets/maps/city_rebuild_v1/world_walk_combat.mjs
assets/maps/city_rebuild_v1/world_walk_melee_host.mjs
mafiozi_bot.py
world.html
```

## Exact required new production paths (14)

```text
assets/maps/city_rebuild_v1/hero_contact_ground_bound.mjs
assets/maps/city_rebuild_v1/npc_blast_ground20.mjs
assets/maps/city_rebuild_v1/npc_blast_parts_prototype20.mjs
assets/maps/city_rebuild_v1/npc_blast_presentation20.mjs
assets/maps/city_rebuild_v1/npc_blast_record20_source.js
assets/maps/city_rebuild_v1/npc_death_entry20.mjs
assets/maps/city_rebuild_v1/npc_death_pose20.mjs
assets/maps/city_rebuild_v1/npc_death_presentation20.mjs
assets/maps/city_rebuild_v1/npc_death_profile20.mjs
assets/maps/city_rebuild_v1/npc_death_record20_source.js
assets/maps/city_rebuild_v1/npc_ground_correction_memo.mjs
assets/maps/city_rebuild_v1/npc_inspection_export.mjs
assets/maps/city_rebuild_v1/npc_surface_diagnostics.mjs
npc_robbery_receipts.py
```

### New dependency edges

All relative names in this table are under `assets/maps/city_rebuild_v1/`,
except the explicitly named root files.

| Consumer | Required new dependency |
|---|---|
| `hero_walk.mjs` | `hero_contact_ground_bound.mjs` |
| `npc_actor.mjs` | `npc_death_entry20.mjs`, `npc_death_pose20.mjs`, `npc_death_presentation20.mjs`, `npc_ground_correction_memo.mjs` |
| `npc_death_presentation20.mjs` | `npc_death_profile20.mjs` |
| `npc_blast_presentation20.mjs` | `npc_death_profile20.mjs` |
| `walk_preview.mjs` | `npc_blast_parts_prototype20.mjs`, `npc_blast_presentation20.mjs` |
| `npc_blast_parts_prototype20.mjs` | `npc_blast_ground20.mjs` |
| `npc_population.mjs` | `npc_surface_diagnostics.mjs` |
| `npc_runtime_inspection.mjs` | `npc_inspection_export.mjs` |
| root `world.html` | `npc_death_record20_source.js`, `npc_blast_record20_source.js` via ordinary synchronous script includes |
| root `mafiozi_bot.py` | root `npc_robbery_receipts.py` |

The blast parts file named **prototype** is already imported by Walk. Excluding
it on its filename alone would break module loading. Conversely a plausible
helper name does not prove connection to the runtime.

## Python: static-only result

- AST parsing passed for `mafiozi_bot.py`, `_preview_ws_server.py` and
  `npc_robbery_receipts.py`; none was imported or executed.
- The sole added import in tracked Python files is
  `mafiozi_bot.py -> npc_robbery_receipts`.
- The new helper imports only standard-library `math`. No extra pip package
  or requirements change is introduced by these deltas.
- All seven referenced helper functions exist: `ensure_schema`, `begin`,
  `report`, `active`, `confiscate`, `resolve_released`, `bribe_latest`.
- `init_db()` now calls `ensure_schema(db)`. The helper creates an additive
  receipt table/index and copies eligible legacy rows with INSERT OR IGNORE;
  static inspection is not a migration or replay correctness test.
- `_preview_ws_server.py` has its own in-memory receipt changes, with no new
  import. Preview behavior alone cannot validate durable server receipts.
- `test_player_rpg_route_contract21.py` imports the real backend under mocked
  I/O guards. It was deliberately **not run by this audit**. It is an RPG
  authority audit and does not replace receipt migration/replay tests.

## Checks actually performed in this audit

Environment: Node `v26.1.0`, Python `3.14.4`.

- `node --check` passed for all **35** JS/MJS files in the 39-path manifest.
- `ast.parse` passed for the **3** Python files above.
- `python check_world.py world.html`: **7 inline script blocks passed**.
- No manifest file changed during the syntax-check pass.
- Required local dependency files exist. No missing new runtime dependency
  was found on disk. They remain untracked until explicitly added.
- Behavior, visual quality, loaded-scene CPU/GPU/FPS and server migrations were
  **not tested by this audit**. Root and scoped owners run those checks.

## Suitable checkpoint verification files

Run from the repository root. This is a recommended verification manifest,
not a declaration that the tests below were rerun here.

### Existing tracked tests with modifications to retain

```text
assets/maps/city_rebuild_v1/test_npc_lifecycle.mjs
assets/maps/city_rebuild_v1/test_npc_phone_visual.mjs
assets/maps/city_rebuild_v1/test_npc_population.mjs
assets/maps/city_rebuild_v1/test_npc_social_pose.mjs
assets/maps/city_rebuild_v1/test_npc_traffic_binding.mjs
assets/maps/city_rebuild_v1/test_npc_vehicle_access.mjs
assets/maps/city_rebuild_v1/test_npc_vehicle_hijack_source.mjs
assets/maps/city_rebuild_v1/test_npc_vehicle_transition_continuity.mjs
assets/maps/city_rebuild_v1/test_world_walk_combat.mjs
test_npc_hold_up_cash18.mjs
test_npc_suspicion_dispatch.mjs
test_world_walk_melee.mjs
```

### New tests directly relevant to connected behavior

| Package | New tests to review/include with its changes |
|---|---|
| Native RPG and physical blast | `test_rpg_native_impact21.mjs`, `test_rpg_flight_integration21.mjs`, `test_walk_local_blast19.mjs`, `test_walk_vehicle_blast_exposure20.mjs`, `test_gas_station20.mjs` |
| Death source/presentation | `test_npc_death_record20_source.mjs`, `test_npc_local_death_extension20.mjs`, `test_npc_death_profile20.mjs`, `test_npc_death_pose20.mjs`, `test_npc_death_integration20.mjs`, `test_npc_death_entry_origins20.mjs`, `test_npc_death_clock_persistence_prototype20.mjs` |
| Death ground/continuity | `test_npc_ground_correction_memo.mjs`, `test_npc_death_ground_integration20.mjs`, `test_npc_vehicle_death_continuity20.mjs --require-fixed`, `test_npc_prone_settle_prototype20.mjs`, `test_npc_blast_survivor_priority21.mjs` |
| Blast parts | `test_npc_blast_record20_source.mjs`, `test_npc_blast_ground20.mjs`, `test_npc_blast_parts_ground20.mjs`, `test_npc_blast_parts_prototype20.mjs`, `test_npc_blast_presentation20.mjs`, `test_npc_blast_runtime20.mjs` |
| Transport | `test_ambulance_loading_ownership20.mjs`, `test_npc_vehicle_door_fleet20.mjs`, `test_vehicle_entry_pending23_audit.mjs` |
| Gestures and profiling | `test_npc_gesture_exit20.mjs`, `test_npc_reading_exit20.mjs`, `test_npc_wet_dry_cost.mjs`, `test_npc_surface_diagnostics.mjs` |

Names in the table are under `assets/maps/city_rebuild_v1/`.
Additional new root tests: `test_melee_ground_bound19.mjs`,
`test_melee_lowfps_contact19.mjs`, `test_npc_native_beach_eligibility19.mjs`,
`test_npc_route_replay_diagnostics19.mjs`.

Important test-only closure:

- `test_npc_blast_parts_prototype20.mjs` imports the **new**
  `assets/maps/city_rebuild_v1/npc_blast_parts_sync_reference20.mjs`.
  Include that file only as its test reference, not as a runtime dependency.
- `test_npc_native_beach_eligibility19.mjs` reads the **untracked**
  `outputs/npc19_live_pending_walk_20260920.json`. If retaining this test,
  explicitly include this single fixture or have its owner relocate the fixture;
  do not add the entire outputs tree. The compressed collision fixture it also
  reads is already tracked.
- Actual GLB tests generally depend on the external local Three vendor directory
  `D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor`.
  It exists on this machine but is not a checkout dependency. Some tests accept
  THREE_VENDOR_ROOT; others hard-code it. A clean checkout on another machine
  needs a supported vendor setup before these tests are reproducible.
- Several filenames containing prototype now test **production** actor behavior
  with an in-memory baseline rollback. Do not reject those solely by name.
- Existing `test_world_walk_melee_host.mjs`, `test_npc_melee_contact.mjs`,
  `test_weapon_effects.mjs` (if selected by owner), and
  `test_blast_response_matrix_scope.mjs` cover adjacent unchanged contracts.
- Follow-up on 23 September closed the direct receipt-test gap:
  `test_npc_robbery_receipts23.py` now passes 17 real in-memory SQLite scenarios;
  see `NPC_ROBBERY_RECEIPTS23_VALIDATION.md`. Include this root test with the
  receipt helper. No dedicated test referencing `createInspectionExport` was
  found during the original audit. The changed hold-up test reads Python source
  and is not itself a durable-receipt database test.

## Exclusions from the minimal production set

These current untracked helpers are **not imported/connected** from the changed
runtime closure; preserve them on disk but do not stage them automatically:

```text
assets/maps/city_rebuild_v1/native_site_control.mjs
assets/maps/city_rebuild_v1/native_site_local_authority.mjs
assets/maps/city_rebuild_v1/npc_blast_palette_prototype20.mjs
assets/maps/city_rebuild_v1/npc_blast_parts_sync_reference20.mjs
assets/maps/city_rebuild_v1/npc_garment_cut_cap20.mjs
assets/maps/city_rebuild_v1/npc_incoming_melee_host19.mjs
assets/maps/city_rebuild_v1/npc_pick_visibility.mjs
assets/maps/city_rebuild_v1/vehicle_entry_hold_clock23_candidate.mjs
npc_native_visit_hybrid_candidate19.mjs
npc_native_visit_hybrid_preload19.mjs
_probe_wander_target1.mjs
```

The sync reference exception for its test is stated above. Also exclude
`.blast_source19.tmp`, broad `outputs/**`, tools/ai_pipeline artifacts and
unrelated design images from a minimal runtime checkpoint. In particular,
the modified tracked
`outputs/interiors_resume/ladder-discoverability-results.json` is an old
output report, not a new Walk import. Docs may be selected independently as
handoff evidence; they are not startup dependencies.

## Blockers and limits to communicate

1. **Packaging blocker if omitted:** all 14 new runtime files must accompany
   their consumers. Their presence in the dirty workspace is not sufficient
   for a pushed checkpoint.
2. **Server integration limit:** the follow-up
   `test_npc_robbery_receipts23.py` passed 17 isolated real SQLite scenarios for
   migration, two legitimate cycles, old-ID retry, cross-NPC conflict, UID
   isolation, reconnect, terminal replay and transaction failures. This closes
   the helper validation gap for the recorded hash. Actual packet admission,
   preview/server parity and real deployment remain separate owner checks.
   The real database was not accessed.
3. **Known diagnostic wiring gap:** `createNpcRuntimeInspection` accepts
   `getActorState`, but current Walk construction does not pass it. Exported
   `presentation.state` will be null, so this export cannot yet supply the
   requested complete actor fixture. This does not prevent gameplay startup.
4. **LIVE acceptance remains open:** root/artist must reload the one authorized
   game, confirm normal startup, player car entry/exit/re-entry, moving NPCs,
   low-FPS melee, RPG ground/direct hit, C4 and car blast, medical crawl/death/
   ambulance ownership, then measure the same loaded scene. No claim that this
   checkpoint fixes lag is established by these syntax/dependency checks.
5. **Candidate is not a shipped fix:** hold-clock23 candidate is not imported;
   shipping current `walk_preview.mjs` ships the pending receipt poll fix,
   but does not by itself ship the separate hold-clock proposal.
6. Snapshot is time-bounded. Shared owners may edit after this report; compare
   the hashes below before using this list for a final checkpoint.

## Audited production SHA-256 snapshot

```text
807fdc9196b220747444b2ad4c12fd4ce2f5d22ba23f57c4c8e0a52e6e19d792  _preview_ws_server.py
01c5d80883a93118ee7ecc0f83ca7b5dce5ed2fe05087bddf779cc9b0b7e3732  assets/maps/city_rebuild_v1/ambulance_transport.js
4c72f99611e45e825ba5c62d7e1c36ba7e3619ee17fe325e05fb02768619426d  assets/maps/city_rebuild_v1/artist14/wet_clothing.mjs
e4ef825a22a06515defa8c7f87f99c2633b4b26a432ffb08ebe06f82c5b77112  assets/maps/city_rebuild_v1/blast_response.mjs
28c623c0e61debb9b0e56e970e9fa64f51b1547cb865a0a6d327642d5dec7e4a  assets/maps/city_rebuild_v1/civilian_parking_trip_source.js
30de352fc12723343aafad5c7b04a3a46a40f417a246953f85bc60c48b0af243  assets/maps/city_rebuild_v1/hero_artist14_surface.mjs
3ac28174104aeab81d7a7458a18a8a109e132be72a00d7f7ae90cc6eee90b749  assets/maps/city_rebuild_v1/hero_contact_ground_bound.mjs
60ad2135010926f9fe1f18c62a89a877eb2547c708b723d7926f513043cc28c3  assets/maps/city_rebuild_v1/hero_walk.mjs
f3c0db20cefe08e927d088dcaece076511cf159779db7e752833bf2999e47b7b  assets/maps/city_rebuild_v1/npc_actor.mjs
98b2cc69ebd95b2187489b7447f25b2c567a0e2aab9cddcb812819df5a5b4f50  assets/maps/city_rebuild_v1/npc_blast_ground20.mjs
4844c2e3b96e417036eafae505b269a5a171d905e3fb6233b8323d97c5782e6d  assets/maps/city_rebuild_v1/npc_blast_parts_prototype20.mjs
9dd9afc9beb231958fbd9f7cc32eae0646185ec75f7abef07fefeb4ce4120223  assets/maps/city_rebuild_v1/npc_blast_presentation20.mjs
3c9469433dfbf77b1ce1d6fc3e96dccd1f5f5d5185f4a2d874bda271ea432310  assets/maps/city_rebuild_v1/npc_blast_record20_source.js
e18b723165196501b57dc04d6f88aabd2dcedcb3277314d530fdb796e267cd66  assets/maps/city_rebuild_v1/npc_combat_session.js
f1507e1e5ac0007efd32e95dcddfc172badd86917791112dfa5448afc5d5df4f  assets/maps/city_rebuild_v1/npc_contact_ray.mjs
ba67380282e04544822bb72632556ff09a5382245c56f5190b310cbff838d564  assets/maps/city_rebuild_v1/npc_death_entry20.mjs
501887edc93e7ccce0c8207f691277c77912511d160b915b304cc2cf20d1f74b  assets/maps/city_rebuild_v1/npc_death_pose20.mjs
e55282d46630479d27dba57cb2d7923f5731171f8a739cffa62617397933f8e3  assets/maps/city_rebuild_v1/npc_death_presentation20.mjs
45fada00da64f49a9a36d755cb00347a1fac5ee91d9b5611587014e3929a5d96  assets/maps/city_rebuild_v1/npc_death_profile20.mjs
a48ecad1eb598bc1ffac0436c31360728c69223b1ec15de6ef12277ea3dfc38a  assets/maps/city_rebuild_v1/npc_death_record20_source.js
5815e1e7d4553545d97bb3434b051ad9e9e5d2a4a38c06a469e524802a755397  assets/maps/city_rebuild_v1/npc_ground_correction_memo.mjs
944bcc8e4de26e6e7386b644b855792ca5c7ba8190b5f6f7afc59709d0b4ced8  assets/maps/city_rebuild_v1/npc_inspection_export.mjs
7897c26dbfd541e0170bea6cacb7924d6ac20675782103be8da532d31f6e001c  assets/maps/city_rebuild_v1/npc_melee_contact.mjs
2e8c050ee8be70eb3b55ab956bcc17f5ca0e9e51999b4ed83ac18e1fccd3ddeb  assets/maps/city_rebuild_v1/npc_phone_visual.mjs
fc3c4cc243ccb7700526b6680fa7ee83e7fbad9e83798880458cb1dd8c0816ad  assets/maps/city_rebuild_v1/npc_population.mjs
5c773a6cbd60af59104c845773fef9c6e481b5c35df6ae5f3ff1cd7b3ba7a937  assets/maps/city_rebuild_v1/npc_runtime_inspection.mjs
36fb317a2aa654275a1cc43e3c5c33ea20bff9673e11f67c4ea6aa245e9060f9  assets/maps/city_rebuild_v1/npc_social_pose.mjs
e2ffa20660b666f9fe993b3ccaed150107789dee6b3456e2e77dc4732d7940e5  assets/maps/city_rebuild_v1/npc_source_lifecycle.mjs
a617a2d7c3b25a8d139ea9661b19b00bc12bb17eeef09180a25a3f58a04749c7  assets/maps/city_rebuild_v1/npc_surface_diagnostics.mjs
bf5d215d4d09368adf88eef8e9873ddfce27b8e438ea46f791416c59cfb09691  assets/maps/city_rebuild_v1/npc_vehicle_hijack_source.js
81619479361a6e0a691122503315c74ce958c89d47c84c80e0468d4f9c148f6b  assets/maps/city_rebuild_v1/npc_vehicle_pose.mjs
5dcec7102fc425c7828239ad5de10d4feb29ff7216610fc842333894f811545c  assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs
109f388b7e64143b5c703d2d01ef4611c1e6f297369a62e1abe9d333646a9c05  assets/maps/city_rebuild_v1/walk_preview.mjs
4dfa7adf47309b89dd1b87bb0776abd1b2385c15c24256b749b7c71dfa9ff7ec  assets/maps/city_rebuild_v1/weapon_effects.mjs
5c63d1ae01b033d28f9a22728a3a715821cf4f70e4b74c42b42810e70a5c3851  assets/maps/city_rebuild_v1/world_walk_combat.mjs
591f331302672f9436bba7a7f4981762b7dc74e5668dc96b0cf3cc2c2f6f11ab  assets/maps/city_rebuild_v1/world_walk_melee_host.mjs
70c251e827d06bc282285a7f9660466ff2524b0b06363943679e845b34d11ec0  mafiozi_bot.py
01ef45d78576f8b9537bbb4deffc764dd863104ee97f580cf8647c6b2a1a0aa6  npc_robbery_receipts.py
9eff15e19fe3665e3365da8437ebfb28f87812bc2acb212dced0800eac0f0e70  world.html
```
