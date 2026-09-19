import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';

const root = new URL('../../', import.meta.url), dir = new URL('assets/maps/city_rebuild_v1/', root);
const flag = name => { const index = process.argv.indexOf(name); return index >= 0 ? process.argv[index + 1] : null; };
const placementUrl = flag('--placement') ? pathToFileURL(path.resolve(flag('--placement'))) : new URL('buildings_placement.v1.json', dir);
const baseline = process.argv.includes('--baseline'), label = flag('--label') || (baseline ? 'baseline' : 'current'), only = flag('--only'), debug = process.argv.includes('--debug'), radius = .36, height = 1.8, spacing = Number(flag('--spacing') || .24), EPS = 1e-6;
if (!/^[a-zA-Z0-9_-]+$/.test(label)) throw new Error('Use a simple alphanumeric --label');
if (!Number.isFinite(spacing) || spacing < .04 || spacing > .3) throw new Error('Audit spacing must be .04 to .3 metres');
const { createWindowedBuildingEntry } = await import(new URL((baseline ? 'interior_qa_baseline/' : '') + 'building_window_integration.mjs', dir));
const { resolveBuildingPurpose } = await import(new URL('building_interior_purpose.mjs', dir));
const vendor = process.env.MAFIOZY_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({ resolve(s, c, next) { return next(s === 'three' ? pathToFileURL(vendor + 'build/three.module.js').href : s, c); } });
const T = await import(pathToFileURL(vendor + 'build/three.module.js')), { GLTFLoader } = await import(pathToFileURL(vendor + 'addons/loaders/GLTFLoader.js'));
const placement = JSON.parse(fs.readFileSync(placementUrl)), instances = placement.instances.filter(item => !only || item.id.includes(only) || item.assetId === only), sources = new Map();
const manifests = [placementUrl, ...['building_storeys.mjs', 'building_interior_design.mjs'].map(file => new URL((baseline ? 'interior_qa_baseline/' : '') + file, dir)), ...['interior_spacious_layout.mjs', 'interior_functional_furnishing.mjs', 'interior_staircase.mjs', 'oriented_staircase.mjs'].map(file => new URL(file, dir))].map(url => ({ url: url.href, sha256: createHash('sha256').update(fs.readFileSync(url)).digest('hex') }));
const insideRect = (x, z, r, margin = 0) => x >= r[0] + margin - EPS && x <= r[2] - margin + EPS && z >= r[1] + margin - EPS && z <= r[3] - margin + EPS;
const rounded = n => Number.isFinite(n) ? +n.toFixed(4) : n;
const pointJSON = p => ({ x: rounded(p.x), y: rounded(p.y), z: rounded(p.z) });

// Exact disk/closed-polygon overlap, including the corner Voronoi regions.
// A mere expanded AABB or edge-plane SAT would incorrectly close diagonals.
function circlePolygon(x, z, poly, r = radius) {
  let inside = false, closest = Infinity;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[j], b = poly[i], dx = b[0] - a[0], dz = b[1] - a[1];
    if ((a[1] > z) !== (b[1] > z) && x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    const t = Math.max(0, Math.min(1, ((x - a[0]) * dx + (z - a[1]) * dz) / (dx * dx + dz * dz || 1)));
    closest = Math.min(closest, (x - a[0] - t * dx) ** 2 + (z - a[1] - t * dz) ** 2);
  }
  return inside || closest < (r - EPS) ** 2;
}
assert.equal(circlePolygon(1.3, 1.3, [[-1, -1], [1, -1], [1, 1], [-1, 1]]), false);
assert.equal(circlePolygon(1.2, 1.2, [[-1, -1], [1, -1], [1, 1], [-1, 1]]), true);
assert.equal(circlePolygon(0, 0, [[-1, -1], [1, -1], [1, 1], [-1, 1]]), true);

