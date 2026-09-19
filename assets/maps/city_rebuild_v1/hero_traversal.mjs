// Pure world-space traversal planning. y is the character's feet/root height.
export const TRAVERSAL = Object.freeze({
  standingHeight: 1.9, carryHeight: 1.1, reach: .9, shoreReach: 2.2,
  maxRise: 1.65, vehicleMaxRise: 2.05, shoreMaxRise: 1.9, maxWidth: 2, clearance: .14,
  probeStep: .06, sweepStep: .04, supportRadius: .22, dryDepth: 0,
});
const clamp = value => Math.max(0, Math.min(1, value));
const smooth = value => { const t = clamp(value); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => a + (b - a) * t;

function surfaceAt(sample, x, z, referenceY) {
  const value = sample(x, z, referenceY);
  if (!value || !Number.isFinite(value.floor) || !Number.isFinite(value.waterDepth)) return null;
  return { ...value, surface: Math.max(value.floor, value.top === Infinity || Number.isFinite(value.top) ? value.top : -Infinity) };
}

function supportedDestination(point, sample, canOccupy, referenceY) {
  if (!canOccupy(point, TRAVERSAL.standingHeight)) return false;
  const r = TRAVERSAL.supportRadius;
  for (const [dx, dz] of [[0, 0], [r, 0], [-r, 0], [0, r], [0, -r]]) {
    const s = surfaceAt(sample, point.x + dx, point.z + dz, referenceY);
    if (!s || s.walkable === false || s.waterDepth > TRAVERSAL.dryDepth || Math.abs(s.surface - point.y) > .16) return false;
  }
  return true;
}

/** Return a dry, supported vault/mantle/shore plan, or null when unsafe.
 * sample(x,z,referenceY) gives {floor,waterDepth,top?,walkable?}; top must include the
 * highest static obstacle at that point. canOccupy checks the whole capsule.
 */
export function planTraversal({ position, direction, swimming = false, sample, canOccupy }) {
  if (!position || !direction || typeof sample !== 'function' || typeof canOccupy !== 'function') return null;
  if (![position.x, position.y, position.z, direction.x, direction.z].every(Number.isFinite)) return null;
  const length = Math.hypot(direction.x, direction.z);
  if (length < .001 || !canOccupy(position, TRAVERSAL.standingHeight)) return null;
  const heading = { x: direction.x / length, z: direction.z / length };
  const reach = swimming ? TRAVERSAL.shoreReach : TRAVERSAL.reach;
  const maxRise = swimming ? TRAVERSAL.shoreMaxRise : TRAVERSAL.maxRise;
  let firstObstacle = null, highest = position.y, mantle = null, edge = null;
  const maxDistance = reach + TRAVERSAL.maxWidth + .5;
  for (let distance = TRAVERSAL.probeStep; distance <= maxDistance; distance += TRAVERSAL.probeStep) {
    const x = position.x + heading.x * distance, z = position.z + heading.z * distance;
    const s = surfaceAt(sample, x, z, position.y);
    if (!s) break;
    const rise = s.surface - position.y;
    // A roof or tall wall may never be skipped in search of a far-side landing.
    const allowedRise = !swimming && s.supportKind === 'vehicle' ? TRAVERSAL.vehicleMaxRise : maxRise;
    if (rise > allowedRise + 1e-6) break;
    highest = Math.max(highest, s.surface);
    if (!edge && (rise > .24 || swimming && s.waterDepth <= TRAVERSAL.dryDepth)) edge = { x, y: s.surface, z };
    if (firstObstacle === null) {
      const obstacle = swimming
        ? s.waterDepth <= TRAVERSAL.dryDepth && rise >= -.4
        : rise > .24 || !canOccupy({ x, y: position.y, z }, TRAVERSAL.standingHeight);
      if (!obstacle) { if (distance > reach) break; continue; }
      if (distance > reach + TRAVERSAL.probeStep) break;
      firstObstacle = distance;
    }
    if (distance - firstObstacle > TRAVERSAL.maxWidth + .45) break;
    if (s.waterDepth > TRAVERSAL.dryDepth || rise < -.45) continue;
    const destination = { x, y: s.surface, z };
    if (!supportedDestination(destination, sample, canOccupy, position.y)) continue;
    const kind = swimming ? 'shore' : rise > .24 ? 'mantle' : 'vault';
    const plan = {
      kind, start: { x: position.x, y: position.y, z: position.z }, destination,
      edge: edge ? { ...edge } : { ...destination },
      direction: heading, clearanceY: highest + TRAVERSAL.clearance,
      duration: Math.max(.85, Math.min(1.25, .76 + Math.max(0, rise) * .15 + distance * .07)),
    };
    if (!safeInterval(plan, 0, 1, canOccupy).safe) continue;
    // A cabin roof is a destination: do not automatically throw the player
    // over it when a supported pull-up is available. Low bonnets still vault.
    if (kind === 'mantle') { if (s.supportKind === 'vehicle' && rise > 1.1) return plan; mantle ??= plan; continue; }
    return plan;
  }
  return mantle;
}

/** Lift before translating, carry above the obstacle, then lower onto support. */
export function sampleTraversal(plan, progress) {
  const p = clamp(progress), { start, destination } = plan;
  let travel = 0, y;
  if (p < .28) y = mix(start.y, plan.clearanceY, smooth(p / .28));
  else if (p < .76) { travel = smooth((p - .28) / .48); y = plan.clearanceY; }
  else { travel = 1; y = mix(plan.clearanceY, destination.y, smooth((p - .76) / .24)); }
  const crouch = Math.min(smooth(p / .2), 1 - smooth((p - .76) / .24));
  return {
    x: mix(start.x, destination.x, travel), y, z: mix(start.z, destination.z, travel),
    progress: p, kind: plan.kind, height: mix(TRAVERSAL.standingHeight, TRAVERSAL.carryHeight, crouch),
    direction: plan.direction,
  };
}

function safeInterval(plan, from, to, canOccupy) {
  // Smoothstep has maximum derivative 1.5. Sampling a conservative velocity
  // bound also checks thin blockers between frames, even for a large dt.
  const horizontal = Math.hypot(plan.destination.x - plan.start.x, plan.destination.z - plan.start.z);
  const rate = Math.max(Math.abs(plan.clearanceY - plan.start.y) / .28,
    horizontal / .48, Math.abs(plan.clearanceY - plan.destination.y) / .24,
    (TRAVERSAL.standingHeight - TRAVERSAL.carryHeight) / .2) * 1.5;
  const count = Math.max(1, Math.ceil((to - from) * rate / TRAVERSAL.sweepStep));
  let last = sampleTraversal(plan, from);
  for (let i = 1; i <= count; i++) {
    const next = sampleTraversal(plan, mix(from, to, i / count));
    if (!canOccupy(next, next.height)) return { safe: false, last };
    last = next;
  }
  return { safe: true, last };
}

/** Dynamic blockers terminate at the last safe root; host resumes gravity. */
export function stepTraversal(state, dt, canOccupy) {
  if (!Number.isFinite(dt) || dt < 0) throw new Error('Invalid traversal time');
  if (state.done) return state;
  const elapsed = Math.min(state.duration, (state.elapsed ?? 0) + dt);
  const from = clamp((state.elapsed ?? 0) / state.duration), to = clamp(elapsed / state.duration);
  const sweep = safeInterval(state, from, to, canOccupy);
  return { ...state, ...sweep.last, elapsed: sweep.safe ? elapsed : sweep.last.progress * state.duration,
    done: !sweep.safe || to >= 1, blocked: !sweep.safe };
}
