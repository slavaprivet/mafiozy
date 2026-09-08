# Artist13/14 animation presentation handoff

## Scope and provenance

This slice transfers presentation only. Movement admission, collision, attack
admission/damage, ammo, reload completion, jump physics and replication remain
owned by the host.

- Artist13 posture/reload/crawl source: immutable checkpoint 10 ZIP SHA256
  `49968DEEB86E3E364412585A42B2CAF94FB4FDE3A5F6E2E3E23F40F180FB07F9`.
- Artist13 jump aim v2 source: immutable checkpoint 11 ZIP SHA256
  `59DA3260E7BB48DA5A60AB49090209CB2972F5A443D90E750AEA229385E4A2F3`.
- Artist14 melee v3 supersedes checkpoint 10 for melee only:
  `D:/codex_release/artist14_melee_20260908/v3/demo.js`, SHA256
  `401EF5C7613F9C1144C92DA859AAADC50FBB2F485BB06D0B1E6DF50ACCB6B7AD`.
- The mutable Artist13 DEV `demo.js` no longer matches checkpoint 10. It was not
  copied wholesale.

## Posture host API

```js
import {
  createHeroPosture,
  requestHeroPosture,
  stepHeroPosture,
  posturePresentation
} from './hero_posture.mjs';

const posture = createHeroPosture('stand');

// Toggle requests. The callback must query the actual host collision volume.
requestHeroPosture(posture, 'stand', {
  canOccupyHeight: (height, target) => canUseCapsule(height, target)
});

// Every frame. Apply returned values in host movement/camera/collider code.
const motion = stepHeroPosture(posture, dt, {
  canOccupyHeight: (height, target) => canUseCapsule(height, target)
});
// motion: {height, eyeHeight, maxSpeed, speedMultiplier,
//          crouch, prone, crawl, blocked, target, value}
```

Reference heights are stand `1.90`, crouch `1.25`, prone `.62` metres. Reference
eye heights are `1.64`, `1.02`, `.43`. Reference movement caps are the current
on-foot `3.20/5.80`, crouch `1.55`, prone `.80` m/s. The host decides whether to
apply these values; the module does not move the actor or alter a collider.

The posture transition rate is checkpoint 10's `2.1` scalar units/second.
Standing up probes clearance both at request time and each transition step. A
failed probe leaves the lower pose active and reports `blocked:true`.

## Ground pose, melee and reload

Call one ground resolver per frame:

```js
hero.update(dt, moving, running, currentWeaponSpec, {
  aimYaw,
  aimPitch,
  recoil,
  recoilYaw
}, {
  posture,
  action: {type, progress, side, blocking, charge},
  reloadProgress
});
```

`type` is `none`, `punch`, `kick` or `heavy`; `progress` is normalized `0..1` from
the accepted host event. `side` is `-1` or `1`. Reload progress must come from the
existing weapon fire state. The module only lowers the weapon, guides the support
hand and moves an existing procedural magazine node before restoring it exactly.

Artist14 v3's ordinary-click choice is exposed without owning input:

```js
import {selectOrdinaryMeleeType,HERO_ACTION_DURATIONS}
  from './hero_motion_presentation.mjs';

// Call exactly once after the host admits an ordinary fists LMB press.
const type = selectOrdinaryMeleeType(oneRandomDraw); // kick below .20
```

`HERO_ACTION_DURATIONS` is `{punch:.34, heavy:.50, kick:.62}`. Heavy remains a
separate accepted 1.2-second hold. Pointer capture, lost-pointer release and input
chording belong in the host; the presentation API never starts another action.

## Jump aim v2

```js
hero.jumpPose(progress, directional, currentWeaponSpec, {
  aimYaw,
  aimPitch,
  recoil,
  recoilYaw
});
```

During a jump, call `jumpPose` instead of `hero.update`; calling both would let the
second resolver erase the first. The method preserves the host root position,
root yaw and locked ballistic direction. It rotates the visual body toward
`aimYaw`, keeps all current 14 weapon grips, applies pitch/recoil, and softens the
dive during steep downward landing. Resolve the muzzle/ejection transforms only
after this final pose and `matrixWorld` update.

Vehicles have higher pose priority. Do not apply posture/melee after
`vehiclePose`, because any ground resolver begins from the authored rest matrices
and would erase staged legs, passenger lap hands, steering-wheel IK and road gaze.

## Casing presentation

The existing bounded casing owner remains `weapon_effects.mjs`. It still uses each
weapon's current `ejectionPort`, delayed pump action, retained revolver cases,
gravity, bounce and the 48-slot pool. Initial automatic casing motion now follows
the demo's clear side/up profile: right `1.65`, up `2.2`, forward `-.4`, with a
2.2-second lifetime. No second casing pool was added.

## Verification and live QA

Passing local checks:

- `test_hero_posture.mjs`
- `test_hero_motion_presentation.mjs`
- `test_hero_presentation_glb.mjs`
- `test_hero_walk.mjs`
- `test_hero_arsenal.mjs`
- `test_hero_weapon_fire.mjs`
- `test_weapon_effects.mjs`

The real male GLB test measures lower crouch/prone silhouettes, prohibits bone
scale changes and limb translations, checks punch/kick/block, magazine extraction
and exact recovery, all 14 weapon grips in crouch/prone, and all 14 jump aim/grip
cases. The existing steering, four seats/passenger pose, rear-assembly clearance,
vertical aim and weapon tests remain green.

`walk_preview.mjs` now owns the first host integration. Ctrl toggles crouch, Z
toggles prone, and Space first returns the actor to standing before launching a
jump. The returned posture height gates ceiling clearance and walking speed; its
eye height drives both the follow target and aimed camera. Vehicle transitions
reset the posture. Each frame applies exactly one final hero resolver
(`vehiclePose`, `jumpPose`, or `update`), then resolves muzzle/ejection transforms
and emits accepted shots. Reload progress comes from the existing fire state.

Opt-in live controls are available at:

`/tools/city_rebuild_walk.html?animationqa=1&weaponqa=1`

Live Chromium evidence on 2026-09-08: the crawl control moved the actor `0.91 m`,
the standing jump reached `0.916 m`, and an M-16 QA burst changed the magazine
from `30` to `28` while recording two projectiles, two impacts, two surface marks
and two casings. R started the authoritative reload state and exposed positive
reload progress to the pose. Browser warning/error logs were empty. This is a
preview integration check; it is not a claim that the main game runtime has been
migrated.

Remaining live gates: low-ceiling blocked stand-up; crawl turn/backward by normal
input; reload silhouettes for pistol and rifle; jump aim up/down with one- and
two-handed weapons; vehicle entry while lowering/low; final Artist14 melee pack
and host-authoritative attack admission/damage.
