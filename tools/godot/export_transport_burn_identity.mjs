#!/usr/bin/env node
// Executed-source proof for construction-captured vehicle burn identities.
// The production source is SHA/sentinel-pinned and instrumented only by the
// Node loader in memory. No source asset, GLB, runtime, or visual export changes.
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const vendor = process.env.MAFIOZI_THREE_VENDOR ?? 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const target = path.join(repo, 'godot/mafiozi_walk/data/transport/source_burn_identities.json');
const visualManifestPath = path.join(repo, 'outputs/coordinator21_vehicle_visual/manifest.json');
const nativeVisualManifestPath = path.join(repo, 'godot/mafiozi_walk/assets/vehicle_visual/manifest.json');
const damagePath = path.join(repo, 'assets/maps/city_rebuild_v1/vehicle_damage.mjs');
const damageUrl = pathToFileURL(damagePath).href;
const expectedDamageSha = 'e029cb4a03dcd23bbdd0fb2f73b7780db92f24f761cf83b030991acb3c403f92';
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const relative = value => path.relative(repo, value).replaceAll('\\', '/');
const dependencies = new Set([fileURLToPath(import.meta.url)]);
const damageBytes = fs.readFileSync(damagePath);
assert.equal(hash(damageBytes), expectedDamageSha, 'Pinned vehicle_damage.mjs changed');
const damageSource = damageBytes.toString('utf8');
const damageSentinel = "car.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.material?.transparent)glass.push(mesh);if(mesh.material?.color&&!materialRest.has(mesh.material))materialRest.set(mesh.material,{color:mesh.material.color.clone(),roughness:mesh.material.roughness});});";
assert.equal(damageSource.split(damageSentinel).length, 2, 'Exact damage return sentinel must occur once');
const instrumentedDamageSource = damageSource.replace(damageSentinel,
  damageSentinel + "globalThis[Symbol.for('mafiozi.transport-burn-probe/v1')]?.({car,materialRest,glass});");

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

const visualManifestBytes = fs.readFileSync(visualManifestPath);
const visualManifest = JSON.parse(visualManifestBytes);
assert.equal(visualManifest.schema, 'mafiozi.vehicle-visual.v1');
assert.equal(visualManifest.three_revision, T.REVISION);
const manifestById = new Map(visualManifest.entries.map(entry => [entry.profile_id, entry]));
const nativeVisualManifestBytes = fs.readFileSync(nativeVisualManifestPath);
const nativeVisualManifest = JSON.parse(nativeVisualManifestBytes);
assert.equal(nativeVisualManifest.schema, visualManifest.schema);
assert.equal(nativeVisualManifest.three_revision, visualManifest.three_revision);
const nativeManifestById = new Map(nativeVisualManifest.entries.map(entry => [entry.profile_id, entry]));
const sedan = ARTIST_VEHICLE_PROFILES.find(profile => profile.id === 'compact_sedan');
assert(sedan);
const profiles = [...ARTIST_VEHICLE_PROFILES, {...sedan, id: 'city_taxi', source_profile_id: 'compact_sedan', wheelDesignId: 'city_taxi'}];
const probeSymbol = Symbol.for('mafiozi.transport-burn-probe/v1');

function f64le(value) {
  const bytes = Buffer.allocUnsafe(8); bytes.writeDoubleLE(value); return bytes.toString('hex');
}

function materialDescriptor(material, materialIds) {
  for (const value of Object.values(material)) assert(!value?.isTexture, 'Texture requires explicit transfer: ' + material.name);
  assert(material.isMeshStandardMaterial || material.isMeshBasicMaterial, 'Unsupported material: ' + material.type);
  if (!materialIds.has(material)) materialIds.set(material, 'm' + materialIds.size.toString().padStart(4, '0'));
  return {
    source_material_id: materialIds.get(material), source_metadata: structuredClone(material.userData),
    name: material.name, type: material.type, color_linear: material.color.toArray(), roughness: material.roughness ?? null,
    metallic: material.metalness ?? null, emissive_linear: material.emissive?.toArray() ?? [0, 0, 0],
    emissive_intensity: material.emissiveIntensity ?? 0, opacity: material.opacity, transparent: material.transparent,
    depth_write: material.depthWrite, depth_test: material.depthTest, side: material.side,
    vertex_colors: material.vertexColors, flat_shading: material.flatShading,
    ior: material.ior ?? null, specular_intensity: material.specularIntensity ?? null,
  };
}

