#!/usr/bin/env node
// Read-only oracle for the actual Walk vehicle factory's detachable assemblies.
// It does not export geometry or mutate source assets.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const output = path.join(repo, 'outputs/transport_damage_source');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const relative = value => path.relative(repo, value).replaceAll('\\', '/');
const dependencies = new Set([fileURLToPath(import.meta.url)]);

registerHooks({
  resolve(specifier, context, next) {
    return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
  },
  load(url, context, next) {
    if (url.startsWith('file:')) dependencies.add(fileURLToPath(url));
    return next(url, context);
  },
});

const T = await import('three');
assert.equal(T.REVISION, '180');
const {GLTFLoader} = await import(pathToFileURL(path.join(vendor, 'addons/loaders/GLTFLoader.js')));
const {RoundedBoxGeometry} = await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {ARTIST_VEHICLE_PROFILES, createArtistVehicle} = await import('../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs');
const {createVehicleHood} = await import('../../assets/maps/city_rebuild_v1/vehicle_hood.mjs');
const {createVehicleTrunk} = await import('../../assets/maps/city_rebuild_v1/vehicle_trunk.mjs');
const {decorateCityTaxi} = await import('../../assets/maps/city_rebuild_v1/vehicle_taxi.mjs');
const {CRASH_PART_IDS} = await import('../../assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs');

const manifestPath = path.join(repo, 'outputs/coordinator21_vehicle_visual/manifest.json');
const manifestBytes = fs.readFileSync(manifestPath);
const manifest = JSON.parse(manifestBytes);
assert.equal(manifest.schema, 'mafiozi.vehicle-visual.v1');
const manifestById = new Map(manifest.entries.map(entry => [entry.profile_id, entry]));
const sedan = ARTIST_VEHICLE_PROFILES.find(profile => profile.id === 'compact_sedan');
assert(sedan);
const profiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];

function sourceCopyEligible(source, damageObject = null, marks = []) {
  return !!source && source.visible && source !== damageObject && !marks.includes(source) && !source.isLine && !source.material?.transparent && !source.userData.vehicleRenderBatch;
}

function nodeRecord(node, keyOf, manifestNodes) {
  const key = keyOf.get(node) ?? null;
  const bound = key == null ? null : manifestNodes.get(key) ?? null;
  assert(key && bound, 'Actual assembly is absent from native visual manifest: ' + (node?.name ?? '<null>'));
  assert.equal(bound.source_name, node.name, 'Traversal/source-name mismatch for ' + key);
  return {
    key,
    source_name: node.name,
    visible: node.visible,
    source_metadata: bound.source_metadata,
  };
}

function structuralParts(car) {
  const parts = new Map();
  for (const [key, door] of car.doors || []) {
    const id = typeof key === 'number' ? 'front_' + (key > 0 ? 'left' : 'right') : key;
    parts.set('door_' + id, door);
  }
  for (const wheel of car.wheels || []) parts.set('wheel_' + wheel.id, wheel.pivot);
  const exact = {Hood_lid: 'hood', Trunk_lid: 'trunk', Bumper_front: 'bumper_front', Bumper_rear: 'bumper_rear'};
  car.object.traverse(node => {
    const id = exact[node.name] || (/_FrontBumper$/.test(node.name) ? 'bumper_front' : /_RearBumper$/.test(node.name) ? 'bumper_rear' : null);
    if (id && !parts.has(id)) parts.set(id, node);
  });
  return parts;
}

