# Exact impulse-only packet review against candidate05

30 September 2026. Read-only review; production and NPC-owned files untouched. One bounded headless rerun, no GPU.

## Verdict

**Compatible and reproducibly tested as a bounded whole-body launch overlay; NOT acceptance of contact-point physical response, living-hit flinch, medical getup, or the newly required always-lethal headshot rule.** Do not advertise these missing behaviours as covered by native465. The packet is safe to review separately from unfinished top-level Artist files; only ready_impulse_only is pinned.

Verified payload hashes match its RECEIPT.json. Candidate05 owner/host/body/lifecycle exactly match all four compatible-base pins: cd0f09b / 59573587 / 19479386 / 84c09b95. Reran the exact external native_ready.gd on candidate05 dependencies: **465 checks, zero failures, exit0, no engine errors,10.978s**,17 measured cases. Result/log: candidate05_native_ready.json/.log here. This fixture swaps in the exact ready owner, uses real native projectile sweeps and original three rigs, synthetic accepted source shot/muzzle and survival RNG, disables automatic emitter ticking and vehicle ray obstruction as already documented. It is not ordinary mouse/Fire/ammo/GPU acceptance or full13gun physical coverage.

## Concrete gaps, ordered for owner action

### 1. Point of impact is transmitted but has no effect on the initial impulse

Ready owner:213,262–281 computes J and passes reference_point=contact, angular_velocity=ZERO to npc_ragdoll_host.activate. That host:135–136 passes J into exit_ragdoll_body.start. The latter:208,216–217 initializes EVERY one of16 segments with:

    linear_velocity = inherited_linear_velocity + angular_velocity.cross(segmentCOM-reference_point) + J/total_mass
    angular_velocity = inherited_angular_velocity

With angular_velocity=ZERO, reference_point cancels completely.225N·s at default75kg is the same +3m/s for every segment;75N·s is +1m/s. Total linear momentum is correctly J (not16*J), but there is no contact torque. A head/shoulder/hip hit of equal weapon/damage/direction produces the same initial launch. Any later spin is collision/constraint response, not response to where the bullet struck.

The existing body.apply_impulse(world_point,J,event_id):339–356 is different: picks nearest capsule and invokes Godot apply_impulse(J,point-bodyOrigin), producing torque. It is NOT called by this packet. Its10,000N·s generic bound and .75m nearest-body tolerance are not a validated bullet tuning policy; event_id is returned but not deduplicated.

**Correction requested:** expose an explicit owner-admitted point-impulse activation branch, preserving the old start semantics for vehicle/traversal callers. Preflight current lease, IDLE, exact collision-derived contact/segment and same accepted HP event; activate with zero added launch J, then apply ONE separately bounded point impulse through that exact host transaction and mark the event consumed only when successful. Do not apply both the current uniform J and a full point J (double momentum), and do not apply75/225N·s unchanged to a small limb. Define and measure a segment/whole-body momentum budget before tuning. If the owner intentionally keeps the uniform launch for now, name it that and do not claim contact-point reaction.

Required proof: equal chest-centre vs lateral shoulder impacts yield a verified selected segment and distinct expected angular response; no double J, duplicate/reentrant/stale rejection; all3rigs, diagonals/steep angle, near-wall support and unchanged joints/capsules. An impulse-energy/momentum sample immediately after activation is more useful than only eventual displacement.

### 2. Shotgun impulse direction is camera-forward, not its accepted contact ray

Single bullet: native producer weapon_projectiles:256 includes actual e.direction and real ray point; owner:189–197 passes it to helper (penetrating multiplier is normalized away by helper). This horizontal directional choice is internally consistent with the current tuning.

Shotgun: owner:145–147 stores camera_direction projected horizontal. Terminal processing:242–243 retains only first point/normal and all hit distances; discards each terminal direction. At254 it passes shot.base_direction to _apply_hit. Actual host preview_weapons:313–343 aims each projectile from MUZZLE towards camera-ray target, then applies spread. In third person these directions differ due to shoulder/muzzle parallax, especially nearby. Existing native_ready fixture makes camera origin=muzzle origin, hiding this discrepancy.

**Minimal correction:** keep source HP calculation unchanged, but retain a separate physical direction from accepted terminals for each target. For the simplest one-contact policy store first receipt.direction with its point/normal and pass it separately to HitImpulse.bullet; do not replace HP dir_r/dir_c semantics accidentally. If selecting a combined momentum vector, sum only that target's validated pellet directions with declared weights and choose an actual accepted contact point, not a midpoint in empty space. Still exactly one impulse per target/accepted salvo after all7 terminals settle. Add an actual shoulder-camera vs muzzle-offset test and permuted pellet-terminal order test; no7fullimpulses.

### 3. Always-lethal headshots are explicitly absent

