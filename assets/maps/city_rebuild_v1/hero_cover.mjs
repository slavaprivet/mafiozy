// Contextual cover geometry in metres. Anchors are physical feet positions;
// exposure offsets belong to the visual pose, never to the collision root.
export const COVER = Object.freeze({
  distance: 1.5, standOff: .48, minHeight: .75, lowHeight: 1.5,
  standingHeight: 1.9, crouchingHeight: 1.69, edgeMargin: .14,
  cornerReach: .7, sweepStep: .06, muzzleClearance: .22,
});
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const finitePoint = p => p && Number.isFinite(p.x) && Number.isFinite(p.z);
const zero = () => ({ x: 0, y: 0, z: 0 });

function inside(point, polygon) {
  let hit = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i], b = polygon[j];
    if ((a.z > point.z) !== (b.z > point.z) && point.x < (b.x - a.x) * (point.z - a.z) / (b.z - a.z) + a.x) hit = !hit;
  }
  return hit;
}

function swept(from, to, height, canOccupy) {
  if (typeof canOccupy !== 'function') return false;
  const count = Math.max(1, Math.ceil(Math.hypot(to.x - from.x, to.y - from.y, to.z - from.z) / COVER.sweepStep));
  for (let i = 0; i <= count; i++) {
    const t = i / count;
    if (!canOccupy({ x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t, z: from.z + (to.z - from.z) * t }, height)) return false;
  }
  return true;
}

/** bodies: [{id,polygon:[{x,z}],minY,maxY,vehicle?,valid?}]. Polygon winding
 * may be either direction. canOccupy(point,height) must check the full capsule,
 * solid geometry, ground support, water and other actors. */
export function findCover({ position, direction, bodies, canOccupy, maxDistance = COVER.distance } = {}) {
  if (!finitePoint(position) || !Number.isFinite(position.y) || !finitePoint(direction) || !Array.isArray(bodies) || !Number.isFinite(maxDistance) || maxDistance <= 0) return null;
  const headingLength = Math.hypot(direction.x, direction.z);
  if (headingLength < .001) return null;
  const heading = { x: direction.x / headingLength, z: direction.z / headingLength };
  let best = null, bestScore = Infinity;
  for (const body of bodies) {
    const polygon = body?.polygon;
    if (body?.valid === false || !Array.isArray(polygon) || polygon.length < 3 || !polygon.every(finitePoint)) continue;
    if (!Number.isFinite(body.minY) || !(Number.isFinite(body.maxY) || body.maxY === Infinity) || body.minY > position.y + .45 || body.maxY - position.y < COVER.minHeight || inside(position, polygon)) continue;
    const area = polygon.reduce((sum, a, i) => { const b = polygon[(i + 1) % polygon.length]; return sum + a.x * b.z - b.x * a.z; }, 0);
    if (Math.abs(area) < .001) continue;
    const height = body.maxY - position.y;
    const standOff = Number.isFinite(body.standOff) ? clamp(body.standOff, .37, COVER.standOff) : COVER.standOff;
    const posture = body.vehicle || height <= COVER.lowHeight ? 'crouch' : 'stand';
    const capsuleHeight = posture === 'crouch' ? COVER.crouchingHeight : COVER.standingHeight;
    for (let i = 0; i < polygon.length; i++) {
      const a = polygon[i], b = polygon[(i + 1) % polygon.length];
      const length = Math.hypot(b.x - a.x, b.z - a.z);
      if (length < .6) continue;
      const tangent = { x: (b.x - a.x) / length, z: (b.z - a.z) / length };
      const winding = Math.sign(area);
      const normal = { x: tangent.z * winding, z: -tangent.x * winding };
      const outwardDistance = (position.x - a.x) * normal.x + (position.z - a.z) * normal.z;
      if (outwardDistance < .02 || outwardDistance > maxDistance + standOff) continue;
      const facing = heading.x * normal.x + heading.z * normal.z;
      if (facing > .65) continue;
      const rawAlong = (position.x - a.x) * tangent.x + (position.z - a.z) * tangent.z;
      const along = clamp(rawAlong, COVER.edgeMargin, length - COVER.edgeMargin);
      const anchor = { x: a.x + tangent.x * along + normal.x * standOff, y: position.y, z: a.z + tangent.z * along + normal.z * standOff };
      const distance = Math.hypot(anchor.x - position.x, anchor.z - position.z);
      if (distance > maxDistance || inside(anchor, polygon) || !swept(position, anchor, capsuleHeight, canOccupy)) continue;
      const score = distance + (facing + 1) * .18;
      if (score < bestScore) {
        bestScore = score;
        best = { id: body.id, body, a: { ...a }, b: { ...b }, normal, tangent, anchor, feetY: position.y, height, posture, length, along, standOff };
      }
    }
  }
  return best;
}