const rows = [];
for (const profile of profiles) {
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath);
  assert.equal(hash(input), profile.sha256, 'Pinned input changed: ' + profile.id);
  const source = (await new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '')).scene;
  const car = profile.id === 'city_taxi'
    ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source, {...sedan, wheelDesignId: 'city_taxi'}))
    : createArtistVehicle(T, RoundedBoxGeometry, source, profile);
  const scene = new T.Scene(); scene.add(car.object);
  const trunk = createVehicleTrunk(T, RoundedBoxGeometry, car, {scene});
  const hood = createVehicleHood(T, RoundedBoxGeometry, car, {scene});
  const vehicleState = {x: 0, y: 0, z: 0, yaw: 0, speed: 0, steer: 0, distance: 0};
  car.update(vehicleState, false); trunk.update(0, {vehicleState}); hood.update(0, {vehicleState});

  const wrapper = new T.Group(); wrapper.name = 'VehicleVisual'; wrapper.rotation.y = Math.PI; wrapper.add(car.object); wrapper.updateMatrixWorld(true);
  const keyOf = new Map(); let index = 0;
  wrapper.traverse(node => keyOf.set(node, 'v' + (index++).toString().padStart(4, '0')));
  const native = manifestById.get(profile.id); assert(native, 'Missing native entry: ' + profile.id);
  const nativePath = path.join(path.dirname(manifestPath), native.file);
  const nativeBytes = fs.readFileSync(nativePath);
  assert.equal(nativeBytes.length, native.bytes, 'Native visual byte count changed: ' + profile.id);
  assert.equal(hash(nativeBytes), native.sha256, 'Native visual SHA changed: ' + profile.id);
  const manifestNodes = new Map(native.nodes.map(node => [node.key, node]));
  assert.equal(keyOf.size, native.nodes.length, 'Traversal node count changed: ' + profile.id);
  for (const [node, key] of keyOf) assert.equal(manifestNodes.get(key)?.source_name, node.name, 'Native traversal mismatch: ' + profile.id + '/' + key);
  assert.equal(native.sha256.length, 64);

  const explosionSources = [
    ...car.doors.values(),
    ...(car.shell || []).filter(node => ['Hood_lid', 'Trunk_lid'].includes(node.name)),
    ...car.wheels.map(wheel => wheel.pivot),
  ].slice(0, 10);
  let nextDraw = 1;
  const explosion = explosionSources.map((node, sourceIndex) => {
    const copyEligible = sourceCopyEligible(node);
    const draws = copyEligible ? Array.from({length: 7}, (_, i) => nextDraw + i) : [];
    nextDraw += draws.length;
    return {
      source_index: sourceIndex,
      ...nodeRecord(node, keyOf, manifestNodes),
      copy_eligible: copyEligible,
      rng_draw_indices: draws,
      rng_slots: copyEligible ? ['angle', 'strength', 'vertical_velocity', 'landing_yaw', 'spin_x', 'spin_y', 'spin_z'] : [],
    };
  });

  const selected = structuralParts(car);
  const structural = CRASH_PART_IDS.map(id => {
    const node = selected.get(id) ?? null;
    return {id, ...(node ? nodeRecord(node, keyOf, manifestNodes) : {key: null, source_name: null, visible: null, source_metadata: null})};
  });
  const missingStructuralIds = structural.filter(part => !part.key).map(part => part.id);

  rows.push({
    profile_id: profile.id,
    source_profile_id: profile.source_profile_id ?? profile.id,
    input_glb: {path: relative(inputPath), sha256: hash(input), expected_sha256: profile.sha256},
    native_visual: {path: relative(nativePath), file: native.file, sha256: native.sha256, bytes: native.bytes},
    wrapper: {key: keyOf.get(wrapper), source_name: wrapper.name, rotation_y_rad: Math.PI, native_basis: 'RY(pi)'},
    profile_source_metadata: manifestNodes.get(keyOf.get(car.object)).source_metadata,
    explosion,
    explosion_rng_draw_count: nextDraw - 1,
    structural,
    missing_structural_ids: missingStructuralIds,
  });
}

const requiredSourcePaths = [
  'assets/maps/city_rebuild_v1/vehicle_damage.mjs',
  'assets/maps/city_rebuild_v1/vehicle_crash.mjs',
  'assets/maps/city_rebuild_v1/vehicle_crash_mechanics.mjs',
];
for (const value of requiredSourcePaths) dependencies.add(path.join(repo, value));
const sourceFiles = [...dependencies]
  .filter(value => value === repo || value.startsWith(repo + path.sep))
  .filter(value => fs.existsSync(value) && fs.statSync(value).isFile())
  .map(value => ({path: relative(value), sha256: hash(fs.readFileSync(value))}))
  .sort((a, b) => a.path.localeCompare(b.path, 'en'));
const result = {
  schema: 'mafiozi.transport-damage-source-assemblies.v1',
  source: 'Actual Walk artist factory + hood + trunk, same bootstrap and traversal as tools/godot/export_vehicle_visual.mjs',
  native_manifest: {path: relative(manifestPath), sha256: hash(manifestBytes), schema: manifest.schema},
  source_files: sourceFiles,
  rng_contract: {
    per_successful_explosion_copy: 7,
    order: ['angle', 'strength', 'vertical_velocity', 'landing_yaw', 'spin_x', 'spin_y', 'spin_z'],
    rejected_copy_draws: 0,
  },
  rows,
};
assert.equal(rows.length, 13);
assert(rows.every(row => row.explosion.length <= 10 && row.explosion_rng_draw_count === row.explosion.filter(part => part.copy_eligible).length * 7));
assert(rows.every(row => row.structural.length === 12));
fs.mkdirSync(output, {recursive: true});
const target = path.join(output, 'assemblies.json');
fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({output: relative(target), sha256: hash(fs.readFileSync(target)), profiles: rows.length, explosion_parts: rows.reduce((sum, row) => sum + row.explosion.length, 0), structural_parts: rows.reduce((sum, row) => sum + row.structural.length, 0), missing_structural: rows.filter(row => row.missing_structural_ids.length).map(row => ({profile_id: row.profile_id, ids: row.missing_structural_ids}))}));
