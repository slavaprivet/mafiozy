# `/walk` weapon presentation slice — 2026-09-08

Scope: isolated third-person `/walk` preview. The modules in this slice render
held props, recoil, projectiles, casings, impact marks and the arsenal HUD. They
do not create an inventory, apply damage, admit hits or change ammo ownership.
The existing host remains authoritative for those mechanics and canonical ids.

## Held weapons and hero pose

- All fourteen firearm ids keep their established order and balance aliases.
- Procedural clay-style models now contain 12–19 readable parts, including
  sights, trigger/guard, receiver details, grip panels, selector/pins, stock,
  muzzle crown and an authored ejection port where the action ejects brass.
- `weapon.userData.muzzle`, `ejectionPort`, `supportGrip` and `mountOffset` are
  model-local integration anchors. `resolveWeaponShotTransforms(THREE, model)`
  returns exact world `origin`, `ejectionOrigin` and `direction` after the hero
  skeleton and weapon matrices are updated.
- The real Artist 13 GLB uses world-space two-bone arm IK. The right palm stays
  on the primary grip and the left palm on the per-model support grip without
  translating or scaling bones. One-handed items leave the left arm free.
- Stocks on M16, AK, Tommy, shotgun and sniper, both Uzi folding stocks, and the
  RPG tube/rear cone/pad remain ahead of the torso band in idle, full recoil and
  five aim elevations. The test covers all fourteen models on the actual GLB.
- `hero.update(dt, moving, running, weapon, {aimPitch,recoil,recoilYaw})` accepts
  aim pitch through `-1.28..1.28` radians and poses chest, neck, head, shoulders,
  hands and weapon from the decaying recoil envelope. Rest matrices are restored
  exactly after recoil, jump, vehicle and tumble states.

The coordinated vehicle API is backward compatible:

```js
hero.vehiclePose(seated, reach, {
  ...entryPose,
  side,
  driver: true,
  steer: carState.steer,
  steeringGrips: car.getSteeringGrips(),
  dt,
});
```

`innerLeg` and `outerLeg` stage the two legs on entry; absent fields retain the
legacy symmetric exit fold. `driver:false` puts passenger hands on the lap.
Driver palms use the car's world-space rotating rim anchors. Because the GLB's
bone-side naming and the car's driver-side axis differ, the pose selects the
nearest non-crossing hand-to-rim assignment instead of trusting labels alone.
Driver head yaw follows steering with damping while neck/head counter the cabin
duck so the gaze remains on the road. The real skinned bounds fit the current
sedan floor `0.40`, seat root `(.43,.22,-.15)` and roof underside `2.08`.

## Visible projectiles, brass and marks

`PROJECTILE_VISUALS` contains a distinct visual signature for every firearm id.
Rounds are now small, elongated solid meshes with restrained motion streaks;
there is no glow sphere, billboard or aura in the projectile pool. AK/M16/sniper
use pointed rifle rounds, the two shotguns emit seven small pellets, and RPG
emits a compact pointed rocket with a narrow exhaust trail.

`createWeaponEffects(THREE, scene, options)` preallocates bounded pools: 112
projectiles, 48 casings, 24 muzzle flashes, 48 impact sparks, 72 surface marks
and 6 RPG explosions by default. `shoot()` spawns at the exact muzzle transform. `update(dt)`
moves each projectile and performs a swept raycast for that frame instead of
drawing an instantaneous full-range line. Cases eject from the action; pump
shotgun brass waits for the pump phase, while revolvers retain their cases.

Every ray hit receives a small, dark, irregular chip aligned to the hit face
normal. There are no large burgundy disks. The mark is
attached to `hit.object` with its world transform preserved, so marks on doors,
vehicles, glass and other moving meshes travel and rotate with that object.
Glass chips, pellet marks, bullet marks and RPG scorch marks use restrained size
and color treatments. Every pooled mark stores its own `expiresAt` and disappears
five seconds after its own impact. An RPG hit starts a bounded 1.25 second
fireball with an expanding hot core, eight flame plumes, six smoke volumes,
twelve embers and a shock ring, based on the production explosion profile.

