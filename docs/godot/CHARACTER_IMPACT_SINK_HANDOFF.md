# Common character impact sink — bounded synchronous adapter

New production component `godot/mafiozi_walk/scripts/character_physics/character_impact_sink.gd`, SHA256 `6cdc58298a64ad11f055d9b112e8b70d70c24b7a631cf05260ecceb19fe4d1de`.

Own test `scripts/tests/test_character_impact_sink.gd`, SHA256 `0729547efaea1b8ff9746e2d548858c37840a032c902b3a0f1ef278fde3dbe53`. Immutable policy remains `7cde00d9978e6940952877866fce1f3eedabedd0955414cf878a5987e6923e9b`. Final native test used owner body `822966ac0b03bbb0dbb37085fccf915fdbc11d07d8c6d05bd9035c66f26f58f8`; both dependencies are hashed before/after the test. No dependency on Artist21's unfinished local sampler. No player/main/driver, source producer, HP, authority or transport implementation was changed.

The adapter binds exactly one actor life/session, resolves a caller-owned accepted event, preflights an injected owner endpoint, consumes the unchanged pure policy, and makes at most one endpoint attempt. It never writes a Node, rigid-body momentum, actor transform, skeleton or HP. Real effect ownership stays in the port implementation. Local owner Callables are trusted in-process dependencies; their results are not network authentication proofs.

## Public API and lifetime

```gdscript
configure(binding: Dictionary, profile: Dictionary, ports: Dictionary) -> Dictionary
submit(admission_handle: Variant, physical_input: Dictionary) -> Dictionary
decorate_selected(delta: float, base_selected: Dictionary) -> Dictionary
state() -> Dictionary
dispose() -> void
```

Bind once. New confirmed life/session needs a new sink. Same-life pose/appearance changes do not reset policy/event history. Death is monotonic within this binding: a validated current dead owner or a consumed definitive final-death admission latches `state().requires_dead`. Subsequent alive owner snapshots reject, even after a failed transaction. This is a read-only admission restriction, not an HP/lifecycle write. Public mutations run only on the main thread, synchronously, with a reentry guard. No `_process`, physics update, background work, queue, await, timed retry or fanout is installed. Freed Callable targets reject cleanly. Dispose clears policy, receipts and all six Callable references; dispose attempted from inside an active callback is ignored until its owning host can dispose after that call.

`binding` has exactly four fields: nonempty String `actor_id`, `session_id` (≤256 characters), positive integer `life_generation`, `session_generation`. Integers/epochs are type-exact; no float aliases. The host supplies its actual canonical ID representation and source/native session mapping.

`profile` is exactly the existing policy profile: `mass_kg`, `max_impulse_ns`, `stance_thresholds_mps`. Current physical-owner mass must match it. These are explicit force/reaction tuning, never inferred from HP. The test uses a **TEST_ONLY** 75 kg/1 m/s standing threshold to exercise routes; it establishes no production combat calibration.

## Six required ports

Every port is a valid Callable. Return synchronously without exceptions; only `dispatch` may perform the admitted owner transaction. Preflight is read-only. Clearing/decoration may change only the presentation sampler's own state. Arguments passed to preflight/dispatch are copied so changing a callback argument cannot rewrite the sink's private command or guard snapshot.

1. `current_owner() -> Dictionary` returns the four binding fields plus:
   - `pose_epoch:int>=0`, `pose_owner:String`, `geometry_revision:int>=0`, `physics_tick:int>=0`;
   - `stance:String` present in configured thresholds, `mass_kg:number`, `dead:bool`; optional `recovery_suppressed:bool`, required **true after every final-dead physical commit**;
   - `driver_mode`: `IDLE`, `DONE`, `FALLING`, `GETTING_UP`, `FAULTED` or `DISPOSED`;
   - `transport_state`: `none`, `seated`, `transition` or `exit_physical`, and `transport_token:String` (nonempty while transport-owned);
   - `physical_body_rids:Array[RID]`, at most 16 valid RIDs currently belonging to this actor's physical owner. Use the active actor collider/parts appropriate to the state, not arbitrary scene bodies or another actor's pool.

   The adapter copies only these bounded values. The callback must derive them from current owner records, driver/pose lease and source lifecycle, not from the incoming event. `recovery_suppressed` must read the actual driver/corpse owner's no-recovery state; it is not a submitted assertion or network proof. Normalize actual StringName pose authority to String at this boundary. The sink checks exact owner fields before policy consumption and checks the planned lease after dispatch. `apply_existing` and `observe_existing` must preserve the exact current body RID array, including order; a successful same-lease receipt cannot silently replace its physical pool.

