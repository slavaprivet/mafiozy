# Vehicle interiors and entry — 2026-09-08

This delivery upgrades the procedural `/walk` sedan only. Main `world.html` and
`three_preview.js` vehicles are inventoried below but have not been migrated.

## Corrected geometry and anchors

The old solid body occupied y=.42..1.04 across the entire cabin. It enclosed the
seats and the seated hero's legs. Its cushion top was .69 m, while the actual
skinned pants bottom at the old root was about .459 m. This explains the visible
intersection. The shell now consists of a low underbody, sills, separate hood and
trunk, pillars, roof and four real door groups, leaving the cabin empty.

Canonical axes are +Z forward / +X driver-left; all values below are metres.

- `DRIVER_SEAT`: `{side:.43,front:-.15,y:.22}` (hero root, not cushion centre).
- Passenger root: `{side:-.43,front:-.15,y:.22}`.
- Rear roots: x=±.43, z=-1.15, y=.22.
- Floor top .40; cushion structural top .59; thin insert/seams reach .616.
- Roof underside 2.08. Front door hinges x=±.92, z=.84, y=.96;
  rear hinges x=±.92, z=-.61, y=.96.
- `car.anchors.doors` includes the exact hinge and external handle positions.

`createVehicleInterior(THREE,RoundedBox,{family})` supports `sedan4`, `coupe` and
`truck`. It returns `object`, `anchors`, `profile`, `parts`, `wheel`, `cargo`,
and `update(carState)`. The truck builder has two front seats in a raised cab and
a separate cargo-bed group. This is a reusable interior builder, not a completed
truck body or production vehicle integration. The sedan includes front/rear
stitched seats and headrests, belt latches, dashboard, vents, radio, round
instruments, left steering wheel and column, gear lever and pedals. Glazing is
transparent and depth-write disabled to expose the interior from third person.

`createDemoCar` preserves `wheels/update/setDoor`, adds `interior/anchors/doors`
and `setRearDoor(amount,side)`. Numeric door map keys ±1 remain front doors;
rear keys are `rear_left/rear_right`. Rear door geometry can animate; passenger
gameplay is not connected. Do not imply that rear seats are already playable.

## Entry integration

Both entry and exit hold exactly .3 s. Entry animation duration is independently
2.6 s. `entryPose` preserves `seat/fold/cabinSlide/door/reach/done` and adds
`phase/handReach/duck/innerLeg/outerLeg/closeReach`. The hand reaches before the
door opens, the inner leg enters first, then the body sits, the outside leg
follows, and the hand closes the door. Pass
`hero.vehiclePose(pose.fold,pose.reach,{...pose,side:t.side})` to the hero adapter.
The moving-exit sweep retains its existing timing and collision prediction.

Hero pose author coordinates the .22 m root with actual skin, floor and cushion
contacts. Geometry tests cannot replace both-door live entry inspection.

## Main-game inventory and migration contract

Sources: `world.html` CAR_MODELS (around line 16853), GANG_CAR_MODELS (16844),
QUEST_CAR_MODELS (16941), POLICE_MODELS (17007); `three_preview.js`
`createVehicleSlot` (2755). Main renderer currently uses +X forward and its own
vehicle scaling. An adapter must explicitly transform axes and metre anchors;
do not attach this +Z builder directly to old slots or change native city 4.1.

| Main-game family / examples | Interior migration requirement |
| --- | --- |
| sedan, taxi, hatch/hatch_blue, classic/classic2, cruiser | Sedan floor and seats; preserve actual door count per body |
| limo, gold_limo, linc_gang, cadillac_eldo | Extended cabin/rear row, longer wheelbase and anchors |
| sport, coupe, supercar, lambo, ferrari, porsche, muscle variants; nine sports quest cars | Two front seats; body-specific low roof, pedals and seat back angle |
| roadster | Open two-seat cabin; no roof glazing |
| suv_black/white, jeep_sand/safari, jeep_gang | Raised floor/seats, actual rear-row and door count; safari open roof |
| pickup, truck | Separate two-seat cab and cargo bed; cabFrac controls body boundary |
| van, minivan, paddyvan | Raised cab plus passenger/cargo compartment and suitable access doors |
| mafia_armored, swat_truck, heavy_gun_truck | Armoured cab and rear compartment; retain turret/equipment anchors |
| ambulance, firetruck, tow | Cab plus medical compartment / firefighting equipment / tow platform; retain all service mechanics |
| helicopter variants and quest motorcycles | Distinct cockpit/saddle contracts; do not apply a sedan cabin |