function counts(meshMaterials) {
  const uses = new Map(); let slots = 0; let multi = 0; let transparent = 0;
  for (const materials of Object.values(meshMaterials)) {
    if (materials.length > 1) multi++;
    for (const material of materials) {
      slots++; uses.set(material.source_material_id, (uses.get(material.source_material_id) ?? 0) + 1);
      if (material.transparent) transparent++;
    }
  }
  const useCounts = [...uses.values()];
  return {material_slots: slots, unique_material_ids: uses.size, alias_slots: slots - uses.size,
    shared_material_ids: useCounts.filter(value => value > 1).length, max_identity_uses: Math.max(...useCounts),
    normalized_multi_entry_nodes: multi, transparent_slots: transparent};
}

function canonicalizeNondeterministicMetadata(meshMaterials) {
  const paletteSources = new Map();
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  // Match the visual manifest's JSON representation as well: properties whose
  // Three material class leaves undefined (for example Basic flatShading) are
  // absent from the persisted descriptor rather than semantically different.
  const result = JSON.parse(JSON.stringify(meshMaterials));
  for (const materials of Object.values(result)) for (const material of materials) {
    const source = material.source_metadata?.interiorPaletteSource;
    if (source == null) continue;
    assert.equal(typeof source, 'string'); assert(uuid.test(source), 'Unexpected interiorPaletteSource representation');
    if (!paletteSources.has(source)) paletteSources.set(source, 'palette_source_' + paletteSources.size.toString().padStart(4, '0'));
    material.source_metadata.interiorPaletteSource = {nondeterministic_three_uuid_ref: paletteSources.get(source)};
  }
  return result;
}