2. `resolve_admitted(handle) -> Dictionary` returns `ok:bool`, all binding fields, current `pose_epoch`, `geometry_revision`, `producer_id:String<=128`, `event_id:String<=256`, `kind` (`bullet`, `blast`, `contact`, `fall`, `melee`), current `world_point:Vector3`, `final_dead:bool`, `authoritative_knockdown:bool`.

   This port resolves an actual accepted source event, including actor/life/context/mesh/triangle validity for stored contact anchors. It re-resolves current posed contact where source requires that. No arbitrary `confirmed` flag or raw hit-power observation substitutes for it. Source HP/death/medical-survival decisions remain external. Sink treats final death as an input/request and writes no lifecycle state.

3. `preflight(route, command) -> {ok:bool, pose_epoch:int, pose_owner:String}` verifies the complete concrete route/contact/rig/force bounds and plans the exact post-transaction lease. Reject unsupported local legs, distance, missing bones, unavailable physical recovery interruption, force beyond endpoint limits, or stale owner. Never move contact to the chest or silently promote it to a knockdown. Existing FALLING and local routes must retain the current lease; physical begin/resume may plan a nondecreasing epoch. Source owner remains unchanged until dispatch.

4. `dispatch(route, command) -> {ok:bool, event_key:String, pose_epoch:int, applied_impulse_ns:Vector3}` performs **one** owner transaction and returns its explicit commit receipt. The event key must match and reported applied J must equal `command.apply_impulse_ns`. Current owner must match the preflight-planned lease; physical dispatch must end in FALLING. A failed/malformed/mismatched receipt is consumed and never retried or routed to another endpoint automatically.

5. `decorate_local(delta, base_selected) -> Dictionary` supplies the injected local spring sampler. `decorate_selected` calls it only for living, ordinary on-foot IDLE/DONE actors with an exact current integer authority_epoch. Its returned validity/epoch and unchanged visual_offset/visual_rotation are checked. The actual sampler/owner must additionally retain base gait/aim, translations/scales and feet/root as in its own contract. The existing actor host remains the only final pose writer. The sink doesn't configure or depend on the unfinished Artist21 implementation.

6. `clear_local(epoch)` clears only local presentation springs when the pose lease changes or physical/transport/death ownership excludes the overlay. It must not clear source replay history or mutate pose authority, actor identity, HP or driver state.

`command` contains `event_key`, copied `binding`, `owner_before`, normalized `admitted`, copied `physical_input`, `reaction`, `action`, `apply_impulse_ns`, `final_dead`, and after preflight `expected_pose_epoch`/`expected_pose_owner`. The `route` is `local` or `physical`; no endpoint runs for `none`.

## Physical input and dispatch actions

Every input has exactly these fields: `delivery` (`command_unapplied` or `solver_observed`), `world_point:Vector3`, `impulse_ns:Vector3`, `physics_tick:int`, `force_profile_id:String<=128`. World coordinates must be finite within ±10 million metres and current admitted contact must agree within 0.1 mm. Tick must equal the current owner's physics tick. Impulse must be finite and within the configured policy bound. A nonempty force-profile label records caller provenance; it does not itself prove force calibration or authority.

`solver_observed` additionally requires `solver_body_rid` belonging to the current owner, finite `post_velocity` (≤80 m/s), `post_angular_velocity` (≤30 rad/s), and `velocity_reference:Vector3`. The supplied velocity must be measured at that reference; adding `omega × r` twice is forbidden. The endpoint validates its actual physical state/provenance, not just membership of a supplied RID.

| State/reaction | Action | New physical impulse |
|---|---|---|
| Ordinary living on-foot local | `local_present` | Zero; presentation receives the original input J as tuning input only |
| On-foot knockdown command | `begin_point_impulse` | Exactly one localized J |
| On-foot knockdown observation | `begin_observed` | Zero; inherit admitted post-solver state |
| Already FALLING command | `apply_existing` | Exactly one J on current body, no restart/local overlay |
| Already FALLING observation | `observe_existing` | Zero, never reapply the reported contact |
| GETTING_UP command/observation | `resume_point_impulse` / `resume_observed` | Owner resumes from displayed skin, then J once / zero |
| Seated or transition | No endpoint; `owner_deferred` | Zero; transport retains lease |
| Existing `exit_physical` FALLING | Existing-body action only | As command/observation above; transport token retained |
| Zero impulse without admitted knockdown/death | No endpoint; `no_reaction` | Zero; event still consumed |

