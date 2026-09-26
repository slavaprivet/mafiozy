#!/usr/bin/env node
// Export the actual Walk factory, preserving independent doors/wheels/panels.
// No source world/session birth, game authority, or source GLB is modified.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const addon = process.env.MAFIOZI_GLTF_EXPORTER ?? path.join(repo, 'outputs/astra21_npc_visual_source/deps/GLTFExporter.mjs');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
assert.equal(hash(fs.readFileSync(addon)), 'e7c29444454eb321b39e4c8b3062944f4fd5299a0e7483e9cb8c0594cdec829f', 'Pinned Three r180 exporter');
const dependencies = new Set([fileURLToPath(import.meta.url), addon]);
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
const {GLTFExporter} = await import(pathToFileURL(addon));
const {RoundedBoxGeometry} = await import('../vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const {ARTIST_VEHICLE_PROFILES, createArtistVehicle} = await import('../../assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs');
const {createVehicleHood} = await import('../../assets/maps/city_rebuild_v1/vehicle_hood.mjs');
const {createVehicleTrunk} = await import('../../assets/maps/city_rebuild_v1/vehicle_trunk.mjs');
const {decorateCityTaxi} = await import('../../assets/maps/city_rebuild_v1/vehicle_taxi.mjs');
if (!globalThis.FileReader) globalThis.FileReader = class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then(result => {this.result = result; this.onloadend?.({target: this});}, error => {this.error = error; this.onerror?.(error);});
  }
};
const args = process.argv.slice(2);
let output = path.join(repo, 'outputs/coordinator21_vehicle_visual');
let profileId = null;
for (let i = 0; i < args.length; ++i) {
  if (args[i] === '--output' && args[i + 1]) output = path.resolve(args[++i]);
  else if (args[i] === '--profile' && args[i + 1]) profileId = args[++i];
  else throw Error('Unknown or incomplete argument: ' + args[i]);
}
const sedan = ARTIST_VEHICLE_PROFILES.find(p => p.id === 'compact_sedan');
const fleetProfiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];
const profiles = fleetProfiles.filter(p => !profileId || p.id === profileId);
assert(profiles.length > 0, 'Unknown profile');
fs.mkdirSync(output, {recursive: true});
const basis = new T.Matrix4().makeRotationY(Math.PI);
const convert = point => new T.Vector3(...point).applyMatrix4(basis).toArray();
const entries = [];
let materialIds = new Map();

function materialState(m) {
  for (const value of Object.values(m)) assert(!value?.isTexture, 'Texture requires explicit transfer: ' + m.name);
  assert(m.isMeshStandardMaterial || m.isMeshBasicMaterial, 'Unsupported material: ' + m.type);
  assert.equal(m.onBeforeCompile, T.Material.prototype.onBeforeCompile, 'Custom shader requires explicit transfer');
  if (!materialIds.has(m)) materialIds.set(m, 'm' + materialIds.size.toString().padStart(4, '0'));
  return {source_material_id: materialIds.get(m), source_metadata: structuredClone(m.userData),
    name: m.name, type: m.type, color_linear: m.color.toArray(), roughness: m.roughness ?? null, metallic: m.metalness ?? null,
    emissive_linear: m.emissive?.toArray() ?? [0, 0, 0], emissive_intensity: m.emissiveIntensity ?? 0,
    opacity: m.opacity, transparent: m.transparent, depth_write: m.depthWrite, depth_test: m.depthTest,
    side: m.side, vertex_colors: m.vertexColors, flat_shading: m.flatShading,
    ior: m.ior ?? null, specular_intensity: m.specularIntensity ?? null};
}

