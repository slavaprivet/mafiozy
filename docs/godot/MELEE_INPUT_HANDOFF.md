# Native melee input projection

27 September 2026. Bounded port of `assets/maps/city_rebuild_v1/world_walk_melee_input.mjs`, SHA-256 `c2d819825128c421b3a14cd773b39f59fbb0327c50eec155f41b54252f42154e`. Original JavaScript was imported unchanged by the oracle exporter. No main/player/NPC/HP/source edits or GPU runs.

## Files and API

- `godot/mafiozi_walk/scripts/combat/melee_input.gd`
- `godot/mafiozi_walk/scripts/tests/test_melee_input.gd`
- `godot/mafiozi_walk/scripts/tests/fixtures/melee_input_oracle.json`
- `tools/godot/build_melee_input_oracle.mjs`

Create a `RefCounted` input instance, then call:

```gdscript
var configured = input.configure({
    "beginWalkMelee": Callable(source_bridge, "begin_melee"),
    "setWalkMeleeCharge": Callable(source_bridge, "set_charge"),
    "setWalkMeleeBlock": Callable(source_bridge, "set_block"),
}, source_clock_seconds)
```

All three source ports must be valid callables bound to the same live Object with exactly one effective argument (bound arguments are accounted for). The optional clock has zero effective arguments and returns finite seconds; omitted clock uses `Time.get_ticks_usec()/1e6`. Configuration is one-shot after success. A failed validation may be corrected before any source command. `configure` returns `{ok:true}` on success; failures return `{valid:false,error,may_have_dispatched}`.

`press(options={})`, `release(options={})`, `step(options={})`, `block(bool)`, and `cancel()` return **the original source snapshot shape**, with no added success flag:

```text
{action:{type,progress,side,blocking,charge},
 start:null|{id,seq,type,time,sourceStartAt,duration,side,yaw,airHeight,contactWindow},
 started,held,sequence}
```

Errors return `{valid:false,error,may_have_dispatched}` instead. Callers must distinguish errors from source snapshots, not assume `snapshot.valid == true`.

Recognized options are `time` (seconds), `allowed`, `armed`, `airborne`, `yaw`, `airHeight`, `blocked`, `cancelled`, and `buttons`. Context is sticky exactly as source: `blocked:true` sets `allowed:false` until an explicit later `allowed:true`. Bridge request is `{angle:PI/2-yaw,airborne,heavy}`. It never includes damage or client charge duration. Source `startAt` remains the source's millisecond metadata; the port copies it without converting it into its local seconds clock.

The real bridge, still required, must own current session/life, input permission, charge timing, attack admission/choice and any source cancellation effects. Binding valid Object callables is a lifetime check, **not proof of gameplay authority**. On actor/session replacement the host must cancel/dispose the old instance and bind a new one. No residents, combat provider or default permission is created here.

## Preserved source behavior

- Monotonic local clock: backward finite times clamp; nonfinite/missing time uses the clock provider. Cancellation/block use the last clock value without reading/advancing time or expiring an attack.
- Ordinary press starts source charge before requesting the source-chosen attack. Held/blocking repetition does not start another attack. Airborne press does not begin a ground charge.
- Automatic heavy at1.2s and heavy on earned release retain source charge reservation until completion/cancel/block. Failed heavy admission is consumed by the input hold (`spent`) and does not retry every frame.
- Source-chosen type, sequence, side, duration, start timestamp and contact window are copied, never recomputed from a local random roll. Source-rejected or nonpositive/nonfinite-duration replies do not become accepted attacks.
- Release with `cancelled:true` suppresses a newly earned heavy but leaves a still-active existing attack, as source does. `cancel()` clears current attack and block.
- Source callback order and duplicate clearing calls are intentional parity: e.g. canceling a reserved heavy while still held can call `setWalkMeleeCharge(false)` twice through source `clearAll/clearHold`. The adapter does not deduplicate these state-setting calls. It never duplicates `beginWalkMelee`.
- Returned snapshot dictionaries and contact-window arrays are private copies. Editing either the bridge reply after return or a public snapshot cannot rewrite stored input state.

## Native boundary additions

These guards are host safety contracts, not extra melee authority:

- Actual source charge/block setters always return bool, including false for refusal or retained heavy charge. Native missing/non-bool acknowledgement faults before any later callback. This closes a confirmed Godot failure: an errored charge callback returned null and previously allowed `beginWalkMelee` to execute. Wrong callable arity is rejected before dispatch. Optional extra arguments must be explicitly bound; this strict host API is intentionally narrower than arbitrary callable invocation.
- A null begin reply retains the original source-input rejection behavior. It cannot distinguish intentional null rejection from a Godot script error in begin. This is not general exception catching or rollback; the real owner must reconcile possible side effects before another life/instance is installed.

- Main-thread synchronous calls only. Missing/freed/queued-for-deletion bridge or fallback clock rejects. Queued deletion inside a callback is detected before accepting its result. Godot itself forbids directly freeing an Object executing a callback; the test uses its legitimate queued-deletion path.
- Reentry, disposal from a callback, invalid clock or malformed successful metadata faults the input instance. No further source callback/retry is attempted from that fault. If a source command was already sent, the error reports `may_have_dispatched:true`; the adapter does not claim to roll back source admission. Host must reconcile that source owner before replacing the instance.
- Native option booleans must actually be bool, and yaw/airHeight numeric. JavaScript coercions of arbitrary objects/strings are not a supported host API. Normal typed source fields, nonfinite yaw fallback and NaN height fallback retain source behavior.
- Accepted positive-duration reply metadata must be scalar (`type:String`, finite numeric seq/startAt/side). Its window is copied finite numeric Array of at most16 entries; real source windows have two. This bounds retained references and rejects arbitrary Object payloads. The adapter deliberately does not grant permission based on a particular attack name or window contents; only the source bridge can authorize them.
- `dispose()` releases ports/clock/current data and sends no source mutations. Use explicit `cancel()` while the same live source owner is still bound if charge/block must be released. Teardown cannot release a newer life implicitly.

Space is constant: one source reply/current attack, one copied window capped16, three source ports and one optional clock. No growing event ledger, actor list, pending jobs or per-frame scene search. The source bridge owns its actual admission/replay namespace.

## Verification and cost

**4,991 assertions PASS**, Godot4.7.2 actual headless. Original JS oracle covers19 scenarios /119 operations; every snapshot and exact ordered callback transcript is compared recursively. Numeric comparison uses float64 tolerance `1e-10 * max(1,abs(value))`, not rounded rendered text. Independent final review adds134 adversarial checks PASS and a separately labelled intentional runtime-error probe. Original failures remain in `outputs/coordinator21_melee_input_review`; the fixed callback fault suppresses begin and reports possible dispatch rather than pretending rollback.

Cases include click/expiry, automatic and released heavy, reserved-heavy cancel/block, rejection, airborne transitions, sticky locks, integer/noninteger and oversized float64 mouse-button masks, backward/fallback time, custom source metadata, empty window, malformed duration and null reply. Independent boundary tests cover private copies, missing/mixed/freed owners, queued deletion, fallback-clock lifetime, invalid types, reentry, no retries and disposal. The test bridge is expressly scripted fixture data, not an emulation or replacement of source gameplay admission.

Warm module CPU,2,000 samples after400 warmups on this machine:

| Work | p50 | p95 | max |
| --- | ---: | ---: | ---: |
| Idle `step` |10µs|13µs|128µs|
| Complete press/sample/release triplet with fixture bridge |65µs|130µs|367µs|

Idle benchmark sends zero bridge commands. There was no native implementation before this port; these are bounded module costs, not a before/after full-scene FPS result. Loaded-scene performance and visible combat remain for integration by root. No GPU acceptance is claimed.

Reproduction, from any directory for exporter (paths resolved from its own location), and repository root for Godot:

```powershell
node tools/godot/build_melee_input_oracle.mjs
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_melee_input.gd
```

Oracle pins actual source bytes, and native test checks the current source hash. Regenerate after an intentional source change; do not bless a stale oracle. Final report/log: `outputs/melee_input/report.json`, `outputs/melee_input/run.log`.

Frozen module SHA-256: `21b211d8a4d45347c8bdc960e1d6113bfdf8f038ceec943f0862d9cff962aac4`.

Root final rerun after acknowledgement/arity fix: idle p50/p95 10/11µs,
press/sample/release64/101µs; still component CPU only.
