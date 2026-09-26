import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {gunzipSync} from 'node:zlib';
import {fileURLToPath} from 'node:url';
import {ARTIST_VEHICLE_PROFILES} from '../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs';
import {VEHICLE_DYNAMICS} from '../../assets/maps/city_rebuild_v1/vehicle_dynamics.mjs';
import {buildEnvironmentVisualPlans} from '../../assets/maps/city_rebuild_v1/environment_planning_worker_core.mjs';
import {explorationKeepouts} from '../../assets/maps/city_rebuild_v1/exploration_scene_support.mjs';

const repositoryRoot = new URL('../../', import.meta.url);
const cityRoot = new URL('assets/maps/city_rebuild_v1/', repositoryRoot);
const outputUrl = new URL('godot/mafiozi_walk/data/transport/vehicle_descriptors.v1.json', repositoryRoot);
const readJson = name => JSON.parse(fs.readFileSync(new URL(name, cityRoot), 'utf8'));
const round = value => Number(Number(value).toFixed(9));
const vector = (x, y, z) => ({x: round(x), y: round(y), z: round(z)});
const localVector = (sourceX, sourceY, sourceZ) => vector(-sourceX, sourceY, -sourceZ);
const godotYaw = sourceYaw => round(Math.atan2(Math.sin(sourceYaw + Math.PI), Math.cos(sourceYaw + Math.PI)));
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');

const sourceFiles = [
  'vehicle_fleet_models.mjs', 'vehicle_dynamics.mjs', 'vehicle_seats.mjs',
  'city_parking_plan.mjs', 'environment_planning_worker_core.mjs',
  'topology_for_placement.json', 'buildings_placement.v1.json',
  'detention_native_sites.v1.json', 'decor_placement.v1.json',
  'test_fixtures/native_static_collision19.json.gz',
];

function adaptedCabin(source) {
  const p = {...source};
  const cabOverAxle = ['van', 'ambulance', 'fire', 'bus'].includes(p.family);
  const floorTop = cabOverAxle ? p.wheelRadius * 2 + .075 : Math.max(.19, p.wheelRadius * .72);
  const bodyH = Math.max(.48, p.height * (['van', 'bus', 'ambulance', 'fire'].includes(p.family) ? .28 : .37));
  const bodyY = p.wheelRadius + bodyH * .52;
  const cabinBase = bodyY + bodyH * .5 - .03;
  const seatRecline = p.family === 'coupe' ? 1 : p.family === 'bus' ? .30 :
    ['fire', 'suv'].includes(p.family) ? .55 :
    ['van', 'ambulance', 'pickup'].includes(p.family) ? .70 : .80;
  const seatedHeadY = floorTop + .817829 + .786602 * Math.cos(seatRecline) + .201946 * Math.sin(seatRecline);
  const cabinRaise = p.family === 'bus' ? 0 : Math.max(0, seatedHeadY + .060 - (cabinBase + p.cabinHeight - .065));
  if (p.family !== 'bus') {
    p.cabinWidth = Math.max(p.cabinWidth, p.width * 1.02);
    p.cabinLength = Math.max(p.cabinLength, p.seatCount === 4 ? 2.72 : 1.65);
    p.cabinHeight += cabinRaise;
  }
  const movedCab = ['van', 'ambulance', 'fire'].includes(p.family) ? p.length * (p.family === 'fire' ? .31 : .28) - .30 : 0;
  const cabinTop = bodyY + bodyH * .5 - .03 + p.cabinHeight;
  let front = p.cabinLength * .5 - .06 + movedCab;
  let rear = -p.cabinLength * .5 + .06 + movedCab;
  let roofBottom = cabinTop - .065;
  if (p.family === 'bus') { front = p.length * .433; rear = p.length * .16; roofBottom = p.height - .12; }
  return {p, floorTop, bodyH, bodyY, front, rear, roofBottom, seatRecline, cabinRaise, movedCab};
}

