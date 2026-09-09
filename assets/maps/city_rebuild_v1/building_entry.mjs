// Physical, same-scene entrance for one audited exterior. No gameplay IDs,
// ownership, saved interiors or GLB bytes are changed by this preview adapter.
import {createAdditionalBuildingEntry} from './building_entry_profiles.mjs';
import {createBuildingContentRoot} from './building_room_profiles.mjs';
import {createTriangleFloorSampler} from './building_floor_surface.mjs';
import {applyBuildingSizeTransform} from './building_size_policy.mjs';
export const BUILDING_ENTRY_PROFILE = Object.freeze({
  assetId: 'strip_club',
  sha256: 'a29f4603767b74b71baae3d42c4cbd44e7831b90634bc1bfa7dbfe23e3f4272c',
  doorX: 0, doorZ: 4.93, floorY: 0.44, openingHalfWidth: 1.45,
  room: Object.freeze({minX: -5.8, maxX: 5.8, minZ: -4.3, maxZ: 4.3}),
});
const liveEntries = new WeakMap();
const clamp = (n, a, b) => Math.max(a, Math.min(b, n));

// Keep the desired camera offset separate in the caller; this only resolves a
// rendered position and never changes orbit direction or stored camera distance.
export function resolveBuildingCameraPosition({THREE, from, desired, objects, padding = .28, ceilingY = Infinity}) {
  // A pitched outdoor boom hits a low ceiling long before the rear wall.
  // Lower its endpoint first, keeping the requested horizontal follow distance.
  // The caller supplies a room ceiling only in ordinary indoor follow mode.
  const endpoint = desired.clone();
  if (Number.isFinite(ceilingY) && endpoint.y > from.y) {
    endpoint.y = Math.min(endpoint.y, Math.max(from.y, ceilingY - padding - .16));
  }
  if (endpoint.y !== desired.y) {
    const original = resolveBuildingCameraPosition({THREE, from, desired, objects, padding});
    const lowered = resolveBuildingCameraPosition({THREE, from, desired: endpoint, objects, padding});
    return lowered.distanceToSquared(from) > original.distanceToSquared(from) ? lowered : original;
  }
  const delta = endpoint.clone().sub(from), distance = delta.length();
  if (distance < .01 || !objects.length) return endpoint;
  const direction = delta.divideScalar(distance);
  const right = new THREE.Vector3(-direction.z, 0, direction.x).normalize();
  const cameraUp = new THREE.Vector3().crossVectors(right, direction).normalize();
  // Test the exact same centre/right/left/up/down rays. Reusing their
  // Raycaster removes five temporary origins, five offset vectors and four
  // cloned basis vectors from every indoor camera solve.
  const ray = new THREE.Raycaster(undefined, undefined, .015, distance + padding);
  let allowed = distance;
  for (let index = 0; index < 5; index++) {
    ray.ray.origin.copy(from);
    if (index === 1) ray.ray.origin.addScaledVector(right, .16);
    else if (index === 2) ray.ray.origin.addScaledVector(right, -.16);
    else if (index === 3) ray.ray.origin.addScaledVector(cameraUp, .16);
    else if (index === 4) ray.ray.origin.addScaledVector(cameraUp, -.16);
    ray.ray.direction.copy(direction);
    const hit = ray.intersectObjects(objects, true).find(h => {
      for (let node = h.object; node; node = node.parent) if (!node.visible) return false;
      return true;
    });
    if (hit) allowed = Math.min(allowed, Math.max(.08, hit.distance - padding));
  }
  return from.clone().addScaledVector(direction, allowed);
}

/** Subtract an axis-aligned volume from a mesh's triangles, in reference space.
 * Attributes/UVs/material groups are interpolated and retained. Returns a new
 * geometry; neither the shared source geometry nor any source material changes.
 */
