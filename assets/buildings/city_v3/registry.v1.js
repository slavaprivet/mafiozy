const REGISTRY_SCHEMA = 'mafiozi.city-v3-building-registry/v1';
const MANIFEST_SCHEMA = 'mafiozi.city-v3-building-asset/v1';
const DIRECT_VERSIONED_KEY = /^[a-z0-9][a-z0-9_-]*@[1-9][0-9]*$/;
const SHA256_HEX = /^[a-f0-9]{64}$/;
const EPSILON_M = 0.015;

export const CITY_V3_REGISTRY_URL = new URL('./registry.v1.json', import.meta.url);
export const CITY_V3_REGISTRY_SHA256 = '1551ff8bcf6df0b37fb9d07dbbb3632c075f9aeef41c8674488f928f1a0d4745';
export const CITY_V3_CIVIC_KEY = 'civic_hall_landmark@1';

export class CityV3BuildingAssetError extends Error {
  constructor(code, message) {
    super(`${code}: ${message}`);
    this.name = 'CityV3BuildingAssetError';
    this.code = code;
  }
}

const fail = (code, message) => { throw new CityV3BuildingAssetError(code, message); };
const finite = value => Number.isFinite(+value);
const near = (actual, expected, epsilon = EPSILON_M) => finite(actual) && Math.abs(+actual - +expected) <= epsilon;
const normalizedHash = value => String(value || '').toLowerCase();
const assert = (condition, code, message) => { if (!condition) fail(code, message); };
const assertVector = (actual, expected, code, epsilon = EPSILON_M) => {
  assert(Array.isArray(actual) && actual.length === expected.length, code, 'vector shape mismatch');
  expected.forEach((value, index) => assert(near(actual[index], value, epsilon), code, `vector[${index}] mismatch`));
};

export function cityV3BuildingPreviewGate(params, hostname = location.hostname) {
  const query = params instanceof URLSearchParams ? params : new URLSearchParams(params || '');
  const local = hostname === '127.0.0.1' || hostname === 'localhost';
  return local && query.get('preview') === '1' && query.get('previewcityv3') === 'stage-a' && query.get('cityv3buildings') === '1';
}

