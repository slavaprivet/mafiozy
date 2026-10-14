# Three-preview-resident owner pause candidate — tools only, HOLD for K

This package derives **the stable Coordinator22 checkpoint**
`PreviewPopulation`, `PreviewResidentHost`, and `PreviewResidentWorldPolicy`
sources into an isolated full-scene stage. It does not
edit production files, `main.gd`, or navigation sources. The stager composes
the separate navigation candidate at its `begin_editor_pause`,
`verify_editor_pause`, `can_end_editor_pause`, `end_editor_pause` receipt API,
including the actual queue owner. It is intentionally
restricted to the three local preview residents; the full default population,
source agenda, authority, save/reload, and active route/job replay remain HOLD.

`build_candidate.mjs` pins both actual source SHA-256 values and injects
owner-held gates before the original mutator bodies. The population lease
begins residents, then policy, then navigation. Failed acquisition verifies
and releases the earlier owners; a failed rollback re-pauses the tree and
enters terminal HOLD. It requires three live admitted bodies and
no resident request IDs. The resident owner captures current body/RID,
collision, all visual-node local transforms, skeleton poses, gait status,
interpolation, walking clock, request/status, owner fields and identities,
source session, manifest and placement data. Rejected writes fault the lease;
teardown is terminal. Verification uses the *owner-held* snapshot, not the
incomplete public `snapshot()` API. Policy lifecycle, access state,
`dead_seen`, source floors and query state are also captured. After unpause,
all three owners must pass an unpaused `can_end_editor_pause` preflight before
any release/replay; a failure re-pauses into terminal HOLD. End is synchronous
before the next physics tick; nav is released while residents/policy remain
gated.

Static source tests: `node tools/godot/map_editor_resident_pause_candidate/test_source_patch.mjs`
returned **74 checks, no failures** against checkpoint pins, including the
queue-drift negative and stale-completed-lease guard.
`node --check`
passed for the builder. Derived SHA-256: resident
`e28e920182913feed9836d97792bb4b7c4d3c7248abab593326c0ca5d65427be`,
population
`4931d6c609b4167e603cf18b6cffab7743d61f03b722809c42053f370d9cd380`,
policy
`b87dcba6d14394d0d21ea9528a7876306b3f5fc05c6866a9c5c62856d9ea74ef`.
`stage_actual_population.mjs` now pins the entire 192-file checkpoint closure
(`cbd718...`) and the three original nav owners, overlays the patched host,
queue and backend together, and reports their SHA-256 values. Its source-only
dry-run passed on that exact closure with no stage created.
Fresh isolated native stage `outputs/map-editor-resident-pause-fJ178S` imported
with Godot 4.7.2 headless exit 0. The positive fixture passed **12/12**
(including a second K-style pause after a completed lease); the negative
fixture passed **22/22** (including a real failed rollback held behind a
paused tree). Both returned exit 0. The first native run on the previous
stage exposed two defects: stale `end_editor_pause` poisoned the next lease,
and a fault-injection fixture dropped its original policy before acquiring
the resident. The source guard and fixture were corrected, then a **new**
stage was built and imported for the passing rerun. This is only the
three-resident preview seam, not the full editor or loaded-game FPS. The open
production game was not changed; GPU/LIVE remain out of scope.

This candidate is **not a complete K lease** even if its native fixture passes.
The current queue owner exposes writable `dead` and other route fields;
`CharacterBody3D` transforms can be written directly; and interior door
commands may change and revert without a revision. A→B→A changes entirely
between verifications cannot be detected by a current-state receipt. The
three-resident owner also exposes its host/owners publicly. These upstream
owners need monotonic mutation revisions or scoped write capabilities before
exact no-mutation-history admission can be claimed. The candidate rejects
known direct mutator calls and detected current drift; it must not be wired
to production or called default-residents K-ready.

Checkpoint source pins: population `4c25bf...`, resident `018e0a...`, policy
`f4e350...`. Moving production NPC/weapon sources are intentionally excluded;
this candidate cannot silently follow them. The separate nav candidate now
exposes read-only unpaused `can_end_editor_pause` at host, queue and backend.
The native fixtures exercise its checkpoint composition, not active routes.
The host releases queue before
backend replay, but a late backend refusal after queue release cannot be rolled
back atomically and forces terminal HOLD. No full-cohort or K approval follows.
