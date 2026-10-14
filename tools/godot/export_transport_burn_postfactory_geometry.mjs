#!/usr/bin/env node
// Executed-source correction for seven visual slots whose original input GLB
// geometry is nonempty but whose actual post-factory geometry is empty.
// Production modules and frozen receipts are read-only and SHA pinned.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const target = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_postfactory_geometry.json');
const step1Path = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_identities.json');
const visualManifestPath = path.join(repo, 'outputs/coordinator21_vehicle_visual/manifest.json');
const nativeVisualManifestPath = path.join(repo, 'godot/mafiozi_walk/assets/vehicle_visual/manifest.json');
const legacyCensusPath = path.join(repo, 'docs/godot/TRANSPORT_BURN_MATERIAL_ALIAS_CENSUS.json');
const damagePath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_damage.mjs');
const damageUrl = pathToFileURL(damagePath).href;
const expectedStep1Sha = '38d370792b7e97445b56efb35b4360121157a659905216db79221f78f22c2d38';
const expectedVisualManifestSha = '10133bb94515eb41078b5b801a647fedad21b1eab4199a430b112359928fc0db';
const expectedNativeVisualManifestSha = '38598f43beb77c095879206ea5820c7fe922b227a64f77f793353f89321fee03';
const expectedLegacyCensusSha = 'ff32550ae7d681dab2ec908088368aed419b09fb0f61fdf84599bfddcd040e54';
const expectedDamageSha = 'e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const relative = value => path.relative(repo, value).replaceAll('\\', '/');
const dependencies = new Set([fileURLToPath(import.meta.url)]);
const readPinned = (file, sha, label) => {const bytes = fs.readFileSync(file); assert.equal(hash(bytes), sha, label + ' changed'); return bytes;};

const step1Bytes = readPinned(step1Path, expectedStep1Sha, 'Frozen source burn identity receipt');
const visualManifestBytes = readPinned(visualManifestPath, expectedVisualManifestSha, 'Raw visual manifest');
const nativeVisualManifestBytes = readPinned(nativeVisualManifestPath, expectedNativeVisualManifestSha, 'Native visual manifest');
const legacyCensusBytes = readPinned(legacyCensusPath, expectedLegacyCensusSha, 'Legacy alias census evidence');
const damageBytes = readPinned(damagePath, expectedDamageSha, 'vehicle_damage.mjs');
const damageSource = damageBytes.toString('utf8');
const damageSentinel = "car.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.material?.transparent)glass.push(mesh);if(mesh.material?.color&&!materialRest.has(mesh.material))materialRest.set(mesh.material,{color:mesh.material.color.clone(),roughness:mesh.material.roughness});});";
assert.equal(damageSource.split(damageSentinel).length, 2, 'Exact damage capture sentinel must occur once');
const instrumentedDamageSource = damageSource.replace(damageSentinel,
  damageSentinel + "globalThis[Symbol.for('mafiozi.transport-postfactory-geometry/v1')]?.({car,materialRest});");

