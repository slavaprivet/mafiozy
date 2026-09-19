import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { COVER, findCover } from './hero_cover.mjs';

const body = extra => ({ id: 'wall', minY: 0, maxY: 5,
  polygon: [{ x: 0, z: 0 }, { x: 6, z: 0 }, { x: 6, z: 2 }, { x: 0, z: 2 }], ...extra });
const find = (surface, extra = {}) => findCover({ position: { x: 3, y: 0, z: -.8 },
  direction: { x: 0, z: 1 }, bodies: [surface], canOccupy: p => p.z < -.3, ...extra });
const near = (a, b) => assert.ok(Math.abs(a-b) < 1e-8, `${a} != ${b}`);
let cases = 0;
function test(name, fn) { fn(); cases++; console.log(`PASS ${name}`); }

test('surface height and posture use the chosen feet anchor, not the broad bounds', () => {
  const sampled = [], capsules = [];
  const result = find(body({ minY: 2, maxY: 7, heightAt: (anchor, normal) => {
    sampled.push({ anchor, normal }); return 3.2;
  } }), { position: { x: 3, y: 2, z: -.8 }, canOccupy: (p, height) => { capsules.push(height); return p.z < -.3; } });
  assert.equal(sampled.length, 1); near(sampled[0].anchor.z, -.48);
  near(sampled[0].normal.z, -1); near(result.height, 1.2);
  assert.equal(result.posture, 'crouch');
  assert.ok(capsules.every(h => h === COVER.crouchingHeight));
  const tall = find(body({ heightAt: () => 2.2 }));
  assert.equal(tall.posture, 'stand'); near(tall.height, 2.2);
});

test('a gap at the nearest point finds real cover 25 cm along the same edge', () => {
  const sampled = [];
  const result = find(body({ heightAt: p => { sampled.push(p.x); return Math.abs(p.x-3) < .2 ? 0 : 1.1; } }));
  near(Math.abs(result.anchor.x-3), .25); near(result.height, 1.1);
  assert.equal(result.edgeIndex, 0); assert.equal(result.posture, 'crouch');
  assert.equal(sampled.length, 2, 'stop once the cheapest valid anchor is found');
});

test('50 cm fallback still requires the whole approach capsule to fit', () => {
  const result = find(body(), { canOccupy: p => p.z < -.3 && !(p.z > -.7 && Math.abs(p.x-3) < .18) });
  near(Math.abs(result.anchor.x-3), .5);
  // This barrier crosses every approach; endpoint-only validation would pass.
  assert.equal(find(body(), { canOccupy: p => p.z < -.3 && Math.abs(p.z+.65) > .035 }), null);
});

test('missing/short sampled surfaces do not inherit the tall broad box', () => {
  for (const top of [undefined, null, NaN, -Infinity, 0, .74]) {
    let probes = 0, capsules = 0;
    assert.equal(find(body({ heightAt: () => { probes++; return top; } }), {
      canOccupy: () => { capsules++; return true; },
    }), null);
    assert.equal(probes, 5); assert.equal(capsules, 0);
  }
  assert.equal(find(body({ heightAt: () => Infinity })).posture, 'stand');
});

test('fallback stays within range, on its edge, and deduplicates clamped endpoints', () => {
  let probes = 0;
  assert.equal(find(body({ heightAt: p => { probes++; return Math.abs(p.x-3) < .2 ? 0 : 3; } }), { maxDistance: .35 }), null);
  assert.equal(probes, 1, 'out-of-range alternatives never sample geometry');
  probes = 0;
  assert.equal(find(body({ heightAt: () => { probes++; return 0; } }), { position: { x: .14, y: 0, z: -.8 } }), null);
  assert.equal(probes, 3, 'clamping creates only three distinct candidate points');
});

test('vertical camera has neutral heading while nearby rear cover remains accessible', () => {
  for (const direction of [{ x: 0, z: 0 }, { x: 1e-7, z: -1e-7 }, { x: 0, z: -1 }]) {
    const result = find(body(), { direction });
    assert.ok(result); near(result.anchor.x, 3); near(result.anchor.z, -.48);
  }
});

test('Ctrl reaches a nearby rear wall without first turning the camera',()=>{
 for(const direction of [{x:0,z:-1},{x:1,z:0},{x:0,z:1}]){
  const result=find(body(),{position:{x:3,y:0,z:-1.1},direction});assert.ok(result);near(result.anchor.z,-.48);
 }
});

test('far and worse-scoring bodies never trigger extra surface/physics work', () => {
  let farProbes = 0, nearestProbes = 0;
  const distant = Array.from({ length: 200 }, (_, i) => {
    const wall = body({ id: `far-${i}`, heightAt: () => { farProbes++; return 3; } });
    wall.polygon = wall.polygon.map(p => ({ x: p.x+20+i*7, z: p.z }));
    return wall;
  });
  const nearest = body({ heightAt: () => { nearestProbes++; return 1.1; } });
  const worse = body({ id: 'behind', heightAt: () => { farProbes++; return 3; } });
  worse.polygon = worse.polygon.map(p => ({ x: p.x, z: p.z+.2 }));
  const result = find(nearest, { bodies: [nearest, worse, ...distant] });
  assert.equal(result.body, nearest); assert.equal(nearestProbes, 1); assert.equal(farProbes, 0);
});

const surface = body({ heightAt: p => Math.abs(p.x-3) < .2 ? 0 : 1.1 });
const plain = body();
function bench(fn) {
  for (let i = 0; i < 1000; i++) fn();
  const samples = [];
  for (let batch = 0; batch < 21; batch++) {
    const start = performance.now();
    for (let i = 0; i < 1000; i++) fn();
    samples.push((performance.now()-start)/1000);
  }
  samples.sort((a, b) => a-b);
  return { p50_ms: samples[10], p95_ms: samples[19] };
}
console.log(JSON.stringify({ cpu_only: true, nearest: bench(() => find(plain)), narrow_gap: bench(() => find(surface)) }));
console.log(`${cases} acquisition tests passed`);
