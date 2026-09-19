import assert from 'node:assert/strict';
import { test } from 'node:test';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { createInteriorBevelBoxGeometry, createInteriorMeshPool, interiorMeshPoolResourceStats } from './interior_mesh_pool.mjs';
import { createInteriorMeshPool as createBaselinePool } from './interior_qa_baseline/interior_mesh_pool.mjs';

const vendor = process.env.MAFIOZY_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
const T = await import(pathToFileURL(vendor + 'build/three.module.js'));
const near = (a, b, tolerance = 1e-6) => assert.ok(Math.abs(a - b) <= tolerance, `${a} differs from ${b}`);
const triangleCount = geometry => (geometry.index?.count || geometry.attributes.position.count) / 3;

test('44 triangle bevel has closed manifold, outward faces, unit smooth bevel normals and flat main faces', () => {
  const geometry = createInteriorBevelBoxGeometry(T), p = geometry.attributes.position, n = geometry.attributes.normal, uv = geometry.attributes.uv;
  assert.equal(triangleCount(geometry), 44);
  for (const axis of ['x', 'y', 'z']) { near(geometry.boundingBox.min[axis], -.5); near(geometry.boundingBox.max[axis], .5); }
  const vertices = Array.from({ length: p.count }, (_, i) => new T.Vector3().fromBufferAttribute(p, i));
  const vertexNormals = Array.from({ length: n.count }, (_, i) => new T.Vector3().fromBufferAttribute(n, i));
  const weldedNormals = new Map(), edges = new Map(), faceTypes = [0, 0, 0, 0];
  const key = v => v.toArray().map(value => value.toFixed(6)).join(',');
  for (let i = 0; i < p.count; i++) {
    assert.ok(vertices[i].toArray().every(Number.isFinite)); near(vertexNormals[i].length(), 1);
    assert.ok(vertexNormals[i].dot(vertices[i]) > 0);
    assert.ok(uv.getX(i) >= 0 && uv.getX(i) <= 1 && uv.getY(i) >= 0 && uv.getY(i) <= 1);
    const welded = weldedNormals.get(key(vertices[i])); if (welded) near(welded.distanceTo(vertexNormals[i]), 0); else weldedNormals.set(key(vertices[i]), vertexNormals[i]);
  }
  for (let i = 0; i < geometry.index.count; i += 3) {
    const ids = [0, 1, 2].map(j => geometry.index.getX(i + j)), [a, b, c] = ids.map(j => vertices[j]);
    const cross = b.clone().sub(a).cross(c.clone().sub(a)), centroid = a.clone().add(b).add(c).multiplyScalar(1 / 3);
    assert.ok(cross.length() > 1e-6, 'No zero-area triangles'); assert.ok(cross.dot(centroid) > 0, 'All winding faces outward');
    const normal = cross.normalize(), axes = normal.toArray().filter(value => Math.abs(value) > 1e-5).length; faceTypes[axes]++;
    if (axes === 1) for (const id of ids) near(vertexNormals[id].distanceTo(normal), 0);
    else { assert.ok(ids.some(id => vertexNormals[id].distanceTo(normal) > .1), 'Bevel uses smooth endpoint normals, not a hard 45-degree face'); for (const id of ids) assert.ok(vertexNormals[id].dot(normal) >= .57); }
    for (let e = 0; e < 3; e++) { const pair = [key(vertices[ids[e]]), key(vertices[ids[(e + 1) % 3]])].sort().join('|'); edges.set(pair, (edges.get(pair) || 0) + 1); }
  }
  assert.deepEqual(faceTypes, [0, 12, 24, 8]);
  for (const count of edges.values()) assert.equal(count, 2, 'Every welded edge belongs to exactly two triangles');
  const mesh = new T.Mesh(geometry, new T.MeshBasicMaterial()); mesh.updateMatrixWorld(true);
  for (const axis of ['x', 'y', 'z']) for (const sign of [-1, 1]) {
    const origin = new T.Vector3(), direction = new T.Vector3(); origin[axis] = sign * 2; direction[axis] = -sign;
    const hit = new T.Raycaster(origin, direction, 0, 4).intersectObject(mesh)[0]; assert.ok(hit); near(hit.point[axis], sign * .5);
  }
  mesh.material.dispose(); geometry.dispose();
  for (const bevel of [0, -.1, .25, NaN]) assert.throws(() => createInteriorBevelBoxGeometry(T, bevel));
});