export function subtractBoxFromGeometry(THREE, source, toReference, box, keepInside = false) {
  const attributes = Object.entries(source.attributes);
  const positions = source.getAttribute('position');
  if (!positions || attributes.some(([, a]) => a.isInterleavedBufferAttribute || a.normalized)) {
    throw Error('Entrance clipping requires ordinary unnormalized vertex attributes');
  }
  const planes = [[0, box.min.x, 1], [0, box.max.x, -1],
    [1, box.min.y, 1], [1, box.max.y, -1], [2, box.min.z, 1], [2, box.max.z, -1]];
  const output = Object.fromEntries(attributes.map(([name]) => [name, []]));
  const groups = [], vertexCount = source.index?.count ?? positions.count;
  let emitted = 0;
  // Indexed triangles share immutable input vertices. Decode each once per cut.
  const vertexCache = source.index ? [] : null;
  const vertex = index => {
    if (vertexCache?.[index]) return vertexCache[index];
    const values = {};
    for (const [name, attribute] of attributes) {
      const row = new Array(attribute.itemSize), offset = index * attribute.itemSize;
      for (let k = 0; k < row.length; k++) row[k] = attribute.array[offset + k];
      values[name] = row;
    }
    const record = {values, reference: new THREE.Vector3().fromArray(values.position).applyMatrix4(toReference).toArray()};
    if (vertexCache) vertexCache[index] = record;
    return record;
  };
  const mix = (a, b, t) => ({
    values: Object.fromEntries(attributes.map(([name]) => [name, a.values[name].map((v, k) => v + (b.values[name][k] - v) * t)])),
    reference: a.reference.map((v, k) => v + (b.reference[k] - v) * t),
  });
  function split(polygon, [axis, boundary, sign]) {
    const inside = [], outside = [];
    for (let i = 0; i < polygon.length; i++) {
      const a = polygon[i], b = polygon[(i + 1) % polygon.length];
      const da = (a.reference[axis] - boundary) * sign, db = (b.reference[axis] - boundary) * sign;
      (da >= 0 ? inside : outside).push(a);
      if ((da >= 0) !== (db >= 0)) {
        const crossing = mix(a, b, da / (da - db));
        inside.push(crossing); outside.push(crossing);
      }
    }
    return [inside, outside];
  }
  function emit(polygon, materialIndex) {
    const start = emitted;
    for (let i = 1; i < polygon.length - 1; i++) {
      for (const v of [polygon[0], polygon[i], polygon[i + 1]]) {
        for (const [name] of attributes) output[name].push(...v.values[name]);
        emitted++;
      }
    }
    if (emitted > start) {
      const previous = groups.at(-1);
      if (previous?.materialIndex === materialIndex && previous.start + previous.count === start) previous.count += emitted - start;
      else groups.push({start, count: emitted - start, materialIndex});
    }
  }
  // Resolve materials from SOURCE ranges, never the output groups being
  // assembled below. Use the cursor only for ordered, disjoint input groups;
  // unusual authored ranges retain the original first-match behavior.
  const sourceGroups = source.groups;
  const orderedGroups = sourceGroups.every((group, i) => i === 0 ||
    group.start >= sourceGroups[i - 1].start + sourceGroups[i - 1].count);
  let materialGroup = 0;
  const materialAt = offset => {
    if (!orderedGroups) return sourceGroups.find(group => offset >= group.start && offset < group.start + group.count)?.materialIndex ?? 0;
    while (materialGroup + 1 < sourceGroups.length && offset >= sourceGroups[materialGroup].start + sourceGroups[materialGroup].count) materialGroup++;
    const group = sourceGroups[materialGroup];
    return group && offset >= group.start && offset < group.start + group.count ? group.materialIndex : 0;
  };
  for (let i = 0; i < vertexCount; i += 3) {
    let polygon = [0, 1, 2].map(k => vertex(source.index ? source.index.getX(i + k) : i + k));
    const materialIndex = materialAt(i);
    for (const plane of planes) {
      if (polygon.length < 3) break;
      const [inside, outside] = split(polygon, plane);
      if (!keepInside) emit(outside, materialIndex); polygon = inside;
    }
    if (keepInside && polygon.length >= 3) emit(polygon, materialIndex);
  }
  const geometry = new THREE.BufferGeometry();
  for (const [name, attribute] of attributes) geometry.setAttribute(name, new THREE.Float32BufferAttribute(output[name], attribute.itemSize));
  for (const group of groups) geometry.addGroup(group.start, group.count, group.materialIndex);
  geometry.computeBoundingBox(); geometry.computeBoundingSphere();
  return geometry;
}