export async function sha256Hex(bytes) {
  const view = bytes instanceof Uint8Array
    ? bytes
    : bytes instanceof ArrayBuffer
      ? new Uint8Array(bytes)
      : fail('bytes_type', 'expected Uint8Array or ArrayBuffer');
  const digest = await crypto.subtle.digest('SHA-256', view);
  return [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('');
}

const readExact = async (url, expectedBytes, expectedSha256, code) => {
  assert(Number.isInteger(expectedBytes) && expectedBytes > 0, `${code}_bytes_contract`, 'invalid expected byte count');
  assert(SHA256_HEX.test(normalizedHash(expectedSha256)), `${code}_sha_contract`, 'invalid expected SHA-256');
  const response = await fetch(url, { cache: 'no-store', credentials: 'same-origin' });
  assert(response.ok, `${code}_fetch`, `${response.status} ${response.statusText}`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  assert(bytes.byteLength === expectedBytes, `${code}_bytes`, `expected ${expectedBytes}, got ${bytes.byteLength}`);
  const actualSha256 = await sha256Hex(bytes);
  assert(actualSha256 === normalizedHash(expectedSha256), `${code}_sha`, `expected ${expectedSha256}, got ${actualSha256}`);
  return { bytes, sha256: actualSha256 };
};

const parseJson = (bytes, code) => {
  try { return JSON.parse(new TextDecoder().decode(bytes)); }
  catch (error) { fail(`${code}_json`, error?.message || 'invalid JSON'); }
};

export function resolveCityV3BuildingAsset(registry, key) {
  assert(registry?.schema === REGISTRY_SCHEMA, 'registry_schema', 'unsupported registry schema');
  assert(registry?.revision === 1, 'registry_revision', 'unsupported registry revision');
  assert(registry?.activation_policy === 'explicit_preview_only_fail_closed', 'registry_policy', 'activation policy mismatch');
  assert(DIRECT_VERSIONED_KEY.test(String(key || '')), 'resolver_key', 'a direct versioned key is required');
  assert(Array.isArray(registry.entries) && registry.entries.length > 0, 'registry_entries', 'registry is empty');
  const matches = registry.entries.filter(entry => entry?.key === key);
  assert(matches.length === 1, 'resolver_cardinality', `expected one ${key}, found ${matches.length}`);
  const entry = matches[0];
  assert(entry.status === 'conditional_preview_only' && entry.live_activation === false, 'resolver_activation', 'asset is not preview-only');
  assert(entry.style_gate === 'review_pending_candidate', 'resolver_style_gate', 'unexpected style gate state');
  for (const [kind, record] of Object.entries({ manifest: entry.manifest, asset: entry.asset, sidecar: entry.sidecar })) {
    assert(record && typeof record.url === 'string' && record.url.startsWith('./'), `resolver_${kind}_url`, 'URL must be registry-relative');
    assert(Number.isInteger(record.bytes) && record.bytes > 0, `resolver_${kind}_bytes`, 'invalid byte count');
    assert(SHA256_HEX.test(normalizedHash(record.sha256)), `resolver_${kind}_sha`, 'invalid SHA-256');
  }
  return entry;
}

const validateManifestAndSidecar = (entry, manifest, sidecar) => {
  assert(manifest?.schema === MANIFEST_SCHEMA, 'manifest_schema', 'unsupported manifest schema');
  assert(manifest.key === entry.key, 'manifest_key', 'registry/manifest key mismatch');
  assert(manifest.status === 'conditional_preview_only', 'manifest_status', 'manifest is not conditional preview-only');
  assert(manifest.asset?.canonical_asset_id === entry.canonical_asset_id, 'manifest_asset_id', 'canonical asset mismatch');
  assert(manifest.asset?.stable_instance_id === entry.stable_instance_id, 'manifest_instance_id', 'stable instance mismatch');
  assert(normalizedHash(manifest.asset?.sha256) === normalizedHash(entry.asset.sha256), 'manifest_asset_sha', 'asset hash mismatch');
  assert(+manifest.asset?.bytes === entry.asset.bytes, 'manifest_asset_bytes', 'asset byte count mismatch');
  assert(normalizedHash(manifest.asset?.sidecar_sha256) === normalizedHash(entry.sidecar.sha256), 'manifest_sidecar_sha', 'sidecar hash mismatch');
  assert(+manifest.asset?.sidecar_bytes === entry.sidecar.bytes, 'manifest_sidecar_bytes', 'sidecar byte count mismatch');
  assert(manifest.provenance?.origin === 'project_generated', 'provenance_origin', 'asset is not project generated');
  assert(typeof manifest.provenance?.generator_path === 'string' && manifest.provenance.generator_path.endsWith('build_civic_hall_landmark_v1.py'), 'provenance_generator_path', 'generator path mismatch');
  assert(normalizedHash(manifest.provenance?.generator_sha256) === 'ebc25b92803a182bcf71ee2b47bf03d18d22c89fa7ab46d2864afe82568781f7', 'provenance_generator_sha', 'generator hash mismatch');
  assert(Array.isArray(manifest.provenance?.external_sources) && manifest.provenance.external_sources.length === 0, 'provenance_external_sources', 'external sources are not allowed');
  assert(manifest.provenance?.usage === 'internal_project_asset', 'provenance_usage', 'usage rights mismatch');
  assert(normalizedHash(manifest.source_contracts?.placement_contract_sha256) === 'afe4459677228424412e273ec3a32a04cc17b1a3a3c24d4f70d2cafb022ce58c', 'placement_contract_sha', 'placement contract mismatch');
  assert(normalizedHash(manifest.source_contracts?.environment_contract_sha256) === '4c304c28a9f041d69f36bc085330dd0c14338393b022f0e9fc522ad971b25b88', 'environment_contract_sha', 'environment contract mismatch');
  assert(normalizedHash(manifest.source_contracts?.environment_package_manifest_sha256) === 'fe3171a80840ada32838c5570246970bb3ec3e71301c6bf7dc388b1411c939d8', 'environment_manifest_sha', 'environment package mismatch');
  assert(manifest.style_gate?.status === 'review_pending_candidate', 'style_status', 'civic asset must remain pending');
  assert(manifest.style_gate?.activation === 'explicit_preview_only_until_live_review', 'style_activation', 'live activation must remain disabled');
  assert(manifest.style_gate?.budget?.triangles <= manifest.style_gate?.budget?.triangles_max, 'style_triangle_budget', 'triangle budget exceeded');
  assert(manifest.style_gate?.budget?.materials <= manifest.style_gate?.budget?.materials_max, 'style_material_budget', 'material budget exceeded');
  assert(manifest.style_gate?.budget?.lod_present === false && manifest.style_gate?.budget?.live_review_required === true, 'style_lod_review', 'missing live-review hold');

  const placement = manifest.placement;
  assert(placement?.district_id === 'central_district' && placement?.parcel_id === 'C-HALL-01', 'placement_identity', 'district or parcel mismatch');
  assertVector(placement.center_grid_rc, [68, 69], 'placement_center', 1e-9);
  assertVector(placement.world_position_xyz_m, [282.9, .9, 278.8], 'placement_world', 1e-9);
  assert(near(placement.runtime_scene_y_m, 0, 1e-9) && placement.runtime_scene_y_rule === 'world_y_minus_terrain_elevation', 'placement_y_adapter', 'terrain datum adapter mismatch');
  assert(near(placement.contract_yaw_deg, 0, 1e-9) && near(placement.asset_correction_yaw_deg, 180, 1e-9) && near(placement.final_runtime_yaw_deg, 180, 1e-9), 'placement_yaw', 'front correction mismatch');
  assert(placement.authored_source_front === '+Y' && placement.raw_gltf_front === '-Z', 'placement_front', 'authored/raw front evidence mismatch');
  assertVector(placement.raw_node_evidence?.translation_xyz_m, [0, .15000000596046448, -2.3499999046325684], 'placement_anchor_evidence', 1e-6);
  assertVector(placement.pre_rotation_recenter_xyz_m, [0, 0, -4.3125], 'placement_recenter', 1e-9);
  assertVector(placement.corrected_centered_runtime_bounds_m?.min_xyz, [-7.7, .03, -6.8375], 'placement_bounds_min');
  assertVector(placement.corrected_centered_runtime_bounds_m?.max_xyz, [7.7, 13.28, 6.8375], 'placement_bounds_max');
  assertVector(placement.corrected_centered_runtime_bounds_m?.dimensions_xyz, [15.4, 13.25, 13.675], 'placement_bounds_size');
  const fit = placement.fit_check;
  assert(near(fit?.building_depth_m, 13.675, 1e-9) && near(fit?.pad_depth_m, 22, 1e-9), 'placement_depth_contract', 'corrected depth or pad mismatch');
  assert(fit.fits === true && fit.building_depth_m <= fit.pad_depth_m && fit.building_width_m <= fit.pad_width_m, 'placement_fit', 'building does not fit pad');
  assert(near(fit.depth_total_margin_m, 8.325, 1e-9), 'placement_depth_margin', '13.675m/22m numeric margin mismatch');
  assertVector(placement.public_door?.anchor_grid_rc, [69.62499997673965, 69], 'placement_door_grid', 1e-6);
  assert(placement.public_door?.accessible === true && placement.public_door?.corridor_half_width_cells >= .3, 'placement_door_access', 'public door corridor missing');

  const substitution = manifest.corrective_substitution;
  assert(normalizedHash(substitution?.old_glb_sha256) === 'd2ba44546903b555ba25df1dea0c1f11799bae6283f14466b13b04736057c134', 'substitution_old_sha', 'old hash mismatch');
  assert(normalizedHash(substitution?.new_glb_sha256) === normalizedHash(entry.asset.sha256), 'substitution_new_sha', 'corrected hash mismatch');
  assert(substitution?.depth_13_675_inside_22m_pad === true, 'substitution_fit', 'corrected depth was not accepted');
  const replacement = manifest.replacement;
  assert(replacement?.policy === 'addressed_removal_only', 'replacement_policy', 'demolition policy mismatch');
  assert(replacement?.legacy_structure_id === 'legacy:procedural:60:60:65:65:68:68', 'replacement_legacy_id', 'legacy structure is not addressed');
  assert(replacement?.replacement_id === 'landmark:civic_hall' && replacement?.routing_preserved === true && replacement?.zero_untracked_demolition === true, 'replacement_contract', 'replacement/routing contract mismatch');
  assert(manifest.runtime_gate?.direct_versioned_key_only === true && manifest.runtime_gate?.fail_closed === true, 'runtime_fail_closed', 'fail-closed gate missing');

  assert(sidecar?.schemaVersion === 1, 'sidecar_schema', 'unsupported sidecar schema');
  assert(sidecar.assetId === 'C-HALL-01' && sidecar.buildingId === 'BLDG_CIVIC_HALL_01', 'sidecar_identity', 'sidecar identity mismatch');
  assert(+sidecar.runtimeBytes === entry.asset.bytes, 'sidecar_asset_bytes', 'sidecar byte count mismatch');
  assert(normalizedHash(sidecar.runtimeSha256) === normalizedHash(entry.asset.sha256), 'sidecar_asset_sha', 'sidecar hash mismatch');
  assert(sidecar.reverseImportValidation?.status === 'pass', 'sidecar_reverse_import', 'reverse-import validation did not pass');
  assertVector(sidecar.validatedBoundsReverseImportedBlenderXYZ?.building?.dimensions, [15.4, 13.675, 13.25], 'sidecar_bounds');
  return true;
};

export function parseGlbJson(bytes) {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  assert(view.byteLength >= 20, 'glb_length', 'file is too short');
  const data = new DataView(view.buffer, view.byteOffset, view.byteLength);
  assert(data.getUint32(0, true) === 0x46546c67, 'glb_magic', 'not a binary glTF');
  assert(data.getUint32(4, true) === 2, 'glb_version', 'only glTF 2 is supported');
  assert(data.getUint32(8, true) === view.byteLength, 'glb_declared_length', 'declared length mismatch');
  let offset = 12, jsonBytes = null;
  while (offset + 8 <= view.byteLength) {
    const length = data.getUint32(offset, true), type = data.getUint32(offset + 4, true);
    offset += 8;
    assert(offset + length <= view.byteLength, 'glb_chunk_length', 'chunk exceeds file');
    if (type === 0x4e4f534a) jsonBytes = view.subarray(offset, offset + length);
    offset += length;
  }
  assert(jsonBytes, 'glb_json_chunk', 'JSON chunk missing');
  return parseJson(jsonBytes, 'glb');
}

const validateRawGlb = (gltfJson, manifest) => {
  const nodes = Array.isArray(gltfJson?.nodes) ? gltfJson.nodes : [];
  const indicesByName = new Map();
  nodes.forEach((node, index) => {
    if (!node?.name) return;
    const list = indicesByName.get(node.name) || [];
    list.push(index); indicesByName.set(node.name, list);
  });
  for (const name of manifest.runtime_gate.required_nodes) assert(indicesByName.get(name)?.length === 1, 'glb_required_node', `${name} missing or duplicated`);
  const rootIndex = indicesByName.get('BLDG_CIVIC_HALL_01')[0];
  const rootNode = nodes[rootIndex];
  assert(rootNode.mesh == null && Array.isArray(rootNode.children) && rootNode.children.length > 0, 'glb_building_root', 'building root is empty or flattened');
  const descendants = new Set(), queue = [...rootNode.children];
  while (queue.length) {
    const index = queue.pop();
    if (descendants.has(index)) continue;
    descendants.add(index);
    for (const child of nodes[index]?.children || []) queue.push(child);
  }
  for (const name of manifest.runtime_gate.excluded_planning_nodes) {
    const index = indicesByName.get(name)?.[0];
    assert(index == null || !descendants.has(index), 'glb_planning_overlap', `${name} is inside the runtime building root`);
  }
  const anchor = nodes[indicesByName.get('ACTION_CIVIC_HALL_01_MAIN')[0]];
  assertVector(anchor.translation, [0, .15000000596046448, -2.3499999046325684], 'glb_anchor_translation', 1e-6);
  assert(anchor.translation[2] < 0 && manifest.placement.asset_correction_yaw_deg === 180, 'glb_front_correction', 'raw -Z entrance is not corrected');
  return { rootIndex, anchorIndex: indicesByName.get('ACTION_CIVIC_HALL_01_MAIN')[0] };
};

const boxValues = box => ({
  min: [box.min.x, box.min.y, box.min.z],
  max: [box.max.x, box.max.y, box.max.z],
  dimensions: [box.max.x - box.min.x, box.max.y - box.min.y, box.max.z - box.min.z],
});

const assertBox = (actual, expected, code) => {
  assertVector(actual.min, expected.min_xyz, `${code}_min`);
  assertVector(actual.max, expected.max_xyz, `${code}_max`);
};

export async function loadCityV3BuildingCandidate({ THREE, params, hostname = location.hostname, key = CITY_V3_CIVIC_KEY } = {}) {
  assert(THREE?.Box3 && THREE?.Group, 'three_api', 'Three.js API missing');
  assert(cityV3BuildingPreviewGate(params, hostname), 'preview_gate', 'explicit local Stage A gate is closed');
  const registryFile = await readExact(CITY_V3_REGISTRY_URL, 1231, CITY_V3_REGISTRY_SHA256, 'registry');
  const registry = parseJson(registryFile.bytes, 'registry');
  const entry = resolveCityV3BuildingAsset(registry, key);
  const manifestUrl = new URL(entry.manifest.url, CITY_V3_REGISTRY_URL);
  const assetUrl = new URL(entry.asset.url, CITY_V3_REGISTRY_URL);
  const sidecarUrl = new URL(entry.sidecar.url, CITY_V3_REGISTRY_URL);
  const [manifestFile, sidecarFile, assetFile] = await Promise.all([
    readExact(manifestUrl, entry.manifest.bytes, entry.manifest.sha256, 'manifest'),
    readExact(sidecarUrl, entry.sidecar.bytes, entry.sidecar.sha256, 'sidecar'),
    readExact(assetUrl, entry.asset.bytes, entry.asset.sha256, 'asset'),
  ]);
  const manifest = parseJson(manifestFile.bytes, 'manifest');
  const sidecar = parseJson(sidecarFile.bytes, 'sidecar');
  validateManifestAndSidecar(entry, manifest, sidecar);
  validateRawGlb(parseGlbJson(assetFile.bytes), manifest);

  const { GLTFLoader } = await import('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/loaders/GLTFLoader.js/+esm');
  assert(typeof GLTFLoader === 'function', 'gltf_loader', 'GLTFLoader export missing');
  const loader = new GLTFLoader();
  const buffer = assetFile.bytes.buffer.slice(assetFile.bytes.byteOffset, assetFile.bytes.byteOffset + assetFile.bytes.byteLength);
  const gltf = await new Promise((resolve, reject) => loader.parse(buffer, new URL('.', assetUrl).href, resolve, reject));
  const buildingRoot = gltf?.scene?.getObjectByName?.('BLDG_CIVIC_HALL_01');
  const anchorObject = gltf?.scene?.getObjectByName?.('ACTION_CIVIC_HALL_01_MAIN');
  assert(buildingRoot && anchorObject, 'gltf_runtime_nodes', 'runtime root or entrance anchor missing');
  buildingRoot.updateMatrixWorld(true);
  const rawBox = boxValues(new THREE.Box3().setFromObject(buildingRoot));
  assertBox(rawBox, manifest.placement.raw_gltf_building_bounds_m, 'gltf_raw_bounds');
  const visibleMeshes = [];
  buildingRoot.traverse(object => {
    if (!object?.isMesh) return;
    assert(object.geometry?.attributes?.position, 'gltf_mesh_geometry', `${object.name || 'mesh'} has no positions`);
    object.castShadow = true;
    object.receiveShadow = true;
    visibleMeshes.push(object);
  });
  assert(visibleMeshes.length > 0, 'gltf_empty_root', 'building root has no renderable meshes');

  const placementRoot = new THREE.Group();
  placementRoot.name = 'CITY_V3_INSTANCE_landmark_civic_hall';
  buildingRoot.position.x += manifest.placement.pre_rotation_recenter_xyz_m[0];
  buildingRoot.position.z += manifest.placement.pre_rotation_recenter_xyz_m[2];
  placementRoot.add(buildingRoot);
  placementRoot.rotation.y = THREE.MathUtils.degToRad(manifest.placement.final_runtime_yaw_deg);
  placementRoot.updateMatrixWorld(true);
  const correctedBox = boxValues(new THREE.Box3().setFromObject(placementRoot));
  assertBox(correctedBox, manifest.placement.corrected_centered_runtime_bounds_m, 'gltf_corrected_bounds');

  return {
    key,
    entry,
    manifest,
    sidecar,
    placementRoot,
    buildingRoot,
    visibleMeshes,
    registrySha256: registryFile.sha256,
    manifestSha256: manifestFile.sha256,
    sidecarSha256: sidecarFile.sha256,
    assetSha256: assetFile.sha256,
    correctedBox,
    installed: false,
  };
}

export function installCityV3BuildingCandidate(candidate, { THREE, scene, bridge, renderer, originR, originC, worldScale } = {}) {
  assert(candidate && candidate.key === CITY_V3_CIVIC_KEY && candidate.installed === false, 'install_candidate', 'candidate missing or already installed');
  assert(scene?.isScene && bridge && renderer?.domElement, 'install_runtime', 'scene, bridge or renderer missing');
  assert(finite(originR) && finite(originC) && finite(worldScale) && +worldScale >= 3 && +worldScale <= 5, 'install_world_scale', 'runtime world scale is outside the supported 3..5 range');
  const placement = candidate.manifest.placement;
  // Placement geometry is authored in metres against the 4.1m contract cell.
  // Three's live renderer may use 3..5 scene units per grid cell, so scale the
  // imported root by the exact ratio. Its grid footprint then remains
  // invariant and matches the collision contract at every renderer profile.
  const sceneUnitsPerMetre = +worldScale / 4.1;
  candidate.placementRoot.scale.setScalar(sceneUnitsPerMetre);
  candidate.placementRoot.position.set(
    (placement.center_grid_rc[1] - originC) * worldScale,
    placement.runtime_scene_y_m,
    (placement.center_grid_rc[0] - originR) * worldScale,
  );
  scene.add(candidate.placementRoot);
  candidate.placementRoot.updateMatrixWorld(true);
  const registered = candidate.placementRoot.parent === scene && scene.getObjectByName(candidate.placementRoot.name) === candidate.placementRoot;
  const worldBox = boxValues(new THREE.Box3().setFromObject(candidate.placementRoot));
  const expectedCenterX = (placement.center_grid_rc[1] - originC) * worldScale;
  const expectedCenterZ = (placement.center_grid_rc[0] - originR) * worldScale;
  const actualCenterX = (worldBox.min[0] + worldBox.max[0]) * .5;
  const actualCenterZ = (worldBox.min[2] + worldBox.max[2]) * .5;
  const boundsEligible = near(actualCenterX, expectedCenterX) && near(actualCenterZ, expectedCenterZ) &&
    near(worldBox.dimensions[0], 15.4 * sceneUnitsPerMetre) && near(worldBox.dimensions[2], 13.675 * sceneUnitsPerMetre);
  const receipt = {
    key: candidate.key,
    instanceId: candidate.entry.stable_instance_id,
    parcelId: placement.parcel_id,
    legacyStructureId: candidate.manifest.replacement.legacy_structure_id,
    registrySha256: candidate.registrySha256,
    manifestSha256: candidate.manifestSha256,
    sidecarSha256: candidate.sidecarSha256,
    glbSha256: candidate.assetSha256,
    loaded: true,
    eligible: registered && boundsEligible && candidate.visibleMeshes.length > 0,
    registered,
    visibleMeshCount: candidate.visibleMeshes.length,
    centerGridRC: [...placement.center_grid_rc],
    contractYawDeg: placement.contract_yaw_deg,
    correctionYawDeg: placement.asset_correction_yaw_deg,
    finalYawDeg: placement.final_runtime_yaw_deg,
    dimensionsM: [...candidate.correctedBox.dimensions],
    runtimeWorldScale: +worldScale,
    runtimeScaleRatio: sceneUnitsPerMetre,
    doorAnchorGridRC: [...placement.public_door.anchor_grid_rc],
  };
  let activation;
  try {
    assert(receipt.eligible, 'install_eligibility', 'scene registration or corrected world bounds failed');
    activation = bridge.activateCityV3BuildingPreview?.(receipt);
    assert(activation?.ok === true && activation?.active === candidate.key, 'install_activation', activation?.reason || 'world activation rejected');
  } catch (error) {
    scene.remove(candidate.placementRoot);
    throw error;
  }
  candidate.installed = true;
  candidate.placementRoot.userData.cityV3Building = true;
  candidate.placementRoot.userData.cityV3Key = candidate.key;
  renderer.domElement.dataset.cityV3BuildingAsset = `${candidate.key}:ready:${candidate.assetSha256.slice(0, 12)}`;
  return { ...candidate, activation, receipt, worldBox };
}
