# WALK melee admission and pending state — 27 September 2026

This package ports the actual local WALK attack-state branch from `world.html`.
It can connect native input to source-selected animation. It is **not complete
combat**: target authority, real contact/ref/collection validation, HP,
witnesses, medical/death, network dispatch and confirmed physical impact remain
with the real host owners. No main/player/target lifecycle files were changed.

## Delivered files and source identity

- `godot/mafiozi_walk/scripts/combat/melee_attack_source.gd`
  SHA256 `1127d5eba2139af8b01df56c77f67dc32e66fb055252810d92b440d46e3bffc4`.
- `godot/mafiozi_walk/scripts/tests/test_melee_attack_source.gd`.
- `tools/godot/build_melee_attack_source_oracle.mjs`.
- `godot/mafiozi_walk/scripts/tests/fixtures/melee_attack_source_oracle.json`.
- Evidence: `outputs/coordinator21_melee_attack_source/report.json`.

Original `world.html`: 5,109,059 bytes, SHA256
`9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5`.
The generator extracts and executes these original slices with only CRLF→LF
line-ending normalization; per-slice UTF-8 SHA256, byte length, start/end markers,
observed raw SHA256/length and line ranges are recorded in the fixture/report.
The full-world observed hash above is provenance, not an unrelated-file gate.
Tests require the four exact canonical slices and their unambiguous boundaries:

| Lines | Extracted source |
|---|---|
| 38598–38645 | Constants, counters, reset, locks, block/charge setters |
| 38710–38732 | Target-prone/ref helpers (WALK begin has no target) |
| 38755–39023 | Whole `punch` implementation and its original closures |
| 71923–71994 | WALK setters, begin and resolve bridge methods |

Packaging audit against committed HEAD `4a98a2ce2c6e46f832da4319bc9a468f93788ecd`:
all four slices are byte-identical after CRLF→LF only. Committed whole-world SHA
`c739ddb00b766b596566cb170aa311a5637b56e601b8904d933b7591129e9fb7`
differs because of unrelated working changes and checkout line endings. No world
changes or foreign snapshot are required to preserve this original JS oracle.
`outputs/coordinator21_melee_attack_source/slice_audit.json` records both sides.
The test accepts `-- --source-path=<absolute-world-snapshot>` for explicit clean
HEAD verification, while normal runs read the repository world. Any used slice
content change still fails SHA/length checks; unrelated edits outside the four
boundaries do not invalidate the package. Original observed raw hashes remain
provenance, and the 25 scenario transcripts remain unchanged.

Oracle dependencies that mutate UI/transport are explicitly TEST_ONLY effect
recorders. The whole original `punch` is evaluated, but the real WALK branch
does not take legacy target selection, non-WALK heavy dash or delayed legacy
damage. Native tests compare the complete supported state/effect transcript,
including RNG draw counts, against execution of these source functions.

## Native API and mandatory host callbacks

Construct one instance for one current source/player lifetime. `configure`
takes five callable ports from the **same live owner**:

| Port | Required result |
|---|---|
| `state()` | Complete current source state dictionary below |
| `clock_ms()` | Finite monotonic source clock in milliseconds |
| `rng()` | One real admitted random draw in [0,1), only when requested |
| `effect(event)` | `{ok:true}` after the required actual effect completes |
| `resolve_contact(context, request)` | Actual source-owner resolution or explicit rejection |

State booleans, all mandatory: `walk_active`, `armed`, `chat_open`,
`menu_open`, `dead`, `arresting`, `driving`, `jetski`, `swimming_deep`, `in_bus`,
`ws_open`. Mandatory finite numbers: `stunned`, `player_r`, `player_c`,
`player_angle`. Mandatory strings: `mode`, `stance`. `arresting` is the source
union of murder-police arrest or online-police role `detainee`; `stance` is
the actual effective stance. Positions/angle are source tile/radian values,
not cropped Godot metres. `ws_open` must be a real transport observation;
missing it rejects configuration use instead of assuming offline permission.

