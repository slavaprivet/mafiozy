import test from 'node:test';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { installBuildingCameraTriangleIndex } from './building_camera_triangle_index.mjs';
const T = await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor') + '/build/three.module.js'));
const original = T.Mesh.prototype._computeIntersections;
function fixture(indexed = true) {
  const source = new T.PlaneGeometry(12, 12, 24, 24).rotateX(-Math.PI / 2), geometry = indexed ? source : source.toNonIndexed();
  geometry.setAttribute('uv1', geometry.attributes.uv.clone()); geometry.addGroup(0, 3, 99);
  const mesh = new T.Mesh(geometry, new T.MeshStandardMaterial({ side: T.DoubleSide })); mesh.updateMatrixWorld(true); return mesh;
}
const ray = (o, d, near = 0, far = Infinity) => new T.Raycaster(new T.Vector3(...o), new T.Vector3(...d).normalize(), near, far);
function parity(mesh, handle, r) {
  handle.setEnabled(false); const expected = r.intersectObject(mesh, false); handle.setEnabled(true); const actual = r.intersectObject(mesh, false);
  assert.equal(actual.length, expected.length);
  for (let i = 0; i < actual.length; i++) { assert.equal(actual[i].object, mesh); assert.equal(expected[i].object, mesh); assert.deepEqual({ ...actual[i], object: null }, { ...expected[i], object: null }, 'distance/point/faceIndex/face/barycoord/UV/UV1/normal exact parity'); }
  return actual;
}

for (const indexed of [true, false]) test('exact camera hits on indexed/non-indexed triangles, sides, near/far and transforms: ' + indexed, () => {
  const mesh = fixture(indexed), geometry = mesh.geometry, positions = geometry.attributes.position.array.slice(), handle = installBuildingCameraTriangleIndex({ THREE: T, mesh }); assert(handle);
  for (const side of [T.FrontSide, T.BackSide, T.DoubleSide]) { mesh.material.side = side;
    for (const x of [-6, -2.25, 0, 2.123, 6, 6 + 1e-10]) for (const z of [-6, 0, .37, 6]) for (const y of [-2, 0, 2]) for (const d of [[0, -1, 0], [0, 1, 0], [1, -1e-12, 0]]) parity(mesh, handle, ray([x, y, z], d));
  }
  mesh.material.side = T.DoubleSide;
  for (const [near, far] of [[0, Infinity], [2, 2], [0, 2], [2, Infinity], [2 + 1e-12, Infinity], [0, 2 - 1e-12]]) parity(mesh, handle, ray([1, 2, 1], [0, -1, 0], near, far));
  for (const [start, count] of [[0, 1], [3, 1], [0, 4], [3, Infinity], [-3, 7], [0, 0]]) { geometry.setDrawRange(start, count); parity(mesh, handle, ray([0, 2, 0], [0, -1, 0])); }
  geometry.setDrawRange(0, Infinity);
  const parent = new T.Group(); parent.position.set(13, -7, 31); parent.rotation.set(.2, .8, .3); parent.scale.set(2, 3, .7); parent.add(mesh);
  for (const scaleX of [2, -2]) { parent.scale.x = scaleX; parent.updateMatrixWorld(true);
    const origin = new T.Vector3(1, 2, .7).applyMatrix4(mesh.matrixWorld), direction = new T.Vector3(0, -1, 0).transformDirection(mesh.matrixWorld);
    assert(parity(mesh, handle, new T.Raycaster(origin, direction)).length);
  }
  assert.deepEqual(geometry.attributes.position.array, positions); assert.equal(mesh.geometry, geometry); assert.equal(mesh.raycast, T.Mesh.prototype.raycast); assert.equal(handle.stats.fallbacks, 0);
  handle.dispose(); assert.equal(mesh._computeIntersections, original); assert(!Object.hasOwn(mesh, '_computeIntersections')); geometry.dispose(); mesh.material.dispose();
});

