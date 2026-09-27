# Shared character impact policy

New production module: `godot/mafiozi_walk/scripts/character_physics/character_impact_policy.gd`.

This is a pure, bounded **single-target reaction proposal**, shared by player/resident/cop and other character hosts. It creates no physics objects, runs no callbacks, broadcasts nothing, and writes no HP, damage, ownership, controller state, bone transforms or actor velocity. Combat is **not wired** by this package. Airborne owns the physical ragdoll/joints; root owns integration and local spring presentation.

The user requested flexible physical responses with stable normal walking, not permanently loose or drunken locomotion. Small impulses return `local`, retaining normal movement/aim ownership. Strong impulses or an explicit authoritative fall/death return a **request** for physical knockdown. The owning controller decides and performs that handoff; the module does not assert that impulse magnitude alone proves the actor has lost balance.

## API and units

```gdscript
configure(actor_id: String, life_generation: int, session_id: String,
          profile: Dictionary) -> Dictionary
consume(event: Dictionary) -> Dictionary
reset_life(actor_id: String, life_generation: int, session_id: String,
           profile: Dictionary) -> Dictionary
state() -> Dictionary
dispose() -> void
```

`profile` has exactly these three fields, all chosen by the owning physical character configuration:

```gdscript
{
    "mass_kg": body_mass_kg,
    "max_impulse_ns": largest_valid_caller_impulse,
    "stance_thresholds_mps": {
        "standing": standing_threshold,
        "crouched": crouched_threshold,
        "prone": prone_threshold,
        "airborne": airborne_threshold,
        "seated": seated_threshold
    }
}
```

Only actually supported stance keys need to be present. An absent stance fails closed; there is no hidden default mass or threshold. Thresholds are the impulse-induced whole-body velocity change `|J|/mass`, in metres/second. They are explicit gameplay/physical balance configuration, **not** bullet calibre, damage or measured human injury predictions. The module does not estimate angular balance from an invented centre of mass. Position-dependent angular response belongs to the real rig's physical impulse application.

`event` requires eight fields:

```gdscript
{
    "actor_id": existing_target_actor_id,
    "life_generation": current_integer_generation,
    "session_id": current_session_id,
    "event_id": unique_caller_event_id,
    "kind": "bullet", # also blast, contact, fall, melee
    "world_point": actual_world_contact_point, # Vector3, metres
    "impulse_ns": effective_target_impulse,    # Vector3, N*s, world axes
    "stance": current_stance                  # required String
    # Optional positive authoritative inputs:
    # "authoritative_knockdown": true/false,
    # "dead": true/false
}
```

The caller must already validate target/attack/contact/source authority, permitted damage/force, explosion distance and occlusion. This module cannot prove network authority, hit ownership, line of sight or whether a contact is real. No `occlusion_verified=true` self-attestation is accepted as proof. For a blocked blast, the caller supplies the already resolved zero impulse. For melee, actual point, relative opponent/body motion and the approved contact model must determine the caller's impulse; this policy adds no random throw direction or canned outcome.

Success returns copied value data: `ok`, `reaction` (`none`, `local`, `knockdown`), `reason`, `request_physical_knockdown`, `proposal_only:true`, exact identity/event/kind/stance, `binding_revision`, unchanged `world_point` and `impulse_ns`, `delta_velocity_mps=J/m`, `delta_speed_mps=|J|/m`, mass, threshold and passed flags. No unknown input fields are forwarded.

- Zero impulse gives `none`, unless a true authoritative knockdown/dead flag requests physical handoff without adding force.
- Nonzero impulse below the current stance threshold gives `local`.
- At/above threshold gives a knockdown **request**. Explicit false flags mean no positive forced request; they do not suppress the threshold proposal or command resurrection.
- All five kinds obey the same physical rule. A bullet is not categorically a cartoon launch; only its caller-supplied momentum and the actor's actual profile matter.
- Repeated small hits preserve each impulse independently. There is no invented time accumulator/decay, random loss of balance or automatic HP inference. The physical host can report genuine balance loss through authoritative input.

