# Vehicle damage / walk adapter — 2026-09-08

This is the isolated `/walk` sedan adapter. The main game's client and server
files were read, not changed. No ownership, economy, occupant health, service AI,
respawn, insurance or server authority was introduced or replaced.

## Source rules retained

`world.html::_damageCarByGun` (around 34924): max HP is `max(120,max_hp ||
(suv ? 360 : van ? 420 : 240))`; regular armor divisor 1.65, otherwise 1;
damage `max(4,round(weaponDamage/armor))`. Smoke at ratio <=.55, fire <=.24.
Zero ballistic HP starts smoke-only destruction for 1550 ms, then one wreck
explosion. Shotgun applies HP damage once per trigger while making several marks.

`world.html::reportCarCrash` (50011): damage `min(80,round(impactTilesPerSecond²
*1.4))`, 250 ms cooldown. Server `mafiozi_bot.py::gta_crash` (18713) only accepts
driver/passenger requests, clamps damage 0..100 and owns resulting HP/wreck state.
`QUEST_CAR_HP=220` is a distinct server default; it does not replace this ordinary
preview sedan's source-default 240 HP.

The old wall caller admits only impact >5.5 tiles/s (22.55 m/s at native 4.1).
That exceeds `/walk`'s maximum 22 m/s. Explicitly approved demo adaptation:
the adapter applies the same quadratic formula to actual speed lost during a
collision, converting metres/s by 4.1, without the old >5.5 admission gate.
Glancing contacts with negligible speed loss therefore cause negligible/no HP
damage. The main wall admission rule is untouched.

`world.html::_spawnRpgExplosion` (34734) immediately wrecks ordinary cars within
1.55 tiles of impact. The preview uses the same 1.55*4.1 m radius around its one
sedan; this may include a nearby building impact. RPG's weapon module owns the
impact fireball. Car damage emits one vehicle-wreck event and debris/fire but
suppresses its own fireball for this case. Bullet-induced destruction retains
the separate 1550 ms countdown and its own blast. Chain-reaction budgets,
armored police turret suppression and occupied-main-car exceptions remain main
game mechanics; this single-sedan adapter does not claim to migrate those systems.

## Host integration

```
const damage = createVehicleDamage(THREE, car, {
  onExplosion(event) {
    // Optional: glassRegistry.shatterAll(car.object) before panes are hidden.
    // Host handles safe occupant detachment; do not invent player HP here.
  }
});
// Weapon-effects onImpact callback, with source weapon damage:
damage.impact(payload);
// Around the one real stepCar:
const before = carState;
carState = stepCar(carState, damage.disabled ? {} : input, dt, allowed);
damage.collision(before, carState);
damage.update(dt);
if (damage.disabled) carState.speed = 0;
```

Call `update(dt)` every frame. Gate entry and driving while `disabled` (destroying
or wrecked). `reset()` restores original geometry, materials, glass visibility and
HP; call it with the scene's reset. `dispose()` releases only adapter-owned GPU
resources and restores the car. Reset/dispose the shared glass registry alongside
this adapter. `damage.state`, `damage.stats()` support UI and live QA.

Impact payload: `{object,point,normal,damage,shotId,explosive}`; positions/normals
are world-space THREE vectors. The adapter checks car ancestry. `shotId` must be
unique per weapon/trigger; all shotgun pellets share it. Duplicate pellets can
leave marks but cannot subtract HP twice. `car.object.userData.vehicleDamageTarget`
is `walk_sedan` for routing. Invalid/missing damage does not silently substitute
a guessed value. Weapon agent supplies exact source damage on each shot.

Visual damage deforms the actual hit mesh locally. Broad flat triangles receive
support vertices once; cumulative displacement is clamped to .18 m. Scratches
and bullet marks attach to the hit mesh and follow doors/car movement. Collision
marks raycast the shell along impact travel rather than floating at an arbitrary
world position. Destruction darkens body materials, lifts/bends hood/trunk panels,
and uses bounded pools: 32 marks, 14 smoke puffs, 9 flames, 3 blast layers,
18 metal/body debris pieces. Glass fragments belong to `glass_breakage`, not to
this module. Debris is cosmetic ballistic motion on the flat demo ground.

## Verification

`test_vehicle_damage.mjs` passes source HP/armor/thresholds, delayed single blast,
collision formula and cooldown, trigger deduplication and bounded event memory,
local centre-panel vertex deformation, original-geometry reset and disposal,
RPG radius and fireball ownership. Vehicle drive, seats and exit regression suites
remain separate. Browser shooting/collision/destruction is the coordinator's next
live stage; unit tests do not establish live acceptance.
# Explosion presentation revision — 2026-09-08

The wreck now keeps a near-black, rough chassis permanently until reset. On its
single explosion, four doors, the hood, trunk lid and four wheel assemblies are
copied from their actual current geometry and thrown outward. The source parts
remain hidden on the wreck. Copies own their geometry/materials, never receive
ballistic hits, and are individually removed and disposed five seconds after
their spawn. Maximum ten assemblies; no generic cube debris remains.

Fire uses 24 bounded rising orange/yellow tongues and a local flickering light.
Post-explosion fire, smoke and blast visuals end within five seconds; the charred
frame has no expiry. HP, armor, delay, crash formula and one-explosion/RPG ownership
are unchanged. Shared glass still receives onExplosion before panes are hidden.
Reset restores original parts, paint, geometry and visibility. Adapter API is
unchanged; stats additionally exposes visible flame count. Unit verification
covers actual named part clones, five-second disposal, persistent chassis and
full reset. Browser review remains with the coordinator.