registerHooks({
  resolve(specifier, context, next) {
    return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
  },
  load(url, context, next) {
    if (url.startsWith('file:')) dependencies.add(fileURLToPath(url));
    if (url === damageUrl) return {format: 'module', source: instrumentedDamageSource, shortCircuit: true};
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

const step1 = JSON.parse(step1Bytes); assert.equal(step1.schema, 'mafiozi.transport-burn-source-identities.v1');
const step1ById = new Map(step1.profiles.map(row => [row.profile_id, row]));
const step1SourcePins = new Map(step1.source_files.map(row => [row.path, row.sha256]));
const visualManifest = JSON.parse(visualManifestBytes); assert.equal(visualManifest.schema, 'mafiozi.vehicle-visual.v1');
const visualById = new Map(visualManifest.entries.map(row => [row.profile_id, row]));
const nativeVisualManifest = JSON.parse(nativeVisualManifestBytes); assert.equal(nativeVisualManifest.schema, visualManifest.schema);
const nativeById = new Map(nativeVisualManifest.entries.map(row => [row.profile_id, row]));
const legacyCensus = JSON.parse(legacyCensusBytes);
const legacyProfileById = new Map(legacyCensus.profiles.map(row => [row.profile_id, row]));
const legacyRows = legacyCensus.missing_source_geometry_receipt.rows.map(row => {
  const slot = legacyProfileById.get(row.profile_id)?.missing_native_slots.find(value => value.node_key === row.node_key);
  assert(slot, 'Legacy missing-slot identity row absent: ' + row.profile_id + '/' + row.node_key);
  assert.equal(slot.source_name, row.source_name);
  return {...row, source_material_id: slot.source_material_id};
});
assert.equal(legacyRows.length, 7);
const legacyByProfile = new Map();
for (const row of legacyRows) {
  if (!legacyByProfile.has(row.profile_id)) legacyByProfile.set(row.profile_id, []);
  legacyByProfile.get(row.profile_id).push(row);
}
const sedan = ARTIST_VEHICLE_PROFILES.find(profile => profile.id === 'compact_sedan'); assert(sedan);
const profiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];
const probeSymbol = Symbol.for('mafiozi.transport-postfactory-geometry/v1');

function typedBytes(array) {return Buffer.from(array.buffer, array.byteOffset, array.byteLength);}
function geometryReceipt(geometry) {
  assert(geometry?.isBufferGeometry, 'BufferGeometry required');
  const position = geometry.attributes.position;
  assert(position && !position.isInterleavedBufferAttribute, 'Plain position attribute required');
  const index = geometry.index;
  const attributes = {};
  for (const [name, attribute] of Object.entries(geometry.attributes)) {
    assert(!attribute.isInterleavedBufferAttribute, 'Interleaved attribute requires an explicit receipt');
    attributes[name] = {count: attribute.count, item_size: attribute.itemSize, normalized: attribute.normalized,
      array_type: attribute.array.constructor.name, values_length: attribute.array.length,
      byte_length: attribute.array.byteLength, bytes_sha256: hash(typedBytes(attribute.array))};
  }
  return {empty_position_geometry: position.count === 0,
    position: {count: position.count, item_size: position.itemSize, normalized: position.normalized,
      array_type: position.array.constructor.name, values_length: position.array.length,
      byte_length: position.array.byteLength, bytes_sha256: hash(typedBytes(position.array))},
    index: index ? {count: index.count, item_size: index.itemSize, normalized: index.normalized,
      array_type: index.array.constructor.name, values_length: index.array.length,
      byte_length: index.array.byteLength, bytes_sha256: hash(typedBytes(index.array)),
      min: index.array.length ? Math.min(...index.array) : null, max: index.array.length ? Math.max(...index.array) : null} : null,
    attributes,
    groups: geometry.groups.map(group => ({start: group.start, count: group.count, material_index: group.materialIndex})),
    draw_range: {start: geometry.drawRange.start,
      count_type: Number.isFinite(geometry.drawRange.count) ? 'finite' : 'positive_infinity',
      count: Number.isFinite(geometry.drawRange.count) ? geometry.drawRange.count : null}};
}
function canonicalMaterialGraph(meshMaterials) {
  const palette = new Map();
  const result = structuredClone(meshMaterials);
  for (const materials of Object.values(result)) for (const material of materials) {
    const source = material.source_metadata?.interiorPaletteSource;
    if (source == null) continue;
    if (!palette.has(source)) palette.set(source, 'palette_source_' + palette.size.toString().padStart(4, '0'));
    material.source_metadata.interiorPaletteSource = {nondeterministic_three_uuid_ref: palette.get(source)};
  }
  return result;
}
function materialDescriptor(material, id) {
  return JSON.parse(JSON.stringify({source_material_id: id, source_metadata: structuredClone(material.userData ?? {}),
    name: material.name, type: material.type, color_linear: material.color?.toArray() ?? null,
    roughness: material.roughness ?? null, metallic: material.metalness ?? null,
    emissive_linear: material.emissive?.toArray() ?? [0, 0, 0], emissive_intensity: material.emissiveIntensity ?? 0,
    opacity: material.opacity, transparent: material.transparent, depth_write: material.depthWrite, depth_test: material.depthTest,
    side: material.side, vertex_colors: material.vertexColors, flat_shading: material.flatShading,
    ior: material.ior ?? null, specular_intensity: material.specularIntensity ?? null}));
}
const orderedMaterials = value => Array.isArray(value) ? value : [value];

const profileReceipts = [];
const targetReceipts = [];
for (const profile of profiles) {
  const step = step1ById.get(profile.id); assert(step, 'Frozen step-1 profile missing: ' + profile.id);
  const visualEntry = visualById.get(profile.id), nativeEntry = nativeById.get(profile.id);
  assert(visualEntry && nativeEntry); assert.deepEqual(nativeEntry.nodes, visualEntry.nodes); assert.deepEqual(nativeEntry.mesh_materials, visualEntry.mesh_materials);
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath); assert.equal(hash(input), profile.sha256); dependencies.add(inputPath);
  const source = (await new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '')).scene;
  const expectedTargets = legacyByProfile.get(profile.id) ?? [];
  const originalMeshes = []; source.traverse(node => {if (node.isMesh) originalMeshes.push(node);});
  const originalReceipts = new Map(expectedTargets.map(targetRow => {
    const matches = originalMeshes.filter(node => node.name === targetRow.source_name); assert.equal(matches.length, 1, 'Original target mesh name is not unique: ' + targetRow.source_name);
    const node = matches[0];
    return [targetRow.source_name, geometryReceipt(node.geometry)];
  }));

  const car = profile.id === 'city_taxi'
    ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source, {...sedan, wheelDesignId: 'city_taxi'}))
    : createArtistVehicle(T, RoundedBoxGeometry, source, profile);
  const scene = new T.Scene(); scene.add(car.object);
  const trunk = createVehicleTrunk(T, RoundedBoxGeometry, car, {scene}); car.trunk = trunk;
  const hood = createVehicleHood(T, RoundedBoxGeometry, car, {scene}); car.hood = hood;
  const state = {x: 0, y: 0, z: 0, yaw: 0, speed: 0, steer: 0, distance: 0};
  car.update(state, false); trunk.update(0, {vehicleState: state}); hood.update(0, {vehicleState: state});
  const wrapper = new T.Group(); wrapper.name = 'VehicleVisual'; wrapper.rotation.y = Math.PI; wrapper.add(car.object); wrapper.updateMatrixWorld(true);
  const keyOf = new Map(), nodeOf = new Map(), nodeRows = []; let nodeIndex = 0;
  wrapper.traverse(node => {const key = 'v' + (nodeIndex++).toString().padStart(4, '0'); keyOf.set(node, key); nodeOf.set(key, node);
    nodeRows.push({key, source_name: node.name, parent: node.parent && node !== wrapper ? keyOf.get(node.parent) : null,
      visible: node.visible, cast_shadow: node.castShadow, receive_shadow: node.receiveShadow});});
  assert.deepEqual(nodeRows, visualEntry.nodes.map(({key, source_name, parent, visible, cast_shadow, receive_shadow}) =>
    ({key, source_name, parent, visible, cast_shadow, receive_shadow})), 'Factory visual key traversal changed: ' + profile.id);
  const materialIds = new Map(), meshMaterials = {}, meshRows = [];
  for (const [node, key] of keyOf) if (node.isMesh) {
    const descriptors = orderedMaterials(node.material).map(material => {
      if (!materialIds.has(material)) materialIds.set(material, 'm' + materialIds.size.toString().padStart(4, '0'));
      return materialDescriptor(material, materialIds.get(material));
    });
    meshMaterials[key] = descriptors;
    meshRows.push({key, source_name: node.name, material_container_kind: Array.isArray(node.material) ? 'array' : 'scalar',
      ordered_material_identity_ids: descriptors.map(row => row.source_material_id)});
  }
  assert.deepEqual(canonicalMaterialGraph(meshMaterials), canonicalMaterialGraph(visualEntry.mesh_materials),
    'Factory visual material identity/descriptor graph changed: ' + profile.id);
  assert.deepEqual(meshRows, step.meshes.map(({key, source_name, material_container_kind, ordered_material_identity_ids}) =>
    ({key, source_name, material_container_kind, ordered_material_identity_ids})), 'Frozen step-1 mesh identity map changed: ' + profile.id);

  let capture = null, captureCalls = 0;
  globalThis[probeSymbol] = payload => {captureCalls++; assert.equal(payload.car, car); capture = payload;};
  let damage;
  try {damage = createVehicleDamage(T, car, {scene, trunk, getState: () => state});}
  finally {delete globalThis[probeSymbol];}
  assert.equal(captureCalls, 1); assert(capture?.materialRest instanceof Map);
  const restIndexByMaterial = new Map([...capture.materialRest.keys()].map((material, index) => [material, index]));

  const visualOraclePath = path.join(path.dirname(visualManifestPath), profile.id + '.oracle.json');
  const visualOracleBytes = fs.readFileSync(visualOraclePath); assert.equal(hash(visualOracleBytes), visualEntry.oracle_sha256);
  const visualOracle = JSON.parse(visualOracleBytes);
  const visualGlbPath = path.join(path.dirname(visualManifestPath), visualEntry.file);
  const visualGlbBytes = fs.readFileSync(visualGlbPath); assert.equal(hash(visualGlbBytes), visualEntry.sha256); assert.equal(visualGlbBytes.length, visualEntry.bytes);
  const rawExportScene = (await new GLTFLoader().parseAsync(visualGlbBytes.buffer.slice(visualGlbBytes.byteOffset, visualGlbBytes.byteOffset + visualGlbBytes.byteLength), '')).scene;
  const rawExportNodes = []; rawExportScene.traverse(node => rawExportNodes.push(node));

  for (const targetRow of expectedTargets) {
    const postNode = nodeOf.get(targetRow.node_key); assert(postNode?.isMesh); assert.equal(postNode.name, targetRow.source_name);
    const post = geometryReceipt(postNode.geometry);
    const oracleMesh = visualOracle.meshes.find(row => row.key === targetRow.node_key); assert(oracleMesh);
    assert.equal(oracleMesh.attributes.position.values.length, 0); assert.equal(oracleMesh.indices, null); assert.deepEqual(oracleMesh.groups, []);
    assert.deepEqual(oracleMesh.draw_range, {start: 0, count: null});
    const exported = rawExportNodes.filter(node => node.name === targetRow.node_key); assert.equal(exported.length, 1);
    assert.equal(exported[0].isMesh, undefined, 'Empty post-factory slot unexpectedly imported as raw exported Mesh');
    assert.equal(exported[0].children.length, 0, 'Empty raw-export node unexpectedly owns children');
    const material = orderedMaterials(postNode.material)[0]; assert.equal(orderedMaterials(postNode.material).length, 1);
    const materialId = materialIds.get(material); assert.equal(materialId, targetRow.source_material_id);
    const original = originalReceipts.get(targetRow.source_name);
    assert(original.position.count > 0 && original.index?.count > 0, 'Original input geometry must be nonempty and indexed');
    assert.equal(original.position.count, targetRow.position_count); assert.equal(original.position.item_size, targetRow.position_item_size);
    assert.equal(original.position.array_type, targetRow.position_array_type); assert.equal(original.position.bytes_sha256, targetRow.position_f32le_sha256);
    assert.equal(original.index.count, targetRow.index_count); assert.equal(original.index.array_type, targetRow.index_array_type);
    assert.equal(original.index.bytes_sha256, targetRow.index_u16le_sha256); assert.equal(original.index.min, targetRow.index_min); assert.equal(original.index.max, targetRow.index_max);
    assert.deepEqual(original.groups, targetRow.groups); assert.equal(original.draw_range.start, targetRow.draw_range.start);
    assert.equal(original.draw_range.count_type, targetRow.draw_range.count === 'Infinity' ? 'positive_infinity' : 'finite');
    assert.equal(post.empty_position_geometry, true); assert.equal(post.position.count, 0); assert.equal(post.position.values_length, 0);
    assert.equal(post.index, null); assert.deepEqual(post.groups, []); assert.equal(post.draw_range.count_type, 'positive_infinity');
    targetReceipts.push({profile_id: profile.id, source_profile_id: profile.source_profile_id ?? profile.id,
      node_key: targetRow.node_key, source_name: targetRow.source_name, source_material_id: materialId,
      original_input_glb_geometry: original, actual_postfactory_geometry: post,
      construction_material_rest: {captured: restIndexByMaterial.has(material), insertion_index: restIndexByMaterial.get(material) ?? null},
      raw_visual_oracle: {path: relative(visualOraclePath), sha256: hash(visualOracleBytes),
        position_values_length: oracleMesh.attributes.position.values.length, indices: oracleMesh.indices,
        groups: oracleMesh.groups, draw_range: oracleMesh.draw_range},
      raw_visual_glb: {path: relative(visualGlbPath), sha256: hash(visualGlbBytes), bytes: visualGlbBytes.length,
        node_name: targetRow.node_key, imported_is_mesh: false, imported_child_count: exported[0].children.length},
      conclusion: 'ORIGINAL_INPUT_NONEMPTY_BUT_ACTUAL_POSTFACTORY_GEOMETRY_EMPTY_BY_SOURCE_CLIPPING'});
  }
  profileReceipts.push({profile_id: profile.id, source_profile_id: profile.source_profile_id ?? profile.id,
    input_glb: {path: relative(inputPath), sha256: hash(input)}, visual_oracle_sha256: visualEntry.oracle_sha256,
    visual_glb_sha256: visualEntry.sha256, node_key_receipt_exact: true,
    material_descriptor_alias_graph_exact: true, frozen_step1_mesh_identity_map_exact: true,
    targeted_empty_postfactory_nodes: expectedTargets.length});
  damage.dispose(); trunk.dispose(); hood.dispose(); wrapper.remove(car.object);
}