## One physical owner, one impulse application

For an impulse not yet applied, a native RigidBody sink uses the world vector and world-relative offset once:

```gdscript
body.apply_impulse(receipt.impulse_ns,
                   receipt.world_point - body.global_position)
```

The actual rig owner must choose the affected body/limb and correct mass/shape. Do not apply full `J` to every ragdoll limb, also apply a COM impulse, or separately reapply the angular effect already produced by the contact point. `delta_velocity_mps` is diagnostic/reference data, not another force write. Local presentation may consume the receipt through root's future spring layer while the ordinary locomotion/aim controller retains authority.

**A solver-reported contact impulse may already have changed the actor velocity. Never apply it a second time.** Such an observation can drive local presentation or a mode-handoff request while conserving the already solved momentum. Likewise, exit ragdoll initialization may inherit the vehicle's actual point velocity once; do not convert that inherited velocity into an extra impulse. An explicit fall request can use `authoritative_knockdown:true` with `J=0`, while the physical owner carries forward real position/velocity. Fall/contact damage remains separate.

Consumers must recheck actor/session/generation and current binding revision when applying a delayed receipt. No asynchronous physics sink or automatic fan-out is installed here.

## Bounds and lifetime

One instance binds one actor lifetime/session. IDs are nonempty Strings, at most 256 characters; generations 1..2147483647. Native Dictionary keys may be String or StringName, but identity/kind/stance values remain strict Strings and event generation is a strict integer. Unknown event fields/kinds/stances, nonfinite values, malformed authority flags and excessive impulses are refused.

Configured mass accepts `.01..1,000,000 kg`, thresholds `.000001..1,000,000 m/s`, max impulse `.000001..100,000,000 N*s`; these are numerical safety bounds, not supplied gameplay settings. The configured impulse norm limit is enforced before classification, including a component precheck preventing huge-vector norm overflow. World coordinate components are bounded to 10,000,000 m. No rejection clamps/amplifies input into a different valid event.

Exactly the last **64 accepted event IDs** are retained in a FIFO ring/set. Duplicates within that window are refused, including zero/occluded impulses; malformed/stale input never poisons the history. Once evicted, an old ID can be accepted again: the authoritative caller must supply a stronger lifetime replay window if required. This is bounded local dedup, not server replay protection.

`reset_life` is an explicit owner operation, unavailable from event data. Same-session reset requires the same actor ID and a strictly increasing generation. A caller-owned new session may begin a new binding; stale old-session events then fail. Successful reset clears the 64-entry history and increments binding revision. Invalid reset leaves everything unchanged. All mutation is main-thread only. `dispose` is idempotent and makes all subsequent inputs fail; no scene/body references are retained.

## Tests and cost

```powershell
& 'C:/Users/Слава/AppData/Local/MafioziTools/Godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path godot/mafiozi_walk --script res://scripts/tests/test_character_impact_policy.gd
```

Godot 4.7.2: **158 checks PASS**. Exact identity/session/generation, typed/nonfinite/excess inputs, profile copying, boundary thresholds, mass/stance effects, local bullets/melee, equal rule across all kinds, caller-occluded blast, authoritative zero-impulse fall, no HP output, multiple-hit conservation, 64-entry retention/eviction, atomic lifetime reset, worker-thread refusal, shared player/cop/resident API and disposal.

One actual headless native RigidBody with zero gravity/damping/contact receives three previously unapplied impulses at the supplied world point. Expected and actual velocity both `(0.1125,0.0375,-0.01875) m/s`; momentum error **0 N*s**. Off-centre angular response is nonzero and a rejected duplicate produces no second impulse. This is the physical sink contract test, not a completed character rig.

2,000 measured calls, input construction outside timing: **p50 11 us, p95 15 us, max 52 us**. No GPU run, no main/player/transport change. Full visible-scene performance and combat integration are not claimed.

Module SHA256: `7cde00d9978e6940952877866fce1f3eedabedd0955414cf878a5987e6923e9b`.