`hero_weapon_fire` copies the exact base damage values from the established
`world.html` `WEAPON_FX_CFG` into each shot receipt. It also emits a stable
`shotId` (`weaponId:sequence`) so all seven shotgun pellet hits can share one
damage event. The effects module never applies damage itself. The host can route
the swept hit to vehicle, glass or other authority with:

```js
const effects = createWeaponEffects(THREE, scene, {
  onImpact(payload) {
    // payload: weaponId, shotId, damage, impulse (= relative damage weight),
    // explosive, projectile, original THREE.Intersection hit, point/normal/
    // direction in world space, and hit object.
    car.damage.impact(payload);
    glassRegistry.hit(payload.hit, payload);
  },
});
```

Existing integration remains valid:

```js
const transforms = resolveWeaponShotTransforms(THREE, weaponModel);
effects.shoot(shot, transforms, target, obstacles);
effects.update(dt);
```

## Arsenal HUD and sniper optic

`createWeaponHud({document,host,arsenal,onSelect})` builds the Q panel without
emoji. Each of the fifteen menu entries has its own authored SVG silhouette.
The panel uses burgundy, brass and dark surfaces; `setState()` exposes ready,
empty, reloading and unarmed states. An empty Deagle with reserve ammunition,
for example, renders `ПУСТО · 0 / 21` with a red warning state.

```js
const hud = createWeaponHud({
  document, host, arsenal: ARSENAL, onSelect:equipWeapon,
  onOpenChange(open) {
    if (open) { releaseControls(); setFreeMouse(false); }
  },
});
hud.setState({weaponId,magazine,reserveAmmo,reloadRemaining,disabled});
hud.setOpen(true);              // or toggle()/handleKeydown(event)
hud.setScopeVisible(aiming && weaponId === 'sniper');
```

`setState()` caches weapon/ammo/disabled values and only writes changed DOM
fields. Disabled state closes the panel and sets actual `disabled` properties on
the launcher and every choice. `onOpenChange` runs for launcher, Q and programmatic
open/close routes, so the host has one place to release movement/combat input.
`host`, `launcher`, `grid` and `scope` are also exposed for minimal host wiring.

The sniper overlay is hidden initially and ignores pointer input. It provides a
circular dark optic, restrained burgundy/brass rim, fine crosshair and tick
marks with a clear center. It does not show invented distance or wind data.

## Automated validation

```text
node assets/maps/city_rebuild_v1/test_hero_walk.mjs
node assets/maps/city_rebuild_v1/test_hero_arsenal.mjs
node assets/maps/city_rebuild_v1/test_hero_weapon_fire.mjs
node assets/maps/city_rebuild_v1/test_weapon_effects.mjs
node assets/maps/city_rebuild_v1/test_weapon_hud.mjs
```

These tests cover the actual GLB hierarchy and skinned bounds, exact one/two
hand anchors, rear-assembly clearance for all fourteen models in idle/aim/recoil,
vertical aim and recoil recovery, fourteen unique small no-aura projectile
visuals, visible time-stepped motion, swept collision, exact muzzle/ejection
transforms, exact world damage and stable shot ids, seven pellets, RPG shape and
fiery explosion, delayed/retained cases, individual five-second dark surface
chips attached to a moving/rotating mesh, pool bounds, fifteen
unique non-emoji icons, empty/reload state and scope pointer passthrough.

Automated results pass. A LIVE PASS is deliberately not claimed here: the
coordinator integrates the new HUD/effects APIs into `walk_preview.mjs` and then
runs the user-visible `/walk` checks for each weapon, walls, glass, the moving
car, empty magazine, reload, scope hold/release, vehicle entry/exit, jump and
tumble recovery.
