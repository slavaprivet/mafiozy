import fs from 'node:fs';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {relative, resolve} from 'node:path';
import {ARTIST_VEHICLE_PROFILES} from '../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs';

const repositoryRoot = new URL('../../', import.meta.url);
const defaultInput = new URL('outputs/coordinator21_vehicle_visual/manifest.json', repositoryRoot);
const output = new URL('godot/mafiozi_walk/data/transport/vehicle_factory_oracle.v1.json', repositoryRoot);
const input = process.argv[2] ? pathToFileURL(resolve(process.argv[2])) : defaultInput;
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const finite = value => Number.isFinite(Number(value));
const vector = value => Array.isArray(value) && value.length === 3 && value.every(finite);

const inputBytes = fs.readFileSync(input);
const repositoryPath = fileURLToPath(repositoryRoot);
const inputPath = fileURLToPath(input);
const sourceManifestPath = relative(repositoryPath, inputPath).replaceAll('\\', '/');
const manifest = JSON.parse(inputBytes);
assert.equal(manifest.schema, 'mafiozi.vehicle-visual.v1');
assert.equal(manifest.godot_forward, '-Z');
assert.equal(manifest.source_forward, '+Z');
const entries = new Map(manifest.entries.map(entry => [entry.profile_id, entry]));
const profiles = ARTIST_VEHICLE_PROFILES.map(source => {
  const entry = entries.get(source.id);
  assert(entry, 'actual factory manifest missing ' + source.id);
  assert.equal(entry.source_glb_sha256, source.sha256, 'source GLB mismatch for ' + source.id);
  const runtime = entry.runtime_profile;
  assert(runtime && finite(runtime.half_width_m) && finite(runtime.half_length_m) && finite(runtime.height_m));
  assert(vector(runtime.bounds_source_m?.min) && vector(runtime.bounds_source_m?.max));
  const expectedSeats = source.seatCount;
  assert.equal(entry.anchors.length, expectedSeats, 'seat count mismatch for ' + source.id);
  for (const anchor of entry.anchors) {
    assert(anchor.id && anchor.door_id && typeof anchor.can_drive === 'boolean');
    assert(vector(anchor.seat_local_m) && vector(anchor.approach_local_m) && vector(anchor.handle_local_m));
  }
  return {
    profile_id: entry.profile_id,
    source_glb_sha256: entry.source_glb_sha256,
    runtime_profile: entry.runtime_profile,
    anchors: entry.anchors,
  };
});

const document = {
  schema: 'mafiozi.transport.vehicle-factory-oracle.v1',
  authority: {
    kind: 'projection_of_actual_createArtistVehicle_post_assembly_output',
    source_manifest: sourceManifestPath.startsWith('../') ? inputPath.replaceAll('\\', '/') : sourceManifestPath,
    source_manifest_sha256: sha256(inputBytes),
    source_factory: 'assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs:createArtistVehicle',
    factory_order: 'body assembly -> visualBounds/profile mutation -> seat doorDistance mutation',
    coordinate_system: {units: 'metres', up: '+Y', forward: '-Z', left: '-X'},
  },
  profiles,
};
fs.mkdirSync(new URL('.', output), {recursive: true});
fs.writeFileSync(output, JSON.stringify(document, null, 2) + '\n');
console.log(JSON.stringify({input: fileURLToPath(input), input_sha256: sha256(inputBytes), output: fileURLToPath(output), output_sha256: sha256(fs.readFileSync(output)), profiles: profiles.length}));