The stripped receipt excludes head zone and headshot lifecycle. No ready-owner hit field carries an authenticated anatomical zone. Unchanged lifecycle84c09b applies ordinary damage and then72% medical survival on first lethal hit. Consequently a full-health ordinary resident can survive a weak actual head contact (e.g. TT24 against60HP), and even a lethal sniper head contact can become medical_downed rather than final death. The465 rerun deliberately tests torso height1.1m, so it says nothing about the new requirement.

**Correction requested:** integrate the separate owner-authored head-zone classifier only after proving current exact original anatomical skin contact under the real native ray (not capsule height/critical/proximity). Carry zone proof into the same completed transaction, before ordinary nonlethal/medical branches. Valid headshots must consume that single accepted damage event and reach final_death regardless of survival RNG; never patch HP afterward or add a second hit. Verify all13guns, three original rigs, weak/far head hit, hair/hat/shoulder/neck negative, world obstruction, duplicate/stale actor, pellet one-head-plus-body combination, and an already medical-down head hit. Preserve protected/invulnerable policy explicitly with Root/user requirements rather than silently reversing it. Do not copy the top-level unaccepted head/ACTIVE files merely because they exist.

### 4. Teleport removal is real, but survivors currently just pause

Ready owner path callback:100–104 now records the original .09tile request and unconditionally returns false; it never writes global_position. This removes the former instantaneous .369m movement for ALL hits, including survivors. It is an intentional user-requested source deviation, not a source-parity improvement. No new collision bypass is introduced because no movement happens there.

walk_pause points at should_pause_walk:303–310, which observes source250ms idleUntil and dead/down/crawl flags; the pinned candidate05 resident host already respects this gate before navigation/gait. Normal surviving hit has no impulse or new flinch. Test fixture explicitly requires TT to remain IDLE/no invented knockdown. User's desire for natural visible surviving-hit response therefore still needs the source .48s additive chest/head flinch or an independently accepted physical reaction. Do not infer that the removed shove has been fully replaced.

Cleanup recommendation: remove this walk_pause Callable on owner disposal only if it is still the exact callable installed by that owner; avoid leaving disposed-owner ownership references or overwriting a newer owner's gate.

### 5. Medical acceptance is narrower than the strength cap implies

Medical caps J at75N·s; initial final caps via weapon table at225N·s. Only IDLE activation consumes J; an already ACTIVE final confirmation changes death/eyes without another impulse; bleedout has zero new J. The latter is correct for a one-time initial-launch scope, but does not satisfy reactive corpse hits/finishing impulses.

native_ready measured medical peak travel .524/.537/1.193m (three rigs), final shotgun2.111/2.067/1.864m; max joint errors .104845/.105293/.096586m below unchanged .20m check. It does NOT complete actual medical getup. Earlier75-cardinal getup proofs use TEST_ONLY source release, not medical recovery authority.150/225 directional failures remain evidence against simply increasing the cap. Exact native first-step capsule floor penetration remains -.141081/-.141641/-.130760m, matching zero-J baseline; matching baseline is not floor-contact acceptance.

Required new point-impulse tests must repeat support/skin/joint/recovery checks; the75 whole-body cap is not transferable to a small segment and passing four cardinal directions does not prove diagonals/obstacles. No tolerance/reserve/mass/joint changes are in this packet, and none should be slipped into adoption. Real medical release/treatment/getup remains unimplemented; no fake release for the game.

## Physical units and retained guard details

- All physical distances passed into helper are native metres; source range converted once by*4.1 and .05tile slack=>.205m. Direction is intentionally projected toXZ; a purely vertical admitted shot returns no J. If user expects full ray direction this is another declared tuning limitation, not a source formula.
- Near <=1.5m, taper linearly to25% by12m; damage/base damage multiplier clamped .18..1.0. Critical/shotgun damage cannot exceed the table peak. Table aliases cover11single+2shotgun guns:45–225N·s; RPG rejected by bullet(). Unwired blast() helper450 should remain unexported/unclaimed or be removed from this bullet-only proposal.
- Bodies16/joints15, default mass75kg, original15mm contact reserve and existing .8/1 joint restitution/softness unchanged. Generic body velocity80m/s and impulse10,000N·s are rejection bounds, not normal tuning values; velocities are not clipped.
- Impulse context bound to current event_id, completed ok/applied HP, invulnerability checked, exact life checked again; replay cannot restart modeACTIVE. These are useful existing guards and must be retained in a point-impulse replacement.
- Full renderer/physics frame-time/memory cost for the new response remains unmeasured. The latest rerun was behavioural headless, not a benchmark; prior author ABBA timings predate the final stripped no-teleport policy and do not measure final whole-scene GPU/solver cost.

## Integration disposition for Root

Review/apply only a narrow diff against cd0f09b; export explicitly includes new npc_hit_impulse.gd, preserve root camera/reticle/surface/cargo changes. For release claiming the user's complete response request, HOLD on verified anatomical always-lethal headshots and natural point/living response. Uniform initial launch may be staged as a clearly limited intermediate change if Root chooses, with the unchanged floor and medical limitations recorded. No generic465 rerun can resolve those semantic gaps; tests need the actual missing contact/zone paths described above.
