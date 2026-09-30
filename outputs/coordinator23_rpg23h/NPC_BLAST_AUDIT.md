# NPC RPG blast audit against accepted23g

Read-only audit plus isolated output proposal,30September2026. Parent checkpoint27ee4b39. No production/Git/thread/GPU/engine operations. ToolSearch/Ruflo is unavailable; local source and pinned owner packages used.

**Use Artist23's existing gate, not a new explosion authority.** `outputs/artist23_rpg_damage/npc_rpg_blast_gate.gd` is `e6f94752…`; its earlier local native fixture445checks, scalar88 and actual-JS oracle18 were inspected as historical evidence. They do not validate today's23g overlay, complete physical blast or loaded performance.

## Original contracts

| Source | Contract that must survive |
|---|---|
| world.html:37708–37753 `_spawnRpgExplosion` | RPG radius2.7cells=11.07native metres, horizontal distance inclusive boundary. Base damage `max(8,round(160*(1-.72*d/2.7)))`; baseline160 at centre and45 at edge. No NPC vertical attenuation or LOS in this specific local RPG route. |
| world.html:37286–37288 `_currentShotDamage` | Multiply rounded base damage by current marksman boost, current global critical multiplier, then JS-round/max1. These modifiers are read at impact, not frozen at RPG launch. Another accepted shot may replace the current context while the rocket flies. |
| world.html:37437–37465 `_localBallisticTargets` | Ordinary NPCs exclude dead/evacuated. Preserve target-specific owner; RPG blast clears the direct-shot single-target restriction. Do not damage corpses again via this HP route. |
| world.html:37749 | Radial direction in source r/c; within.01cells use dir_r=0,dir_c=1, mapping to native+X. |
| world.html:69980–70001 `_walkImpactRpg` | Known immutable flight, same scene/interior, age≤15s, bounded along/lateral trajectory; consume before blast callbacks. Cosmetic explosion is not damage proof. |
| world.html:69799–69829 `_applyWalkLocalBlast19` | **Different route:** vehicle/C4 use exposure/LOS and event history512. Do not silently import these rules into local RPG or apply RPG's no-LOS rule to them. |
| `npc_blast_record20_source.js`:1–16 | Enrichment requires a newly created, confirmed fatal blast record with matching target/event/deathKey. visualSpeed5m/s is presentation metadata, not physical impulse authority. No manufactured `_deathRecord20` from a cosmetic effect. |
| world.html:25482–25514 `_maybeSeverLimb` | Separate original sever/detached-part mechanism and ownership. This recipient does not claim severing or native limb detachment. |

Local ordinary HP remains a **new local session**, not server/save authority. Source server RPG has separate launch/arrival and LOS requirements (earlier audit in `outputs/astra21_character_impact_ranged_blast/CONTRACT.json`); this package must not claim those services are installed. Current23g source services still queue fatal/murder/social effects rather than authenticate an original durable death record.

## Existing native seams

Current owner `npc_local_preview_hit_owner.gd` already registers accepted RPG shots as context-only (`_on_shot`:139–167). It shares source RNG/current modifiers once per session registry. Ordinary/pellet impact handlers do not grant RPG HP. `npc_ordinary_hit_lifecycle.gd`:86 explicitly rejects RPG. No `bind_native_rpg_gate`/`accept_native_rpg_blast` methods currently exist.

The Artist gate uses the actual existing Inventory and Flight. Root hooks must surround the real prepare→ammo settlement→flight commit synchronously, then publish accepted shot once. Native query is performed once by the gate, not duplicated; impact admission must run inside retired Flight callback **before** cosmetic signals, including range-end. Current `rpg_effects.gd` emits cosmetic impacts only for a physical hit, so connecting that signal alone misses range-end and has no authority.

The gate binds exact3 admitted owners72/169/252, player actor/life, worldRID/scene, Flight/inventory object identity, UID/ammo sequence/muzzle epoch and immutable launch token. Targets recheck session/source/render/life/owner binding plus body instance/RID/world. An ACTIVE medical body uses actual physical anchor, not the stale standing capsule. Dead/evacuated targets are excluded. Event/target tickets are consumed before callbacks; lifecycle independently deduplicates event IDs. Root must bind `current_damage_context` from the actual same registry owner, not an arbitrary guessed critical=false provider.

The packet uses private owner/Flight internals as an owner-reviewed integration capability, not a generally callable public damage API. Root must preserve its pinned lifetime/reentrancy tests on current Flight. Our recipient adds a same-owner/gate/binding check after `take_target` callback and blocks reentrant recipient admission; it does not weaken gate checks.

## Exact23g-compatible output overlay

