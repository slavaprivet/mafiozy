# `/walk` day/night host plan — HOLD-safe source gate — 23 September 2026

Status: **HOLD-ready, not integrated**. This plan does not edit
`walk_preview.mjs`, `world.html`, `three_preview.js` or the live game. It is
intended for the owner slot after traversal integration has settled.

The source gate is semantic. It checks stable responsibilities and call sites,
so it does not depend on the old whole-file hash `EDDA124C…BA2E`, which can
legitimately change while traversal lands:

```powershell
node assets/maps/city_rebuild_v1/test_walk_time_of_day_host_gate.mjs
$env:WALK_TOD_REQUIRE_INTEGRATED='1'
node assets/maps/city_rebuild_v1/test_walk_time_of_day_host_gate.mjs
Remove-Item Env:WALK_TOD_REQUIRE_INTEGRATED
```

The first command must report `HOLD-ready` on the current unintegrated host.
The required mode must fail until every integration responsibility below is
present. A candidate copy can be checked without touching production with
`WALK_PREVIEW_CANDIDATE`.

## Intended bounded diff

Only `walk_preview.mjs` is changed in the later owner slot; it imports the
already isolated `walk_time_of_day.mjs`. The bounded edit consists of:

1. One import of `createWalkTimeOfDay`.
2. One controller, one reusable `walkSunOffset`, and presentation values for
   `environmentNight`, `environmentLampPower` and the QA offset. The controller
   lives outside `clearContent`, so a content rebuild neither recreates nor
   disposes it. Also create one stable `walkTimeTargets` object; only its
   `interiorLightingActive` boolean changes per frame.
3. One `update` and one `apply` in each active presentation frame, after the
   base hero/traversal presentation and before culling/street lights. The
   250 ms bridge reader calls `npcBridge?.getEnvironmentState?.()` and samples
   `npcBridge?.getInteriorState?.()` in the same bounded reader. The latter is
   a large source snapshot and must not be called directly every frame. An
   interior-read failure retains its last safe flag; the module holds noon at
   invalid clock startup and the last valid clock after a later bad read.
4. `apply` receives `{scene,ambient,sun,renderer,sunOffsetVector:walkSunOffset,
   interiorLightingActive}`. The interior flag combines the existing
   `insideBuilding()` authority with a bridge interior flag when available.
   While indoors, polling and smoothing continue, but background, fog,
   ambient, sun, exposure and environment intensity remain untouched.
5. Publish `environmentNight=walkTimeFrame.night` and
   `environmentLampPower=walkTimeFrame.lampPower`. Pass lamp power to
   `streetLighting.update({...,night:environmentLampPower})`; exterior street
   lighting continues while the player is indoors.
6. Replace the cull-time `new THREE.Vector3(-75,130,90)` with
   `walkSunOffset`. The module updates this reusable vector only when exterior
   presentation is active.
7. Replace the existing night button's direct light/background/fog writes with
   `walkTimeOfDay.setOffset(0|12)`. The label and `aria-pressed` describe a QA
   offset; the authoritative city clock is never overwritten.
8. Extend the existing diagnostics cadence with
   `document.body.dataset.walkTimeOfDay`: hour, phase, daylight, dawn, dusk,
   night, lamp power, QA offset, interior flag, accepted/rejected samples and
   disposed state.
9. Add exactly one `walkTimeOfDay.dispose()` to the existing `pagehide`
   cleanup. Disposal is idempotent.

## Conflict-safe anchors in the current host

The current host includes the new transport imports and presentation hooks.
Use these semantic anchors instead of line numbers:

- Put the import directly after the existing `createStreetLighting` import.
  Do not insert into the earlier transport import group.
- Create the controller beside the existing single declaration that calls
  `createStreetLighting(...)` and initializes `environmentNight`. At that point
  `scene`, `renderer`, `ambient` and `sun` already exist. Keep `npcBridge` where
  it is; define `readWalkTimeSource()` immediately after its existing
  declaration so the dependency is explicit.
- In `frame()`, use the existing `const now=performance.now()` after
  `glass.update(dt)` as the sole timestamp. The exact order is
  `update -> set interior flag -> apply -> publish night/lampPower -> cull ->
  streetLighting.update`. This is after hero/traversal, vehicle and NPC pose
  ownership, and before the only render call, so it cannot steal animation
  ownership and the same frame receives the lighting result.
