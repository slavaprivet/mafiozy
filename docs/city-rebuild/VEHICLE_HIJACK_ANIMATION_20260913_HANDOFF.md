# Driver extraction animation — Artist 17

Production files: `vehicle_hijack_pose.mjs`, narrow integration in `npc_actor.mjs`. The walk host, source ownership/HP and extraction trajectory belong to the parent/trips owner; this module never moves authoritative roots or decides whether an extraction succeeds.

## Contracts

NPC snapshot `life.vehicleHijack`:

```js
{phase:'seated'|'pulled'|'released', progress:0..1,
 carId:'actual source presentation car ID', seatId:'front_left', side:-1,
 eventId:'stable receipt ID'}
```

`seated` keeps an already-dead driver slumped in the native seat; it does not require progress. `pulled` uses source progress and the actual vehicle seat binding, unfolds the body and presents live resistance or a limp corpse fall. `released`/absent relinquishes animation ownership. Dead/alive is taken from the existing actor lifecycle, never from an animation request. The source must maintain the victim's existing car yaw through extraction and physically advance its root to the outside position. No source HP/death timestamps are reset.

The final dead extraction uses the existing Artist14 death pose and **its existing death side**, so clearing the extraction receipt does not turn or revive the body. Custody/cuffed presentation suppresses the new extraction layer. Active extraction suppresses only the competing reaction's visual application, while keeping its lifecycle state intact.

Hero integration:

```js
const pose = createVehicleHijackPose({THREE, walker, getVehicle});
pose.applyPuller(source.vehicleEntry, {blocked: isDeadOrInCustody});
```

Call after the hero's normal pose. Recreate/cache one helper per actual walker on model swaps. The hero receipt uses `phase:'pull_driver', progress, carId, victimId, seatId`. An optional `gripWorld:{x,y,z}` should come from the actual victim's upper-arm/chest world position; without it the helper uses the authored car seat as the contact reference. Source controls the pulling character's position, yaw and weapon visibility.

`life.hijackReaction:{phase:'protest'|'retake'|'flee',eventId,since,until,carId}` drives a brief two-arm protest for living unarmed characters. Since/until are source milliseconds and pose time is seconds. Flee uses the existing locomotion. Phone/corpse-report animation reuses existing `life.phoneCalling`: the phone object, hand pose and source wait already exist. The reaction owner must avoid simultaneous panic/flee flags while holding the call, since those states correctly take precedence over a phone pose.

## Verification

`node assets/maps/city_rebuild_v1/test_vehicle_hijack_pose.mjs` exercises actual male/female hero skeletons and compact sedan GLB, 61 extraction phases for alive/dead actors. Checks include finite bones, unchanged bone lengths/scales, preserved authoritative root/yaw, seated-corpse continuity, persistent death, final match to the ordinary grounded death pose, pulling-arm IK without stretching, and blocked protest priority.

Maximum per-sample bone displacement: living .0512/.0520 m; dead .2770/.2921 m (the authored rapid fall). Final extraction-to-standard-death displacement stays below .08 m. Test CPU actor update measured p50 about .18–.25 ms, p95 1.48–1.75 ms across short runs. This includes the existing base/vehicle/death pose work; it is not an isolated regression delta or a global FPS measurement. JSON output is `outputs/vehicle_hijack_animation_20260913.json`.

Existing `test_npc_actor.mjs` and actual male/female `test_hero_custody_vehicle_pose.mjs` also pass. The module adds no meshes, textures or draw calls, and its vectors/quaternions are initialized lazily only for an affected actor. Normal crowd actors do not instantiate a new pose helper.

No GPU scene was opened. Full scene performance and visible source-driven carjacking still require the parent's single-scene LIVE check. Animation tests do not prove police calls, vehicle ownership changes, source collision trajectories or successful theft. New authoring assets were not created; all movement uses the accepted hero/NPC rigs.