const rows = [];
for (const profile of profiles) {
  const inputPath = path.join(repo, 'assets/maps/city_rebuild_v1/models/artist_vehicle_pack', profile.modelFile);
  const input = fs.readFileSync(inputPath);
  assert.equal(hash(input), profile.sha256, 'Pinned input changed: ' + profile.id);
  dependencies.add(inputPath);
  const source = (await new GLTFLoader().parseAsync(input.buffer.slice(input.byteOffset, input.byteOffset + input.byteLength), '')).scene;
  const car = profile.id === 'city_taxi'
    ? decorateCityTaxi(T, RoundedBoxGeometry, createArtistVehicle(T, RoundedBoxGeometry, source, {...sedan, wheelDesignId: 'city_taxi'}))
    : createArtistVehicle(T, RoundedBoxGeometry, source, profile);
  const scene = new T.Scene(); scene.add(car.object);
  const trunk = createVehicleTrunk(T, RoundedBoxGeometry, car, {scene}); car.trunk = trunk;
  const hood = createVehicleHood(T, RoundedBoxGeometry, car, {scene}); car.hood = hood;
  const vehicleState = {x: 0, y: 0, z: 0, yaw: 0, speed: 0, steer: 0, distance: 0};
  car.update(vehicleState, false); trunk.update(0, {vehicleState}); hood.update(0, {vehicleState});

  // Reproduce the visual export's wrapper traversal without mutating source names.
  const wrapper = new T.Group(); wrapper.name = 'VehicleVisual'; wrapper.rotation.y = Math.PI; wrapper.add(car.object); wrapper.updateMatrixWorld(true);
  const keyOf = new Map(); const nodeRows = []; let nodeIndex = 0;
  wrapper.traverse(node => {
    const key = 'v' + (nodeIndex++).toString().padStart(4, '0'); keyOf.set(node, key);
    nodeRows.push({key, source_name: node.name, parent: node.parent && node !== wrapper ? keyOf.get(node.parent) : null, visible: node.visible});
  });
  const materialIds = new Map(); const descriptorByMaterial = new Map(); const meshMaterials = {}; const meshRows = [];
  for (const [node, key] of keyOf) {
    if (!node.isMesh) continue;
    const containerKind = Array.isArray(node.material) ? 'array' : 'scalar';
    const current = containerKind === 'array' ? node.material : [node.material];
    const descriptors = current.map(material => {
      const descriptor = materialDescriptor(material, materialIds); descriptorByMaterial.set(material, descriptor); return descriptor;
    });
    meshMaterials[key] = descriptors;
    meshRows.push({key, source_name: node.name, traversal_index: nodeRows.findIndex(row => row.key === key),
      material_container_kind: containerKind, ordered_material_identity_ids: descriptors.map(row => row.source_material_id)});
  }

  const manifestEntry = manifestById.get(profile.id);
  assert(manifestEntry, 'Missing visual manifest profile: ' + profile.id);
  const nativeManifestEntry = nativeManifestById.get(profile.id);
  assert(nativeManifestEntry, 'Missing native visual manifest profile: ' + profile.id);
  assert.equal(manifestEntry.source_glb_sha256, profile.sha256, 'Visual manifest GLB pin mismatch: ' + profile.id);
  assert.deepEqual(nativeManifestEntry.mesh_materials, manifestEntry.mesh_materials, 'Raw/native visual material receipt mismatch: ' + profile.id);
  assert.deepEqual(nativeManifestEntry.nodes, manifestEntry.nodes, 'Raw/native visual node receipt mismatch: ' + profile.id);
  const visualGlbPath = path.join(path.dirname(visualManifestPath), manifestEntry.file);
  const visualGlbBytes = fs.readFileSync(visualGlbPath);
  assert.equal(visualGlbBytes.length, manifestEntry.bytes, 'Visual GLB byte count mismatch: ' + profile.id);
  assert.equal(hash(visualGlbBytes), manifestEntry.sha256, 'Visual GLB SHA mismatch: ' + profile.id);
  const visualOraclePath = path.join(path.dirname(visualManifestPath), profile.id + '.oracle.json');
  const visualOracleBytes = fs.readFileSync(visualOraclePath);
  assert.equal(hash(visualOracleBytes), manifestEntry.oracle_sha256, 'Visual oracle SHA mismatch: ' + profile.id);
  assert.deepEqual(nodeRows.map(({key, source_name, parent, visible}) => ({key, source_name, parent, visible})),
    manifestEntry.nodes.map(({key, source_name, parent, visible}) => ({key, source_name, parent, visible})),
    'Visual traversal receipt mismatch: ' + profile.id);
  // Three assigns fresh UUIDs on each factory construction. Preserve and compare
  // their equality graph, while replacing only that known random spelling with
  // stable first-seen tokens so this proof remains byte reproducible.
  const canonicalMeshMaterials = canonicalizeNondeterministicMetadata(meshMaterials);
  const canonicalManifestMaterials = canonicalizeNondeterministicMetadata(manifestEntry.mesh_materials);
  assert.deepEqual(canonicalMeshMaterials, canonicalManifestMaterials, 'Visual material descriptor/alias graph mismatch: ' + profile.id);
  const canonicalDescriptorById = new Map();
  for (const materials of Object.values(canonicalMeshMaterials)) for (const descriptor of materials)
    if (!canonicalDescriptorById.has(descriptor.source_material_id)) canonicalDescriptorById.set(descriptor.source_material_id, descriptor);

  let proof = null; let proofCalls = 0;
  assert.equal(globalThis[probeSymbol], undefined, 'Burn proof hook already installed');
  globalThis[probeSymbol] = payload => { proofCalls++; assert.equal(payload.car, car); proof = payload; };
  let damage;
  try { damage = createVehicleDamage(T, car, {scene, trunk, getState: () => vehicleState}); }
  finally { delete globalThis[probeSymbol]; }
  assert.equal(proofCalls, 1, 'Damage capture hook must fire exactly once: ' + profile.id);
  assert(proof && proof.materialRest instanceof Map && Array.isArray(proof.glass), 'In-memory damage proof hook unavailable');
  const capturedIds = new Set();
  const capturedMaterials = [...proof.materialRest.entries()].map(([material, rest], insertionIndex) => {
    const descriptor = descriptorByMaterial.get(material); assert(descriptor, 'Captured identity absent from visual alias graph: ' + profile.id);
    assert(!capturedIds.has(descriptor.source_material_id)); capturedIds.add(descriptor.source_material_id);
    assert(rest.color?.isColor, 'Invalid captured rest color: ' + profile.id + '/' + descriptor.source_material_id);
    assert.notEqual(rest.color, material.color, 'Captured rest color must be a clone');
    assert.deepEqual(rest.color.toArray(), material.color.toArray(), 'Captured rest color differs at capture');
    assert.equal(rest.roughness, material.roughness, 'Captured rest roughness differs at capture');
    assert(rest.roughness === undefined || Number.isFinite(rest.roughness), 'Invalid captured rest roughness: ' + profile.id + '/' + descriptor.source_material_id);
    const color = rest.color.toArray();
    const roughnessIsUndefined = rest.roughness === undefined;
    const roughness = roughnessIsUndefined ? null : rest.roughness;
    return {identity_id: descriptor.source_material_id, insertion_index: insertionIndex,
      rest_color_linear_f64: color, rest_color_linear_f64le: color.map(f64le),
      rest_roughness_type: roughnessIsUndefined ? 'undefined' : 'f64', rest_roughness_f64: roughness,
      rest_roughness_f64le: roughnessIsUndefined ? null : f64le(roughness),
      transparent_at_capture: material.transparent, material_type_at_capture: material.type};
  });
  const glassKeys = proof.glass.map((node, glassIndex) => {
    const key = keyOf.get(node); assert(key, 'Glass node absent from visual traversal: ' + profile.id);
    assert(!Array.isArray(node.material), 'Closure glass capture unexpectedly has array container');
    const descriptor = descriptorByMaterial.get(node.material); assert(descriptor, 'Glass material absent from identity map');
    return {key, source_name: node.name, glass_index: glassIndex,
      source_material_id: descriptor.source_material_id, visible_at_capture: node.visible};
  });
  const glassIndexByNode = new Map(proof.glass.map((node, index) => [node, index]));
  for (const mesh of meshRows) {
    const node = [...keyOf].find(([, key]) => key === mesh.key)[0];
    mesh.captured_material_identity_ids = mesh.ordered_material_identity_ids.filter(id => capturedIds.has(id));
    mesh.construction_glass_index = glassIndexByNode.get(node) ?? null;
  }
  const distinctMaterials = [...materialIds].sort((a, b) => a[1].localeCompare(b[1], 'en')).map(([material, id]) => ({
    identity_id: id, descriptor: canonicalDescriptorById.get(id),
    source_node_keys: meshRows.filter(row => row.ordered_material_identity_ids.includes(id)).map(row => row.key),
    captured_in_material_rest: capturedIds.has(id),
  }));
  const census = counts(meshMaterials);
  assert.equal(capturedMaterials.length, distinctMaterials.filter(row => row.captured_in_material_rest).length);
  assert(glassKeys.every(row => meshRows.some(mesh => mesh.key === row.key && mesh.material_container_kind === 'scalar')),
    'Source optional-chain glass capture must be scalar in this proof: ' + profile.id);
  rows.push({profile_id: profile.id, source_profile_id: profile.source_profile_id ?? profile.id,
    input_glb: {path: relative(inputPath), sha256: hash(input), expected_sha256: profile.sha256},
    visual_manifest_entry: {source_glb_sha256: manifestEntry.source_glb_sha256, visual_glb_file: manifestEntry.file,
      visual_glb_sha256: manifestEntry.sha256, visual_glb_bytes: manifestEntry.bytes,
      oracle_file: relative(visualOraclePath), oracle_sha256: manifestEntry.oracle_sha256},
    factory_receipt: {node_count: nodeRows.length, mesh_count: meshRows.length, ...census,
      visual_descriptor_alias_graph_exact_after_nondeterministic_uuid_canonicalization: true, visual_traversal_exact: true,
      metadata_canonicalization: 'Only source_metadata.interiorPaletteSource Three UUID spelling is replaced by a stable first-seen token; its alias relation is compared exactly.'},
    captured_materials: capturedMaterials, construction_glass: glassKeys, materials: distinctMaterials, meshes: meshRows});
  damage.dispose(); trunk.dispose(); hood.dispose(); wrapper.remove(car.object);
}