Methods match `melee_input.gd`: `beginWalkMelee(request)`,
`setWalkMeleeCharge(active)`, `setWalkMeleeBlock(active)`. Also call `advance()`
from the host's live timer/update path to service source timeout callbacks.
No internal Node, Timer or per-frame polling is created. A timer may be late
by the host tick duration, as with browser event-loop delivery; it is not
silently skipped. `snapshot()` copies diagnostics only; it does not advance
time. `reset(reason)` mirrors source transient reset, not a new lifetime.
Destroy/replace both input and attack-source instances for a new player life
or source session; bind their owner to that life. A same-object host replacing
its player is **not automatically detected** by this package.

Input bridge requests use numeric angle and actual boolean heavy/airborne
fields. Return times/windows use milliseconds; duration uses seconds, exactly
as the source input bridge. The input projector supplies seconds for its own
clock, so both ports must derive from the same underlying clock.

Native host-service bound: `MAX_PENDING_TIMERS=8`. Before a new attack can
change heading, consume RNG or emit effects, it must reserve its complete
callback requirement: one cooldown, or two for a charged ground heavy. A
backlog that cannot fit the reservation returns
`{accepted:false,reason:"timer-backlog"}`. Existing callbacks, charge, pending
context, animation, counters and cadence remain unchanged. No overdue timer
is silently expired/discarded. The host can call `advance()` to execute all
due callbacks and then retry; this refusal is recoverable, unlike a callback
fault. Normal frame service keeps the queue well below eight. Deliberately
beginning every 300 ms without service stays bounded at eight even after
100 further requests. The original 132-operation source oracle is unchanged.

## Required effects, not optional success stubs

`effect` receives these events in the original branch's order:

- `heading {angle}`: commit actual player source heading before attack RNG.
- `telemetry {field,value}`: expose source decision/block/charge/attack status.
- `camera_kick {angle,power:.6}`: source `addKick`. Its actual source formula
  (`world.html:25709`) uses `k=max(.35,power||1)*.95`, adds
  `(-cos(angle)*k,-sin(angle)*k)` to the camera-kick state and clamps each axis
  to ±6. It has no RNG. The actual native camera presentation mapping is a
  host integration responsibility, not an assumed completed effect.
- `cooldown {active,duration_ms:300}`: start/remove the actual attack cooldown
  presentation. Each source attack owns its removal callback; removal does
  not acquire a new authority/sequence fence absent from the source.
- `renew_locks`: renew every real selected target's expiry to current source
  clock + 5,000 ms (`world.html:56480`, constant at 55802). A genuinely empty
  current target set is valid; a fake always-empty provider is not parity.
- `packet {type,data}`: perform the actual `melee_block`/`melee_charge` send
  when `ws_open` is true. Sequence increments occur only on this online path.
- `toast {id:pve_observer_melee,duration_ms:2600}`: source observer refusal
  explains that PvE observer cannot fight and can change to PvP.

A callback returning null after a GDScript runtime error is **not success**.
Required effects acknowledge `{ok:true}`. Missing/malformed acknowledgement,
owner deletion, invalid RNG/clock or reentry latches a fault, prevents later
callbacks, clears the begin guard and reports `valid:false`. Earlier effects
may already have happened and are not rolled back. This is an explicit native
fail-closed adaptation; it does not claim arbitrary callbacks are exception
safe or source WebSocket exceptions always abort browser code. A faulted
instance requires host cleanup/replacement, not silent reset-and-continue.
Boolean false from a healthy charge/block setter remains an ordinary refusal;
null is a fault signal that the input projector already recognizes.

## Admission, randomness and pending semantics

- Actual locks and PvE observer refusal remain. No new permission derives
  from preview rendering or a spawn receipt. Ordinary WALK begin is forced
  but still unarmed; legacy mobile lock-on and non-WALK target search are not
  part of this branch.
- Cadence is exactly 300 ms. Initial last-punch time is zero, so a request
  before clock 300 ms is refused just as in source.
- Ordinary attacks consume exactly one RNG draw: `<0.20` kick, otherwise
  punch. Heavy and airborne attacks consume none. Every accepted attack
  flips the hand counter; kicks independently flip the leg counter.
- Heavy ground admission requires 1,200 ms source charge; the nested original
  punch's 1,165 ms tolerance does not weaken the bridge's 1,200 ms gate.
  Source time zero remains its charge sentinel. Airborne begin chooses
  dropkick without charge. No native dive/hop movement is synthesized here.
- Source damage metadata remains punch12 / kick21 / heavy18; these numbers
  are not applied HP and are never interpreted as impulse in N·s.
