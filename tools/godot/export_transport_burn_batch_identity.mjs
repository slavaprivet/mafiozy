#!/usr/bin/env node
// Executed-source proof for source-mesh -> hidden/canonical body-batch identity.
// Production modules are SHA/sentinel pinned and instrumented only in memory.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const target = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_batch_identities.json');
const step1Path = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_identities.json');
const rawVisualManifestPath = path.join(repo, 'outputs/coordinator21_vehicle_visual/manifest.json');
const nativeVisualManifestPath = path.join(repo, 'godot/mafiozi_walk/assets/vehicle_visual/manifest.json');
const batchesPath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_render_batches.mjs');
const batchesUrl = pathToFileURL(batchesPath).href;
const expectedBatchesSha = 'a9b4c0c93652b52e29a2c29fe65748bdf451122594583d3bd455238f766df648';
const expectedStep1Sha = '38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38';
const additionalSourcePins = new Map([
  ['assets/maps/city_rebuild_v1/vehicle_rollover.mjs', '21650742ccef39b229917e92986f0a57e91e2b4d77a9ad586839ffb5c50f76d8'],
  ['assets/maps/city_rebuild_v1/tyre_damage.mjs', '5fb71f8ad6efd84f4a9e998c93a3a112e7874fd4a18448370378c0acd78762af'],
]);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const relative = value => path.relative(repo, value).replaceAll('\\', '/');
const dependencies = new Set([fileURLToPath(import.meta.url)]);

const batchesBytes = fs.readFileSync(batchesPath);
assert.equal(hash(batchesBytes), expectedBatchesSha, 'Pinned vehicle_render_batches.mjs changed');
const batchesSource = batchesBytes.toString('utf8');
const batchesSentinel = 'export function getVehicleRenderSourceMaterial(mesh){const saved=sourceMaterials.get(mesh);return saved&&mesh.material===saved.hidden?saved.material:mesh.material;}';
assert.equal(batchesSource.split(batchesSentinel).length, 2, 'Exact canonical getter sentinel must occur once');
const instrumentedBatchesSource = batchesSource.replace(batchesSentinel, batchesSentinel +
  "export function __transportBurnBatchProofRegistration(mesh){const saved=sourceMaterials.get(mesh);return saved?Object.freeze({hidden:saved.hidden,material:saved.material}):null;}");

