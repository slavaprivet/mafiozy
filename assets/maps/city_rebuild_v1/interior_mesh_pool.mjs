// A single-chamfer cube: six flat faces (12 triangles), twelve edge strips
// (24) and eight corner patches (8). At every bevel endpoint the normal is
// the exact adjacent face normal: interpolation rounds only the narrow edge.
export function createInteriorBevelBoxGeometry(T, bevel = .055) {
  if (!Number.isFinite(bevel) || bevel <= 0 || bevel >= .25) throw new RangeError('Interior bevel must be between 0 and .25');
  const core = .5 - bevel, positions = [], normals = [], uvs = [], indices = [];
  const pushPolygon = (points, outward) => {
    const a = points[0], b = points[1], c = points[2];
    const ab = b.map((n, i) => n - a[i]), ac = c.map((n, i) => n - a[i]);
    const cross = [ab[1] * ac[2] - ab[2] * ac[1], ab[2] * ac[0] - ab[0] * ac[2], ab[0] * ac[1] - ab[1] * ac[0]];
    if (cross.reduce((sum, n, i) => sum + n * outward[i], 0) < 0) points.reverse();
    const first = positions.length / 3, dominant = outward.map(Math.abs).indexOf(Math.max(...outward.map(Math.abs))), uvAxes = [0, 1, 2].filter(axis => axis !== dominant);
    for (const point of points) {
      positions.push(...point);
      const normal = point.map(n => n - Math.max(-core, Math.min(core, n))), length = Math.hypot(...normal);
      normals.push(...normal.map(n => n / length)); uvs.push(point[uvAxes[0]] + .5, point[uvAxes[1]] + .5);
    }
    for (let i = 1; i < points.length - 1; i++) indices.push(first, first + i, first + i + 1);
  };
  for (let axis = 0; axis < 3; axis++) {
    const [u, v] = [0, 1, 2].filter(i => i !== axis);
    for (const sign of [-1, 1]) {
      const points = [[-core, -core], [core, -core], [core, core], [-core, core]].map(([x, y]) => { const p = [0, 0, 0]; p[axis] = sign * .5; p[u] = x; p[v] = y; return p; });
      const normal = [0, 0, 0]; normal[axis] = sign; pushPolygon(points, normal);
    }
  }
  for (let along = 0; along < 3; along++) {
    const [u, v] = [0, 1, 2].filter(i => i !== along);
    for (const su of [-1, 1]) for (const sv of [-1, 1]) {
      const point = (length, upper) => { const p = [0, 0, 0]; p[along] = length; p[u] = su * (upper ? core : .5); p[v] = sv * (upper ? .5 : core); return p; };
      const normal = [0, 0, 0]; normal[u] = su; normal[v] = sv;
      pushPolygon([point(-core, false), point(core, false), point(core, true), point(-core, true)], normal);
    }
  }
  for (const x of [-1, 1]) for (const y of [-1, 1]) for (const z of [-1, 1]) pushPolygon([[x * .5, y * core, z * core], [x * core, y * .5, z * core], [x * core, y * core, z * .5]], [x, y, z]);
  const geometry = new T.BufferGeometry(); geometry.setAttribute('position', new T.Float32BufferAttribute(positions, 3)); geometry.setAttribute('normal', new T.Float32BufferAttribute(normals, 3)); geometry.setAttribute('uv', new T.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices); geometry.computeBoundingBox(); geometry.computeBoundingSphere(); geometry.name = 'Interior_Bevel_Box_44'; geometry.userData.interiorBevel = bevel;
  return geometry;
}

const resources = new WeakMap();
function acquire(T) {
  let entry = resources.get(T);
  if (!entry) {
    entry = { references: 0, geometry: { box: createInteriorBevelBoxGeometry(T), cylinder: new T.CylinderGeometry(.5, .5, 1, 12), sphere: new T.SphereGeometry(.5, 12, 8) }, materials: [new T.MeshStandardMaterial({ roughness: .76 }), new T.MeshStandardMaterial({ roughness: .32, metalness: .65 })] };
    resources.set(T, entry);
  }
  entry.references++; return entry;
}
function release(T, entry) {
  if (--entry.references) return;
  for (const geometry of Object.values(entry.geometry)) geometry.dispose();
  for (const material of entry.materials) material.dispose(); resources.delete(T);
}
export function interiorMeshPoolResourceStats(T) {
  const entry = resources.get(T); return { references: entry?.references || 0, geometries: entry ? 3 : 0, materials: entry ? 2 : 0 };
}