test('shared geometry and materials preserve transformed instance colours and six material/shape buckets', () => {
  const roots = [new T.Group(), new T.Group()], pools = roots.map(root => createInteriorMeshPool(T, root));
  const transform = new T.Matrix4().makeRotationY(.7).setPosition(7, 3, -4), expected = [];
  for (const shape of ['box', 'cylinder', 'sphere']) for (const metalness of [0, .7]) for (let i = 0; i < 2; i++) {
    const part = { shape, metalness, position: [i * 3, .8, -.3], size: [1.7, .9, .6], yaw: -.35, color: i ? '#73545c' : 0xb19c6f };
    pools[0].add(part, transform); pools[1].add(part, transform); expected.push(part);
  }
  const reports = pools.map(pool => pool.flush());
  for (const report of reports) { assert.equal(report.parts, 12); assert.equal(report.draws, 6); assert.ok(report.triangles > 0); }
  assert.deepEqual(interiorMeshPoolResourceStats(T), { references: 2, geometries: 3, materials: 2 });
  for (const mesh of roots[0].children) {
    const other = roots[1].getObjectByName(mesh.name); assert.equal(mesh.geometry, other.geometry); assert.equal(mesh.material, other.material);
    assert.ok(/^Interior_Furnishings_(box|sphere|cylinder)[01]$/.test(mesh.name));
    assert.equal(mesh.castShadow, true); assert.equal(mesh.receiveShadow, true); assert.equal(mesh.instanceColor.count, 2);
    const shape = mesh.name.slice('Interior_Furnishings_'.length, -1), metal = Number(mesh.name.slice(-1));
    const parts = expected.filter(v => v.shape === shape && Number(v.metalness > .3) === metal);
    for (const [i, part] of parts.entries()) {
      const actualMatrix = new T.Matrix4(); mesh.getMatrixAt(i, actualMatrix);
      const expectedMatrix = new T.Matrix4().compose(new T.Vector3(...part.position), new T.Quaternion().setFromAxisAngle(new T.Vector3(0, 1, 0), part.yaw), new T.Vector3(...part.size)).premultiply(transform);
      actualMatrix.elements.forEach((value, index) => near(value, expectedMatrix.elements[index]));
      const color = new T.Color(); mesh.getColorAt(i, color); const intendedColor = new T.Color(part.color); near(color.r, intendedColor.r); near(color.g, intendedColor.g); near(color.b, intendedColor.b);
      const instanceBounds = mesh.geometry.boundingBox.clone().applyMatrix4(actualMatrix); assert.ok(mesh.boundingBox.containsBox(instanceBounds));
    }
  }
  assert.equal(pools[0].flush(), reports[0], 'Repeated flush is idempotent'); assert.equal(roots[0].children.length, 6);
  assert.throws(() => pools[0].add(expected[0]), /flushed/);
  for (const pool of pools) pool.dispose(); assert.equal(interiorMeshPoolResourceStats(T).references, 0);
});

test('unloading one building keeps neighbours alive, last release disposes resources once and frees instance buffers', () => {
  const rootA = new T.Group(), rootB = new T.Group(), a = createInteriorMeshPool(T, rootA), b = createInteriorMeshPool(T, rootB), part = { shape: 'box', position: [0, .5, 0], size: [1, 1, 1] };
  a.add(part); b.add(part); a.flush(); b.flush();
  const oldGeometry = rootA.children[0].geometry, oldMaterial = rootA.children[0].material;
  let geometryDisposes = 0, materialDisposes = 0, instanceDisposes = 0;
  oldGeometry.addEventListener('dispose', () => geometryDisposes++); oldMaterial.addEventListener('dispose', () => materialDisposes++);
  rootA.children[0].addEventListener('dispose', () => instanceDisposes++); rootB.children[0].addEventListener('dispose', () => instanceDisposes++);
  a.dispose(); a.dispose(); assert.equal(rootA.children.length, 0); assert.equal(rootB.children.length, 1); assert.equal(geometryDisposes, 0); assert.equal(materialDisposes, 0); assert.equal(instanceDisposes, 1); assert.equal(interiorMeshPoolResourceStats(T).references, 1);
  assert.throws(() => a.add(part), /disposed/); assert.throws(() => a.flush(), /disposed/);
  b.dispose(); b.dispose(); assert.equal(geometryDisposes, 1); assert.equal(materialDisposes, 1); assert.equal(instanceDisposes, 2); assert.deepEqual(interiorMeshPoolResourceStats(T), { references: 0, geometries: 0, materials: 0 });
  const freshRoot = new T.Group(), fresh = createInteriorMeshPool(T, freshRoot); fresh.add(part); fresh.flush(); assert.notEqual(freshRoot.children[0].geometry, oldGeometry); assert.notEqual(freshRoot.children[0].material, oldMaterial); fresh.dispose();
  const empty = createInteriorMeshPool(T, new T.Group()); assert.equal(empty.flush().parts, 0); empty.dispose(); assert.equal(interiorMeshPoolResourceStats(T).references, 0);
});