export function createBuildingEntry({THREE, visual, instance, metresPerCell = 4.1, sizeApplied = false}) {
  if (!sizeApplied) applyBuildingSizeTransform(visual,instance,THREE);
  if (liveEntries.has(visual)) return liveEntries.get(visual);
  const profile = BUILDING_ENTRY_PROFILE;
  if (instance?.assetId !== profile.assetId) return createAdditionalBuildingEntry({THREE,visual,instance,metresPerCell});
  if (instance.binding?.sha256 !== profile.sha256 || instance.binding?.lod !== 0) return null;
  if (!visual?.traverse || !Number.isFinite(metresPerCell) || metresPerCell <= 0) throw Error('Invalid entry instance');
  // GLTFLoader removes dots from exported names (Entrance_Door.001 -> ...001).
  const lookup = name => {
    const normalized = name.replace(/\./g, '');
    let found = null;
    visual.traverse(n => { if (n.name.replace(/\./g, '') === normalized) found = n; });
    if (!found) throw Error(`Audited entrance node missing: ${name}`);
    return found;
  };
  const shell = lookup('Club_First_Floor'), recess = lookup('Entrance_Deep_Recess');
  const cornice = lookup('Facade_Cornice.001'), rope = lookup('Queue_Burgundy_Rope');
  const leafSets = ['.001', ''].map(suffix => [lookup('Entrance_Door' + suffix), lookup('Entrance_Door_Glass' + suffix), lookup('Entrance_Door_Pushbar' + suffix)]);
  const platform = lookup('Club_Platform');
  visual.updateWorldMatrix(true, true);
  const inverse = new THREE.Matrix4().copy(visual.matrixWorld).invert();
  const originals = [], hidden = [], reparented = [], ownedGeometry = [], ownedMaterials = [];
  const generated = new THREE.Group(); generated.name = 'Runtime_SameScene_Club_Entry'; visual.add(generated);
  const localMatrix = node => new THREE.Matrix4().multiplyMatrices(inverse, node.matrixWorld);
  const bounds = node => new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position).applyMatrix4(localMatrix(node));
  const shellBounds = bounds(shell), platformBounds = bounds(platform);
  const platformFloor=createTriangleFloorSampler(THREE,platform,localMatrix(platform));
  if (Math.abs(shellBounds.min.x + 6) > .02 || Math.abs(shellBounds.max.z - 4.5) > .02 || Math.abs(platformBounds.max.y - .44) > .02) {
    generated.removeFromParent(); throw Error('Audited entrance dimensions changed');
  }
  function cut(node, box) {
    originals.push([node, node.geometry]);
    node.geometry = subtractBoxFromGeometry(THREE, node.geometry, localMatrix(node), box);
    ownedGeometry.push(node.geometry);
  }
  const aperture = new THREE.Box3(new THREE.Vector3(-1.45, -.1, 4.15), new THREE.Vector3(1.45, 3.35, 5.5));
  cut(shell, aperture); cut(cornice, aperture);
  hidden.push([recess, recess.visible]); recess.visible = false;
  const wallMaterial = new THREE.MeshStandardMaterial({color: '#b8aaa0', roughness: .88, side: THREE.DoubleSide});
  const floorMaterial = new THREE.MeshStandardMaterial({color: '#4c3331', roughness: .8});
  const brass = new THREE.MeshStandardMaterial({color: '#b18348', metalness: .56, roughness: .34});
  const warm = new THREE.MeshStandardMaterial({color: '#ffe1a6', emissive: '#ffb755', emissiveIntensity: .65, roughness: .5});
  ownedMaterials.push(wallMaterial, floorMaterial, brass, warm);
  function box(name, x, y, z, w, h, d, material) {
    const geometry = new THREE.BoxGeometry(w, h, d); ownedGeometry.push(geometry);
    const mesh = new THREE.Mesh(geometry, material); mesh.name = name; mesh.position.set(x, y, z);
    mesh.receiveShadow = true; mesh.castShadow = true; generated.add(mesh); return mesh;
  }
  // A real empty room remains within the unchanged exterior footprint.
  box('Interior_Floor', 0, .445, 0, 11.6, .01, 8.6, floorMaterial);
  box('Interior_Left_Wall', -5.86, 2.34, 0, .12, 3.8, 8.7, wallMaterial);
  box('Interior_Right_Wall', 5.86, 2.34, 0, .12, 3.8, 8.7, wallMaterial);
  box('Interior_Rear_Wall', 0, 2.34, -4.36, 11.6, 3.8, .12, wallMaterial);
  box('Interior_Front_Left', -3.635, 2.34, 4.36, 4.33, 3.8, .12, wallMaterial);
  box('Interior_Front_Right', 3.635, 2.34, 4.36, 4.33, 3.8, .12, wallMaterial);
  box('Interior_Entry_Header', 0, 3.8, 4.36, 2.94, .9, .12, wallMaterial);
  box('Interior_Ceiling', 0, 4.23, 0, 11.6, .08, 8.6, wallMaterial);
  const contentRoot=createBuildingContentRoot(THREE,generated,instance,new THREE.Vector3(0,.45,0));
  for (const x of [-3, 3]) {
    box('Interior_Pendant_Mount', x, 4.12, 0, .4, .1, .4, brass);
    box('Interior_Pendant_Light', x, 4.04, 0, .3, .08, .3, warm);
    const light = new THREE.PointLight('#ffd29a', 9, 10, 2); light.position.set(x, 3.9, 0); generated.add(light);
  }
  // Visible, continuous ramp: sidewalk y=0 -> original platform y=.44.
  const rampGeometry = new THREE.BufferGeometry();
  rampGeometry.setAttribute('position', new THREE.Float32BufferAttribute([
    -1.45, .44, 5.1, 1.45, 0, 7.4, 1.45, .44, 5.1,
    -1.45, .44, 5.1, -1.45, 0, 7.4, 1.45, 0, 7.4,
  ], 3)); rampGeometry.computeVertexNormals(); ownedGeometry.push(rampGeometry);
  const ramp = new THREE.Mesh(rampGeometry, platform.material); ramp.name = 'Entrance_Access_Ramp'; ramp.receiveShadow = true; generated.add(ramp);
  // Split the queue rope into two side runs. Preserve the authored posts.
  const ropeState = {parent: rope.parent, position: rope.position.clone(), quaternion: rope.quaternion.clone(), scale: rope.scale.clone()};
  reparented.push([rope, ropeState]);
  const otherRope = rope.clone(); otherRope.name = 'Queue_Rope_Right_Clear_Entry'; generated.add(otherRope);
  rope.scale.x *= .23; rope.position.x -= 2.36;
  otherRope.scale.x *= .23; otherRope.position.x += 2.36;
  for (const [suffix, offset] of [['.001', 1.46], ['', -1.46]]) {
    for (const base of ['Queue_Stanchion', 'Queue_Stanchion_Base']) {
      const post = lookup(base + suffix).clone(); post.name += '_Inner'; post.position.x += offset; generated.add(post);
    }
  }
  const hinges = leafSets.map((leaves, index) => {
    const hinge = new THREE.Group(); hinge.name = `Entry_Hinge_${index === 0 ? 'Left' : 'Right'}`;
    hinge.position.set(index === 0 ? -1.33 : 1.33, .44, 4.93); generated.add(hinge);
    hinge.updateWorldMatrix(true, false);
    for (const node of leaves) {
      reparented.push([node, {parent: node.parent, position: node.position.clone(), quaternion: node.quaternion.clone(), scale: node.scale.clone()}]);
      hinge.attach(node);
    }
    return hinge;
  });
  visual.updateWorldMatrix(true, true);
  const staticRects = [
    [-6, -4.5, -5.8, 4.5, .44, 4.3], [5.8, -4.5, 6, 4.5, .44, 4.3], [-6, -4.5, 6, -4.3, .44, 4.3],
    [-6, 4.3, -1.45, 4.5, .44, 4.3], [1.45, 4.3, 6, 4.5, .44, 4.3], [-1.45, 4.3, 1.45, 4.5, 3.35, 4.3],
  ];
  const excluded = new Set([shell, platform, cornice, recess, rope, ...leafSets.flat()]);
  // Preserve real low façade/yard obstacles; omit overhead canopy and floor.
  visual.traverse(node => {
    if (!node.isMesh || excluded.has(node) || !node.visible) return;
    for (let p = node.parent; p && p !== visual; p = p.parent) if (p === generated || !p.visible) return;
    const b = bounds(node);
    if (b.max.y <= .5 || b.min.y >= 2.4) return;
    staticRects.push([b.min.x, b.min.z, b.max.x, b.max.z, b.min.y, b.max.y]);
  });
  // Add only side rope spans and their inner posts, leaving the 2.9m entry open.
  staticRects.push([-3.13, 6.56, -1.6, 7.03, .84, 1.31], [1.6, 6.56, 3.13, 7.03, .84, 1.31]);
  let fraction = 0, target = 0, disposed = false;
  const report = {assetId: instance.assetId, instanceId: instance.id, status: 'physical-entry-needs-live-review',
    room: {...profile.room,width:11.6,usableDepth:8.6,area:99.76,height:3.74},contentRootId:contentRoot.name, floorY: visual.localToWorld(new THREE.Vector3(0,.45,0)).y, clippedNodes: [shell.name, cornice.name], hiddenNodes: [recess.name],
    sameScene: true, gameplayActive: false, openFraction: 0};
  // This older adapter has the same exact local-space floor tests as the
  // profile entries. Its world AABB is only a conservative broadphase hint.
  const sampleBounds = new THREE.Box3().setFromObject(visual);
  const local = point => new THREE.Vector3(point.x, point.y ?? 0, point.z).applyMatrix4(inverse);
  const sweepOccupied = point => { if (!point) return false; const p = local(point); return Math.abs(p.x) < 1.85 && p.z > 3.25 && p.z < 5.65; };
  function worldBody(rect) {
    const [minX, minZ, maxX, maxZ, minY, maxY] = rect;
    const points = [[minX, minZ], [maxX, minZ], [maxX, maxZ], [minX, maxZ]].map(([x, z]) => visual.localToWorld(new THREE.Vector3(x, 0, z)));
    return {polygonCR: points.map(p => [p.x / metresPerCell, p.z / metresPerCell]),
      minYM: visual.localToWorld(new THREE.Vector3(0, minY, 0)).y,
      maxYM: visual.localToWorld(new THREE.Vector3(0, maxY, 0)).y, buildingEntryId: instance.id};
  }
  // Placement is immutable for this entry generation. Rebuild only the leaf
  // bodies when a hinge moves; callers treat the returned array as read-only.
  const staticBodies = staticRects.map(worldBody);
  let collisionBodies = null;
  const api = {
    report, object: generated, visual, instance,contentRoot,sampleBounds,
    get needsUpdate() { return fraction !== target; },
    proximity(point, distance = 2.45) {
      const p = local(point), d = Math.hypot(p.x, p.z - profile.doorZ);
      return Math.abs(p.x) <= 1.85 && Math.abs(p.y - .45) < 2 && d <= distance ? {
        distance: d, opening: target === 1, fraction, instanceId: instance.id,
        anchor: visual.localToWorld(new THREE.Vector3(0, 2, profile.doorZ)),
        action: target === 1 ? 'Закрыть дверь' : 'Открыть дверь',
      } : null;
    },
    interact(point) {
      if (!api.proximity(point)) return {accepted: false, reason: 'out-of-range'};
      if (target === 1 && sweepOccupied(point)) return {accepted: false, reason: 'door-sweep-occupied'};
      target = target ? 0 : 1;
      return {accepted: true, opening: target === 1};
    },
    update(dt, point) {
      if (disposed) return;
      if (!Number.isFinite(dt) || dt < 0) throw Error('Invalid entrance timestep');
      if (target === 0 && fraction > 0 && sweepOccupied(point)) target = 1;
      const change = clamp(dt, 0, .1) / .65;
      const previous = fraction;
      fraction += clamp(target - fraction, -change, change);
      if (previous === fraction) return;
      collisionBodies = null;
      const eased = fraction * fraction * (3 - 2 * fraction);
      hinges.forEach((hinge, i) => { hinge.rotation.y = (i === 0 ? 1 : -1) * eased * Math.PI / 2; });
      generated.updateWorldMatrix(true, true); report.openFraction = fraction;
    },
    getCollisionBodies() {
      if (collisionBodies) return collisionBodies;
      const bodies = staticBodies.slice();
      // The real animated leaf rectangle, not an on/off invisible barrier.
      for (const hinge of hinges) {
        const leaf = hinge.children[0], b = leaf.geometry.boundingBox ?? (leaf.geometry.computeBoundingBox(), leaf.geometry.boundingBox);
        const points = [[b.min.x, b.min.z], [b.max.x, b.min.z], [b.max.x, b.max.z], [b.min.x, b.max.z]].map(([x, z]) => leaf.localToWorld(new THREE.Vector3(x, b.min.y, z)));
        const top = leaf.localToWorld(new THREE.Vector3(0, b.max.y, 0)).y;
        bodies.push({polygonCR: points.map(p => [p.x / metresPerCell, p.z / metresPerCell]), minYM: points[0].y, maxYM: top, buildingEntryId: instance.id, movingDoor: true});
      }
      collisionBodies = bodies;
      return collisionBodies;
    },
    containsInterior(point) {
      const p = local(point), r = profile.room;
      return p.x > r.minX && p.x < r.maxX && p.z > r.minZ && p.z < r.maxZ;
    },
    floorHeight(x, z) {
      const p = local({x, z});
      if (Math.abs(p.x) <= 1.450001 && p.z >= 5.1-1e-6 && p.z <= 7.4+1e-6) return visual.localToWorld(new THREE.Vector3(p.x, .44 * clamp((7.4 - p.z) / 2.3,0,1), p.z)).y;
      if(p.x>=profile.room.minX&&p.x<=profile.room.maxX&&p.z>=profile.room.minZ&&p.z<=profile.room.maxZ)return visual.localToWorld(new THREE.Vector3(p.x,.45,p.z)).y;
      const support=platformFloor(p.x,p.z);if(support!==null)return visual.localToWorld(new THREE.Vector3(p.x,support,p.z)).y;
      return null;
    },
    approachPoint() { return visual.localToWorld(new THREE.Vector3(0,0,7.25)); },
    roomPoint() { return visual.localToWorld(new THREE.Vector3(0,.45,0)); },
    roomCenterPoint() { return contentRoot.getWorldPosition(new THREE.Vector3()); },
    ceilingHeight(point) { return api.containsInterior(point) ? visual.localToWorld(new THREE.Vector3(0,4.19,0)).y : null; },
    dispose() {
      if (disposed) return; disposed = true;
      for (const [node, state] of reparented) {
        state.parent.add(node); node.position.copy(state.position); node.quaternion.copy(state.quaternion); node.scale.copy(state.scale);
      }
      for (const [node, geometry] of originals) node.geometry = geometry;
      for (const [node, visible] of hidden) node.visible = visible;
      generated.removeFromParent();
      for (const geometry of ownedGeometry) geometry.dispose();
      for (const material of ownedMaterials) material.dispose();
      liveEntries.delete(visual);
    },
  };
  liveEntries.set(visual, api); return api;
}