test('position/index version, geometry replacement, altered layout and custom vertex path always fall back', () => {
  const mutations = [m => m.geometry = m.geometry.clone(), m => m.geometry.setAttribute('position', m.geometry.attributes.position.clone()), m => m.geometry.attributes.position.needsUpdate = true,
    m => m.geometry.attributes.position.array = m.geometry.attributes.position.array.slice(), m => m.geometry.index.needsUpdate = true, m => m.geometry.setIndex(m.geometry.index.clone()),
    m => m.geometry.setDrawRange(1, 3), m => { m.material = [m.material]; m.geometry.groups[0].materialIndex = 0; }, m => { m.geometry.morphAttributes.position = [m.geometry.attributes.position.clone()]; m.updateMorphTargets(); },
    m => m.getVertexPosition = function (i, p) { return T.Mesh.prototype.getVertexPosition.call(this, i, p); }, m => m.raycast = function (...args) { return T.Mesh.prototype.raycast.apply(this, args); }];
  for (const mutate of mutations) {
    const mesh = fixture(), handle = installBuildingCameraTriangleIndex({ THREE: T, mesh }), r = ray([.2, 2, .3], [0, -1, 0]); mutate(mesh);
    const expected = [], actual = []; original.call(mesh, r, expected, r.ray); mesh._computeIntersections(r, actual, r.ray);
    assert.deepEqual(actual.map(h => ({ ...h, object: null })), expected.map(h => ({ ...h, object: null }))); assert.equal(handle.stats.fallbacks, 1); handle.dispose();
  }
});

test('dynamic UV/normal interpolation and material side remain native without rebuilding positional BVH', () => {
  const mesh = fixture(), handle = installBuildingCameraTriangleIndex({ THREE: T, mesh }), r = ray([.13, 2, .27], [0, -1, 0]);
  mesh.geometry.attributes.uv.array.fill(.3); mesh.geometry.attributes.uv.needsUpdate = true; mesh.geometry.attributes.normal.setXYZ(0, .1, .8, .2); mesh.material.side = T.BackSide; parity(mesh, handle, r);
  mesh.material.side = T.DoubleSide; assert(parity(mesh, handle, r).length); assert.equal(handle.stats.fallbacks, 0); handle.dispose();
});

test('plain immutable eligibility rejects small meshes, batched/skinned/morph/custom and non-writable hooks', () => {
  const small = new T.Mesh(new T.BoxGeometry(), new T.MeshBasicMaterial()); assert.equal(installBuildingCameraTriangleIndex({ THREE: T, mesh: small }), null);
  for (const mutate of [m => m.isInstancedMesh = true, m => m.isBatchedMesh = true, m => m.isSkinnedMesh = true, m => m.material = [m.material], m => m.raycast = () => {}, m => m._computeIntersections = () => {}, m => Object.defineProperty(m, '_computeIntersections', { value: original, writable: false }), m => Object.preventExtensions(m)]) {
    const mesh = fixture(); mutate(mesh); assert.equal(installBuildingCameraTriangleIndex({ THREE: T, mesh }), null);
  }
});

test('disposal, geometry disposal, saved descriptors and later owners are preserved exactly', () => {
  const mesh = fixture(); mesh._computeIntersections = original; const descriptor = Object.getOwnPropertyDescriptor(mesh, '_computeIntersections'), handle = installBuildingCameraTriangleIndex({ THREE: T, mesh });
  handle.dispose(); handle.dispose(); assert.deepEqual(Object.getOwnPropertyDescriptor(mesh, '_computeIntersections'), descriptor); assert.equal(handle.setEnabled(true), false);
  const other = fixture(), oldRaycast = other.raycast, h2 = installBuildingCameraTriangleIndex({ THREE: T, mesh: other }); other.geometry.dispose(); assert.equal(h2.stats.disposed, true); assert.equal(other._computeIntersections, original); assert.equal(other.raycast, oldRaycast); h2.dispose();
  const replaced = fixture(), h3 = installBuildingCameraTriangleIndex({ THREE: T, mesh: replaced }), later = () => {}; replaced._computeIntersections = later; h3.dispose(); assert.equal(replaced._computeIntersections, later);
});

test('native interpolation/push exceptions keep prior hits and restore real mesh identity', () => {
  for (const mode of ['uv', 'push']) {
    const mesh = fixture(), handle = installBuildingCameraTriangleIndex({ THREE: T, mesh }), failure = new Error(mode), r = ray([0, 2, 0], [0, -1, 0]);
    const uv = mesh.geometry.attributes.uv, getX = uv.getX; let reads = 0;
    if (mode === 'uv') uv.getX = function (i) { if (++reads === 4) throw failure; return getX.call(this, i); };
    function collect(method) { reads = 0; const prior = { object: 'prior' }, hits = [prior]; if (mode === 'push') hits.push = function (h) { Array.prototype.push.call(this, h); throw failure; };
      assert.throws(() => method.call(mesh, r, hits, r.ray), e => e === failure); assert.equal(hits[0], prior); assert.equal(hits.length, 2); assert.equal(hits[1].object, mesh); return { ...hits[1], object: null }; }
    assert.deepEqual(collect(mesh._computeIntersections), collect(original)); handle.dispose();
  }
});
