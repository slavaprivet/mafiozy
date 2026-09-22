// Presentation boundary only. The host must create this record at the accepted
// fatal transition, after survival/downed decisions or a matched server ACK.
// This module neither authenticates messages nor creates a death from HP/hits.
const causes = new Set(['bullet', 'melee', 'super', 'kick', 'dropkick', 'blast', 'fire', 'vehicle', 'bleedout']);
const text = value => typeof value === 'string' && value.length > 0 && value.length <= 256;
const point = value => value && ['x', 'y', 'z'].every(axis => Number.isFinite(value[axis]));
const unknown = reason => Object.freeze({known: false, cause: 'unknown', reason});

/**
 * record v1: {confirmed:true, fatal:true, targetId, eventId, deathKey, cause,
 *   travelWorld?:{x,y,z}, pointWorldMeters?:{x,y,z}}
 * deathKey is the exact source lifecycle epoch, never a recent-hit timestamp.
 * travelWorld points in the impact's travel direction (away from an explosion).
 * It is normalized to a dimensionless vector; it is NOT a surface normal.
 * Optional contact positions are already metres in Walk coordinates:
 * +X = increasing source column, +Z = increasing source row, +Y = up.
 * yaw is the actor's Three.js rotation about +Y in radians. Local +Z is forward.
 * Missing geometry stays null. Never invent blast force from weapon or HP.
 */
export function normalizeNpcDeathProfile({targetId, lifecycle, record, yaw} = {}) {
  if (lifecycle?.dead !== true) return unknown('not-dead');
  if (!text(targetId) || !text(lifecycle.key) || lifecycle.key === 'dead') return unknown('unbound-epoch');
  if (!record || record.version !== 1 || record.confirmed !== true || record.fatal !== true) return unknown('unconfirmed-record');
  if (record.targetId !== targetId || record.deathKey !== lifecycle.key || !text(record.eventId)) return unknown('identity-mismatch');
  if (!causes.has(record.cause)) return unknown('unsupported-cause');
  let directionWorld = null, directionLocal = null, pointWorldMeters = null;
  if (record.travelWorld != null) {
    if (!point(record.travelWorld)) return unknown('invalid-direction');
    const {x, y, z} = record.travelWorld, length = Math.hypot(x, y, z);
    if (!Number.isFinite(length) || length <= 1e-8) return unknown('invalid-direction');
    directionWorld = Object.freeze({x: x / length, y: y / length, z: z / length});
    if (Number.isFinite(yaw)) {
      const c = Math.cos(yaw), s = Math.sin(yaw);
      directionLocal = Object.freeze({x: c * directionWorld.x - s * directionWorld.z, y: directionWorld.y, z: s * directionWorld.x + c * directionWorld.z});
    }
  }
  if (record.pointWorldMeters != null) {
    if (!point(record.pointWorldMeters)) return unknown('invalid-contact');
    pointWorldMeters = Object.freeze({x: record.pointWorldMeters.x, y: record.pointWorldMeters.y, z: record.pointWorldMeters.z});
  }
  return Object.freeze({known: true, cause: record.cause, targetId, eventId: record.eventId,
    deathKey: record.deathKey, directionWorld, directionLocal, pointWorldMeters});
}