- Durations/windows: punch .34 s/[35,190] ms; kick .62/[180,340]; heavy
  .50/[70,360]; dropkick1.25/[160,380]. `walk-melee:<seq>` is a source-local
  ID, not a session/life-aware authenticated damage receipt.
- There is one pending context. A later admitted begin replaces it. Early
  resolve and wrong sequence do not consume it. After the earliest contact
  time it is consumed **before** current-lock/contact validation or host
  resolution; failed late resolution cannot be retried against another life.
- Delivery grace is 250 ms after the window, while sampled contact time must
  remain inside the exact original window and not exceed delivery age.
- A heavy keeps its source charge until resolution or window end +80 ms.
  A normal setter release cannot prematurely drop a healthy pending charge.
  Source reset clears transient state but retains counters, cadence and
  already-captured timeout contexts. This surprising reset/timer behavior is
  explicitly oracle-tested, not rewritten as a new cancellation mechanic.

## Explicit remaining resolve boundary

Native code owns sequence, early/consume-once, delivery grace, current locks,
missing-contact miss and contact-age checks. For an actual nonempty contact,
`resolve_contact` receives a copied context (including original animation,
window, age and sampled contactAge) and original request. The real owner must
execute the remaining original `resolveWalkMelee` section:

1. Resolve current `_walkShotNativeRef` and view, reject dead/missing objects;
   validate point/normal and normalize only a valid normal of length ≥.01.
2. Validate source ranges: player→point ≤1.85 tiles and view→point ≤.7 tiles,
   with correct scene-origin conversion; native metres cannot be passed as
   source r/c. Check current exact collection identity and target lifetime.
3. Dispatch the actual local impact closure (its range/LOS, defense, HP,
   witnesses, medical/death and other consequences) or actual supported
   server path with its real pending ID. Server pending is not a confirmed hit.
4. Return source-shaped `{accepted:true,hit:false}`, local confirmed result
   including boolean `hit/confirmed/blocked`, a real pending result, or
   `{accepted:false,reason:...}`. A claimed hit without `confirmed:true`
   rejects. Those fields acknowledge the real owner; this module cannot
   authenticate an arbitrary dishonest callback.

If unavailable, return the explicit rejection
`{accepted:false,reason:"source-melee-handler-unavailable"}`. Do not return a
fake miss/hit to hide absent damage ownership. The two delegated-contact
oracle cases exercise this call boundary using original-source rejection
results; they do **not** prove the external suffix is implemented. Root owns
that suffix and current source/target life binding. This package supplies no
NPC HP, final-death authority, new combat provider or physical hit receipt.

## Verification and cost

Godot 4.7.2 headless: **9,351 checks PASS, exit 0**, 25 extracted-JS scenarios,
132 operations. Covers every source lock, RNG threshold/cadence/hand order,
network sequence behavior, charge limits, pending replacement, early/late
resolve, contact ages, locked resolution, reset and timeout behavior. Actual
native `melee_input` is connected in a separate TEST_ONLY integration case.
Callback tests cover null/malformed acknowledgements, reentry, owner queued
both before and inside callback, missing real network state, invalid RNG and
one intentional actual GDScript runtime error. That named diagnostic in the
test log is expected; the test verifies no later source effect is dispatched.

Local per-operation CPU p50/p95 **41/115 µs** for the 132 mixed operations,
including state copies and TEST_ONLY effect recording. This is not a loaded
scene, physical contact or FPS claim. There is no GPU, mesh or per-frame IO.
Host `advance()` scheduling and real callback costs still require integration
measurement. No content or source consequence was removed to report this cost.

```powershell
node tools/godot/build_melee_attack_source_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_attack_source.gd
```

Before LIVE: wire real heading/camera/cooldown/lock effects; bind current life;
preserve the single full-matrix melee pose writer; resolve stretched-pose →
canonical physical-body transition separately; provide real contact and full
source damage consequences. The existing physics guard must not be loosened
to turn a source-authored 1.2× limb stretch into a different physical skeleton.

Packaging retest: 9,363 PASS on current working world and separately on exact
committed HEAD world snapshot (exit 0 both). All 25 / 132 original scenario
transcripts are byte-identical before/after regenerating with LF normalization.
The test still intentionally logs one injected callback runtime error as part of
its fail-closed negative case; the final failures list is empty.
