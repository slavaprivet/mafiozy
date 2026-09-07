const REGISTRY_SCHEMA = 'mafiozi.civic-park-decor-registry/v1';
const PLACEMENT_SCHEMA = 'mafiozi.civic-park-decor-placement-candidate/v1';
const DIRECT_VERSIONED_KEY = /^[a-z0-9][a-z0-9_-]*@[1-9][0-9]*$/;
const SHA256_HEX = /^[a-f0-9]{64}$/;
const FORBIDDEN_SURFACES = new Set(['road', 'water', 'building', 'rail', 'door', 'protected']);

export const CIVIC_PARK_V2_REGISTRY_URL = new URL('./registry.v1.json', import.meta.url);
export const CIVIC_PARK_V2_REGISTRY_BYTES = 24361;
export const CIVIC_PARK_V2_REGISTRY_SHA256 = '6d00520c407a61ae3174f6e4e54d393e1c5050f53df9ecc1bae55a6a9fe17c6d';

export class CivicParkDecorAssetError extends Error {
  constructor(code, message) {
    super(`${code}: ${message}`);
    this.name = 'CivicParkDecorAssetError';
    this.code = code;
  }
}

const fail = (code, message) => { throw new CivicParkDecorAssetError(code, message); };
const assert = (condition, code, message) => { if (!condition) fail(code, message); };
const normalizedHash = value => String(value || '').toLowerCase();

export function civicParkDecorPreviewGate(params, hostname = location.hostname) {
  const query = params instanceof URLSearchParams ? params : new URLSearchParams(params || '');
  const local = hostname === '127.0.0.1' || hostname === 'localhost';
  return local && query.get('preview') === '1' && query.get('previewcityv3') === 'stage-a' && query.get('cityv3decor') === '1';
}

export async function civicParkSha256Hex(bytes) {
  const view = bytes instanceof Uint8Array ? bytes : bytes instanceof ArrayBuffer ? new Uint8Array(bytes) : fail('bytes_type', 'expected Uint8Array or ArrayBuffer');
  const digest = await crypto.subtle.digest('SHA-256', view);
  return [...new Uint8Array(digest)].map(value => value.toString(16).padStart(2, '0')).join('');
}