// GLTFExporter normalizes source normals, including zeros. Restore the exact
// FLOAT32 source buffer rather than silently accepting changed attributes.
function preserveNormals(raw, sourceMeshes) {
  const bytes = Buffer.from(raw), jsonLength = bytes.readUInt32LE(12);
  const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength).toString('utf8'));
  const bin = Buffer.from(bytes.subarray(28 + jsonLength));
  const visited = new Map();
  let corrected = 0;
  for (const node of gltf.nodes ?? []) {
    if (node.mesh == null) continue;
    const source = sourceMeshes.get(node.extras?.vehicle_visual_key);
    assert(source, 'Unbound exported mesh');
    for (const primitive of gltf.meshes[node.mesh].primitives) {
      const index = primitive.attributes.NORMAL;
      if (index == null) {assert(!source.geometry.attributes.normal); continue;}
      const values = source.geometry.attributes.normal.array;
      const accessor = gltf.accessors[index], view = gltf.bufferViews[accessor.bufferView];
      assert.equal(accessor.componentType, 5126); assert.equal(accessor.type, 'VEC3');
      assert.equal(accessor.count * 3, values.length); assert.equal(view.buffer, 0);
      assert(!accessor.sparse);
      const sourceBytes = Buffer.from(values.buffer, values.byteOffset, values.byteLength);
      if (visited.has(index)) {assert(visited.get(index).equals(sourceBytes)); continue;}
      visited.set(index, Buffer.from(sourceBytes));
      const start = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0), stride = view.byteStride ?? 12;
      const min = [Infinity, Infinity, Infinity], max = [-Infinity, -Infinity, -Infinity];
      for (let i = 0; i < accessor.count; i++) for (let c = 0; c < 3; c++) {
        const at = start + i * stride + c * 4, value = values[i * 3 + c];
        if (!Object.is(bin.readFloatLE(at), value)) corrected++;
        bin.writeFloatLE(value, at); min[c] = Math.min(min[c], value); max[c] = Math.max(max[c], value);
      }
      if (accessor.min) accessor.min = min; if (accessor.max) accessor.max = max;
    }
  }
  // Offline byte-exact buffer-view sharing: no vertex quantization, decimation
  // or change of surface ownership. This reduces package/IO cost only.
  const uniqueViews = new Map(), chunks = [];
  let packedLength = 0;
  for (const view of gltf.bufferViews ?? []) {
    assert.equal(view.buffer, 0);
    const payload = bin.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength);
    const layout = {...view}; delete layout.byteOffset;
    const key = JSON.stringify(layout) + ':' + hash(payload);
    const candidates = uniqueViews.get(key) ?? [];
    const same = candidates.find(row => row.bytes.equals(payload));
    if (same) {view.byteOffset = same.offset; continue;}
    const padding = (4 - packedLength % 4) % 4;
    if (padding) {chunks.push(Buffer.alloc(padding)); packedLength += padding;}
    view.byteOffset = packedLength;
    candidates.push({offset: packedLength, bytes: payload}); uniqueViews.set(key, candidates);
    chunks.push(payload); packedLength += payload.length;
  }
  const packedBin = Buffer.concat([...chunks, Buffer.alloc((4 - packedLength % 4) % 4)]);
  gltf.buffers[0].byteLength = packedBin.length;
  const text = Buffer.from(JSON.stringify(gltf));
  const json = Buffer.concat([text, Buffer.alloc((4 - text.length % 4) % 4, 32)]);
  const header = Buffer.alloc(20), binHeader = Buffer.alloc(8);
  header.write('glTF'); header.writeUInt32LE(2, 4); header.writeUInt32LE(28 + json.length + packedBin.length, 8);
  header.writeUInt32LE(json.length, 12); header.writeUInt32LE(0x4e4f534a, 16);
  binHeader.writeUInt32LE(packedBin.length, 0); binHeader.writeUInt32LE(0x004e4942, 4);
  return {bytes: Buffer.concat([header, json, binHeader, packedBin]), corrected, saved_bytes: bin.length - packedBin.length};
}

