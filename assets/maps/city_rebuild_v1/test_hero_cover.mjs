import assert from 'node:assert/strict';
import { COVER, findCover, moveCover, coverExposure } from './hero_cover.mjs';

const rectangle = (height = 3, extras = {}) => ({ id: 'wall', minY: 0, maxY: height,
  polygon: [{ x: 0, z: 0 }, { x: 6, z: 0 }, { x: 6, z: 2 }, { x: 0, z: 2 }], ...extras });
const close = (a, b) => assert.ok(Math.abs(a - b) < 1e-8, `${a} != ${b}`);
const fits = p => p.z <= -.25 || p.z >= 2.25 || p.x <= -.25 || p.x >= 6.25;
const acquire = (body = rectangle(), extras = {}) => findCover({
  position: { x: 3, y: 0, z: -1 }, direction: { x: 0, z: 1 }, bodies: [body], canOccupy: fits, ...extras,
});

let cases = 0;
function test(name, fn) { fn(); cases++; console.log(`PASS ${name}`); }

test('wall attaches to exterior and faces the obstacle for both polygon windings', () => {
  for (const polygon of [rectangle().polygon, rectangle().polygon.toReversed()]) {
    const cover = acquire(rectangle(3, { polygon }));
    assert.equal(cover.posture, 'stand'); close(cover.anchor.z, -.48);
    close(cover.anchor.x, 3); close(cover.normal.z, -1); close(cover.height, 3);
    assert.ok(cover.along >= COVER.edgeMargin);
  }
});

test('cars and low objects choose crouch while curb/overhead bodies do not attach', () => {
  assert.equal(acquire(rectangle(1.1)).posture, 'crouch');
  assert.equal(acquire(rectangle(1.8, { vehicle: true })).posture, 'crouch');
  assert.equal(acquire(rectangle(.74)), null);
  assert.equal(acquire(rectangle(3, { minY: .46 })), null);
  assert.equal(acquire(rectangle(3, { valid: false })), null);
  assert.equal(acquire(rectangle(3, { minY: NaN })), null);
  assert.equal(acquire(rectangle(Infinity)).posture, 'stand');
  assert.equal(acquire(rectangle(3, { minY: 2 }), { position: { x: 3, y: 2, z: -1 } }).posture, 'crouch');
});

test('invalid, inside, distant and facing-away requests do not teleport into cover', () => {
  assert.equal(findCover(), null);
  assert.equal(acquire(rectangle(), { direction: { x: 0, z: 0 } }), null);
  assert.equal(acquire(rectangle(), { direction: { x: 0, z: -1 } }), null);
  assert.equal(acquire(rectangle(), { position: { x: 3, y: 0, z: 1 } }), null);
  assert.equal(acquire(rectangle(), { position: { x: 3, y: 0, z: -3 } }), null);
  assert.equal(acquire(rectangle(), { canOccupy: undefined }), null);
});

test('approach checks the entire swept path and crouched capsule height', () => {
  let checks = 0;
  assert.equal(acquire(rectangle(), { canOccupy: p => { checks++; return Math.abs(p.z + .75) > .04 && fits(p); } }), null);
  assert.ok(checks >= 3);
  const heights = [];
  assert.ok(acquire(rectangle(1), { canOccupy: (p, h) => { heights.push(h); return fits(p); } }));
  assert.ok(heights.length >= 9 && heights.every(h => h === 1.69));
});

test('movement stays on the selected edge and stops before a thin new blocker', () => {
  const cover = acquire();
  const end = moveCover(cover, 999, fits);
  close(end.along, end.length - COVER.edgeMargin);
  close(end.anchor.z, -.48);
  const start = moveCover(end, -999, fits);
  close(start.along, COVER.edgeMargin);
  const stopped = moveCover(cover, 2, p => fits(p) && p.x < 3.8);
  assert.ok(stopped.anchor.x < 3.8 && stopped.anchor.x > 3.7);
  assert.equal(moveCover(cover, Infinity, fits), cover);
});

test('tall wall middle is protected but cannot fire through the wall', () => {
  const cover = acquire();
  assert.equal(coverExposure(cover).mode, 'hidden');
  for (const aiming of [true, false]) {
    const exposure = coverExposure(cover, { aiming, firing: true, direction: { x: 0, z: 1 } });
    assert.equal(exposure.mode, 'blocked'); assert.equal(exposure.muzzle, null);
  }
});

