import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { COVER, findCover, moveCover, advanceCoverCorner, coverExposure } from './hero_cover.mjs';

const rectangle = () => ({ id: 'same-wall', minY: 0, maxY: 3,
  polygon: [{ x: 0, z: 0 }, { x: 6, z: 0 }, { x: 6, z: 2 }, { x: 0, z: 2 }] });
const gap = (p, q) => Math.hypot(p.x-q.x, p.z-q.z);
const near = (a, b, epsilon = 1e-7) => assert.ok(Math.abs(a-b) < epsilon, `${a} != ${b}`);
const rotate = (p, yaw) => ({ x: p.x*Math.cos(yaw)-p.z*Math.sin(yaw), z: p.x*Math.sin(yaw)+p.z*Math.cos(yaw) });
function segmentDistance(p, a, b) {
  const dx = b.x-a.x, dz = b.z-a.z;
  const t = Math.max(0, Math.min(1, ((p.x-a.x)*dx+(p.z-a.z)*dz)/(dx*dx+dz*dz)));
  return Math.hypot(p.x-a.x-dx*t, p.z-a.z-dz*t);
}
// Independent full polygon/circle collision check, including rounded corners.
function fitsPolygon(p, polygon, radius = .36) {
  let inside = false;
  for (let i = 0, j = polygon.length-1; i < polygon.length; j = i++) {
    const a = polygon[i], b = polygon[j];
    if ((a.z > p.z) !== (b.z > p.z) && p.x < (b.x-a.x)*(p.z-a.z)/(b.z-a.z)+a.x) inside = !inside;
    if (segmentDistance(p, a, b) < radius-1e-9) return false;
  }
  return !inside;
}
function setup({ yaw = 0, reversed = false, vehicle = false } = {}) {
  const body = rectangle();
  body.polygon = body.polygon.map(p => rotate(p, yaw));
  if (reversed) body.polygon.reverse();
  if (vehicle) { body.vehicle = true; body.maxY = 1.6; body.standOff = .37; }
  const canOccupy = p => fitsPolygon(p, body.polygon);
  const cover = findCover({ position: { ...rotate({ x: 3, z: -1 }, yaw), y: 0 },
    direction: rotate({ x: 0, z: 1 }, yaw), bodies: [body], canOccupy });
  assert.ok(cover);
  return { body, cover, canOccupy };
}
let cases = 0;
function test(name, fn) { fn(); cases++; console.log(`PASS ${name}`); }

test('nearby cover is found while looking away, without extending distant acquisition', () => {
  const body = rectangle(), canOccupy = p => fitsPolygon(p, body.polygon);
  for (const yaw of [0, .7, Math.PI, 4.2]) {
    const result = findCover({ position: { x: 3, y: 0, z: -.6 }, direction: rotate({ x: 0, z: 1 }, yaw), bodies: [body], canOccupy });
    assert.ok(result); near(result.anchor.z, -.48);
  }
  assert.equal(findCover({ position: { x: 3, y: 0, z: -1 }, direction: { x: 0, z: -1 }, bodies: [body], canOccupy }), null);
});

test('default movement stops for peeking and corner transfer requires reaching an endpoint', () => {
  const { cover, canOccupy } = setup();
  assert.equal(advanceCoverCorner(cover, 1, .1, canOccupy), cover);
  const edge = moveCover(cover, 999, canOccupy);
  near(edge.along, edge.length-COVER.edgeMargin);
  assert.ok(!edge.cornerTravel);
  assert.equal(coverExposure(edge, { aiming: true, direction: { x: 1, z: .1 } }).mode, 'aimed');
  const transfer = advanceCoverCorner(edge, 1, .02, canOccupy);
  assert.ok(transfer.cornerTravel);
  assert.equal(moveCover(transfer, .5, canOccupy), transfer);
  for (const intent of [{}, { aiming: true }, { firing: true }]) {
    assert.equal(coverExposure(transfer, { ...intent, direction: { x: 1, z: 0 } }).mode, 'blocked');
  }
});

test('both sides, windings, rotations and vehicle standoffs follow continuous capsule-safe arcs', () => {
  for (const yaw of [0, .31, 1.7, 3.4, 5.8]) for (const reversed of [false, true])
    for (const vehicle of [false, true]) for (const side of [-1, 1]) {
      const { body, cover, canOccupy } = setup({ yaw, reversed, vehicle });
      const start = moveCover(cover, side*999, canOccupy);
      let current = start, moved = 0;
      for (let frame = 0; frame < 100; frame++) {
        let checks = 0;
        const next = advanceCoverCorner(current, side, .025, (p, height) => {
          checks++; near(height, vehicle ? COVER.crouchingHeight : COVER.standingHeight);
          return canOccupy(p);
        });
        assert.ok(checks <= 5, 'bounded capsule queries per frame');
        assert.ok(gap(current.anchor, next.anchor) <= .025000001, 'no position teleport');
        const normalAngle = Math.acos(Math.max(-1, Math.min(1, current.normal.x*next.normal.x+current.normal.z*next.normal.z)));
        assert.ok(normalAngle <= .025/(vehicle ? .37 : .48)+1e-6, 'normal rotates at arc speed');
        near(Math.hypot(next.normal.x, next.normal.z), 1);
        near(next.normal.x*next.tangent.x+next.normal.z*next.tangent.z, 0);
        // Densely check the actual linear movement between returned frame poses.
        for (let j = 0; j <= 10; j++) assert.ok(canOccupy({ x: current.anchor.x+(next.anchor.x-current.anchor.x)*j/10,
          y: 0, z: current.anchor.z+(next.anchor.z-current.anchor.z)*j/10 }));
        moved += gap(current.anchor, next.anchor);
        current = next;
        assert.equal(current.id, body.id); assert.equal(current.body, body);
        if (!current.cornerTravel && current.edgeIndex !== start.edgeIndex) break;
      }
      assert.ok(!current.cornerTravel);
      assert.equal(current.edgeIndex, (start.edgeIndex+side+4)%4);
      near(current.along, side > 0 ? COVER.edgeMargin : current.length-COVER.edgeMargin);
      assert.ok(moved > .8 && moved < 1.04);
    }
});

