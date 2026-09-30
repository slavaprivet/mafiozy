# Final foot-contact review — candidate07

**No critical runtime defect found in the reviewed integration.** This is a fresh read-only review
of the frozen files and their real call chain, not a claim that every possible runtime defect is
excluded. Reviewer disclosure: this agent authored the proposed port and its earlier harness;
this is a separate final review pass, not an independent author/external reviewer.
No engine was started, and no candidate/shared runtime file was edited during this review.

## Earlier threats

- **Replacement epoch:** port lines19–22 derive a positive per-instance epoch from the RefCounted
  ObjectID. Admission line80 requires that exact epoch. The former constant epoch1 is gone.
- **Callback disposal/life replacement:** `_live` lines57–63 captures incarnation/host identity,
  invokes the public current-life callback, and repeats configured/disposed/epoch/binding/final-death
  checks after it returns. Admission lines149–150 repeats the life check and validates the move
  receipt/body ownership immediately before the single force write. The installed current-life
  callback is read-only, main-thread checked and additionally requires the host still registered
  under the same source ID. Generic same-generation binding alone is no longer sufficient.
- **Stale `get_position_delta`:** player line292 clears the stamp at the beginning of its real
  physics callback; lines334–339 publish frame/serial/pose/start/end only after normal
  `move_and_slide`. The public receipt rejects a different frame/pose/authority. Sampler requires
  that receipt; port lines83–85 compares it, and line151 consumes its serial before applying force.
  New event IDs cannot reuse the same completed movement; old-frame relabelling cannot create a stamp.
- **Alive/medical/recovery:** registration may include IDLE hosts, but both host and public resident
  validator must report ACTIVE + confirmed final_dead + nonempty death_key before admission. The
  resident validator also rechecks source life, actor/rig identity and current registry host.
  Death still belongs to the original confirmed-event NPC path; this port does not manufacture it.
- **Real contact only:** admission independently checks original player/capsule, current measured
  movement, exact owned body RID/instance/shape and native capsule rest/sweep contact, low contact
  height, positive relative closing speed and layer1 obstruction. It repeats the actual movement
  endpoint/velocity checks and rederives the allowed impulse. Initial overlap has a real rest-info
  fallback instead of disappearing after the first sweep.
- **Force/lifecycle:** the only physical write is `body.apply_impulse` on the revalidated exact
  segment at line157. The bounded point-energy limiter and80–1000ms allowed cooldown remain.
  No freeze, pose, mask, HP, blood, joint, velocity or transform writes occur in the port/sampler.
  Population disposal retires the port before hit owners/residents; disposed forwarding fails closed.

The conclusions apply to the installed trusted read-only resident callback and normal main-thread
root call chain. This is not a general permission/security API for arbitrary scripts that can
rewrite private player/NPC state.

## Minimal deployment seams

1. Add `scripts/npc_visual/final_dead_contact_port.gd` (**bc7c93a5…490aa3**) and the root sampler
   `scripts/player_corpse_contact.gd` (**a0659745…603122**).
2. Preserve the player receipt fields/public getter at lines72–85, optional owner setter at88–95,
   stamp invalidation at292 and the begin → native move → stamp → finish block at333–340.
3. Preserve population port registration/ready/admit at141–166 and dispose-before-NPC ordering
   at123–130. It obtains capabilities through the public resident accessor, not a root private scrape.
4. Preserve only the resident's two reviewed public accessor/validator methods at619–638 when
   merging with newer owner changes; do not overwrite a newer NPC owner file with candidate07.
5. Main has the export/default and measured constant at37–39, binds after population setup at209,
   and uses `_bind_final_dead_contact_port` at905–915. Keep that wiring with the measured limits.

**Current default: `preview_final_dead_contact_enabled = false`.** Neither `main.tscn` nor
`project.godot` overrides it. It is a startup toggle, not a runtime unbind switch. Setting it true
before scene startup invokes the existing main binding; tests may explicitly call `_bind...` once.
When OFF, the sampler is absent and no contact geometry queries run. Main's default binding limits
are now the measured constant (3Ns, gain1, deltaE1.5J, linear2.5, angular15,160ms), not an empty map.
Population/port still reject missing or invalid supplied limits and repeated registration.

## Evidence and limits

Existing evidence only, not rerun here: component `native12`119PASS covers callback-disposal,
epoch/serial/replay/host-replacement negatives and three original corpses. Actual root
`main07_02`64PASS uses fully scheduled player physics, ordinary InputMap and the production
population binding: original252 naturally sleeps, exact hand wakes, motion3.47cm; alive/medical,
stationary/away and a registered physical blocking wall admit zero force. HP/blood/death and
mass/joint/filter/freeze checks pass. These results support the reviewed code path, not GPU/FPS claims.

Ready checks scan registered records and the public current-life validator can traverse the NPC
scene; no O(1) or city-scale performance claim is made. The pool is a registered local-session
snapshot (maximum128 records), so a future population/life replacement must use the existing
dispose/recreate lifecycle. New bodies are never silently accepted into an old capability pool.
Candidate08's separate head merge is outside this read-only candidate07 review.