for (const item of instances) {
  if (sources.has(item.binding.url)) continue;
  const bytes = fs.readFileSync(new URL(item.binding.url.slice(1), root));
  const loader = new GLTFLoader().register(() => ({ name: 'CPU_INTERIOR_NAVIGATION_AUDIT', loadTexture: () => Promise.resolve(new T.Texture()) }));
  sources.set(item.binding.url, (await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene);
}

function openDoors(entry) {
  const approach = entry.approachPoint(), far = new T.Vector3(approach.x + 1000, approach.y + 1000, approach.z + 1000), attempts = [];
  const tick = () => { for (let i = 0; i < 15; i++) entry.update(.1, far); };
  const main = entry.proximity(approach)?.opening ? { accepted: true, opening: true } : entry.interact(approach); tick();
  for (const door of entry.interiorDesign?.doors || []) {
    if (door.fraction > .999) continue;
    let accepted = false;
    for (const distance of [1.5, 1.1, .85]) {
      if (accepted) break;
      for (const sign of [-1, 1]) {
        if (accepted) break;
        for (const tangent of [0, -.4, .4]) {
          const p = new T.Vector3(door.x + (door.axis === 'z' ? sign * distance : tangent), door.y, door.z + (door.axis === 'x' ? sign * distance : tangent));
          entry.storeys.root.localToWorld(p);
          if (entry.proximity(p)?.door !== door) continue;
          const result = entry.interact(p);
          if (result.accepted && result.opening) { tick(); accepted = true; break; }
        }
      }
    }
    attempts.push({ name: door.name, opened: door.fraction > .999, target: door.target, fraction: door.fraction });
  }
  return { mainAccepted: !!main.accepted, mainReason: main.reason || null, roomDoors: entry.interiorDesign?.doors.length || 0, opened: (entry.interiorDesign?.doors || []).filter(d => d.fraction > .999).length, failures: attempts.filter(a => !a.opened) };
}

function auditEntry(entry, item, visual, gridSpacing = spacing, canRefine = true) {
  const spacing = gridSpacing;
  const started = performance.now(), st = entry.storeys, interior = entry.interiorDesign, frame = st.root, inverse = frame.matrixWorld.clone().invert(), baseY = frame.getWorldPosition(new T.Vector3()).y;
  const toWorld = (x, y, z) => new T.Vector3(x, y, z).applyMatrix4(frame.matrixWorld);
  const approachWorld = entry.approachPoint(), approach = approachWorld.clone().applyMatrix4(inverse), doors = openDoors(entry);
  frame.updateWorldMatrix(true, true);
  const failures = [], addFailure = (kind, detail) => failures.push({ kind, ...detail });
  if (!doors.mainAccepted) addFailure('entrance-door-not-opened', { reason: doors.mainReason });
  for (const door of doors.failures) addFailure('room-door-not-opened', door);
  const rawBodies = entry.getCollisionBodies(), bodies = rawBodies.map((body, index) => {
    const polygon = body.polygonCR.map(([x, z]) => { const p = new T.Vector3(x * 4.1, baseY, z * 4.1).applyMatrix4(inverse); return [p.x, p.z]; });
    return { index, polygon, minY: body.minYM ?? -Infinity, maxY: body.maxYM ?? Infinity, bounds: [Math.min(...polygon.map(p => p[0])), Math.min(...polygon.map(p => p[1])), Math.max(...polygon.map(p => p[0])), Math.max(...polygon.map(p => p[1]))], kind: body.furnitureKind || body.storeyPart || (body.interiorDoor ? 'interior-door' : body.movingDoor ? 'entrance-door' : body.interiorSafe ? 'safe' : body.interiorFurniture ? 'legacy-furniture' : 'authored-shell'), part: body.coverKind || null };
  });
  const tile = 2, bins = new Map();
  for (const body of bodies) for (let x = Math.floor((body.bounds[0] - radius) / tile); x <= Math.floor((body.bounds[2] + radius) / tile); x++) for (let z = Math.floor((body.bounds[1] - radius) / tile); z <= Math.floor((body.bounds[3] + radius) / tile); z++) { const key = `${x}:${z}`; if (!bins.has(key)) bins.set(key, []); bins.get(key).push(body); }
  const nearBodies = (x, z) => bins.get(`${Math.floor(x / tile)}:${Math.floor(z / tile)}`) || [];
  const collisions = (x, z, y) => nearBodies(x, z).filter(body => body.maxY > y + .06 + EPS && body.minY < y + height - EPS && circlePolygon(x, z, body.polygon));
  const headOffsets = [[0, 0], [radius, 0], [-radius, 0], [0, radius], [0, -radius], ...[-1, 1].flatMap(x => [-1, 1].map(z => [x * radius / Math.SQRT2, z * radius / Math.SQRT2]))];
  function headroom(x, z, y) {
    let clearance = Infinity;
    for (const [dx, dz] of headOffsets) { const p = toWorld(x + dx, y - baseY, z + dz), ceiling = entry.ceilingHeight(p); if (Number.isFinite(ceiling)) clearance = Math.min(clearance, ceiling - y); }
    return clearance;
  }
  const describeBodies = hits => hits.slice(0, 5).map(b => ({ index: b.index, kind: b.kind, part: b.part, minY: rounded(b.minY), maxY: rounded(b.maxY), localBounds: b.bounds.map(rounded) }));
  const floors = [], graph = new Map(), components = [];
  for (const f of st.floors) {
    const r = f.rect, ground = f.level === 0, domain = r.slice();
    if (ground) { domain[0] = Math.min(domain[0], approach.x - 1.25); domain[2] = Math.max(domain[2], approach.x + 1.25); domain[1] = Math.min(domain[1], approach.z - 1.25); domain[3] = Math.max(domain[3], approach.z + 1.25); }
    const doorway = { x: Math.max(r[0], Math.min(r[2], approach.x)), z: Math.max(r[1], Math.min(r[3], approach.z)) };
    const approachCorridor = [Math.min(approach.x, doorway.x) - 1.15, Math.min(approach.z, doorway.z) - 1.15, Math.max(approach.x, doorway.x) + 1.15, Math.max(approach.z, doorway.z) + 1.15];
    const nx = Math.ceil((domain[2] - domain[0]) / spacing) + 1, nz = Math.ceil((domain[3] - domain[1]) / spacing) + 1, count = nx * nz;
    const valid = new Uint8Array(count), heights = new Float32Array(count), labels = new Int32Array(count).fill(-1), causes = { collision: 0, headroom: 0, floor: 0, domain: 0 }, componentIds = [], y = baseY + f.y;
    const coords = index => ({ x: domain[0] + index % nx * spacing, z: domain[1] + Math.floor(index / nx) * spacing });
    function sample(x, z, detail = false) {
      const inFloor = insideRect(x, z, r);
      if (!inFloor && !(ground && insideRect(x, z, approachCorridor))) return detail ? { ok: false, reason: 'domain' } : 0;
      const p = toWorld(x, f.y, z), sampled = entry.floorHeight(p.x, p.z, y), feet = Number.isFinite(sampled) ? sampled : ground && !inFloor ? 0 : NaN;
      if (!Number.isFinite(feet) || inFloor && Math.abs(feet - y) > .08) return detail ? { ok: false, reason: 'floor', expected: y, actual: sampled } : 0;
      const hits = collisions(x, z, feet);
      if (hits.length) return detail ? { ok: false, reason: 'collision', bodies: describeBodies(hits), feet: rounded(feet) } : 0;
      const clearance = headroom(x, z, feet);
      if (clearance < height - .01) return detail ? { ok: false, reason: 'headroom', clearance: rounded(clearance) } : 0;
      return detail ? { ok: true, feet, clearance } : 1;
    }
    const segmentFree = (a, b) => { const distance = Math.hypot(a.x - b.x, a.z - b.z), steps = Math.max(1, Math.ceil(distance / .08)); let previous = null; for (let i = 0; i <= steps; i++) { const t = i / steps, s = sample(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, true); if (!s.ok || previous !== null && Math.abs(s.feet - previous) > .28) return false; previous = s.feet; } return true; };
    for (let index = 0; index < count; index++) { const p = coords(index), s = sample(p.x, p.z, true); if (s.ok) { valid[index] = 1; heights[index] = s.feet; } else causes[s.reason]++; }
    const queue = new Int32Array(count);
    for (let start = 0; start < count; start++) {
      if (!valid[start] || labels[start] !== -1) continue;
      const id = components.length; components.push({ id, level: f.level, cells: 0 }); componentIds.push(id); graph.set(id, []); labels[start] = id;
      let begin = 0, end = 1; queue[0] = start;
      while (begin < end) {
        const index = queue[begin++], x = index % nx, z = Math.floor(index / nx), p = coords(index); components[id].cells++;
        for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const xx = x + dx, zz = z + dz, next = zz * nx + xx; if (xx < 0 || zz < 0 || xx >= nx || zz >= nz || !valid[next] || labels[next] !== -1 || Math.abs(heights[next] - heights[index]) > .28 || !segmentFree(p, coords(next))) continue; labels[next] = id; queue[end++] = next; }
      }
    }
    const snap = p => {
      if (!sample(p.x, p.z)) return { component: null, reason: sample(p.x, p.z, true) };
      const ix = Math.round((p.x - domain[0]) / spacing), iz = Math.round((p.z - domain[1]) / spacing), candidates = [];
      for (let dx = -2; dx <= 2; dx++) for (let dz = -2; dz <= 2; dz++) { const x = ix + dx, z = iz + dz, index = z * nx + x; if (x < 0 || z < 0 || x >= nx || z >= nz || !valid[index]) continue; const q = coords(index), distance = Math.hypot(q.x - p.x, q.z - p.z); if (distance <= .4) candidates.push({ index, q, distance }); }
      candidates.sort((a, b) => a.distance - b.distance);
      const found = candidates.find(c => segmentFree(p, c.q)); return found ? { component: labels[found.index], index: found.index, distance: rounded(found.distance) } : { component: null, reason: 'no-connected-grid-cell-within-40cm' };
    };
    floors.push({ level: f.level, y, rect: r.slice(), domain, nx, nz, valid, labels, coords, sample, snap, componentIds, causes, cells: count, freeCells: valid.reduce((a, b) => a + b, 0) });
  }
  const stairReports = [];
  for (let index = 0; index < st.stairs.length; index++) {
    const stair = st.stairs[index], bad = [], route = stair.route;
    let minClearance = Infinity, maxRise = 0, maxFloorError = 0, previous = null;
    for (let i = 0; i < route.length; i++) {
      const point = route[i], world = toWorld(point.x, point.y, point.z), sampled = entry.floorHeight(world.x, world.z, world.y), floorError = Number.isFinite(sampled) ? Math.abs(sampled - world.y) : Infinity;
      maxFloorError = Math.max(maxFloorError, floorError);
      const feet = Number.isFinite(sampled) ? sampled : world.y, clearance = headroom(point.x, point.z, feet), hits = collisions(point.x, point.z, feet), rise = previous === null ? 0 : Math.abs(feet - previous); previous = feet;
      minClearance = Math.min(minClearance, clearance); maxRise = Math.max(maxRise, rise);
      if (floorError > .065 || clearance < height - .01 || hits.length || rise > .28) { if (bad.length < 12) bad.push({ index: i, local: pointJSON(point), world: pointJSON(world), floorError: rounded(floorError), clearance: rounded(clearance), rise: rounded(rise), bodies: describeBodies(hits) }); }
    }
    const lower = floors[stair.lowerLevel].snap(route[0]), upper = floors[stair.upperLevel].snap(route.at(-1)), ok = !bad.length && lower.component !== null && upper.component !== null;
    if (ok) { graph.get(lower.component).push(upper.component); graph.get(upper.component).push(lower.component); }
    else addFailure('stair-route-blocked', { stair: index, lowerLevel: stair.lowerLevel, upperLevel: stair.upperLevel, lower, upper, routeFailures: bad });
    stairReports.push({ index, lowerLevel: stair.lowerLevel, upperLevel: stair.upperLevel, routePoints: route.length, minClearance: rounded(minClearance), maxRise: rounded(maxRise), maxFloorError: rounded(maxFloorError), lower, upper, ok, failures: bad });
  }
  const start = floors[0].snap(approach), reachable = new Set();
  if (start.component === null) addFailure('entrance-approach-blocked', { local: pointJSON(approach), world: pointJSON(approachWorld), diagnosis: start.reason });
  else { const queue = [start.component]; reachable.add(start.component); for (let i = 0; i < queue.length; i++) for (const next of graph.get(queue[i])) if (!reachable.has(next)) { reachable.add(next); queue.push(next); } }
  const roomReports = [];
  for (const [index, room] of interior.rooms.entries()) {
    const f = floors[room.level], targetComponents = new Set(); let freeCells = 0, reachableCells = 0, target = null;
    const authored = item.bankLayout?.roomLabels.find(label => label.id === room.id), anchor = authored ? visual.localToWorld(new T.Vector3(...authored.center)).applyMatrix4(inverse) : null;
    for (let i = 0; i < f.valid.length; i++) { if (!f.valid[i]) continue; const p = f.coords(i); if (!insideRect(p.x, p.z, room.rect, .4) || anchor && Math.hypot(p.x - anchor.x, p.z - anchor.z) > 1.4) continue; freeCells++; targetComponents.add(f.labels[i]); if (reachable.has(f.labels[i])) { reachableCells++; if (!target) target = { ...p, y: f.y }; } }
    const items = room.items || [], missing = [];
    if (!items.length) missing.push('nonempty-furniture');
    if (/^(bedroom|guest_bedroom|hotel_guestroom)$/.test(room.role || '') && !items.some(v => v === 'bed' || v === 'single_bed')) missing.push('bed');
    if (/^(hospital_ward|treatment_room)$/.test(room.role || '')) { if (!items.includes('hospital_bed')) missing.push('hospital_bed'); if (!items.includes('iv_stand')) missing.push('iv_stand'); }
    if (missing.length) addFailure('room-functional-content-missing', { room: index, id: room.id, level: room.level, role: room.role, name: room.name, missing, items, rect: room.rect, omitted: room.omitted, rejected: room.rejected });
    if (!reachableCells) addFailure('room-unreachable-from-entrance', { room: index, id: room.id, level: room.level, name: room.name, freeCells, componentIds: [...targetComponents], rect: room.rect, authoredAnchor: anchor ? pointJSON(anchor) : null, anchorDiagnosis: anchor ? f.sample(anchor.x, anchor.z, true) : null });
    roomReports.push({ id: room.id, level: room.level, name: room.name, role: room.role, rect: room.rect, items, freeCells, reachableCells, componentIds: [...targetComponents], reachable: reachableCells > 0, target: target ? pointJSON(target) : null, authoredAnchor: anchor ? pointJSON(anchor) : null, missing });
  }
  for (const report of stairReports) { report.lowerReachable = report.lower.component !== null && reachable.has(report.lower.component); report.upperReachable = report.upper.component !== null && reachable.has(report.upper.component); }
  let probe = null;
  if (flag('--probe')) {
    const values = flag('--probe').split(',').map(Number); if (values.length !== 4 || !values.every(Number.isFinite)) throw new Error('--probe is x0,z0,x1,z1 in floor-local metres');
    const [x0, z0, x1, z1] = values, steps = Math.max(1, Math.ceil(Math.hypot(x1 - x0, z1 - z0) / .03)), samples = [];
    for (let i = 0; i <= steps; i++) { const t = i / steps, x = x0 + (x1 - x0) * t, z = z0 + (z1 - z0) * t, result = floors[0].sample(x, z, true); if (!result.ok) samples.push({ x: rounded(x), z: rounded(z), ...result }); }
    probe = { from: { local: [x0, z0], world: pointJSON(toWorld(x0, 0, z0)) }, to: { local: [x1, z1], world: pointJSON(toWorld(x1, 0, z1)) }, steps, ok: !samples.length, failures: samples };
  }
  const report = { id: item.id, assetId: item.assetId, purpose: resolveBuildingPurpose(item), gridSpacing: spacing, milliseconds: rounded(performance.now() - started), bodies: bodies.length, doors, entry: { local: pointJSON(approach), world: pointJSON(approachWorld), ...start }, floors: floors.map(f => ({ level: f.level, y: rounded(f.y), rect: f.rect.map(rounded), cells: f.cells, freeCells: f.freeCells, reachedCells: f.componentIds.reduce((n, id) => n + (reachable.has(id) ? components[id].cells : 0), 0), componentIds: f.componentIds, causes: f.causes, ...(debug ? { gridOrigin: f.domain.slice(0, 2), spacing, rows: Array.from({ length: f.nz }, (_, z) => Array.from({ length: f.nx }, (_, x) => { const label = f.labels[z * f.nx + x]; return label < 0 ? '#' : reachable.has(label) ? '.' : String.fromCharCode(65 + label % 26); }).join('')) } : {}) })), components, stairs: stairReports, rooms: roomReports, failures, ...(probe ? { probe } : {}), ...(debug ? { collisionBodies: bodies.map(b => ({ index: b.index, kind: b.kind, part: b.part, minY: b.minY, maxY: b.maxY, polygon: b.polygon, bounds: b.bounds })) } : {}) };
  const disconnected = failures.filter(f => f.kind === 'room-unreachable-from-entrance');
  if (canRefine && spacing > .061 && disconnected.length) { const refined = auditEntry(entry, item, visual, .06, false); refined.coarseGrid = { spacing, disconnectedRoomIds: disconnected.map(room => room.id), milliseconds: report.milliseconds }; refined.milliseconds = rounded(refined.milliseconds + report.milliseconds); return refined; }
  return report;
}

