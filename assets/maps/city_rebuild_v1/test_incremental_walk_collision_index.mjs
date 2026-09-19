import test from 'node:test';
import assert from 'node:assert/strict';
import { createWalkCollisionIndex } from './walk_collision_index.mjs';
import { createIncrementalWalkCollisionIndex, updateWalkEntryCollisionGroups } from './incremental_walk_collision_index.mjs';
import { createNpcNativePerception } from './npc_native_perception.mjs';
import { createNpcNativeNavigation } from './npc_native_navigation.mjs';

const rect = (id, x, z, w = 1, d = 1, extra = {}) => ({ id, polygonCR: [[x, z], [x + w, z], [x + w, z + d], [x, z + d]], ...extra });
const points = [[-4, -4], [-.001, -.001], [0, 0], [3.999, 3.999], [4, 4], [8, 0], [20.5, .5], [-20, 4], [999, 999]];
function parity(index, collections, samples = points) {
  const old = createWalkCollisionIndex(collections);
  for (const [x, z] of samples) {
    const a = index(x, z), b = old(x, z); assert.equal(a.length, b.length);
    for (let i = 0; i < b.length; i++) assert.equal(a[i], b[i], 'candidate order and exact body identity');
  }
  assert.deepEqual(index.allBodies(), collections.flat());
}

test('ordered candidates retain duplicates, height layers, negative edges and degenerates', () => {
  const duplicate = rect('shared', 0, 0), staticBodies = [rect('edge', -4, -4, 4, 4), duplicate, { id: 'no-poly' }];
  const upstairs = rect('upstairs', 0, 0, 2, 2, { minYM: 4, maxYM: 7 });
  const a = [rect('room', 0, 0), upstairs, duplicate], b = [rect('degenerate', 4, 4, 0, 0), duplicate];
  const index = createIncrementalWalkCollisionIndex();
  index.replaceGroup('b', b, { order: 2 }); index.replaceGroup('static', staticBodies, { order: 0 }); index.replaceGroup('a', a, { order: 1 });
  parity(index, [staticBodies, a, b]); assert(index.has(staticBodies[2])); assert(index(0, 0).includes(upstairs));
  assert.equal(index(0, 0).filter(body => body === duplicate).length, 3);
});

test('moving groups clear old cells in the same frame without rebuilding distant entries', () => {
  const near = [rect('near', 0, 0)], distant = [rect('distant', 20, 0)], index = createIncrementalWalkCollisionIndex();
  index.replaceGroup('near', near, { order: 1 }); index.replaceGroup('distant', distant, { order: 2 });
  const stableCell = index(20.5, .5); index.resetCounters();
  const moved = [rect('door', -20, 4, .25, 2, { movingDoor: true })]; index.replaceGroup('near', moved, { order: 1 });
  assert.equal(index(20.5, .5), stableCell, 'untouched query cache survives');
  assert(!index.has(near[0])); assert(index.has(moved[0])); assert.equal(index.stats.bodiesVisited, 1);
  parity(index, [moved, distant]);
});

test('fence splice and in-place polygon mutation use force/revision and previous membership', () => {
  const removed = rect('fence', 0, 0), retained = rect('retained', 0, 0), added = rect('cut-side', 20, 0);
  const source = [removed, retained], index = createIncrementalWalkCollisionIndex(); index.replaceGroup('world', source, { order: 0 });
  source.splice(0, 1); source.push(added); index.replaceGroup('world', source, { order: 0, force: true });
  assert(!index.has(removed)); assert(index.has(retained)); assert(index.has(added)); parity(index, [source]);
  added.polygonCR = added.polygonCR.map(([x, z]) => [x - 40, z + 4]); index.replaceGroup('world', source, { revision: 1 });
  parity(index, [source]); assert(!index(20.5, .5).includes(added)); assert(index(-20, 4).includes(added));
});

test('membership reference counts survive group removal and lazy snapshots refresh', () => {
  const shared = rect('shared', 0, 0), index = createIncrementalWalkCollisionIndex();
  index.replaceGroup('a', [shared], { order: 0 }); index.replaceGroup('b', [shared, shared], { order: 1 });
  const all = index.allBodies(); assert.equal(index.allBodies(), all);
  index.removeGroup('a'); assert(index.has(shared)); assert.notEqual(index.allBodies(), all);
  assert.equal(index.stats.bodyReferences, 2); index.removeGroup('b'); assert(!index.has(shared));
  assert.equal(index.stats.cells, 0); assert.equal(index.stats.bucketReferences, 0); assert.equal(index.stats.uniqueBodies, 0);
  parity(index, []);
});