Files are in `npc_proposal/`; `RECEIPT.json` has exact before/afterSHA, and `PROPOSAL.patch` is a reviewable two-file diff. Generator asserts23g owner0a3e311d/lifecycle80f7a0cb before producing anything.

1. Add bound gate member, a reentry flag, configure/accept methods and disposal clear to current owner. Consume opaque target ticket; validate current owner identity and typed finite target/origin. Feed only the issuer's accepted hit into existing `_adapter.hit` via `_admitting`. Never accept a caller damage dictionary.
2. Change **one lifecycle guard**: RPG admitted only when trusted callback supplies `admission_kind=owner_proved_native_rpg`. Preserve current anatomical-head policy, ordinary damage, medical-survival/final-death logic, callbacks and idempotence. Do not replace current lifecycle with the stale whole-file Artist packet.
3. After applied HP, feed the matching event's existing `HitImpulse.blast` into `_native_impulse_context` with `uniform_only=true`. This flag originates inside recipient, not blast input. `_publish_physical` has two narrow changes: zero point share for matching uniform-only event and skip the point API when share is zero. All bullet/shotgun point behavior otherwise remains.

No stale head policy is copied onto RPG. No fabricated anatomical contact, bullet hole or blood renderer receipt is emitted at the epicentre. Blood severity state still follows ordinary source lifecycle services; visible blast blood needs an appropriate source/owner receipt rather than pretending every victim was hit at one bullet surface point.

## Direction and mass

Existing `npc_hit_impulse.gd`:25–31 supplies a **user-tuned**, not source-exact, horizontal450Ns centre→126Ns edge proposal, radius11.07m. Radial direction and distance come from the opaque ticket's actual target anchor/epicentre. Invulnerability rejects force. Source5m/s presentation speed and HP are not converted into momentum.

For an initially IDLE recipient, existing `npc_ragdoll_host.activate` and `exit_ragdoll_body.start`:196–216 give every owned segment the same delta-v `J/total_mass`, conserving total requested momentum across the body's measured mass partition. Default75kg implies6m/s at450Ns; this is not per-segment450Ns. Medical transitions retain the existing75Ns cap. Use actual target/pelvis reference, never explosion origin as a bullet torque lever. Existing native inherited velocity remains intact; no pose/velocity reset beyond the already-owned activation transaction is introduced.

Artist impulse handoff reports horizontal+X threshold fixtures through450Ns on three original rigs; upward.3 variant failed169 getup and was rejected. This is not all-direction native RPG acceptance. Need true23g RPG/HP/medical/final tests plus loaded cost before enabling.

**Explicit remaining HOLD:** `_publish_physical` for already ACTIVE medical→final currently only confirms final death; it does not apply an additional blast impulse. Native public body methods provide `start` and nearest-segment `apply_impulse(point,J,event)`, plus `owned_bodies`; no public uniform-active-pressure method exists. Reusing the nearest-segment method for the full450Ns would be wrong and could create excessive torque. The proposal does not edit native body or restart a corpse; its returned `blast_physical.status` reports this gap. A later owner-reviewed uniform-active port must deduplicate event/life, validate all owned masses/bodies before force, apply per-segment central `J_i=J*m_i/sum(m)` with conserved sum, wake naturally and never move/freeze poses. It needs explicit tests; it is not included here.

Standing survivors with no source ragdoll transition retain that behavior; the patch does not create a knockdown solely from explosion proximity. Current final-dead targets remain outside source HP recipient enumeration. Source severing, full medical recovery, global social/server effects and vehicle/building/player blast recipients remain separate work.

## Required focused integration evidence

- Actual one-round RPG fire→existing Flight→native wall/range-end→three current original recipients. Preserve UID, one ammo commit and one shared critical context; include later accepted gun shot replacing current critical context before arrival.
- Radius centre/edge/just-outside, high vertical offset and local RPG no-LOS parity. Do not test against vehicle/C4 attenuation and call it the same contract.
- Forged cosmetic/native dictionary, replayed/wrong-owner target ticket, new life/session/scene, expired/evicted Flight, disposal/replacement during context or target callback: no HP/force.
- Initial final and medical transitions: uniform sumJ and mass,75Ns medical cap, original16segments/joints, no point impulse, no pose teleport, retained head/marks/foot regressions. ACTIVE finisher extra force stays HOLD until its public port exists.
- Same populated scene before/after, full RPG Flight/query/3recipient/HP/physics/effects cost and native behavior; component445/88/18 and one helper threshold are not this acceptance.

No engine tests were run on today's overlay. It is prepared for root's isolated candidate12 and owner review, not shared deployment. `PINS.json` records exact read dependencies and proposal hashes; earlier packages and all shared files are untouched.
