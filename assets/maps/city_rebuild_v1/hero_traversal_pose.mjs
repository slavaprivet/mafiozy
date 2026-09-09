// Presentation only. The host resets/poses the hero first and owns collision,
// root translation/yaw and weapon visibility. Distances are world metres.
const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
const smooth = (a, b, n) => { const t = clamp((n - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };

/** sample: {progress, kind:'vault'|'mantle'|'shore', direction:{x,z},
 * obstacleHeight?, edge?, start?, optional handL/handR fixed world contacts}.
 * sample.height is the collision capsule, never the obstacle height.
 * Returns false for absent/invalid data; never calls groundPose or changes root.
 */
export function applyTraversalPose(THREE, context, sample) {
  if (!THREE || !context?.bones || !context.reachPalm || !Number.isFinite(sample?.progress)) return false;
  const p = clamp(sample.progress, 0, 1);
  const weight = smooth(0, .22, p) * (1 - smooth(.68, 1, p));
  if (weight === 0) return true;
  const c = context, unit = c.targetHeight / 1.9;
  const obstacleHeight = Number.isFinite(sample.obstacleHeight) ? sample.obstacleHeight
    : Number.isFinite(sample.edge?.y) && Number.isFinite(sample.start?.y) ? sample.edge.y - sample.start.y : .8;
  const height = clamp(obstacleHeight / unit, .15, 1.85);
  const vault = sample.kind === 'vault', shore = sample.kind === 'shore';
  const pull = smooth(.12, .52, p), over = smooth(.36, .77, p);
  // Blend the completed IK pose against the supplied base, rather than moving
  // the IK target a tiny distance: that also prevents elbow pops at entry/exit.
  const before = new Map();
  for (const name of ['chest','neck','head', ...['l','r'].flatMap(s =>
    ['thigh','shin','foot','upperarm','forearm','hand'].map(n => `${n}_${s}`))]) {
    const bone = c.bones[name];
    if (bone) { const pos = new THREE.Vector3(), q = new THREE.Quaternion(), scale = new THREE.Vector3(); bone.matrix.decompose(pos, q, scale); before.set(name, {pos, q, scale}); }
  }
  const chest = (vault ? .35 : .22) + over * .2;
  c.rotate('chest', chest);
  c.rotate('neck', -chest * .55);
  c.rotate('head', -chest * .35);
  for (const [side, lead] of [['l', 1], ['r', 0]]) {
    // One knee reaches the ledge first; the trailing leg follows through.
    const tuck = smooth(lead ? .07 : .2, lead ? .42 : .55, p);
    const unfold = 1 - smooth(lead ? .53 : .64, .94, p);
    const fold = tuck * unfold;
    c.rotate(`thigh_${side}`, -(vault ? 1.32 : 1.52) * fold, 0, (side === 'l' ? -.1 : .1) * fold);
    c.rotate(`shin_${side}`, (vault ? 1.7 : 1.92) * fold);
    c.rotate(`foot_${side}`, -.28 * fold);
  }
  c.object.updateMatrixWorld(true);
  const rootQ = c.object.getWorldQuaternion(new THREE.Quaternion());
  const forward = new THREE.Vector3(sample.direction?.x || 0, 0, sample.direction?.z || 0);
  if (!Number.isFinite(forward.lengthSq()) || forward.lengthSq() < 1e-8) forward.set(0, 0, 1).applyQuaternion(rootQ).setY(0);
  forward.normalize();
  const right = new THREE.Vector3(forward.z, 0, -forward.x);
  const root = c.object.getWorldPosition(new THREE.Vector3());
  // The fallback is a bent-arm balance pose after releasing the ledge.
  // Lift-first movement makes a low ledge unreachable early: do not keep
  // dragging the palms down to it as the physical feet clear its top.
  const palmHeight = (vault ? 1.08 : 1.27 + height * .14) - pull * (shore ? .42 : .32);
  const palmDepth = .43 - over * .24;
  const edgeContacts = [];
  for (const [side, sign] of [['l', -1], ['r', 1]]) {
    const explicit = side === 'l' ? sample.handL : sample.handR;
    const valid = point => point && ['x','y','z'].every(k => Number.isFinite(point[k]));
    const target = root.clone().addScaledVector(forward, palmDepth * unit).addScaledVector(right, sign * .27 * unit).add(new THREE.Vector3(0, palmHeight * unit, 0));
    const contact = valid(explicit) ? new THREE.Vector3(explicit.x, explicit.y, explicit.z)
      : valid(sample.edge) ? new THREE.Vector3(sample.edge.x, sample.edge.y + .025 * unit, sample.edge.z)
        .addScaledVector(right, sign * .27 * unit).addScaledVector(forward, .025 * unit) : null;
    const baseQ = c.bones[`hand_${side}`].getWorldQuaternion(new THREE.Quaternion());
    const palmTurn = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), -Math.PI / 2);
    const handQ = rootQ.clone().multiply(palmTurn).multiply(rootQ.clone().invert()).multiply(baseQ);
    if (contact) {
      const shoulder = c.worldPosition(`upperarm_${side}`);
      const elbow = c.worldPosition(`forearm_${side}`), wrist = c.worldPosition(`hand_${side}`);
      const reach = shoulder.distanceTo(elbow) + elbow.distanceTo(wrist);
      const wristOffset = c.rest[`socket_hand_${side}`].p.clone().multiplyScalar(c.targetHeight / c.sourceHeight).applyQuaternion(handQ);
      const distance = contact.clone().sub(wristOffset).distanceTo(shoulder);
      // Smoothly leave contact before the arm reaches full extension; a very
      // distant shore edge never attracts the hands in the first place.
      const reachWeight = 1 - smooth(reach * (valid(explicit) ? .86 : .3), reach * .995, distance);
      const phaseWeight = valid(explicit) ? 1 : 1 - smooth(.18, .4, p);
      const aboveFeet = 1 - smooth(.35 * unit, .8 * unit, root.y + .8 * unit - contact.y);
      const contactWeight = reachWeight * phaseWeight * aboveFeet;
      if (valid(explicit)) target.lerp(contact, contactWeight);
      else edgeContacts.push({side,contact,handQ,weight:contactWeight});
    }
    c.reachPalm(side, target, handQ);
  }
  for (const [name, base] of before) {
    const bone = c.bones[name], q = new THREE.Quaternion();
    bone.matrix.decompose(new THREE.Vector3(), q, new THREE.Vector3());
    const arm = /^(upperarm|forearm|hand)_/.test(name);
    const blend = arm && sample.edge ? smooth(0, .2, p) * (1 - smooth(.68, 1, p)) : weight;
    bone.matrix.compose(base.pos, base.q.slerp(q, blend), base.scale);
    bone.matrixWorldNeedsUpdate = true;
  }
  c.object.updateMatrixWorld(true);
  // Blend edge contact from the already bent-arm fallback. Blending directly
  // from a straight rest arm to IK can switch shortest rotation at 180 degrees
  // while the shoulder passes a ledge, producing a visible elbow snap.
  for (const contact of edgeContacts) {
    const blend = contact.weight * smooth(0, .2, p) * (1 - smooth(.68, 1, p));
    if (blend < 1e-7) continue;
    const saved = new Map();
    for (const part of ['upperarm','forearm','hand']) {
      const name = `${part}_${contact.side}`, bone = c.bones[name];
      const pos = new THREE.Vector3(), q = new THREE.Quaternion(), scale = new THREE.Vector3();
      bone.matrix.decompose(pos,q,scale); saved.set(name,{pos,q,scale});
    }
    c.reachPalm(contact.side,contact.contact,contact.handQ);
    for (const [name,base] of saved) {
      const bone=c.bones[name],q=new THREE.Quaternion();
      bone.matrix.decompose(new THREE.Vector3(),q,new THREE.Vector3());
      bone.matrix.compose(base.pos,base.q.slerp(q,blend),base.scale);bone.matrixWorldNeedsUpdate=true;
    }
    c.object.updateMatrixWorld(true);
  }
  return true;
}