test('aimed corner exposes body, blind corner exposes only a reachable weapon', () => {
  for (const end of [-1, 1]) {
    const cover = moveCover(acquire(), end * 999, fits);
    const aimed = coverExposure(cover, { aiming: true, direction: { x: 0, z: 1 } });
    const blind = coverExposure(cover, { firing: true, direction: { x: 0, z: 1 } });
    assert.equal(aimed.mode, 'aimed'); assert.equal(aimed.side, end); assert.equal(aimed.bodyExposed, true);
    assert.ok(Math.abs(aimed.offset.x) > .3);
    assert.equal(blind.mode, 'blind'); assert.equal(blind.bodyExposed, false); assert.deepEqual(blind.offset, { x: 0, y: 0, z: 0 });
    assert.ok(Math.hypot(blind.gunOffset.x, blind.gunOffset.y, blind.gunOffset.z) <= .7);
    assert.ok(blind.muzzle.x < 0 || blind.muzzle.x > 6);
    assert.equal(coverExposure(cover, { aiming: true, direction: { x: -end, z: .1 } }).mode, 'blocked');
  }
});

test('low cover aims over the top and blind firing stays crouched', () => {
  const cover = acquire(rectangle(1.15));
  const aimed = coverExposure(cover, { aiming: true, direction: { x: 0, z: 1 } });
  const blind = coverExposure(cover, { firing: true, direction: { x: 0, z: 1 } });
  assert.equal(aimed.posture, 'stand'); assert.equal(aimed.bodyExposed, true);
  assert.equal(blind.posture, 'crouch'); assert.equal(blind.bodyExposed, false);
  assert.ok(aimed.muzzle.y > cover.height && blind.muzzle.y > cover.height);
  assert.ok(Math.hypot(blind.gunOffset.x, blind.gunOffset.y, blind.gunOffset.z) <= .66);
  assert.equal(coverExposure(acquire(rectangle(1.45)), { firing: true, direction: { x: 0, z: 1 } }).mode, 'blocked');
  assert.equal(coverExposure(acquire(rectangle(1.45)), { aiming: true, direction: { x: 0, z: 1 } }).mode, 'aimed');
});

test('far corner permits body peek but refuses an impossible stretched blind arm', () => {
  const cover = moveCover(acquire(), -2.4, fits);
  assert.equal(coverExposure(cover, { aiming: true, direction: { x: 0, z: 1 } }).mode, 'aimed');
  assert.equal(coverExposure(cover, { firing: true, direction: { x: 0, z: 1 } }).mode, 'blocked');
});

test('rotated cover preserves outward normals and corner muzzle clearance', () => {
  for (let angle = 0; angle < Math.PI * 2; angle += .15) {
    const rotate = p => ({ x: p.x * Math.cos(angle) - p.z * Math.sin(angle) + 20, z: p.x * Math.sin(angle) + p.z * Math.cos(angle) - 7 });
    const body = rectangle(3, { polygon: rectangle().polygon.map(rotate) });
    const direction = { x: -Math.sin(angle), z: Math.cos(angle) };
    const position = { ...rotate({ x: .2, z: -1 }), y: 0 };
    const cover = findCover({ position, direction, bodies: [body], canOccupy: () => true });
    assert.ok(cover);
    const exp = coverExposure(cover, { aiming: true, direction });
    assert.equal(exp.mode, 'aimed');
    close(exp.offset.x * cover.normal.x + exp.offset.z * cover.normal.z, 0);
    const muzzleAlong = (exp.muzzle.x - cover.a.x) * cover.tangent.x + (exp.muzzle.z - cover.a.z) * cover.tangent.z;
    assert.ok(muzzleAlong < 0 || muzzleAlong > cover.length);
  }
});

test('body selection skips invalid nearest objects and handles concave outlines', () => {
  const concave = { id: 'L', minY: 0, maxY: 3, polygon: [{ x: 0, z: 0 }, { x: 6, z: 0 }, { x: 6, z: 2 }, { x: 2, z: 2 }, { x: 2, z: 6 }, { x: 0, z: 6 }] };
  const cover = acquire(concave, { bodies: [rectangle(3, { id: 'stale', valid: false }), concave] });
  assert.equal(cover.id, 'L'); close(cover.anchor.z, -.48);
  const inner = findCover({ position: { x: 3, y: 0, z: 3 }, direction: { x: -1, z: 0 }, bodies: [concave], canOccupy: p => p.x >= 2.25 && p.z >= 2.25 });
  assert.ok(inner); close(inner.anchor.x, 2.48); close(inner.normal.x, 1);
});

console.log(`${cases} contextual cover geometry cases passed.`);