const readExact = async (url, expectedBytes, expectedSha256, code, signal) => {
  assert(Number.isInteger(expectedBytes) && expectedBytes > 0, `${code}_bytes_contract`, 'invalid expected byte count');
  assert(SHA256_HEX.test(normalizedHash(expectedSha256)), `${code}_sha_contract`, 'invalid expected SHA-256');
  const response = await fetch(url, { cache: 'no-store', credentials: 'same-origin', signal });
  assert(response.ok, `${code}_fetch`, `${response.status} ${response.statusText}`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  assert(bytes.byteLength === expectedBytes, `${code}_bytes`, `expected ${expectedBytes}, got ${bytes.byteLength}`);
  const actualSha256 = await civicParkSha256Hex(bytes);
  assert(actualSha256 === normalizedHash(expectedSha256), `${code}_sha`, `expected ${expectedSha256}, got ${actualSha256}`);
  return { bytes, sha256: actualSha256 };
};

const parseJson = (bytes, code) => {
  try { return JSON.parse(new TextDecoder().decode(bytes)); }
  catch (error) { fail(`${code}_json`, error?.message || 'invalid JSON'); }
};

export function parseCivicParkGlbJson(bytes) {
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
  assert(offset === view.byteLength, 'glb_trailing_bytes', 'invalid trailing bytes');
  assert(jsonBytes, 'glb_json_chunk', 'JSON chunk missing');
  return parseJson(jsonBytes, 'glb');
}

const triangleCount = doc => {
  const accessors = Array.isArray(doc?.accessors) ? doc.accessors : [];
  let triangles = 0;
  for (const mesh of doc?.meshes || []) for (const primitive of mesh?.primitives || []) {
    assert((primitive.mode ?? 4) === 4, 'glb_primitive_mode', 'only triangle primitives are accepted');
    const accessorIndex = primitive.indices ?? primitive.attributes?.POSITION;
    assert(Number.isInteger(accessorIndex) && accessors[accessorIndex], 'glb_accessor', 'primitive accessor missing');
    triangles += Math.floor(+accessors[accessorIndex].count / 3);
  }
  return triangles;
};

const validateRegistry = registry => {
  assert(registry?.schema === REGISTRY_SCHEMA && registry?.revision === 1, 'registry_schema', 'unsupported registry');
  assert(registry.status === 'READY_STATIC_RUNTIME_WIRE_REQUIRED' && registry.runtimeActivation === false, 'registry_status', 'registry must remain static-only');
  assert(registry.activationPolicy === 'explicit_local_preview_only_fail_closed', 'registry_policy', 'activation policy mismatch');
  assert(registry.catalogGlbsShipped === false && registry.catalogLayoutPlacementForbidden === true, 'registry_catalog', 'catalog layout must never become placement');
  assert(registry.hostThreePolicy?.secondThreeInstanceForbidden === true && registry.hostThreePolicy?.threeInjectedByHost === true && registry.hostThreePolicy?.gltfLoaderInjectedByHost === true && registry.hostThreePolicy?.registryImportsThree === false, 'registry_three', 'host-THREE isolation contract mismatch');
  assert(registry.rightsScope?.allowed === 'internal_project_staging_only' && registry.rightsScope?.publicRedistributionCleared === false && registry.rightsScope?.failClosedOutsideAllowedScope === true, 'registry_rights', 'rights scope is not fail-closed');
  assert(Array.isArray(registry.entries) && registry.entries.length === 18, 'registry_entries', 'expected 18 asset types');
  return registry;
};

const loadRegistry = async signal => {
  const file = await readExact(CIVIC_PARK_V2_REGISTRY_URL, CIVIC_PARK_V2_REGISTRY_BYTES, CIVIC_PARK_V2_REGISTRY_SHA256, 'registry', signal);
  return { registry: validateRegistry(parseJson(file.bytes, 'registry')), registrySha256: file.sha256 };
};

export function resolveCivicParkDecorAsset(registry, key, lod = 1) {
  validateRegistry(registry);
  assert(DIRECT_VERSIONED_KEY.test(String(key || '')), 'resolver_key', 'a direct versioned key is required');
  assert(Number.isInteger(lod) && lod >= 0 && lod <= 2, 'resolver_lod', 'LOD must be 0, 1 or 2');
  const matches = registry.entries.filter(entry => entry?.key === key);
  assert(matches.length === 1, 'resolver_cardinality', `expected one ${key}, found ${matches.length}`);
  const entry = matches[0], record = entry.lods?.find(item => item.lod === lod);
  assert(record && typeof record.url === 'string' && record.url.startsWith('./models/'), 'resolver_url', 'asset URL must be model-directory relative');
  assert(Number.isInteger(record.bytes) && record.bytes > 0 && SHA256_HEX.test(normalizedHash(record.sha256)), 'resolver_integrity', 'asset byte/hash contract invalid');
  return { entry, record };
}

const validateRawAsset = (entry, record, doc) => {
  assert(!doc?.images?.length && !doc?.textures?.length, 'glb_texture', 'image textures are outside the approved smooth-clay package');
  const counts = new Map();
  for (const node of doc?.nodes || []) if (node?.name) counts.set(node.name, (counts.get(node.name) || 0) + 1);
  for (const name of entry.requiredNodes || []) assert(counts.get(name) === 1, 'glb_required_node', `${name} missing or duplicated`);
  if (entry.requiresAnimatedWaterSurface) assert([...counts.keys()].some(name => name.startsWith('ANIMATED_SURFACE_')), 'glb_water_surface', 'animated water surface missing');
  if (entry.requiresWaterJetSockets) assert([...counts.keys()].some(name => name.startsWith('WATER_JET_SOCKET_')), 'glb_water_jet', 'water jet socket missing');
  assert(triangleCount(doc) === record.triangles, 'glb_triangles', 'triangle count differs from pinned audit');
};

export async function loadCivicParkDecorAssetCandidate({ THREE, GLTFLoader, params, hostname = location.hostname, key, lod = 1, rightsScope = 'internal_project_staging_only', signal } = {}) {
  assert(THREE?.Object3D && THREE?.Group && THREE?.Box3, 'three_api', 'host Three.js API missing');
  assert(typeof GLTFLoader === 'function', 'gltf_loader_injection', 'the host must inject its GLTFLoader bound to the same Three.js instance');
  assert(civicParkDecorPreviewGate(params, hostname), 'preview_gate', 'explicit local Stage A decor gate is closed');
  assert(rightsScope === 'internal_project_staging_only', 'rights_scope', 'public/export use is not cleared by the source package');
  const { registry, registrySha256 } = await loadRegistry(signal);
  const { entry, record } = resolveCivicParkDecorAsset(registry, key, lod);
  const assetUrl = new URL(record.url, CIVIC_PARK_V2_REGISTRY_URL);
  const file = await readExact(assetUrl, record.bytes, record.sha256, 'asset', signal);
  validateRawAsset(entry, record, parseCivicParkGlbJson(file.bytes));
  const loader = new GLTFLoader();
  const buffer = file.bytes.buffer.slice(file.bytes.byteOffset, file.bytes.byteOffset + file.bytes.byteLength);
  const gltf = await new Promise((resolve, reject) => {
    let settled=false;
    const cancel=()=>{if(!settled){settled=true;reject(signal.reason||new Error('decor parse cancelled'));}};
    if(signal?.aborted){cancel();return;}
    signal?.addEventListener('abort',cancel,{once:true});
    loader.parse(buffer, new URL('.', assetUrl).href, value=>{
      signal?.removeEventListener('abort',cancel);
      if(settled){disposeCivicParkDecorCandidate({assetRoot:value?.scene});return;}
      settled=true;resolve(value);
    },error=>{signal?.removeEventListener('abort',cancel);if(!settled){settled=true;reject(error);}});
  });
  if (signal?.aborted) { disposeCivicParkDecorCandidate({assetRoot:gltf?.scene}); throw signal.reason || new Error('decor load cancelled'); }
  assert(gltf?.scene?.isObject3D === true && gltf.scene instanceof THREE.Object3D, 'gltf_host_three', 'parsed scene is not owned by the injected host Three.js instance');
  for (const name of entry.requiredNodes || []) assert(gltf.scene.getObjectByName?.(name), 'gltf_runtime_node', `${name} missing after host parse`);
  gltf.scene.updateMatrixWorld(true);
  const bounds = new THREE.Box3().setFromObject(gltf.scene);
  assert(!bounds.isEmpty(), 'gltf_bounds', 'parsed asset has empty bounds');
  return Object.freeze({ key, lod, entry, record, gltf, assetRoot: gltf.scene, assetSha256: file.sha256, registrySha256, installed: false });
}

export async function loadCivicParkPlacementCandidate({ params, hostname = location.hostname, rightsScope = 'internal_project_staging_only', signal } = {}) {
  assert(civicParkDecorPreviewGate(params, hostname), 'preview_gate', 'explicit local Stage A decor gate is closed');
  assert(rightsScope === 'internal_project_staging_only', 'rights_scope', 'public/export use is not cleared by the source package');
  const { registry, registrySha256 } = await loadRegistry(signal);
  const record = registry.placementCandidate;
  const file = await readExact(new URL(record.url, CIVIC_PARK_V2_REGISTRY_URL), record.bytes, record.sha256, 'placement', signal);
  const contract = parseJson(file.bytes, 'placement');
  assert(contract?.schema === PLACEMENT_SCHEMA && contract.revision === 1, 'placement_schema', 'unsupported placement contract');
  assert(contract.status === 'READY_STATIC_RUNTIME_WIRE_REQUIRED' && contract.runtimeActivation === false && contract.placementAuthorized === false, 'placement_status', 'placement candidate is not static-only');
  assert(contract.rollback?.atomic === true && contract.rollback?.mutatesMapTiles === false && contract.rollback?.suppressesLegacyDecor === false, 'placement_rollback', 'non-atomic or destructive rollback contract');
  return Object.freeze({ contract, placementSha256: file.sha256, registrySha256, installed: false });
}

const sampleAabb = function* (aabb, step = .2) {
  const rows = Math.max(1, Math.ceil((aabb.maxR - aabb.minR) / step));
  const cols = Math.max(1, Math.ceil((aabb.maxC - aabb.minC) / step));
  for (let ri = 0; ri <= rows; ri++) for (let ci = 0; ci <= cols; ci++) yield [
    aabb.minR + (aabb.maxR - aabb.minR) * ri / rows,
    aabb.minC + (aabb.maxC - aabb.minC) * ci / cols,
  ];
};

export function preflightCivicParkPlacementCandidate(candidate, host) {
  const contract = candidate?.contract;
  assert(contract?.schema === PLACEMENT_SCHEMA && candidate.installed === false, 'preflight_candidate', 'static candidate missing or already installed');
  assert(host?.mapRows === 200 && host?.mapCols === 180 && Math.abs(+host.worldUnitsPerGridCellM - 4.1) <= 1e-9, 'preflight_map', 'live map dimensions or scale differ');
  assert(typeof host.classifySurface === 'function', 'preflight_surface_api', 'live classifySurface(r,c) callback missing');
  const accepted = [];
  for (const placement of contract.placements) {
    for (const [r, c] of sampleAabb(placement.clearanceAabbGridRC)) {
      const surface = String(host.classifySurface(r, c) || 'unknown');
      assert(surface !== 'unknown' && !FORBIDDEN_SURFACES.has(surface), 'preflight_surface', `${placement.id} intersects ${surface} at ${r.toFixed(3)},${c.toFixed(3)}`);
    }
    accepted.push(placement.id);
  }
  return Object.freeze({ ok: true, staticOnly: true, placementSha256: candidate.placementSha256, accepted: Object.freeze(accepted) });
}

// This is a rollback primitive for a future atomic wire.  This registry has no
// install function, so invoking it during READY_STATIC is harmless/idempotent.
export function disposeCivicParkDecorCandidate(candidate) {
  const root = candidate?.assetRoot;
  if (!root?.traverse) return { ok: true, disposed: false };
  if (root.parent) root.parent.remove(root);
  root.traverse(object => {
    object.geometry?.dispose?.();
    const materials = Array.isArray(object.material) ? object.material : object.material ? [object.material] : [];
    for (const material of materials) material.dispose?.();
  });
  return { ok: true, disposed: true };
}