test('active transfer can retreat exactly to its source without switching body', () => {
  const { cover, canOccupy } = setup();
  const start = moveCover(cover, 999, canOccupy);
  const middle = advanceCoverCorner(start, 1, .5, canOccupy);
  assert.ok(middle.cornerTravel.progress > 0 && middle.cornerTravel.progress < 1);
  assert.equal(advanceCoverCorner(middle, -1, .1, canOccupy), middle);
  const restored = advanceCoverCorner(middle, 1, -99, canOccupy);
  assert.ok(!restored.cornerTravel); near(gap(restored.anchor, start.anchor), 0);
  assert.equal(restored.edgeIndex, start.edgeIndex);
});

test('acute and obtuse convex polygon corners preserve physical clearance', () => {
  for (const apex of [{ x: 2, z: 3 }, { x: 8, z: 3 }]) for (const side of [-1, 1]) {
    const body = { id: 'triangle', minY: 0, maxY: 3,
      polygon: [{ x: 0, z: 0 }, { x: 6, z: 0 }, apex] };
    const canOccupy = p => fitsPolygon(p, body.polygon);
    let cover = findCover({ position: { x: 3, y: 0, z: -.6 }, direction: { x: 0, z: 1 }, bodies: [body], canOccupy });
    cover = moveCover(cover, side*999, canOccupy);
    const sourceIndex = cover.edgeIndex;
    for (let frame = 0; frame < 160; frame++) {
      const next = advanceCoverCorner(cover, side, .02, canOccupy);
      assert.ok(canOccupy(next.anchor));
      assert.ok(gap(next.anchor, cover.anchor) <= .020000001);
      cover = next;
      if (cover.edgeIndex !== sourceIndex) break;
    }
    assert.ok(!cover.cornerTravel);
    assert.equal(cover.edgeIndex, (sourceIndex+side+3)%3);
  }
});

test('other solids and missing support stop the sweep before the blocked interval', () => {
  for (const forbidden of [p => p.x > 6.10 && p.x < 6.16, p => p.z > -.30]) {
    const { cover, canOccupy } = setup();
    const start = moveCover(cover, 999, canOccupy);
    const stopped = advanceCoverCorner(start, 1, 999, p => canOccupy(p) && !forbidden(p));
    assert.ok(stopped.cornerTravel);
    assert.ok(!forbidden(stopped.anchor));
    assert.ok(stopped.cornerTravel.progress < .7);
    const again = advanceCoverCorner(stopped, 1, .025, p => canOccupy(p) && !forbidden(p));
    assert.ok(!forbidden(again.anchor));
  }
});

test('invalidated or moved body cannot advance a stale corner', () => {
  for (const mutate of [b => { b.valid = false; }, b => { b.polygon[1].x += .2; }]) {
    const { body, cover, canOccupy } = setup();
    const edge = moveCover(cover, 999, canOccupy), middle = advanceCoverCorner(edge, 1, .3, canOccupy);
    mutate(body);
    assert.equal(advanceCoverCorner(middle, 1, .1, () => true), middle);
  }
});

test('concave inset does not become a diagonal corner shortcut', () => {
  const body = { id: 'L', minY: 0, maxY: 3, polygon: [
    { x: 0, z: 0 }, { x: 4, z: 0 }, { x: 4, z: 1 }, { x: 1, z: 1 }, { x: 1, z: 4 }, { x: 0, z: 4 }] };
  const cover = findCover({ position: { x: 2, y: 0, z: 1.6 }, direction: { x: 0, z: -1 }, bodies: [body], canOccupy: () => true });
  assert.equal(cover.edgeIndex, 2);
  const end = moveCover(cover, 999, () => true);
  assert.equal(advanceCoverCorner(end, 1, 999, () => true), end);
});

test('one request never skips another corner and callback work is bounded', () => {
  const { cover, canOccupy } = setup();
  const start = moveCover(cover, 999, canOccupy);
  let checks = 0;
  const end = advanceCoverCorner(start, 1, Number.MAX_VALUE, p => { checks++; return canOccupy(p); });
  assert.equal(end.edgeIndex, 1); assert.ok(!end.cornerTravel);
  assert.ok(checks <= 107);
});

// CPU-only hot-path report. No claim about whole-scene frame times or GPU load.
const fixture = setup(), edge = moveCover(fixture.cover, 999, fixture.canOccupy);
const middle = advanceCoverCorner(edge, 1, .35, fixture.canOccupy);
function bench(fn) {
  for (let i = 0; i < 1000; i++) fn();
  const samples = [];
  for (let batch = 0; batch < 25; batch++) {
    const t = performance.now();
    for (let i = 0; i < 1000; i++) fn();
    samples.push((performance.now()-t)/1000);
  }
  samples.sort((a, b) => a-b);
  return { p50_ms: samples[12], p95_ms: samples[23] };
}
console.log(JSON.stringify({ cpu_only: true, straight_25mm: bench(() => moveCover(fixture.cover, .025, fixture.canOccupy)),
  corner_25mm: bench(() => advanceCoverCorner(middle, 1, .025, fixture.canOccupy)) }));
console.log(`${cases} corner tests passed`);