const results = [], began = performance.now();
for (const [index, item] of instances.entries()) {
  const group = new T.Group(), visual = sources.get(item.binding.url).clone(true), t = item.transform;
  visual.traverse(node => { if (item.hideNodeNames?.includes(node.name)) node.visible = false; }); visual.position.fromArray(t.modelLocalOffsetM); group.add(visual); group.position.fromArray(t.positionM); group.rotation.y = t.yawDegrees * Math.PI / 180; group.scale.setScalar(t.uniformScale); group.updateMatrixWorld(true);
  let applied;
  try { applied = createWindowedBuildingEntry({ THREE: T, visual, instance: item }); if (!applied.entry?.storeys || !applied.entry?.interiorDesign) throw new Error('Building has no connected storeys/interior'); const result = auditEntry(applied.entry, item, visual); results.push(result); console.log(`${index + 1}/${instances.length} ${item.id}: ${result.rooms.filter(r => r.reachable).length}/${result.rooms.length} rooms, ${result.stairs.filter(s => s.ok).length}/${result.stairs.length} stair routes, ${result.failures.length} failures`); }
  catch (error) { results.push({ id: item.id, assetId: item.assetId, floors: [], rooms: [], stairs: [], failures: [{ kind: 'audit-construction-error', message: error.message, stack: error.stack }] }); console.log(`${index + 1}/${instances.length} ${item.id}: ERROR ${error.message}`); }
  finally { applied?.roomReveals?.dispose(); applied?.entry?.dispose(); applied?.windows?.dispose(); group.removeFromParent(); }
}
const failureKinds = {};
for (const result of results) for (const failure of result.failures) failureKinds[failure.kind] = (failureKinds[failure.kind] || 0) + 1;
const total = { buildings: results.length, floors: results.reduce((n, r) => n + r.floors.length, 0), rooms: results.reduce((n, r) => n + r.rooms.length, 0), reachableRooms: results.reduce((n, r) => n + r.rooms.filter(room => room.reachable).length, 0), stairs: results.reduce((n, r) => n + r.stairs.length, 0), clearStairs: results.reduce((n, r) => n + r.stairs.filter(stair => stair.ok).length, 0), routePoints: results.reduce((n, r) => n + r.stairs.reduce((sum, stair) => sum + stair.routePoints, 0), 0), failures: Object.values(failureKinds).reduce((a, b) => a + b, 0), failureKinds, milliseconds: rounded(performance.now() - began) };
const output = new URL(`outputs/interior_rebuild_20260912/${label}_navigation.json`, root); fs.mkdirSync(new URL('.', output), { recursive: true }); fs.writeFileSync(output, JSON.stringify({ scenario: `Actual native GLBs and transformed entry collision bodies; open doors through their interaction API; .36m-radius, 1.8m-high capsule; ${spacing}m floor grid with .08m edge sweep; nine-point ceiling samples; all stair route samples. Grid-disconnected narrow gaps should be refined with --spacing .06 before treating them as physically blocked. CPU only; no GPU/FPS or live movement claim.`, sourceManifests: manifests, total, buildings: results }, null, 2));
console.log(JSON.stringify(total)); console.log(output.href);
process.exitCode = total.failures ? 1 : 0;