for (const profile of profiles) {
  materialIds = new Map();
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath); assert.equal(hash(input), profile.sha256);
  dependencies.add(inputPath);
  const source = (await new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '')).scene;
  const car = profile.id === 'city_taxi'
    ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source, {...sedan, wheelDesignId: 'city_taxi'}))
    : createArtistVehicle(T, RoundedBoxGeometry, source, profile);
  const scene = new T.Scene(); scene.add(car.object);
  const trunk = createVehicleTrunk(T, RoundedBoxGeometry, car, {scene});
  const hood = createVehicleHood(T, RoundedBoxGeometry, car, {scene});
  const vehicleState = {x: 0, y: 0, z: 0, yaw: 0, speed: 0, steer: 0, distance: 0};
  car.update(vehicleState, false); trunk.update(0, {vehicleState}); hood.update(0, {vehicleState});
  const wrapper = new T.Group(); wrapper.name = 'VehicleVisual'; wrapper.rotation.y = Math.PI;
  wrapper.add(car.object); wrapper.updateMatrixWorld(true);
  const nodes = [], meshes = [], meshMap = new Map();
  const originalMetadata = new Map();
  wrapper.traverse(node => {
    const key = 'v' + nodes.length.toString().padStart(4, '0');
    originalMetadata.set(node, node.userData);
    node.userData = {vehicle_visual_key: key, vehicle_source_name: node.name, vehicle_source_visible: node.visible};
    node.name = key;
    nodes.push({key, source_name: node.userData.vehicle_source_name,
      parent: node.parent && node !== wrapper ? node.parent.userData.vehicle_visual_key : null,
      visible: node.visible, cast_shadow: node.castShadow, receive_shadow: node.receiveShadow,
      local_matrix: node.matrix.toArray(), world_matrix: node.matrixWorld.toArray()});
    assert(!node.isSkinnedMesh && !node.isInstancedMesh && !node.isLight, 'Explicitly unsupported animated/light type');
    if (!node.isMesh) return;
    const attributes = {};
    for (const [name, attr] of Object.entries(node.geometry.attributes)) {
      assert(!attr.isInterleavedBufferAttribute);
      attributes[name] = {item_size: attr.itemSize, normalized: attr.normalized, values: Array.from(attr.array)};
    }
    const materials = (Array.isArray(node.material) ? node.material : [node.material]).map(materialState);
    meshes.push({key, attributes, indices: node.geometry.index ? Array.from(node.geometry.index.array) : null,
      groups: node.geometry.groups, draw_range: {start: node.geometry.drawRange.start, count: Number.isFinite(node.geometry.drawRange.count) ? node.geometry.drawRange.count : null}, materials});
    meshMap.set(key, node);
  });
  const omittedMetadata = [];
  function metadataValue(value, field, ancestors = new Set()) {
    if (value == null || typeof value === 'string' || typeof value === 'boolean') return value ?? null;
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    if (value?.isObject3D && originalMetadata.has(value)) return {source_node_key: value.userData.vehicle_visual_key};
    if (value?.isVector2 || value?.isVector3 || value?.isVector4 || value?.isQuaternion || value?.isMatrix4 || value?.isColor)
      return {three_type: value.constructor.name, values: value.toArray()};
    if (ArrayBuffer.isView(value)) return {array_type: value.constructor.name, values: Array.from(value)};
    if (ancestors.has(value) || typeof value !== 'object' || !(Array.isArray(value) || Object.getPrototypeOf(value) === Object.prototype)) {
      omittedMetadata.push({field, type: typeof value === 'object' ? value?.constructor?.name ?? 'unknown' : typeof value});
      return null;
    }
    const next = new Set(ancestors).add(value);
    if (Array.isArray(value)) return value.map((item, i) => metadataValue(item, field + '[' + i + ']', next));
    return Object.fromEntries(Object.entries(value).map(([name, item]) => [name, metadataValue(item, field + '.' + name, next)]));
  }
  for (const [node, data] of originalMetadata) {
    const row = nodes.find(n => n.key === node.userData.vehicle_visual_key);
    row.source_metadata = metadataValue(data, row.key);
  }
  const keyOf = node => node?.userData.vehicle_visual_key ?? null;
  const controls = {doors: {}, wheels: {}, steering_wheel: keyOf(car.interior.steeringWheel), hood: keyOf(hood.hinge), trunk: keyOf(trunk.hinge)};
  for (const [id, node] of car.doors) controls.doors[id] = keyOf(node);
  for (const w of car.wheels) controls.wheels[w.id] = {pivot: keyOf(w.pivot), spin: keyOf(w.wheel), front: w.front,
    rest_position_m: convert(w.restPosition.toArray()), rolling_radius_m: w.rollingRadius};
  const anchors = car.seats.map(s => ({id: s.id, can_drive: s.canDrive, door_id: s.doorId,
    seat_local_m: convert([s.anchor.side, s.anchor.y, s.anchor.front]),
    approach_local_m: convert([s.side * s.doorDistance, 0, s.doorFront]),
    handle_local_m: car.getDoorHandleWorld(s.id).toArray()}));
  const exportResult = preserveNormals(await new GLTFExporter().parseAsync(wrapper, {binary: true, onlyVisible: false}), meshMap);
  const file = profile.id + '.' + hash(exportResult.bytes).slice(0, 12) + '.glb';
  fs.writeFileSync(path.join(output, file), exportResult.bytes);
  // Neutral/open/moving matrices are an independent source-controller oracle.
  const samples = [];
  for (const amount of [0, 0.5, 1]) {
    for (const id of car.doors.keys()) car.setDoorById(amount, id);
    car.update({...vehicleState, steer: amount * 0.5, distance: amount * 0.7}, false);
    wrapper.updateMatrixWorld(true);
    samples.push({door_amount: amount, steer: amount * 0.5, distance_delta_m: amount * 0.7,
      nodes: Object.fromEntries(nodes.map(row => {const n = wrapper.getObjectByName(row.key); return [row.key, n.matrixWorld.toArray()];}))});
  }
  const oracle = {schema: 'mafiozi.vehicle-visual-oracle.v1', profile_id: profile.id, nodes, meshes, samples};
  const oracleBytes = Buffer.from(JSON.stringify(oracle));
  fs.writeFileSync(path.join(output, profile.id + '.oracle.json'), oracleBytes);
  const entry = {profile_id: profile.id, source_glb_sha256: profile.sha256, file, sha256: hash(exportResult.bytes),
    bytes: exportResult.bytes.length, controls, anchors,
    nodes: nodes.map(({key, source_name, parent, visible, cast_shadow, receive_shadow, source_metadata}) => ({key, source_name, parent, visible, cast_shadow, receive_shadow, source_metadata})),
    omitted_metadata: omittedMetadata,
    mesh_materials: Object.fromEntries(meshes.map(row => [row.key, row.materials])),
    runtime_profile: {half_width_m: car.profile.halfWidth, half_length_m: car.profile.halfLength, height_m: car.profile.height,
      bounds_source_m: car.profile.bounds, wheel_positions_source_m: car.profile.wheelPositions},
    oracle_sha256: hash(oracleBytes), mesh_count: meshes.length,
    triangle_count: meshes.reduce((n, m) => n + (m.indices?.length ?? m.attributes.position.values.length / 3) / 3, 0),
    corrected_normal_components: exportResult.corrected,
    exact_buffer_sharing_saved_bytes: exportResult.saved_bytes,
    status: 'NATIVE_REVIEW_REQUIRED', limits: ['No gameplay/session/authority changes', 'KHR material extensions, glass depth and emission require native render verification', 'Hood/trunk geometry retained; their dynamic motion/debris not ported by this exporter', 'Source red_demo Kingswell is a separate factory pending export']};
  entries.push(entry);
  console.log(JSON.stringify({profile: profile.id, meshes: meshes.length, bytes: entry.bytes, triangles: entry.triangle_count, half_width: entry.runtime_profile.half_width_m}));
}
const manifest = {schema: 'mafiozi.vehicle-visual.v1', three_revision: T.REVISION, godot_forward: '-Z', source_forward: '+Z', entries,
  dependencies: [...dependencies].sort().map(file => ({path: path.relative(repo, file).replaceAll('\\', '/'), sha256: hash(fs.readFileSync(file))}))};
fs.writeFileSync(path.join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