Every production adapter must retain entity ID, owner, model ID, damage state,
doors/interactions, AI paths, service equipment, inventory and server authority.
Family parameters are a starting contract; each body requires measured cavity,
seat-root, footwell, steering and door-handle anchors before being marked ready.

Automated: `test_vehicle_interiors.mjs`, `test_car_entry.mjs`, `test_car_drive.mjs`,
`test_car_exit.mjs`. Current-browser visual inspection remains the coordinator's
next integration step; this handoff does not claim every vehicle is complete.

## Live feedback follow-up: sealed shell, arches, four independent seats

The user approved the interior and reported gaps and tire/body intersections.
The hood is now a thin lid over a narrow engine core. A cowl under the windscreen,
firewall, door jambs and connected frames close the exterior gaps without filling
the cabin. Fender and rear-door lower contours have actual .48 m wheel-arch
cutouts. The lower central beam and shortened sills clear the tires. Floor width
is 1.55 m and its front edge .78 m so it stays clear of the tire wells.

Full ±.56 rad steering is unchanged. Tire sweep reaches approximately |x|=1.254,
so the conservative collision half-width is now 1.28 m. Geometry tests sample
real tire vertices against the shell from -.56 to +.56; drive and exit tests pass.

`vehicle_seats.mjs` exports four stable IDs: `front_left`, `front_right`,
`rear_left`, `rear_right`. Only `front_left` controls the car. Host integration:

1. Store `occupiedSeat` (null or ID) independently of vehicle control authority.
   Use `!!occupiedSeat` for seated animation, weapon suppression, camera following
   and suppressing walking. Use `canControlVehicle(occupiedSeat)` solely for
   W/S/A/D/Space vehicle input; `inputForVehicleSeat` enforces this restriction.
2. `findVehicleEntry(carState,heroPosition,walkAllowed)` selects the nearest safe
   doorway and returns `{seatId,doorId,side,outside,distance,label,canDrive}`.
   Save the full result in the entry transition; do not infer all entries as driver.
3. `vehicleEntryPoint(carState,seatId,p,outside)` returns `x,y,z,yaw,pose` for the
   exact selected seat. Pass the pose as the third argument to `hero.vehiclePose`.
   No passenger crosses the centre console. On completion set `occupiedSeat`.
4. Every seated frame place the hero at `vehicleSeatPoint(carState,occupiedSeat)`
   and call `hero.vehiclePose(1,0,{driver:canControlVehicle(occupiedSeat),steer,dt,
   steeringGrips:car.getSteeringGrips()})`. The hero adapter consumes grips for
   drivers only. Passenger hands use their seated-rest pose.
5. E exit calls `planVehicleSeatExit(carState,occupiedSeat,driveAllowed,canWalk)`.
   Preserve its `seatId/doorId/side/distance/kind`. During the coasting door phase
   use `vehicleDeparturePoint(carState,t.seatId,t.distance,p)`. Existing
   `launchExitBody` / body recovery remain unchanged. Release `occupiedSeat` when
   the body detaches; stop treating a seated passenger as a pedestrian obstacle.
6. Use `car.setDoorById(amount,t.doorId)` throughout transitions. It animates only
   that door and closes other doors. A blocked own doorway refuses departure;
   it does not teleport the passenger to an opposite seat/door.

`car.getSteeringGrips()` returns `{left,right}` world-space THREE.Vector3 points
on the actual torus rim, including parent transforms and the full wheel rotation.
Wheel local coordinates are x=±.1558846, y=.09, z=-.025. The left grip is physical
driver-left (+X), not a statement about the GLB bone naming convention. The rig
adapter should associate bones with the correct physical side. The wheel object
is available as `car.interior.steeringWheel` (also `wheel`).

`test_vehicle_seats.mjs` verifies every door at four headings, no cross-cabin
slide, driver-only inputs and 64 seat-specific exits across forward/reverse speeds.
The old `car_exit.mjs` API remains for existing callers/tests. These seat modules
are ready for host integration; runtime integration is owned by the coordinator.