const sourceFiles = [...dependencies]
  .filter(value => value === repo || value.startsWith(repo + path.sep))
  .filter(value => fs.existsSync(value) && fs.statSync(value).isFile())
  .map(value => ({path: relative(value), sha256: hash(fs.readFileSync(value))}))
  .sort((a, b) => a.path.localeCompare(b.path, 'en'));
const result = {schema: 'mafiozi.transport-burn-source-identities.v1', three_revision: T.REVISION,
  proof_method: {kind: 'sha_and_sentinel_pinned_in_memory_capture_hook', production_source_modified: false,
    damage_source_sha256: expectedDamageSha, exposed: ['materialRest', 'glass']},
  source_order: {damage_before_render_batches: true, batch_canonical_registration_exported: false,
    incomplete: 'Render-batch hidden/canonical/current identity proof is the next bounded component.'},
  identity_scope: 'source_material_id is deterministic only within profile + pinned factory/visual receipt + vehicle lifecycle generation',
  visual_manifest: {path: relative(visualManifestPath), sha256: hash(visualManifestBytes), schema: visualManifest.schema},
  native_visual_manifest: {path: relative(nativeVisualManifestPath), sha256: hash(nativeVisualManifestBytes), schema: nativeVisualManifest.schema,
    exact_material_and_node_receipt_match: true},
  source_files: sourceFiles, profiles: rows};
assert.equal(rows.length, 13);
assert(rows.every(row => row.factory_receipt.visual_descriptor_alias_graph_exact_after_nondeterministic_uuid_canonicalization && row.factory_receipt.visual_traversal_exact));
fs.mkdirSync(path.dirname(target), {recursive: true});
fs.writeFileSync(target, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify({output: relative(target), sha256: hash(fs.readFileSync(target)), profiles: rows.length,
  materials: rows.reduce((sum, row) => sum + row.materials.length, 0),
  captured_materials: rows.reduce((sum, row) => sum + row.captured_materials.length, 0),
  glass_nodes: rows.reduce((sum, row) => sum + row.construction_glass.length, 0),
  status: 'BATCH_CANONICAL_IDENTITY_PENDING'}));
