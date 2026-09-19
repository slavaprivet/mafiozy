import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

// Execute only the owned update hook with lightweight adapters. Loading /walk
// would create a renderer and is inappropriate for this CPU timing contract.
const source = fs.readFileSync(new URL('walk_preview.mjs', import.meta.url), 'utf8');
const body = source.match(/function updateBuildingEntries\(dt\)\{([\s\S]*?)\n\}/)?.[1];
assert(body, 'owned entry update hook exists');
const run = new Function('s', `const {createIncrementalWalkCollisionIndex,updateWalkEntryCollisionGroups,entryBodyVersions,buildingEntries,hero,bodies,walkCollisionDiagnostic,performance,document}=s;let walkCollisionIndex=s.index;const dt=1/60;${body};s.index=walkCollisionIndex;`);
function harness(enabled) {
  let now = 0, reads = 0, calls = 0, updates = 0, writes = 0, totals = { replacements: 5, verticesVisited: 100, bodiesVisited: 25, queryCacheBuilds: 2, bodyReferences: 20147, groups: 79 };
  const index = Object.defineProperty(() => [], 'stats', { get() { reads++; return { ...totals }; } });
  const dataset = new Proxy({}, { set(target, key, value) { writes++; target[key] = value; return true; } });
  const s = { index, entryBodyVersions: new Map(), buildingEntries: [], bodies: [], hero: null, walkCollisionDiagnostic: enabled ? { at: -Infinity, index: null, stats: null } : null,
    performance: { now() { calls++; return now; } }, document: { body: { dataset } }, updateWalkEntryCollisionGroups() { updates++; } };
  return { s, tick(time) { now = time; run(s); }, totals, counts: () => ({ reads, calls, updates, writes }), diagnostic: () => JSON.parse(dataset.walkCollisionIndex) };
}

test('normal gameplay has no diagnostic timer, stats read or DOM serialization', () => {
  const h = harness(false); for (let i = 0; i < 120; i++) h.tick(i * 1000 / 60);
  assert.deepEqual(h.counts(), { reads: 0, calls: 0, updates: 120, writes: 0 });
});

test('perf QA samples at most once per second and retains animation totals between samples', () => {
  const h = harness(true); h.tick(0); assert.equal(h.diagnostic().counterWindow, 'generation');
  for (let time = 1; time < 1000; time += 16) { h.totals.replacements++; h.totals.verticesVisited += 4; h.tick(time); }
  assert.equal(h.counts().writes, 1); h.tick(1000);
  assert.equal(h.counts().writes, 2); assert.equal(h.diagnostic().dirtyGroups, h.totals.replacements - 5); assert.equal(h.diagnostic().verticesVisitedDelta, h.totals.verticesVisited - 100);
  h.tick(1999); assert.equal(h.counts().writes, 2); h.tick(2000); assert.equal(h.counts().writes, 3); assert.equal(h.diagnostic().dirtyGroups, 0);
  h.s.index = Object.defineProperty(() => [], 'stats', { get: () => ({ replacements: 1, verticesVisited: 4, bodiesVisited: 1, queryCacheBuilds: 0, bodyReferences: 10, groups: 2 }) });
  h.tick(3000); assert.equal(h.diagnostic().counterWindow, 'generation'); assert.equal(h.diagnostic().dirtyGroups, 1); assert.equal(h.diagnostic().totalBodies, 10);
});