function sourceProfile(source) {
  const {p, floorTop, bodyH, bodyY, front, rear, roofBottom, seatRecline, cabinRaise, movedCab} = adaptedCabin(source);
  const interiorHalfWidth = Math.min(p.cabinWidth * .5 - .065, p.width * .49);
  const rowCount = p.seatCount === 4 ? 2 : 1;
  const rowLength = (front - rear) / rowCount;
  const gap = .035;
  const seatSide = Math.min(interiorHalfWidth * .50, .52);
  const driverRootY = floorTop - .25;
  const seats = [];
  const doors = [];
  for (const side of [1, -1]) for (let row = 0; row < rowCount; row++) {
    const id = (row ? 'rear_' : 'front_') + (side > 0 ? 'left' : 'right');
    const doorFront = front - row * rowLength - gap;
    const doorRear = p.family === 'bus' ? doorFront - 1.30 : front - (row + 1) * rowLength + gap;
    const sourceMinX = side > 0 ? interiorHalfWidth - .008 : -p.width * .7;
    const sourceMaxX = side > 0 ? p.width * .7 : -interiorHalfWidth + .008;
    const opening = {min: vector(-sourceMaxX, floorTop + .025, -doorFront), max: vector(-sourceMinX, roofBottom - .035, -doorRear)};
    const doorX = side * (p.cabinWidth * .5 - .035);
    const panelTop = bodyY + bodyH * .45;
    const seatZ = front - row * rowLength - Math.min(rowLength * .62, .62);
    const doorFrontMid = (doorRear + doorFront) / 2;
    const canDrive = id === 'front_left';
    doors.push({
      id, side: side > 0 ? 'left' : 'right', row: row ? 'rear' : 'front',
      hinge_local_m: localVector(doorX, Math.max(floorTop + .4, panelTop), doorFront),
      handle_local_m: localVector(doorX + side * .05, panelTop, doorRear + .15),
      opening_local_aabb_m: opening,
    });
    seats.push({
      id, door_id: id,
      label_ru: canDrive ? 'Водитель' : row ? (side > 0 ? 'Задний левый пассажир' : 'Задний правый пассажир') : 'Передний пассажир',
      can_drive: canDrive,
      anchor_local_m: localVector(side * seatSide, driverRootY, seatZ),
      approach_local_m: localVector(side * (p.halfWidth + .57), 0, doorFrontMid),
      source_side: side,
    });
  }
  return {
    profile_id: p.id, label: p.label, family: p.family, model_file: p.modelFile,
    model_sha256: p.sha256, source_units: 'metres', godot_forward_axis: '-Z', source_forward_axis: '+Z',
    seat_count: seats.length, mass_kg: round(p.massKg),
    body_half_extents_m: vector(p.halfWidth, p.height * .5, p.halfLength),
    ground_clearance_m: null, center_of_mass_local_m: null,
    wheelbase_m: round(p.wheelBase), track_width_m: null, wheel_radius_m: round(p.wheelRadius),
    suspension_rest_length_m: null, steering_limit_rad: round(VEHICLE_DYNAMICS.maxSteer),
    engine_accel_mps2: round(p.acceleration), brake_decel_mps2: round(VEHICLE_DYNAMICS.serviceDeceleration),
    reverse_accel_mps2: 4.5, max_forward_speed_mps: round(p.maxSpeed), max_reverse_speed_mps: round(p.reverseSpeed),
    linear_drag: round(VEHICLE_DYNAMICS.coastDrag), angular_drag: null,
    dynamics_note: p.physicsTuning,
    physics_source_provenance: {
      exact_or_source_derived: ['mass_kg', 'body_half_extents_m', 'wheelbase_m', 'wheel_radius_m', 'steering_limit_rad', 'engine_accel_mps2', 'brake_decel_mps2', 'reverse_accel_mps2', 'max_forward_speed_mps', 'max_reverse_speed_mps', 'linear_drag'],
      unavailable_in_walk_source: ['ground_clearance_m', 'center_of_mass_local_m', 'track_width_m', 'suspension_rest_length_m', 'angular_drag'],
    },
    cabin_derivation: {floor_top_m: round(floorTop), roof_bottom_m: round(roofBottom), seat_recline_rad: round(seatRecline), cabin_raise_m: round(cabinRaise), source_cab_forward_correction_m: round(movedCab)},
    seats, doors,
  };
}

function currentParkingPlan() {
  const staticSnapshot = JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz', cityRoot))));
  const buildings = [...readJson('buildings_placement.v1.json').instances, ...readJson('detention_native_sites.v1.json').instances];
  const authoredDecor = readJson('decor_placement.v1.json').instances;
  assert.deepEqual(staticSnapshot.buildings, buildings, 'tracked collision fixture and building placement differ');
  assert.equal(staticSnapshot.authoredDecor.length, authoredDecor.length, 'tracked decor fixture differs');
  const instances = [...buildings, ...authoredDecor];
  return buildEnvironmentVisualPlans({
    topology: readJson('topology_for_placement.json'), instances,
    keepouts: explorationKeepouts(instances), decorPlan: {colliders: staticSnapshot.decorPlan.colliders},
  }).parkingPlan;
}

function parkingDescriptors(plan) {
  const lotsById = new Map(plan.lots.map(lot => [lot.id, lot]));
  return plan.bays.map(bay => {
    const lot = lotsById.get(bay.lotId);
    if (!lot) throw new Error('Parking bay has no lot: ' + bay.id);
    return {
      parking_id: bay.id, lot_id: bay.lotId, building_id: lot.buildingId,
      kind: lot.kind, layout: lot.layout,
      position_m: vector(bay.x, lot.groundY ?? 0, bay.z), yaw_rad: godotYaw(bay.yaw),
      width_m: round(bay.width), length_m: round(bay.length),
      exit_rule: lot.exitRule,
    };
  });
}

const parking = currentParkingPlan();
const sources = sourceFiles.map(path => ({path: 'assets/maps/city_rebuild_v1/' + path, sha256: sha256(fs.readFileSync(new URL(path, cityRoot)))}));
const document = {
  schema: 'mafiozi.transport.descriptors.v1',
  authority: {kind: 'derived_from_tracked_walk_source', immutable: true, sources},
  coordinate_system: {units: 'metres', up: '+Y', forward: '-Z', left: '-X', source_local_conversion: 'godot_local=(-source_x,source_y,-source_z)', source_yaw_conversion: 'godot_yaw=wrap(source_yaw+pi)'},
  lifecycle_contract: {
    vehicle_identity: ['vehicle_id', 'life_generation'], actor_identity: ['actor_id', 'life_generation'],
    source_clock: 'strictly_monotonic_integer_microseconds',
    session_modes: ['NEW_SESSION_BOOTSTRAP', 'IMPORTED_EXISTING'],
    births: 'explicit_authoritative_roster_only', hold_duration_us: 300000,
  },
  profiles: ARTIST_VEHICLE_PROFILES.map(sourceProfile),
  parking: {source_version: parking.version, metres_per_cell: parking.metresPerCell, stats: parking.stats, bays: parkingDescriptors(parking)},
};

fs.mkdirSync(new URL('.', outputUrl), {recursive: true});
fs.writeFileSync(outputUrl, JSON.stringify(document, null, 2) + '\n');
console.log(JSON.stringify({output: fileURLToPath(outputUrl), profiles: document.profiles.length, lots: parking.lots.length, bays: document.parking.bays.length, sha256: sha256(fs.readFileSync(outputUrl))}));
