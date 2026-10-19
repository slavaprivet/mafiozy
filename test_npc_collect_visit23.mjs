import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import fs from 'node:fs';
import {collectVisit23} from './npc_collect_visit23_candidate.mjs';

// Synthetic lifecycle contract, deliberately not a claim of native site binding.
const fixture = () => ({
  action: {kind: 'collect', target_id: 'owned-business'},
  actionKey: 'collect:owned-business:100', generation: 3, provenance: 'server',
  binding: {holdingId: 'owned-business', ownerId: 'boss', siteId: 'fixture-site', open: true, r: 20, c: 30},
  actor: {leaderId: 'boss', alive: true, r: 20, c: 29.5},
  guard: {ownerId: 'boss', siteId: 'fixture-site', alive: true, r: 20, c: 30.5},
  arrivedExact: true, now: 1000
});
let count = 0;
function test(name, fn) {fn(); count++; console.log('PASS', name);}
test('physical arrival required; exact route plus distance', () => {
  for (const change of [{arrivedExact: false}, {actor: {...fixture().actor, r: 40}}]) {
    const result = collectVisit23(null, {...fixture(), ...change});
    assert.equal(result.state.phase, 'approach'); assert.equal(result.effect, null);
  }
});
test('one visit across 100 repeated polls, no position or economy mutation', () => {
  const input = fixture(), before = structuredClone(input);
  let {state, effect} = collectVisit23(null, input);
  assert.equal(effect.type, 'begin-check'); assert.deepEqual(effect.facing, {r: 20, c: 30.5});
  for (let i = 0; i < 100; i++) {
    const result = collectVisit23(state, {...input, now: 1000 + i * 100});
    state = result.state; assert.notEqual(result.effect?.type, 'begin-check');
  }
  assert.equal(state.phase, 'done'); assert.deepEqual(input, before);
  assert.equal(Object.keys(state).length, 5);
});
test('offline, preview, missing/mismatched/closed site cannot start', () => {
  const base = fixture();
  for (const change of [{provenance: 'offline'}, {provenance: 'preview'},
    {actionKey: 'collect:offline:boss'}, {binding: null},
    {binding: {...base.binding, ownerId: 'rival'}},
    {binding: {...base.binding, holdingId: 'other'}},
    {binding: {...base.binding, open: false}}]) {
    assert.equal(collectVisit23(null, {...base, ...change}).effect, null);
  }
});
test('combat, death, hidden, loss of ownership and changed site interrupt permanently', () => {
  const base = fixture(), started = collectVisit23(null, base).state;
  for (const change of [{actor: {...base.actor, combat: true}},
    {actor: {...base.actor, alive: false}}, {actor: {...base.actor, hidden: true}},
    {binding: {...base.binding, ownerId: 'rival'}},
    {binding: {...base.binding, siteId: 'other-site'}}]) {
    const result = collectVisit23(started, {...base, ...change});
    assert.equal(result.state.phase, 'cancelled');
    assert.equal(result.effect.type, 'release');
    assert.equal(collectVisit23(result.state, base).effect, null);
  }
});
test('displacement and clock rollback release the visit', () => {
  const base = fixture(), state = collectVisit23(null, base).state;
  for (const change of [{actor: {...base.actor, r: 23}}, {now: 1}]) {
    const result = collectVisit23(state, {...base, ...change});
    assert.equal(result.state.phase, 'cancelled'); assert.equal(result.effect.type, 'release');
  }
});
test('new order starts once; stale generation is ignored', () => {
  const base = fixture(), started = collectVisit23(null, base).state;
  const next = {...base, generation: 4, actionKey: 'collect:owned-business:200'};
  const result = collectVisit23(started, next);
  assert.equal(result.effect.type, 'begin-check');
  const stale = collectVisit23(result.state, base);
  assert.equal(stale.state, result.state); assert.equal(stale.effect, null);
  const changedKind = collectVisit23(result.state, {...next, generation: 5, action: {kind: 'gang_war'}});
  assert.equal(changedKind.state.phase, 'cancelled');
  assert.equal(changedKind.effect.type, 'release');
  const distantNew = collectVisit23(started, {...next, arrivedExact: false});
  assert.equal(distantNew.state.phase, 'approach'); assert.equal(distantNew.effect.type, 'release');
  assert.equal(collectVisit23(started, {...base, actionKey: ''}).effect.type, 'release');
});
test('missing, distant or enemy guard is not used as a conversation partner', () => {
  const base = fixture();
  for (const guard of [null, {...base.guard, r: 40}, {...base.guard, ownerId: 'rival'}, {...base.guard, alive: false}]) {
    assert.deepEqual(collectVisit23(null, {...base, guard}).effect.facing, {r: 20, c: 30});
  }
});
const input = fixture(), state = collectVisit23(null, input).state;
const samples = [];
for (let warm = 0; warm < 10000; warm++) collectVisit23(state, input);
for (let sample = 0; sample < 200; sample++) {
  const start = performance.now();
  for (let boss = 0; boss < 19; boss++) collectVisit23(state, input);
  samples.push(performance.now() - start);
}
samples.sort((a,b) => a-b);
const report = {candidateOnly: true, tests: count, cpu19ActorsMs: {p50: samples[100], p95: samples[190]}, limitations: 'Synthetic lifecycle only. No production wiring, native geometry, authenticated server visit or full-scene FPS.'};
fs.writeFileSync('outputs/npc_collect_visit23_candidate.json', JSON.stringify(report, null, 2)+'\n');
console.log(JSON.stringify(report));