assert.equal(profileReceipts.length, 13); assert.equal(targetReceipts.length, 7);
assert.equal(targetReceipts.filter(row => row.construction_material_rest.captured).length, 7);
const sourceFiles = [...dependencies].filter(value => value.startsWith(repo + path.sep) && fs.existsSync(value) && fs.statSync(value).isFile())
  .map(value => ({path: relative(value), sha256: hash(fs.readFileSync(value))})).sort((a, b) => a.path.localeCompare(b.path, 'en'));
const ownTool = relative(fileURLToPath(import.meta.url));
for (const row of sourceFiles) {
  if (row.path === ownTool) continue;
  const expected = step1SourcePins.get(row.path); assert(expected, 'Loaded source absent from frozen step-1 allowlist: ' + row.path);
  assert.equal(row.sha256, expected, 'Loaded source changed: ' + row.path);
}
const result = {schema: 'mafiozi.transport-burn-postfactory-geometry.v1', three_revision: T.REVISION,
  status: 'SEVEN_ACTUAL_POSTFACTORY_EMPTY_GEOMETRIES_PROVED',
  correction: {supersedes_legacy_conclusion: 'The seven native placeholders are an export/import coverage loss',
    corrected_conclusion: 'The original input GLB geometry is nonempty, but the actual source factory clipping leaves all seven post-factory Mesh geometries empty before visual export; zero native mesh surfaces preserve that post-factory result.',
    no_restored_original_content: true},
  source_clipping_evidence: {path: 'assets/maps/city_rebuild_v1/vehicle_fleet_models.mjs',
    split_assignment_lines: [182, 193], empty_source_removal_line: 226,
    note: 'Executed receipts, rather than the line references alone, prove the seven final post-factory outcomes.'},
  inputs: {frozen_step1: {path: relative(step1Path), sha256: hash(step1Bytes)},
    raw_visual_manifest: {path: relative(visualManifestPath), sha256: hash(visualManifestBytes)},
    native_visual_manifest: {path: relative(nativeVisualManifestPath), sha256: hash(nativeVisualManifestBytes)},
    legacy_alias_census_evidence_only: {path: relative(legacyCensusPath), sha256: hash(legacyCensusBytes),
      accepted_fields: ['profile_id', 'node_key', 'source_name', 'source_material_id',
        'position_count', 'position_item_size', 'position_array_type', 'position_f32le_sha256',
        'index_count', 'index_array_type', 'index_u16le_sha256', 'index_min', 'index_max', 'groups', 'draw_range'],
      rejected_legacy_conclusion: 'export/import coverage loss'}},
  identity_scope: {node: 'profile_id + pinned source/visual receipts + v####', material: 'profile-local m####', global_ids: false},
  source_files: sourceFiles, profiles: profileReceipts, nodes: targetReceipts,
  limits: ['Only the seven previously disputed nodes are admitted by this correction receipt',
    'Original input geometry is recorded as evidence but is not source runtime content after factory clipping and must not be restored',
    'No renderer, native binder, material mutation, explosion callback, debris copy, GPU, LIVE, authority, HP, physics, or Git integration']};
fs.mkdirSync(path.dirname(target), {recursive: true});
fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({output: relative(target), sha256: hash(fs.readFileSync(target)), profiles: profileReceipts.length,
  nodes: targetReceipts.length, empty_postfactory_nodes: targetReceipts.filter(row => row.actual_postfactory_geometry.empty_position_geometry).length,
  captured_material_rest_nodes: targetReceipts.filter(row => row.construction_material_rest.captured).length, status: result.status}));