test('primitive budget drops box triangles 192 to 44 while keeping cylinder/sphere tessellation and all instances', () => {
  const beforeRoot = new T.Group(), afterRoot = new T.Group(), before = createBaselinePool(T, beforeRoot), after = createInteriorMeshPool(T, afterRoot);
  for (const shape of ['box', 'cylinder', 'sphere']) for (let i = 0; i < 15; i++) { const part = { shape, position: [i * .8, .4, 0], size: [.6, .8, .5], color: i % 2 ? '#786344' : '#a99269' }; before.add(part); after.add(part); }
  assert.equal(before.flush().parts, after.flush().parts);
  const rows = beforeRoot.children.map(mesh => { const optimized = afterRoot.getObjectByName(mesh.name); return { shape: mesh.name, before: triangleCount(mesh.geometry), after: triangleCount(optimized.geometry), instances: mesh.count }; });
  assert.equal(rows[0].before, 192); assert.equal(rows[0].after, 44);
  for (const row of rows.slice(1)) assert.equal(row.before, row.after);
  console.log(JSON.stringify({ primitiveTriangles: rows })); before.dispose(); after.dispose();
});

test('growing packed instance buffers preserves every transform and colour across capacity boundaries', () => {
  const root = new T.Group(), pool = createInteriorMeshPool(T, root), count = 135;
  for (let i = 0; i < count; i++) pool.add({ shape: 'box', position: [i * .75, .5, i % 11], size: [.7, 1, .6], color: i % 2 ? '#78654f' : '#af9583' });
  assert.equal(pool.flush().parts, count); const mesh = root.children[0], matrix = new T.Matrix4(), color = new T.Color();
  assert.equal(mesh.instanceColor.count, count);
  for (let i = 0; i < count; i++) { mesh.getMatrixAt(i, matrix); near(matrix.elements[12], i * .75); near(matrix.elements[14], i % 11); mesh.getColorAt(i, color); const intended = new T.Color(i % 2 ? '#78654f' : '#af9583'); near(color.r, intended.r); near(color.g, intended.g); near(color.b, intended.b); }
  pool.dispose(); assert.equal(interiorMeshPoolResourceStats(T).references, 0);
});

if (process.env.INTERIOR_MESH_POOL_PERF === '1') {
  const factories = { before: createBaselinePool, after: createInteriorMeshPool }, summary = {};
  const parts = Array.from({ length: 245 }, (_, i) => ({ shape: i % 13 === 0 ? 'sphere' : i % 7 === 0 ? 'cylinder' : 'box', position: [i % 14 - 7, .9, Math.floor(i / 14) - 8], size: [.45, 1.8, .7], color: i % 2 ? '#73816f' : '#d1c4aa', metalness: i % 5 === 0 ? .65 : 0 }));
  for (const [label, factory] of Object.entries(factories)) {
    const samples = [], counts = [];
    for (let repeat = 0; repeat < 15; repeat++) {
      const roots = [], pools = []; const start = performance.now();
      for (let building = 0; building < 75; building++) { const root = new T.Group(), pool = factory(T, root); roots.push(root); pools.push(pool); for (const part of parts) pool.add(part); pool.flush(); }
      const cost = performance.now() - start;
      if (repeat >= 3) samples.push(cost);
      if (repeat === 14) { const geometries = new Set(), materials = new Set(); let triangles = 0, instances = 0, draws = 0; for (const root of roots) for (const mesh of root.children) { geometries.add(mesh.geometry); materials.add(mesh.material); triangles += triangleCount(mesh.geometry) * mesh.count; instances += mesh.count; draws++; } counts.push({ geometries: geometries.size, materials: materials.size, triangles, instances, draws }); }
      for (const pool of pools) pool.dispose();
    }
    samples.sort((a, b) => a - b); summary[label] = { p50Ms: +samples[Math.floor(samples.length * .5)].toFixed(3), p95Ms: +samples[Math.floor(samples.length * .95)].toFixed(3), ...counts[0] };
  }
  console.log(JSON.stringify({ scenario: 'CPU 75 pools x identical 245 parts, 3 warmups + 12 measured runs; no GPU/FPS claim', summary }, null, 2));
}