`FAULTED`/`DISPOSED` physical owners reject. Confirmed dead state forces a physical route and prohibits local overlays; the physical owner must suppress recovery for that life. A final-dead dispatch succeeds only if the post-transaction current owner remains `dead=true` **and** reports actual `recovery_suppressed=true`. Missing, false or non-boolean suppression fails closed. The sink does not set either field or fix the body after a failed transaction. An independently admitted final-death/knockdown request may begin physics with zero J; no invented force is needed.

For `begin_point_impulse`, the owner must acquire its physical pose/motor lease, capture the displayed pose, start the prepared body using inherited velocity and **zero uniform outward J**, then apply exactly one `body.apply_impulse(world_point,J)`. Do not use existing `driver.start_fall(v,J/75)` and then add the same localized impulse: that doubles momentum. Existing driver is player-shaped and GETTING_UP interruption needs an owner API; the sink does not call cancel, restore walking collision, teleport an NPC or fabricate that support.

## Receipts and replay limits

Statuses: `no_reaction`, `local_presented`, `physical_applied`, `physical_started` (zero-J begin/resume), `observed_only`, `owner_deferred`, `rejected`, `consumed_failed`. Results expose `consumed`, binding, event key/reaction/pose epoch when consumed, `physical_applied`, `applied_impulse_ns`. An uncertain dispatch sets `may_have_applied=true` and both physical application fields to **null**, so callers cannot mistake an unknown outcome for a safe retry.

Owner/preflight rejection or transport defer is not consumed. After policy consumes, there is one attempt and a terminal receipt even if the endpoint fails. No rollback or fallback can secretly apply J twice. Source producer namespace plus event ID form an unambiguous JSON pair; its hash is the policy's bounded event key. Both local receipt history and immutable policy remember only 64 accepted events. An evicted event can be accepted again: upstream source admission retains durable replay/ordering responsibility, including same-life appearance reloads. The sink is not network dedup.

## Verification and performance

Godot 4.7.2, from repository root:

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script scripts/tests/test_character_impact_sink.gd
```

**1,171 checks PASS** (original 1,138 plus 33 targeted regression checks), clean `outputs/character_impact_sink_test.log`; numeric report `outputs/character_impact_sink_test.json`. Tests cover exact identity/session/life and integer epochs, geometry/contact replacement, nonfinite/stale input, unsupported local preflight, reentry/dispose, freed port owner, uncertain dispatch/replay, zero-J replay, transport ownership, get-up/death routing, 64-entry eviction, unchanged visual metadata and disposal. Added regressions cover command/observed existing-pool swaps; clearing confirmed death; uncommitted final death; absent/false/wrong-type recovery suppression; subsequent new-event revival attempts; and no retry after owner reconciliation.

Independent protocol suite **125 PASS**, `outputs/character_impact_sink_regression/independent_{review.gd,report.json,run.log}`. It is a copy of the reviewer’s exact 125 assertions, changing only its expected sink SHA and report output path; the original review and its three reproduced failures remain in `outputs/coordinator21_impact_sink_review`. Original harness SHA `aabe28d8eb87ae8a270229335e5fc715966a829c8f2157a5ab0dd7970a8956d5`. All three reported post-commit gaps now return terminal `consumed_failed` with `may_have_applied=true` and null application fields, without another dispatch. No author-owned independent test or production file was modified.

Real native 16-body rig verifies one initial point impulse and a second hit while falling: each total momentum error is **5.96×10⁻⁸ N·s**. Already-applied contact observation adds **0** further momentum. Contact/joint/gravity/damping effects are disabled only in this fixture to isolate impulse conservation. Transaction/admission/presentation ports are explicitly test stubs; these tests do not authenticate source events or establish real NPC/transport integration. Observed post-velocity/angular velocity are read from the actual native body.

1,000 local dispatches, including bounded port stubs: p50/p95/max **175/246/393 µs**. Native single samples: begin **1,407 µs**, second hit **306 µs**, observed event **408 µs**. No sink-owned idle loop; host must bound event delivery per physics frame and must not reinterpret this cost as a crowd budget. These are module/fixture CPU measurements; renderer, physics solver workload, whole-scene FPS and LIVE behavior remain unmeasured here. No GPU was launched.

Source melee/bullet/blast producers remain unwired. Audited accepted source paths lack measured J; damage/72, cell push, visualSpeed and authored throw velocity are not substitute momentum. The component can be reviewed and tested now; production combat reactions still need admitted producer/contact contracts, explicit force calibration and real owner endpoints. Root owns the integration decision.
