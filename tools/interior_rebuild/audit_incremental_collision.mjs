import fs from 'node:fs';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { registerHooks } from 'node:module';
import { pathToFileURL } from 'node:url';
import { performance } from 'node:perf_hooks';
import { createWalkCollisionIndex } from '../../assets/maps/city_rebuild_v1/walk_collision_index.mjs';
import { createIncrementalWalkCollisionIndex, updateWalkEntryCollisionGroups } from '../../assets/maps/city_rebuild_v1/incremental_walk_collision_index.mjs';
import { createNpcNativePerception } from '../../assets/maps/city_rebuild_v1/npc_native_perception.mjs';
import { applyBuildingDoorsGlass } from '../../assets/maps/city_rebuild_v1/building_doors_glass.mjs';
import { createWindowedBuildingEntry } from '../../assets/maps/city_rebuild_v1/building_window_integration.mjs';

const root = new URL('../../', import.meta.url), dir = new URL('assets/maps/city_rebuild_v1/', root), out = new URL('outputs/entry_collision_index_20260913/', root);
fs.mkdirSync(out, { recursive: true });
const input = new URL(process.argv[2] || 'outputs/roads_logical_20260912/integration_candidate_snapshot.json', root), inputBytes = fs.readFileSync(input), snapshot = JSON.parse(inputBytes);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const moduleFiles = fs.readdirSync(dir).filter(f => /^(building_|interior_|incremental_walk_collision_index|hospital_public_approach|tower_public_approach|detention_native_sites).*\.mjs$/.test(f) && !f.startsWith('test_'));
const sourceManifest = moduleFiles.map(file => ({ file, sha256: hash(fs.readFileSync(new URL(file, dir))) }));
const vendor = process.env.MAFIOZI_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({ resolve(s, c, next) { return next(s === 'three' ? pathToFileURL(vendor + 'build/three.module.js').href : s, c); } });
const T = await import(pathToFileURL(vendor + 'build/three.module.js')), { GLTFLoader } = await import(pathToFileURL(vendor + 'addons/loaders/GLTFLoader.js'));
const scene = new T.Scene(), sources = new Map(), entries = [], active = [], instanceReports = [], started = performance.now();
for (const instance of snapshot.buildings) {
  if (sources.has(instance.binding.url)) continue;
  const bytes = fs.readFileSync(new URL(instance.binding.url.slice(1), root)); assert.equal(hash(bytes), instance.binding.sha256, 'actual GLB bytes match worker binding');
  const loader = new GLTFLoader().register(() => ({ name: 'CPU_COLLISION_GEOMETRY_AUDIT', loadTexture: () => Promise.resolve(new T.Texture()) }));
  sources.set(instance.binding.url, (await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene);
}
for (const instance of snapshot.buildings) {
  const group = new T.Group(), visual = sources.get(instance.binding.url).clone(true), t = instance.transform;
  visual.traverse(node => { if (instance.hideNodeNames?.includes(node.name)) node.visible = false; });
  visual.position.fromArray(t.modelLocalOffsetM || [0, 0, 0]); const doorsGlass = applyBuildingDoorsGlass(visual, instance);
  group.add(visual); group.position.fromArray(t.positionM); group.rotation.y = t.yawDegrees * Math.PI / 180; group.scale.setScalar(t.uniformScale ?? 1); scene.add(group); group.updateMatrixWorld(true);
  const applied = createWindowedBuildingEntry({ THREE: T, visual, instance }); assert(applied.entry, instance.id);
  entries.push(applied.entry); active.push({ group, doorsGlass, ...applied });
  const bodies = applied.entry.getCollisionBodies(); instanceReports.push({ id: instance.id, assetId: instance.assetId, role: instance.role, bodies: bodies.length, roomDoors: applied.entry.interiorDesign?.doors.length || 0, safes: applied.entry.interiorDesign?.safes.length || 0 });
}
const constructionMs = performance.now() - started;
// Static fixture uses the exact serialized final worker bodies. Cuttable fences
// are separately exercised by force/splice unit tests; no guessed fence height.
const staticBodies = [...snapshot.authoredDecor.flatMap(i => i.collision?.worldBodies || []), ...snapshot.decorPlan.colliders, ...snapshot.roadPlan.colliders, ...snapshot.parkingPlan.colliders];
const versions = new Map(), index = createIncrementalWalkCollisionIndex(), far = new T.Vector3(1e6, 1e6, 1e6);
index.replaceGroup('world-static', staticBodies, { order: 0 }); updateWalkEntryCollisionGroups(index, versions, entries, 0, far);
const groupsNow = () => entries.map(entry => versions.get(entry).bodies), closed = groupsNow();
assert(closed.flat().length >= 16000, 'real full interior fixture, not a few synthetic boxes');
const sortedEntries = entries.filter(e => e.instance.role !== 'district_detention').sort((a, b) => versions.get(b).bodies.length - versions.get(a).bodies.length);
let parityQueries = 0, comparedCandidates = 0, perceptionQueries = 0, checksum = 0;
const addCells = (set, bodies) => {
  for (const body of bodies) {
    const polygon = body.polygonCR; if (!polygon?.length) continue;
    const minC = Math.floor(Math.min(...polygon.map(p => p[0])) / 4), maxC = Math.floor(Math.max(...polygon.map(p => p[0])) / 4), minR = Math.floor(Math.min(...polygon.map(p => p[1])) / 4), maxR = Math.floor(Math.max(...polygon.map(p => p[1])) / 4);
    for (let r = minR; r <= maxR; r++) for (let c = minC; c <= maxC; c++) set.set(c + ',' + r, [c * 4 + 2, r * 4 + 2]);
  }
};
const allCells = new Map(); addCells(allCells, staticBodies); for (const bodies of closed) addCells(allCells, bodies);
const cityQueries = [...allCells.values()].filter((_, i) => i % Math.max(1, Math.floor(allCells.size / 96)) === 0).slice(0, 96);
const scenarios = [], usedOuter = new Set(), usedRoom = new Set(), usedSafe = new Set();
function openOuter(entry) {
  const p = entry.approachPoint(), proximity = entry.proximity(p);
  if (!proximity || proximity.door || proximity.opening) return null;
  const result = entry.interact(p); if (!result.accepted || !entry.needsUpdate) return null;
  usedOuter.add(entry); return { kind: 'external_door', buildingId: entry.instance.id };
}
function openRoom(entry) {
  for (const door of entry.interiorDesign?.doors || []) {
    if (usedRoom.has(door) || door.target) continue;
    for (const distance of [1.5, 1.1, .85]) for (const sign of [-1, 1]) for (const tangent of [0, -.4, .4]) {
      const p = new T.Vector3(door.x + (door.axis === 'z' ? sign * distance : tangent), door.y, door.z + (door.axis === 'x' ? sign * distance : tangent)); entry.storeys.root.localToWorld(p);
      if (entry.proximity(p)?.door !== door) continue;
      const result = entry.interact(p); if (result.accepted && result.opening) { usedRoom.add(door); return { kind: 'room_door', buildingId: entry.instance.id, name: door.name }; }
    }
  }
  return null;
}
function openSafe(entry) {
  const safe = entry.interiorDesign?.safes.find(s => !usedSafe.has(s) && !s.getState().opened); if (!safe) return null;
  const state = safe.getState(); assert(safe.applySourceState({ targetId: state.id, opened: true, revision: 1 }, { animate: true }).ok);
  usedSafe.add(safe); return { kind: 'safe_local_receipt_fixture', buildingId: entry.instance.id, safeId: state.id };
}
function activateFirst(fn, filter = () => true) {
  for (const entry of sortedEntries) if (filter(entry)) { const result = fn(entry); if (result) return result; }
  throw new Error('No actual eligible entry for ' + fn.name);
}
function capture(name, actions) {
  const initial = groupsNow(), initiated = actions.map(action => action()), frames = []; let previous = initial;
  index.resetCounters(); const captureStarted = performance.now();
  for (let step = 0; step < 64; step++) {
    updateWalkEntryCollisionGroups(index, versions, entries, 1 / 60, far);
    const groups = groupsNow(), dirty = groups.map((b, i) => b !== previous[i] ? i : -1).filter(i => i >= 0);
    for (const i of dirty) addCells(allCells, groups[i]);
    const legacy = createWalkCollisionIndex([staticBodies, groups.flat()]);
    for (const [c, r] of allCells.values()) {
      const a = index(c, r), b = legacy(c, r); parityQueries++; assert.equal(a.length, b.length, name + ': candidate count');
      for (let j = 0; j < b.length; j++) { assert.equal(a[j], b[j], name + ': candidate order/reference'); comparedCandidates++; }
    }
    const moving = dirty.flatMap(i => groups[i].filter(b => b.movingDoor)).slice(0, 12), localQueries = [];
    const oldSight = createNpcNativePerception({ bodiesAt: legacy }), newSight = createNpcNativePerception({ bodiesAt: index });
    for (const body of moving) {
      const c = body.polygonCR.reduce((s, p) => s + p[0], 0) / body.polygonCR.length, r = body.polygonCR.reduce((s, p) => s + p[1], 0) / body.polygonCR.length;
      localQueries.push([c, r]); const height = (body.minYM ?? 0) + .9;
      const query = { fromC: c - 2, fromR: r - .2, toC: c + 2, toR: r + .2, eyeHeight: height, targetHeight: height };
      assert.deepEqual(newSight.query(query), oldSight.query(query), 'actual NPC perception uses fresh animated body pose'); perceptionQueries++;
    }
    frames.push({ groups, dirty, queries: [...cityQueries, ...localQueries] }); previous = groups;
  }
  assert(frames.some(f => f.dirty.length), 'scenario moved actual collider arrays');
  assert(frames.slice(-4).every(f => !f.dirty.length), 'all poses settle, idle arrays retain identity');
  const counters = index.stats; index.resetCounters(); updateWalkEntryCollisionGroups(index, versions, entries, 1 / 60, far);
  assert.equal(index.stats.bodiesVisited, 0); assert.equal(index.stats.replacements, 0);
  const scenario = { name, initial, frames, initiated, captureMs: performance.now() - captureStarted, counters }; scenarios.push(scenario);
  console.log(JSON.stringify({ phase: 'actual-animation-parity', name, activeFrames: frames.filter(f => f.dirty.length).length, maxDirtyEntries: Math.max(...frames.map(f => f.dirty.length)), initiated }));
}

capture('one_external_door', [() => activateFirst(openOuter, e => !usedOuter.has(e))]);
capture('one_room_door', [() => activateFirst(openRoom)]);
capture('one_safe', [() => activateFirst(openSafe)]);
capture('multiple_doors_and_safes', [() => activateFirst(openOuter, e => !usedOuter.has(e)), () => activateFirst(openOuter, e => !usedOuter.has(e)), () => activateFirst(openRoom), () => activateFirst(openSafe), () => activateFirst(openSafe)]);

function replay(scenario, incremental) {
  let target = scenario.initial, current = target.slice();
  const proxies = current.map((_, i) => ({ get needsUpdate() { return target[i] !== current[i]; }, update() { current[i] = target[i]; }, getCollisionBodies() { return current[i]; } }));
  let query, oldVersions = current.slice(); const map = new Map();
  if (incremental) { query = createIncrementalWalkCollisionIndex(); query.replaceGroup('world-static', staticBodies, { order: 0 }); updateWalkEntryCollisionGroups(query, map, proxies, 0, far); }
  else query = createWalkCollisionIndex([staticBodies, oldVersions.flat()]);
  for (const [c, r] of cityQueries) checksum += query(c, r).length;
  if (incremental) query.resetCounters();
  const activeTimes = [], idleTimes = [];
  for (const frame of scenario.frames) {
    target = frame.groups; const start = performance.now();
    if (incremental) updateWalkEntryCollisionGroups(query, map, proxies, 1 / 60, far);
    else {
      let changed = false;
      for (let i = 0; i < proxies.length; i++) {
        if (!proxies[i].needsUpdate && oldVersions[i] !== undefined) continue;
        proxies[i].update(); const next = proxies[i].getCollisionBodies(); if (oldVersions[i] !== next) { oldVersions[i] = next; changed = true; }
      }
      if (changed) query = createWalkCollisionIndex([staticBodies, oldVersions.flat()]);
    }
    for (const [c, r] of frame.queries) checksum += query(c, r).length;
    (frame.dirty.length ? activeTimes : idleTimes).push(performance.now() - start);
  }
  return { activeTimes, idleTimes, counters: incremental ? query.stats : null };
}
const quantiles = values => { const a = values.slice().sort((a, b) => a - b); return { samples: a.length, p50: a[Math.floor((a.length - 1) * .5)] ?? 0, p95: a[Math.floor((a.length - 1) * .95)] ?? 0 }; };
const measurements = [];
for (const scenario of scenarios) {
  const before = [], after = [], idleBefore = [], idleAfter = []; let counters;
  for (let pair = 0; pair < 4; pair++) {
    for (const incremental of pair % 2 ? [true, false] : [false, true]) {
      const measured = replay(scenario, incremental); if (!pair) continue;
      (incremental ? after : before).push(...measured.activeTimes); (incremental ? idleAfter : idleBefore).push(...measured.idleTimes); if (incremental) counters = measured.counters;
    }
  }
  measurements.push({ scenario: scenario.name, initiated: scenario.initiated, activeFrames: scenario.frames.filter(f => f.dirty.length).length, maxDirtyEntries: Math.max(...scenario.frames.map(f => f.dirty.length)), beforeMs: quantiles(before), afterMs: quantiles(after), idleBeforeMs: quantiles(idleBefore), idleAfterMs: quantiles(idleAfter), incrementalCountersPer64Frames: counters,
    baselineBodyVisitsPer64Frames: scenario.frames.filter(f => f.dirty.length).reduce((sum, f) => sum + staticBodies.length + f.groups.reduce((n, b) => n + b.length, 0), 0) });
}

// Compact deduplicated actual geometry fixture: body identity table, group
// versions and frame indices preserve the same reference-sharing in replays.
const bodyIds = new Map(), bodyTable = [], groupIds = new Map(), groupTable = [];
function groupId(bodies) {
  if (groupIds.has(bodies)) return groupIds.get(bodies);
  const ids = bodies.map(body => {
    if (!bodyIds.has(body)) {
      bodyIds.set(body, bodyTable.length); const value = {};
      for (const key of ['id', 'node', 'polygonCR', 'minYM', 'maxYM', 'buildingEntryId', 'movingDoor', 'interiorDoor', 'interiorSafe', 'safeId', 'interiorFurniture', 'furnitureKind', 'storeyPart']) if (body[key] !== undefined) value[key] = body[key];
      bodyTable.push(value);
    }
    return bodyIds.get(body);
  });
  const id = groupTable.length; groupIds.set(bodies, id); groupTable.push(ids); return id;
}
const fixture = { version: 1, inputSHA256: hash(inputBytes), staticGroup: groupId(staticBodies), closedGroups: closed.map(groupId), instances: instanceReports, scenarios: scenarios.map(s => ({ name: s.name, initial: s.initial.map(groupId), frames: s.frames.map(f => f.groups.map(groupId)) })), bodies: bodyTable, groups: groupTable };
fs.writeFileSync(new URL('actual_collision_fixture.json', out), JSON.stringify(fixture));
for (const applied of active) { applied.roomReveals?.dispose(); applied.entry.dispose(); applied.windows?.dispose(); applied.doorsGlass.dispose(); applied.group.removeFromParent(); }
index.clear(); versions.clear(); assert.equal(index.stats.bodyReferences, 0); assert.equal(index.stats.groups, 0); assert.equal(index.stats.cells, 0);
const sourceStable = sourceManifest.every(s => hash(fs.readFileSync(new URL(s.file, dir))) === s.sha256), inputStable = fs.readFileSync(input).equals(inputBytes);
const report = { status: sourceStable && inputStable ? 'PASS' : 'SOURCE_CHANGED', input: input.href, inputSHA256: hash(inputBytes), inputStable, sourceStable, sourceManifest,
  fixture: { buildings: entries.length, ordinaryBuildings: instanceReports.filter(i => i.role !== 'district_detention').length, entryBodies: closed.reduce((n, b) => n + b.length, 0), staticBodies: staticBodies.length, totalBodies: staticBodies.length + closed.reduce((n, b) => n + b.length, 0), cells: allCells.size, constructionMs, instances: instanceReports },
  parity: { frames: scenarios.reduce((n, s) => n + s.frames.length, 0), queries: parityQueries, comparedCandidates, actualNpcPerceptionQueries: perceptionQueries, errors: 0 }, measurements, checksum,
  limits: ['Actual current building GLBs/factory/door-glass adapter; CPU placeholder textures, no renderer/GPU or source network calls.', 'Safes use a local confirmed-state fixture, not a live economic action.', 'Paired measurements replay identical actual collider versions. They include old flat/index or new entry invalidation and identical query workload; factory construction and door geometry updates are common and excluded from timed replay.', 'First pair is warmup; three alternating pairs retained. CPU update timings do not measure loaded-scene frame p50/p95.', 'External static bodies are serialized final worker decor/road/parking bodies; cuttable fences are covered separately by force/splice regression.'] };
fs.writeFileSync(new URL('actual_collision_index_report.json', out), JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify({ ...report, sourceManifest: undefined, fixture: { ...report.fixture, instances: undefined } }, null, 2));
assert(sourceStable && inputStable, 'source/input changed while measuring');
