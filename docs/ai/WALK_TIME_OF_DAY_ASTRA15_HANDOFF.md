# Astra15: isolated `/walk` time-of-day visual curve — 23 September 2026

`assets/maps/city_rebuild_v1/walk_time_of_day.mjs` is an unimported,
presentation-only extraction of `three_preview.js` lines 5168-5188. No world,
walk preview, clock, interior or production host file changed.

The module reproduces the existing solar curve and palette constants for scene
background, fog colour/density, hemisphere ambient colour/ground/intensity,
sun colour/intensity/offset, renderer exposure, environment intensity, `night`
and scheduled `lampPower`. It intentionally excludes facade, water, sky-shader,
post-process and street-light mutations because the requested walk hook does not
own them.

## Host API

Create once and call every presentation frame. The clock reader is polled at
the source cadence of exactly 250 ms, without catch-up reads. Bridge samples
are accepted only when `hour` and `minute` are number-typed finite integers in
`0..23` and `0..59`. Invalid or throwing later reads retain the last valid city
time; invalid startup uses 12:00. Palette smoothing uses the existing rate
`2.4` and caps a presentation step at `.1 s`, exactly as the source preview
does.

```js
const timeOfDay=createWalkTimeOfDay({
  THREE,
  initialHour:environment.hour,
  initialMinute:environment.minute,
});

const frame=timeOfDay.update(performance.now(),()=>bridge.getEnvironmentState(),{
  weather:selectedWeather,
});
timeOfDay.apply(frame,{
  scene,
  ambient:skyLight,
  sun,
  renderer,
  sunOffsetVector,
  interiorLightingActive,
});
environmentNight=frame.night;
environmentLampPower=frame.lampPower;
```

`update` and its colour/vector members are reusable. A dt=0 frame does not
advance smoothing. Production bridge hours never wrap. Only an explicit
number-typed QA offset set with `timeOfDay.setOffset(hours)` wraps across
midnight; strings, booleans and non-finite offsets are rejected.

`timeOfDay.dispose()` is idempotent. After disposal, `update` returns the same
frozen-in-place output and `apply` returns `false`. `stats` reports accepted
and rejected bridge reads, total samples, next poll, active QA offset and the
disposed flag for host diagnostics.

`applyWalkTimeOfDay` never replaces `scene.fog`: it copies colour and changes
`density` only for an existing `FogExp2`. An existing linear `Fog` keeps its
type, `near` and `far`. When `interiorLightingActive` is true it returns `false`
without touching background, fog, lights, exposure or environment intensity.

## Verification

`test_walk_time_of_day.mjs` PASSes exact source-curve checkpoints at 00:00,
05:00, 06:21, 12:00, 17:00, 18:39 and 22:00; explicit-offset 24-hour wrap;
strict bridge clock rejection and last-good retention; exact 250 ms cadence;
exponential smoothing and dt=0; reusable output objects;
both `FogExp2` and linear `Fog`; interior isolation; and every owned render
channel, disposal and bridge diagnostics. The final 500,000-sample CPU loop completed in about 0.095 s after the
reusable palette cache was added. This is a
CPU unit test, not a LIVE/GPU acceptance.