// Colour is per instance. Each building draws at most three shape types times
// two material classes, sharing all five GPU resources with the other rooms.
export function createInteriorMeshPool(T, root) {
  const shared = acquire(T), { geometry, materials } = shared;
  const buckets = new Map(), meshes = [], matrix = new T.Matrix4(), position = new T.Vector3(), scale = new T.Vector3(), rotation = new T.Quaternion(), axis = new T.Vector3(0, 1, 0), color = new T.Color();
  let statistics = null, disposed = false;
  function add(part, transform) {
    if (disposed) throw new Error('Cannot add to a disposed interior mesh pool');
    if (statistics) throw new Error('Cannot add after the interior mesh pool was flushed');
    if (!part?.position?.every(Number.isFinite) || part.position.length !== 3 || !part?.size?.every(n => Number.isFinite(n) && n > 0) || part.size.length !== 3 || !Number.isFinite(part.yaw ?? 0)) throw new TypeError('Interior part needs finite position, positive size and finite yaw');
    const shape = part.shape === 'cylinder' || part.shape === 'sphere' ? part.shape : 'box', metal = (part.metalness ?? 0) > .3 ? 1 : 0, key = shape + metal;
    if (!buckets.has(key)) buckets.set(key, { matrices: new Float32Array(32 * 16), colors: new Float32Array(32 * 3), count: 0, capacity: 32 });
    const bucket = buckets.get(key);
    if (bucket.count === bucket.capacity) { bucket.capacity *= 2; const matrices = new Float32Array(bucket.capacity * 16), colors = new Float32Array(bucket.capacity * 3); matrices.set(bucket.matrices); colors.set(bucket.colors); bucket.matrices = matrices; bucket.colors = colors; }
    position.fromArray(part.position); scale.fromArray(part.size); rotation.setFromAxisAngle(axis, part.yaw ?? 0); matrix.compose(position, rotation, scale); if (transform) matrix.premultiply(transform);
    matrix.toArray(bucket.matrices, bucket.count * 16); color.set(part.color ?? '#9d8973'); const offset = bucket.count * 3; bucket.colors[offset] = color.r; bucket.colors[offset + 1] = color.g; bucket.colors[offset + 2] = color.b; bucket.count++;
  }
  function flush() {
    if (disposed) throw new Error('Cannot flush a disposed interior mesh pool');
    if (statistics) return statistics;
    let parts = 0, triangles = 0;
    for (const [key, bucket] of buckets) {
      const shape = key.slice(0, -1), metal = Number(key.slice(-1)), mesh = new T.InstancedMesh(geometry[shape], materials[metal], bucket.count);
      mesh.name = 'Interior_Furnishings_' + key; mesh.instanceMatrix.array.set(bucket.matrices.subarray(0, bucket.count * 16)); mesh.instanceMatrix.needsUpdate = true; mesh.instanceColor = new T.InstancedBufferAttribute(bucket.colors.slice(0, bucket.count * 3), 3);
      mesh.castShadow = mesh.receiveShadow = true; mesh.computeBoundingBox(); mesh.computeBoundingSphere(); mesh.userData.worldBlastStaticBounds = true; root.add(mesh); meshes.push(mesh);
      parts += bucket.count; triangles += (geometry[shape].index?.count || geometry[shape].attributes.position.count) / 3 * bucket.count;
    }
    // Instance buffers now own these transforms/colours. Do not keep cloned
    // Matrix4s or JS arrays duplicating the entire furnished city's CPU memory.
    buckets.clear(); statistics = Object.freeze({ parts, draws: meshes.length, triangles }); return statistics;
  }
  function dispose() {
    if (disposed) return;
    disposed = true; for (const mesh of meshes) { mesh.removeFromParent(); mesh.dispose?.(); }
    meshes.length = 0; buckets.clear(); release(T, shared);
  }
  return { add, flush, dispose };
}