/** Slide along this edge only. Stops at the last safe sample if a pedestrian,
 * doorway edge or another vehicle blocks motion during this frame. */
export function moveCover(cover, amount, canOccupy) {
  if (!cover || !Number.isFinite(amount) || typeof canOccupy !== 'function') return cover;
  const along = clamp(cover.along + amount, COVER.edgeMargin, cover.length - COVER.edgeMargin);
  const distance = along - cover.along;
  const steps = Math.max(1, Math.ceil(Math.abs(distance) / COVER.sweepStep));
  const height = cover.posture === 'crouch' ? COVER.crouchingHeight : COVER.standingHeight;
  let result = cover;
  for (let i = 1; i <= steps; i++) {
    const nextAlong = cover.along + distance * i / steps;
    const anchor = { x: cover.a.x + cover.tangent.x * nextAlong + cover.normal.x * (cover.standOff ?? COVER.standOff), y: cover.feetY, z: cover.a.z + cover.tangent.z * nextAlong + cover.normal.z * (cover.standOff ?? COVER.standOff) };
    if (!canOccupy(anchor, height)) break;
    result = { ...cover, along: nextAlong, anchor };
  }
  return result;
}

/** Direction is the intended shot heading. Aimed mode exposes the body;
 * blind mode leaves the body at its anchor and reaches only the weapon out.
 * muzzle is a world point, gunOffset is relative to the hidden shoulder.
 * Host must validate pose/capsule clearance and raycast actual projectiles. */
export function coverExposure(cover, { aiming = false, firing = false, direction } = {}) {
  if (!cover) return null;
  const base = { mode: 'hidden', offset: zero(), gunOffset: zero(), side: 0, posture: cover.posture, muzzle: null, bodyExposed: false };
  if (!aiming && !firing) return base;
  if (!finitePoint(direction) || Math.hypot(direction.x, direction.z) < .001) return { ...base, mode: 'blocked' };
  const magnitude = Math.hypot(direction.x, direction.z);
  const facing = (direction.x * cover.normal.x + direction.z * cover.normal.z) / magnitude;
  if (facing > .65) return { ...base, mode: 'blocked' };
  const mode = aiming ? 'aimed' : 'blind';
  const shoulderY = cover.feetY + (cover.posture === 'crouch' ? .94 : 1.42);
  // A crouching shoulder cannot lift a gun over a 1.5 m wall without exposing
  // the torso. Blind fire uses a reachable top or a nearby corner instead.
  const vehicleCorner = cover.body?.vehicle && Math.min(cover.along, cover.length-cover.along) <= COVER.cornerReach;
  if (!vehicleCorner && cover.height <= COVER.lowHeight && (aiming || cover.height <= 1.28)) {
    const muzzle = {
      x: cover.anchor.x - cover.normal.x * .3,
      y: cover.feetY + Math.max(aiming ? 1.57 : 1.1, cover.height + COVER.muzzleClearance),
      z: cover.anchor.z - cover.normal.z * .3,
    };
    return { ...base, mode, posture: aiming ? 'stand' : 'crouch', bodyExposed: aiming, muzzle,
      gunOffset: { x: muzzle.x - cover.anchor.x, y: muzzle.y - shoulderY, z: muzzle.z - cover.anchor.z } };
  }
  const lateral = (direction.x * cover.tangent.x + direction.z * cover.tangent.z) / magnitude;
  const sides = [{ side: -1, distance: cover.along }, { side: 1, distance: cover.length - cover.along }]
    .filter(v => v.distance <= COVER.cornerReach && lateral * v.side >= -.15)
    .sort((a, b) => a.distance - b.distance);
  if (!sides.length) return { ...base, mode: 'blocked' };
  const { side, distance } = sides[0];
  const reach = distance + COVER.muzzleClearance;
  // A blind arm cannot reach a distant corner while its shoulder stays hidden.
  if (!aiming && reach > .66) return { ...base, mode: 'blocked' };
  const offset = aiming ? { x: cover.tangent.x * side * (reach+.20), y: 0, z: cover.tangent.z * side * (reach+.20) } : zero();
  const muzzle = {
    x: cover.anchor.x + cover.tangent.x * side * reach - cover.normal.x * .15,
    y: shoulderY + .08,
    z: cover.anchor.z + cover.tangent.z * side * reach - cover.normal.z * .15,
  };
  return { ...base, mode, side, offset, muzzle, bodyExposed: aiming,
    gunOffset: { x: muzzle.x - cover.anchor.x, y: muzzle.y - shoulderY, z: muzzle.z - cover.anchor.z } };
}