registerHooks({
  resolve(specifier, context, next) {
    return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
  },
  load(url, context, next) {
    if (url.startsWith('file:')) dependencies.add(fileURLToPath(url));
    if (url === batchesUrl) return {format: 'module', source: instrumentedBatchesSource, shortCircuit: true};
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
const {createVehicleDamage} = await import('../../assets/maps/city_rebuild_v1/vehicle_damage.mjs');
const {createVehicleRollover} = await import('../../assets/maps/city_rebuild_v1/vehicle_rollover.mjs');
const {createTyreDamage} = await import('../../assets/maps/city_rebuild_v1/tyre_damage.mjs');
const {createVehicleRenderBatches, getVehicleRenderSourceMaterial, __transportBurnBatchProofRegistration} =
  await import('../../assets/maps/city_rebuild_v1/vehicle_render_batches.mjs');

const step1Bytes = fs.readFileSync(step1Path);
assert.equal(hash(step1Bytes), expectedStep1Sha, 'Frozen source burn identity receipt changed');
const step1 = JSON.parse(step1Bytes);
assert.equal(step1.schema, 'mafiozi.transport-burn-source-identities.v1');
const step1ById = new Map(step1.profiles.map(row => [row.profile_id, row]));
const step1SourcePins = new Map(step1.source_files.map(row => [row.path, row.sha256]));
for (const [sourcePath, sha256] of step1SourcePins) {
  const absolute = path.join(repo, sourcePath); assert(fs.existsSync(absolute), 'Frozen step-1 dependency missing: ' + sourcePath);
  assert.equal(hash(fs.readFileSync(absolute)), sha256, 'Frozen step-1 dependency changed: ' + sourcePath);
}
for (const [sourcePath, sha256] of additionalSourcePins)
  assert.equal(hash(fs.readFileSync(path.join(repo, sourcePath))), sha256, 'Additional fleet-order dependency changed: ' + sourcePath);
const rawVisualManifestBytes = fs.readFileSync(rawVisualManifestPath);
const rawVisualManifest = JSON.parse(rawVisualManifestBytes);
const nativeVisualManifestBytes = fs.readFileSync(nativeVisualManifestPath);
const nativeVisualManifest = JSON.parse(nativeVisualManifestBytes);
assert.equal(step1.visual_manifest.sha256, hash(rawVisualManifestBytes));
assert.equal(step1.native_visual_manifest.sha256, hash(nativeVisualManifestBytes));
assert.equal(rawVisualManifest.schema, 'mafiozi.vehicle-visual.v1');
assert.equal(nativeVisualManifest.schema, rawVisualManifest.schema);
const rawEntryById = new Map(rawVisualManifest.entries.map(row => [row.profile_id, row]));
const nativeEntryById = new Map(nativeVisualManifest.entries.map(row => [row.profile_id, row]));

const sedan = ARTIST_VEHICLE_PROFILES.find(profile => profile.id === 'compact_sedan');
assert(sedan);
const profiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
function canonicalSourceMetadata(material, paletteSources) {
  const metadata = structuredClone(material.userData ?? {});
  const source = metadata.interiorPaletteSource;
  if (source != null) {
    assert.equal(typeof source, 'string'); assert(uuidPattern.test(source), 'Unexpected interiorPaletteSource representation');
    if (!paletteSources.has(source)) paletteSources.set(source, 'palette_source_' + paletteSources.size.toString().padStart(4, '0'));
    metadata.interiorPaletteSource = {nondeterministic_three_uuid_ref: paletteSources.get(source)};
  }
  return metadata;
}
function visualMaterialDescriptor(material, sourceMaterialId, paletteSources) {
  assert(material?.isMaterial, 'Material identity expected');
  return JSON.parse(JSON.stringify({source_material_id: sourceMaterialId,
    source_metadata: canonicalSourceMetadata(material, paletteSources), name: material.name, type: material.type,
    color_linear: material.color?.toArray() ?? null, roughness: material.roughness ?? null,
    metallic: material.metalness ?? null, emissive_linear: material.emissive?.toArray() ?? [0, 0, 0],
    emissive_intensity: material.emissiveIntensity ?? 0, opacity: material.opacity,
    transparent: material.transparent, depth_write: material.depthWrite,
    depth_test: material.depthTest, side: material.side, vertex_colors: material.vertexColors,
    flat_shading: material.flatShading, ior: material.ior ?? null, specular_intensity: material.specularIntensity ?? null}));
}
function runtimeMaterialDescriptor(material, paletteSources) {
  const descriptor = visualMaterialDescriptor(material, null, paletteSources); delete descriptor.source_material_id;
  descriptor.visible = material.visible; return descriptor;
}

function orderedMaterialObjects(value) { return Array.isArray(value) ? value : [value]; }
function containerKind(value) { return Array.isArray(value) ? 'array' : 'scalar'; }
const jsonMatrix = matrix => matrix.toArray().map(value => Object.is(value, -0) ? 0 : value);
function jsonDifferences(actual, expected, at = '$') {
  if (Object.is(actual, expected)) return [];
  if (Array.isArray(actual) || Array.isArray(expected)) {
    if (!Array.isArray(actual) || !Array.isArray(expected)) return [{path: at, actual, expected}];
    const rows = []; if (actual.length !== expected.length) rows.push({path: at + '.length', actual: actual.length, expected: expected.length});
    for (let i = 0; i < Math.max(actual.length, expected.length); i++) rows.push(...jsonDifferences(actual[i], expected[i], at + '[' + i + ']'));
    return rows;
  }
  if (actual && expected && typeof actual === 'object' && typeof expected === 'object') {
    const rows = []; const keys = [...new Set([...Object.keys(actual), ...Object.keys(expected)])].sort();
    for (const key of keys) rows.push(...jsonDifferences(actual[key], expected[key], at + '.' + key));
    return rows;
  }
  return [{path: at, actual: actual ?? null, expected: expected ?? null}];
}

const rows = [];
for (const profile of profiles) {
  const step = step1ById.get(profile.id);
  assert(step, 'Step-1 profile missing: ' + profile.id);
  const rawEntry = rawEntryById.get(profile.id), nativeEntry = nativeEntryById.get(profile.id);
  assert(rawEntry && nativeEntry, 'Visual manifest profile missing: ' + profile.id);
  assert.deepEqual(nativeEntry.nodes, rawEntry.nodes, 'Raw/native visual node receipt mismatch: ' + profile.id);
  assert.deepEqual(nativeEntry.mesh_materials, rawEntry.mesh_materials, 'Raw/native visual material receipt mismatch: ' + profile.id);
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath);
  assert.equal(hash(input), profile.sha256, 'Pinned source GLB changed: ' + profile.id);
  dependencies.add(inputPath);
  const source = (await new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '')).scene;
  const car = profile.id === 'city_taxi'
    ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source, {...sedan, wheelDesignId: 'city_taxi'}))
    : createArtistVehicle(T, RoundedBoxGeometry, source, profile);
  const scene = new T.Scene(); scene.add(car.object);
  const trunk = createVehicleTrunk(T, RoundedBoxGeometry, car, {scene}); car.trunk = trunk;
  const hood = createVehicleHood(T, RoundedBoxGeometry, car, {scene}); car.hood = hood;
  const vehicleState = {x: 0, y: 0, z: 0, yaw: 0, speed: 0, steer: 0, distance: 0};

  // Freeze the source identity/key space before damage adds effects and batching
  // adds proxies. This must reproduce the already frozen step-1 receipt exactly.
  const wrapper = new T.Group(); wrapper.name = 'VehicleVisual'; wrapper.rotation.y = Math.PI; wrapper.add(car.object); wrapper.updateMatrixWorld(true);
  const keyOf = new Map(); const nodeOf = new Map(); const actualNodes = []; let nodeIndex = 0;
  wrapper.traverse(node => {const key = 'v' + (nodeIndex++).toString().padStart(4, '0'); keyOf.set(node, key); nodeOf.set(key, node);
    actualNodes.push({key, source_name: node.name, parent: node.parent && node !== wrapper ? keyOf.get(node.parent) : null,
      visible: node.visible, cast_shadow: node.castShadow, receive_shadow: node.receiveShadow,
      // JSON, including the frozen visual oracle, canonicalizes IEEE -0 to 0.
      // Apply only that exact serialization rule; no epsilon/tolerance is used.
      local_matrix: jsonMatrix(node.matrix), world_matrix: jsonMatrix(node.matrixWorld)});});
  assert.equal(nodeIndex, step.factory_receipt.node_count, 'Step-1 node count mismatch: ' + profile.id);
  assert.deepEqual(actualNodes.map(({key, source_name, parent, visible, cast_shadow, receive_shadow}) =>
    ({key, source_name, parent, visible, cast_shadow, receive_shadow})),
  rawEntry.nodes.map(({key, source_name, parent, visible, cast_shadow, receive_shadow}) =>
    ({key, source_name, parent, visible, cast_shadow, receive_shadow})), 'Raw visual node/ancestry receipt mismatch: ' + profile.id);
  const visualOraclePath = path.join(path.dirname(rawVisualManifestPath), profile.id + '.oracle.json');
  const visualOracleBytes = fs.readFileSync(visualOraclePath);
  assert.equal(hash(visualOracleBytes), rawEntry.oracle_sha256, 'Visual oracle changed: ' + profile.id);
  const visualGlbPath = path.join(path.dirname(rawVisualManifestPath), rawEntry.file);
  const visualGlbBytes = fs.readFileSync(visualGlbPath);
  assert.equal(visualGlbBytes.length, rawEntry.bytes, 'Raw visual GLB byte count changed: ' + profile.id);
  assert.equal(hash(visualGlbBytes), rawEntry.sha256, 'Raw visual GLB changed: ' + profile.id);
  const visualOracle = JSON.parse(visualOracleBytes);
  assert.deepEqual(actualNodes, visualOracle.nodes.map(({key, source_name, parent, visible, cast_shadow, receive_shadow, local_matrix, world_matrix}) =>
    ({key, source_name, parent, visible, cast_shadow, receive_shadow, local_matrix, world_matrix})),
  'Visual node transform receipt mismatch: ' + profile.id);
  const materialIds = new Map(); const materialById = new Map();
  for (const [node] of keyOf) if (node.isMesh) for (const material of orderedMaterialObjects(node.material)) {
    if (!materialIds.has(material)) {
      const id = 'm' + materialIds.size.toString().padStart(4, '0'); materialIds.set(material, id); materialById.set(id, material);
    }
  }
  assert.equal(materialIds.size, step.materials.length, 'Step-1 material count mismatch: ' + profile.id);
  const paletteSources = new Map();
  const productionMaterialReceipts = [];
  for (const receipt of step.materials) {
    const material = materialById.get(receipt.identity_id); assert(material, 'Step-1 material identity missing: ' + receipt.identity_id);
    const productionDescriptor = visualMaterialDescriptor(material, receipt.identity_id, paletteSources);
    const differences = jsonDifferences(productionDescriptor, receipt.descriptor);
    const sourceNodeKeys = [];
    for (const [node, key] of keyOf) if (node.isMesh && orderedMaterialObjects(node.material).includes(material)) sourceNodeKeys.push(key);
    assert.deepEqual(sourceNodeKeys, receipt.source_node_keys, 'Step-1 material source-node alias mismatch: ' + profile.id + '/' + receipt.identity_id);
    productionMaterialReceipts.push({identity_id: receipt.identity_id, source_node_keys: sourceNodeKeys,
      production_prebatch_descriptor: productionDescriptor, visual_step1_descriptor: receipt.descriptor,
      descriptor_exact_equal: differences.length === 0, descriptor_differences: differences});
  }
  for (const receipt of step.meshes) {
    const node = nodeOf.get(receipt.key); assert(node?.isMesh, 'Step-1 mesh key missing: ' + profile.id + '/' + receipt.key);
    assert.equal(containerKind(node.material), receipt.material_container_kind, 'Step-1 material container mismatch');
    assert.deepEqual(orderedMaterialObjects(node.material).map(material => materialIds.get(material)), receipt.ordered_material_identity_ids,
      'Step-1 material identity order mismatch: ' + profile.id + '/' + receipt.key);
  }

  // The visual wrapper exists only to reproduce frozen v/m keys. Production
  // fleet ownership has the car directly under scene before damage/roll/tyres.
  wrapper.remove(car.object); scene.add(car.object); car.object.updateMatrixWorld(true);
  const meshNodes = [...keyOf].filter(([node]) => node.isMesh).map(([node, key]) => ({node, key}));
  const idForPreMaterial = material => {const id = materialIds.get(material); assert(id, 'Current material absent from step-1 m namespace'); return id;};
  // Exact fleet constructor order before body batching. Rollover is state-only at
  // construction; tyre damage creates a scene-owned auxiliary effect subtree.
  const massKg = Math.max(400, Math.min(40000, Number.isFinite(car.profile?.massKg) ? car.profile.massKg :
    Number.isFinite(car.object.userData.massKg) ? car.object.userData.massKg : 1500));
  const damageMaxHp = Math.max(240, Math.min(1200, Math.round(massKg * .16)));
  const damage = createVehicleDamage(T, car, {scene, trunk, allowed: () => true, getState: () => vehicleState,
    profile: {maxHp: damageMaxHp}});
  const rollover = createVehicleRollover(T, car);
  const tyres = createTyreDamage(T, car);
  assert.equal(tyres.object.parent, scene, 'Tyre auxiliary root must use production scene parent');
  for (let node = tyres.object; node; node = node.parent) assert.notEqual(node, car.object, 'Tyre auxiliary subtree entered source car hierarchy');
  const auxiliaryNodeIds = new Map(); const auxiliaryMaterialIds = new Map(); const tyreAuxiliaryNodes = []; let auxiliaryNodeIndex = 0;
  tyres.object.traverse(node => {
    const id = 'a' + (auxiliaryNodeIndex++).toString().padStart(4, '0'); auxiliaryNodeIds.set(node, id);
    const materials = node.isMesh ? orderedMaterialObjects(node.material) : [];
    const materialIdentityIds = materials.map(material => {
      if (!auxiliaryMaterialIds.has(material)) auxiliaryMaterialIds.set(material, 'am' + auxiliaryMaterialIds.size.toString().padStart(4, '0'));
      return auxiliaryMaterialIds.get(material);
    });
    tyreAuxiliaryNodes.push({auxiliary_node_id: id, parent_auxiliary_node_id: auxiliaryNodeIds.get(node.parent) ?? null,
      parent_scope: node === tyres.object ? 'scene' : 'tyre_auxiliary', name: node.name, type: node.type, visible: node.visible,
      material_container_kind: node.isMesh ? containerKind(node.material) : null,
      auxiliary_material_identity_ids: materialIdentityIds, source_copy_scope: false});
  });
  const tyreAuxiliaryMaterials = [...auxiliaryMaterialIds].sort((a, b) => a[1].localeCompare(b[1], 'en')).map(([material, id]) => ({
    auxiliary_material_identity_id: id, descriptor: runtimeMaterialDescriptor(material, paletteSources)}));
  const initialMeshes = meshNodes.map(({node, key}, observationIndex) => {
    assert.equal(__transportBurnBatchProofRegistration(node), null, 'Registration exists before batching: ' + profile.id + '/' + key);
    const current = orderedMaterialObjects(node.material); const canonical = orderedMaterialObjects(getVehicleRenderSourceMaterial(node));
    return {source_node_key: key, observation_index: observationIndex, source_visible: node.visible,
      current_container_kind: containerKind(node.material), current_identity_ids: current.map(idForPreMaterial),
      getter_container_kind: containerKind(getVehicleRenderSourceMaterial(node)), getter_identity_ids: canonical.map(idForPreMaterial),
      registration: null};
  });

  // Exact production order: body/interior/door presentation batching follows
  // damage, rollover, and tyre controller construction.
  const body = createVehicleRenderBatches({THREE: T, root: car.object, includeDoors: true, includeBody: true, detailOptimization: true});
  const hiddenIds = new Map(); const hiddenCanonical = new Map();
  const hiddenId = (hidden, canonical) => {
    if (!hiddenIds.has(hidden)) hiddenIds.set(hidden, 'h' + hiddenIds.size.toString().padStart(4, '0'));
    const id = hiddenIds.get(hidden), canonicalId = idForPreMaterial(canonical);
    if (hiddenCanonical.has(hidden)) assert.equal(hiddenCanonical.get(hidden), canonicalId, 'Hidden identity aliases multiple canonicals');
    else hiddenCanonical.set(hidden, canonicalId);
    return id;
  };
  const classifyCurrent = value => orderedMaterialObjects(value).map(material => {
    if (materialIds.has(material)) return materialIds.get(material);
    if (hiddenIds.has(material)) return hiddenIds.get(material);
    throw Error('Body phase material has no exact m/h identity: ' + profile.id);
  });
  const bodyMeshes = meshNodes.map(({node, key}, observationIndex) => {
    const registration = __transportBurnBatchProofRegistration(node);
    if (registration) {
      assert(!Array.isArray(registration.hidden) && !Array.isArray(registration.material), 'Batch registration must be scalar');
      assert.notEqual(registration.hidden, registration.material);
      assert.equal(registration.hidden.visible, false);
      hiddenId(registration.hidden, registration.material);
    }
    const current = node.material;
    const getter = getVehicleRenderSourceMaterial(node);
    if (registration && current === registration.hidden) assert.equal(getter, registration.material, 'Canonical getter mismatch');
    return {source_node_key: key, observation_index: observationIndex, source_visible: node.visible,
      current_container_kind: containerKind(current), current_identity_ids: classifyCurrent(current),
      getter_container_kind: containerKind(getter), getter_identity_ids: classifyCurrent(getter),
      registration: registration ? {owner: 'body', hidden_identity_id: hiddenIds.get(registration.hidden),
        canonical_container_kind: containerKind(registration.material), canonical_identity_ids: [idForPreMaterial(registration.material)]} : null};
  });
  car.object.traverse(node => {if (__transportBurnBatchProofRegistration(node)) assert(keyOf.has(node), 'Batch registered a post-step1 source node');});
  const proxies = []; let proxyIndex = 0;
  car.object.traverse(node => {
    if (!node.userData?.vehicleRenderBatch) return;
    assert(node.isBatchedMesh, 'Render proxy metadata on non-BatchedMesh');
    const materials = orderedMaterialObjects(node.material);
    proxies.push({proxy_identity_id: 'b' + (proxyIndex++).toString().padStart(4, '0'), name: node.name,
      parent_source_node_key: keyOf.get(node.parent) ?? null,
      material_container_kind: containerKind(node.material), canonical_material_identity_ids: materials.map(idForPreMaterial),
      flags: {vehicle_render_batch: node.userData.vehicleRenderBatch === true,
        vehicle_door_render_batch: node.userData.vehicleDoorRenderBatch === true,
        vehicle_root_door_render_batch: node.userData.vehicleRootDoorRenderBatch === true,
        vehicle_body_render_batch: node.userData.vehicleBodyRenderBatch === true,
        vehicle_detail_render_batch: node.userData.vehicleDetailRenderBatch === true,
        vehicle_fixture_render_batch: node.userData.vehicleFixtureRenderBatch === true},
      member_source_keys: null, member_binding_status: 'PENDING_PRIVATE_BATCH_ENTRY_RECEIPT',
      geometry_layout_receipt: null, geometry_layout_status: 'PENDING_PROXY_GEOMETRY_AND_PRIVATE_BATCH_ENTRY_RECEIPT'});
  });
  const hiddenMaterials = [...hiddenIds].sort((a, b) => a[1].localeCompare(b[1], 'en')).map(([material, id]) => ({
    hidden_identity_id: id, canonical_material_identity_id: hiddenCanonical.get(material), descriptor: runtimeMaterialDescriptor(material, paletteSources),
    member_source_keys: bodyMeshes.filter(row => row.registration?.hidden_identity_id === id).map(row => row.source_node_key)}));
  assert.equal(bodyMeshes.filter(row => row.registration).length, body.stats.members);
  assert.equal(proxies.length, body.stats.batches);

  rows.push({profile_id: profile.id, source_profile_id: profile.source_profile_id ?? profile.id,
    scope: {proof_generation: 1, runtime_vehicle_generation: null, step1_receipt_sha256: expectedStep1Sha,
      raw_visual_manifest_sha256: hash(rawVisualManifestBytes), source_glb_sha256: profile.sha256},
    options: {include_doors: true, include_body: true, detail_optimization_requested: true,
      detail_optimization_enabled: body.stats.detailOptimizationEnabled, root_door_batches: false,
      wheel_render_optimization_requested: false, wheel_phase_executed: false,
      wheel_phase_status: 'PENDING_OPTIONAL_EXPLICIT_SOURCE_PROOF'},
    constructor_order: ['damage', 'rollover', 'tyres', 'body_render_batches'],
    constructor_options: {damage_max_hp: damageMaxHp, ground_height: 'constant_zero', allowed: 'constant_true',
      pre_batch_car_update_called: false, pre_batch_trunk_update_called: false, pre_batch_hood_update_called: false},
    production_prebatch_materials: productionMaterialReceipts,
    pre_body_controllers: {rollover_initial_stats: structuredClone(rollover.stats()), tyre_initial_stats: structuredClone(tyres.stats()),
      tyre_auxiliary: {namespace: 'a#### nodes / am#### materials', source_copy_scope: false,
        root_parent_scope: 'scene', nodes: tyreAuxiliaryNodes, materials: tyreAuxiliaryMaterials}},
    initial_phase: {phase: 'after_damage_rollover_tyres_before_body_batches', meshes: initialMeshes},
    body_phase: {phase: 'after_body_constructor_initial_update', stats: structuredClone(body.stats),
      meshes: bodyMeshes, hidden_materials: hiddenMaterials, proxies},
    pending_phases: ['wheel_optional', 'detail_toggle', 'fallback', 'dispose', 'explosion_callback_and_copy']});

  body.dispose(); tyres.dispose(); rollover.reset(); damage.dispose(); trunk.dispose(); hood.dispose(); car.object.removeFromParent();
}