test('reordering groups changes candidate order without touching any polygon', () => {
  const a = [rect('a', 0, 0)], b = [rect('b', 0, 0)], index = createIncrementalWalkCollisionIndex();
  index.replaceGroup('a', a, { order: 1 }); index.replaceGroup('b', b, { order: 2 }); index(0, 0); index.resetCounters();
  index.replaceGroup('b', b, { order: 1 }); index.replaceGroup('a', a, { order: 2 });
  parity(index, [b, a]); assert.equal(index.stats.bodiesVisited, 0); assert.equal(index.stats.orderUpdates, 2);
});

test('entry updater publishes each door/safe step, skips idle work, handles equal-length replacement and reload', () => {
  function entry(id, x) {
    let bodies = [rect(id, x, 0)], fraction = 0;
    return { needsUpdate: false, updates: 0, reads: 0, update(dt) { this.updates++; if (this.needsUpdate) { fraction += dt; bodies = [rect(id, x + fraction * 20, 0, .3, 1, { movingDoor: true })]; if (fraction >= 1) this.needsUpdate = false; } }, getCollisionBodies() { this.reads++; return bodies; } };
  }
  const index = createIncrementalWalkCollisionIndex(), versions = new Map(), a = entry('door', 0), b = entry('safe', 20), staticBodies = [rect('street', -20, 4)];
  index.replaceGroup('static', staticBodies, { order: 0 }); updateWalkEntryCollisionGroups(index, versions, [a, b], 0, null);
  index.resetCounters(); updateWalkEntryCollisionGroups(index, versions, [a, b], .1, null);
  assert.equal(index.stats.replacements, 0); assert.equal(index.stats.bodiesVisited, 0); assert.equal(a.updates, 1); assert.equal(a.reads, 1);
  a.needsUpdate = true; b.needsUpdate = true;
  for (let step = 0; step < 8; step++) {
    updateWalkEntryCollisionGroups(index, versions, [a, b], .125, null);
    parity(index, [staticBodies, versions.get(a).bodies, versions.get(b).bodies], [...points, [step * 2.5, 0], [20 + step * 2.5, 0]]);
  }
  assert.equal(index.stats.replacements, 16, 'every animated pose is indexed');
  index.resetCounters(); updateWalkEntryCollisionGroups(index, versions, [b, a], .1, null);
  assert.equal(index.stats.bodiesVisited, 0); parity(index, [staticBodies, versions.get(b).bodies, versions.get(a).bodies]);
  const c = entry('replacement', -20), oldA = versions.get(a).bodies[0]; updateWalkEntryCollisionGroups(index, versions, [b, c], 0, null);
  assert(!index.has(oldA)); assert(!versions.has(a)); parity(index, [staticBodies, versions.get(b).bodies, versions.get(c).bodies]);
  updateWalkEntryCollisionGroups(index, versions, [], 0, null); parity(index, [staticBodies]);
  index.clear(); versions.clear(); assert.equal(index.stats.groups, 0); assert.equal(index.stats.cells, 0); assert.equal(index.stats.bodyReferences, 0);
  index.replaceGroup('static', staticBodies, { order: 0 }); updateWalkEntryCollisionGroups(index, versions, [c], 0, null); parity(index, [staticBodies, versions.get(c).bodies]);
});

test('invalid replacement leaves previous group usable and queries retain stable empty array', () => {
  assert.throws(() => createIncrementalWalkCollisionIndex(0), RangeError);
  const index = createIncrementalWalkCollisionIndex(), bodies = [rect('valid', 0, 0)]; index.replaceGroup('a', bodies);
  assert.throws(() => index.replaceGroup('a', [rect('invalid', Infinity, 0)]), RangeError);
  parity(index, [bodies]); assert.equal(index(200, 200), index(-200, -200));
});

test('native NPC sight observes multiple door updates immediately; navigation retains its frame cache contract', () => {
  const index = createIncrementalWalkCollisionIndex(), closed = [rect('door', 3.99, -.4, .04, .8, { minYM: 0, maxYM: 2.2 })];
  const open = [rect('door-open', 3.99, 5, .04, .8, { minYM: 0, maxYM: 2.2 })];
  const sight = createNpcNativePerception({ bodiesAt: index });
  const nav = createNpcNativeNavigation({ bodiesAt: index, containsBody: (b, r, c) => c >= b.polygonCR[0][0] && c <= b.polygonCR[2][0] && r >= b.polygonCR[0][1] && r <= b.polygonCR[2][1] });
  const ray = { fromR: 0, fromC: 0, toR: 0, toC: 8 }, sample = { r: 0, c: 4 };
  for (const bodies of [closed, open, closed, open]) {
    index.replaceGroup('entry', bodies, { order: 1 });
    assert.equal(sight.query(ray).blocked, bodies === closed, 'no cached old query function or cell list');
    nav.beginFrame(); assert.equal(nav.query(sample).blocked, bodies === closed);
    assert.equal(nav.query(sample).blocked, bodies === closed, 'same-frame navigation cache remains correct');
  }
  assert.equal(nav.diagnostics().cacheHits, 4);
});