- Replace only the `new THREE.Vector3(-75,130,90)` inside the existing
  `now-lastCull>250` block. Leave transport, stable-entry-light and power-panel
  updates in that block untouched.
- Add diagnostics to the first existing `if(now-lastStats>1000)` block, beside
  `dataset.streetLighting`; do not add a new timer or stringify every frame.
- Add a short standalone `pagehide` listener beside the HUD/indoor/mercenary
  listeners. Do not modify the large shared cleanup closure containing vehicle,
  NPC, weapon, fleet and content disposal.

The current bridge exposes a strict `{hour, minute}` through
`getEnvironmentState()` and a nullable interior snapshot through
`getInteriorState()`. It does not expose an `interior` field on the environment
object, so a check such as `environment.interior` would silently miss source
interiors.

The reviewed adapter shape is:

```js
let streetLighting=createStreetLighting(/* existing arguments */),
  environmentNight=0,environmentLampPower=0;
const walkTimeOfDay=createWalkTimeOfDay({THREE});
const walkSunOffset=new THREE.Vector3(-75,130,90);
const walkTimeTargets={scene,ambient,sun,renderer,
  sunOffsetVector:walkSunOffset,interiorLightingActive:false};
let walkTimeFrame=walkTimeOfDay.output,walkTimeQaOffsetHours=0,
  walkTimeSourceInterior=false;

// Place immediately after the existing npcBridge declaration.
function readWalkTimeSource(){
  const environment=npcBridge?.getEnvironmentState?.();
  try{walkTimeSourceInterior=!!npcBridge?.getInteriorState?.()}catch{}
  return environment;
}

// Inside frame(), using its existing `now`.
walkTimeFrame=walkTimeOfDay.update(now,readWalkTimeSource);
walkTimeTargets.interiorLightingActive=insideBuilding()||walkTimeSourceInterior;
walkTimeOfDay.apply(walkTimeFrame,walkTimeTargets);
environmentNight=walkTimeFrame.night;
environmentLampPower=walkTimeFrame.lampPower;
// Existing cull block follows, with `.add(walkSunOffset)`.
// Then: streetLighting.update({focus:...,night:environmentLampPower});
```

Passing the named reader and stable target object avoids new closures and apply
target objects on every rendered frame. `walkTimeOfDay.stats` is intentionally
read only inside the existing one-second diagnostics block because that getter
returns a diagnostic snapshot object.

The integration must not edit world time, interiors, weather ownership,
`street_lighting.mjs`, or the source curve in `three_preview.js`.

## Required checks before LIVE

```powershell
node assets/maps/city_rebuild_v1/test_walk_time_of_day.mjs
node assets/maps/city_rebuild_v1/test_walk_time_of_day_host_gate.mjs
node assets/maps/city_rebuild_v1/test_street_lighting.mjs
```

After the bounded host patch, rerun the semantic gate with
`WALK_TOD_REQUIRE_INTEGRATED=1`. Use the coordinator's existing game tab; do
not open a second GPU scene. In that tab:

- inspect `document.body.dataset.walkTimeOfDay`; bridge reads should rise about
  four times per second while presentation still applies once per frame;
- verify 00:00, 05:00, 06:21, 12:00, 17:00, 18:39 and 22:00 against the source
  curve, including lamp power 0 by day, at least 0.48 after 17:00, and 1 at
  full night;
- use the night QA button twice and confirm only the offset toggles, the source
  clock does not change, and returning to zero follows city time smoothly;
- enter an interior, record every owned render channel, advance outdoor time,
  and confirm those channels remain unchanged until exit; after exit they
  resume the current eased city time;
- confirm `scene.fog` keeps object identity and remains linear `Fog` with its
  existing near/far values;
- compare warmed, same-camera frame-time p50/p95 before and after. There must be
  no extra bridge read above the fixed 250 ms cadence and no second per-frame
  application.

Unit/source PASS is not a LIVE or GPU acceptance. Final acceptance needs the
single coordinated game tab and the shared-scene performance comparison.