const sourceFiles = [...dependencies]
  .filter(value => value === repo || value.startsWith(repo + path.sep))
  .filter(value => fs.existsSync(value) && fs.statSync(value).isFile())
  .map(value => ({path: relative(value), sha256: hash(fs.readFileSync(value))}))
  .sort((a, b) => a.path.localeCompare(b.path, 'en'));
const ownToolPath = relative(fileURLToPath(import.meta.url));
for (const row of sourceFiles) {
  if (row.path === ownToolPath) continue;
  const expected = step1SourcePins.get(row.path) ?? additionalSourcePins.get(row.path);
  assert(expected, 'Loaded repo dependency is absent from frozen/additional allowlist: ' + row.path);
  assert.equal(row.sha256, expected, 'Loaded repo dependency SHA mismatch: ' + row.path);
}
const result = {schema: 'mafiozi.transport-burn-batch-identities.v1', three_revision: T.REVISION,
  status: 'INITIAL_AND_BODY_SOURCE_PROOF_WHEEL_TOGGLE_FALLBACK_CALLBACK_PENDING',
  proof_method: {kind: 'sha_and_sentinel_pinned_in_memory_private_weakmap_query', production_source_modified: false,
    vehicle_render_batches_sha256: expectedBatchesSha},
  identity_scope: {canonical: 'm#### profile-local from frozen step-1 receipt', hidden: 'h#### profile/body-phase-local first keyed observation',
    proxy: 'b#### profile/body-phase-local source traversal', global_ids: false,
    required_runtime_scope: ['profile_id', 'source pins', 'step1 receipt SHA', 'visual manifest SHA', 'vehicle lifecycle generation', 'material revision']},
  inputs: {step1_receipt: {path: relative(step1Path), sha256: hash(step1Bytes)},
    raw_visual_manifest: {path: relative(rawVisualManifestPath), sha256: hash(rawVisualManifestBytes)},
    native_visual_manifest: {path: relative(nativeVisualManifestPath), sha256: hash(nativeVisualManifestBytes)}},
  source_files: sourceFiles, profiles: rows,
  native_binding_dependency: {status: 'UNRESOLVED_PRODUCTION_PREBATCH_VS_VISUAL_BASELINE',
    exact_difference: 'One taillamp emissive_intensity per profile: production prebatch 1.6199999141693127, frozen visual/native baseline 0.5.',
    requirement: 'Host must bind an exact current source-state writer/material revision; shared m identity does not waive the property mismatch.'},
  limits: ['Body/interior/door initial registration only', 'Wheel optional phase pending and never inferred',
    'Proxy member-to-batch relation and proxy geometry/layout receipt pending private batch-entry proof',
    'Toggle, fallback, dispose, callback, and debris-copy phases pending',
    'No native binder, authority, HP, physics, rendering, GPU, LIVE, or Git integration']};
assert.equal(rows.length, 13);
fs.mkdirSync(path.dirname(target), {recursive: true});
fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({output: relative(target), sha256: hash(fs.readFileSync(target)), profiles: rows.length,
  registered_source_meshes: rows.reduce((sum, row) => sum + row.body_phase.meshes.filter(mesh => mesh.registration).length, 0),
  hidden_materials: rows.reduce((sum, row) => sum + row.body_phase.hidden_materials.length, 0),
  proxies: rows.reduce((sum, row) => sum + row.body_phase.proxies.length, 0), status: result.status}));
