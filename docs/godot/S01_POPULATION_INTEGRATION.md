# Population integration checkpoint — 27 September 2026

Root wired `preview_population.gd` into main behind **default OFF**
`preview_residents_enabled` / `--preview-residents`. The existing visible
compact14b game PID45824 is unchanged. This is not a live-city completion.

The root owns the navigation queue, current source permissions, resident bodies,
door occupancy collection and invalidation before the first accepted door turn.
Cold visual admission runs during startup after physics has received colliders.
Scene teardown disposes the resident host, navigation, queue and policy.

## Evidence that changed the next step

The earlier 73-check host test used a player surface guard. That guard allows
roads, whereas ordinary native `npcWaypointOk` rejects them. All three pinned
e926 initialization candidates are on tile0 / roadMask1:

- resident_72: r9.5, c76.5
- resident_169: r4.5, c106.5
- resident_252: r12.5, c104.5

These rows still have `_npcInitialPlacementPending=true`; the packet explicitly
ends BEFORE_NATIVE_RESOLVER. Physical floor support alone does not admit them.
The new world policy correctly leaves all three invisible/PENDING_PLACEMENT.
Root actual-main test: eight fail-closed checks PASS, movement gate explicitly
NOT_RUN_PENDING_SOURCE_PLACEMENT. See outputs/population15_main_pending.log.
Do not describe the old permissive walk test as ordinary source-policy parity.

The real source initial-placement algorithm (world.html around9380) performs
bounded round-robin radial search, checks source body clearance and .55-cell
spacing against the full NPCS/cityCops/worldCops context (including skipped
nondead actors). Artist21 is preparing the exact same-session context and source
oracle. Three chosen rows alone cannot reproduce that spacing state. Preserve
immutable birth descriptors and apply placement to a separately admitted runtime
state only after the actual algorithm authorizes it. Do not invent free points.

Actual source intent audit further establishes that after hypothetical admitted
placement, 72 and252 choose walk while169 chooses drive, with zero initial RNG
draws. Current pending rows choose nothing. A drive owner, source agenda/retained
search, continued source clocks/RNG and long-distance target admission remain
needed; 2m ping-pong would not preserve the source behavior. See
PREVIEW_RESIDENT_INTENT_HANDOFF.md.

## Packaging

Exact prepared runtime closure is in
outputs/coordinator21_npc_export_closure.json: three bundled SCNs, not the three
historical unreferenced scenes. Original GLBs are unnecessary for this runtime.
Standalone cache verification: 61 checks PASS, all three real rigs instantiated.

First export residents15-gate produced exact SCN/packet/manifest bytes, but
actual PCK verification FAILED: Godot compiled away the raw loader/float bridge
scripts despite include_filter. The cache uses their exact SHA receipts.
The pinned addons/npc_source_receipts export plugin now includes just those two
original source byte streams while preserving compiled script loading. Actual
residents15-gate2 PCK: 514 checks PASS, all three cache actors construct with
exact bytes and identities. PCK SHA d2927fc8fc72ec9500ce8a8401592f277de44f06c0f9427f67987748d36278ad.
The negative isolated mutated-source export adds neither raw script; runtime
receipt admission rejects it. The export callback cannot abort the engine, so
external PCK validation remains required. See outputs/coordinator21_npc_pck_gate_review.md.

Gate2 editor scanning reported one Unexpected NUL warning before class
registration. Audit of366 current text resources found no NUL/invalid UTF8;
actual PCK runtime has no parse/leak warnings. Cause remains unresolved, do not
call the warning proven harmless. This packaging PASS does not admit placement.

## Other active dependencies

- Physics unified handling candidate AE4D... remains outside production;
  current accepted body is a382. Boarding camera jerk is a separate user report
  under per-frame transition telemetry, not covered by moving-exit LIVE PASS.
- Traversal package has physical/headless evidence but still requires the root
  player/rig integration and sole-window LIVE.
- Editor owner is preparing scripts/map_editor; root K/geometry invalidation
  hookup is held for that package. No duplicate GPU game is authorized.
- Paused cloud/Astra assignments remain paused. Existing local authors continue.

Last verified remote checkpoint: 3ab358711d1763579c116905d9b225b4e4cc3db6.
This population work is newer uncommitted integration work, not that checkpoint.

### 02:55 MSK: visible camera16 refresh

User asked ETA/new scene and showed Godot project.godot external-change modal plus transient map_editor parse errors. Root accepted Reload with focused Enter, confirmed editor_controller check-only PASS (owner already renamed Panel to EditorPanel). Editor owner ordered to keep unfinished writes outside res and freeze until parsechecked. No old game existed on fresh inventory. New sole sourcegame PID24040, revision s01-20260927-camera16; notes updated to actual changes, residents explicitly in work/default OFF. Boarding camera fix now resets world orbit basis after each transport tick. Independent same4seats21checks: unintended rotation eliminated (camera angle0), worst perframe shift .321m→.062m matchesphysicalpivot; seated endpoint .016m unchanged. Optional GPU boarding trace pending, source scene newlyopened foruser. Evidence before/after outputs/coordinator21_vehicle_liveqa/board_camera_trace*.json.
