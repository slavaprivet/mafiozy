const TAU = Math.PI * 2;

export const THIRD_PERSON_CAMERA_DEFAULTS = Object.freeze({
  mouseSensitivity: 0.0027,
  zoomSensitivity: 0.0015,
  minPitch: 0.12,
  maxPitch: 1.08,
  targetDamping: 18,
  rotationDamping: 22,
  distanceDamping: 13,
  obstructionDamping: 34,
  minObstructionDistance: 1.15,
  modes: Object.freeze({
    world: Object.freeze({distance: 8.6, minDistance: 4.2, maxDistance: 14, pitch: 0.34, fov: 58}),
    vehicle: Object.freeze({distance: 11.5, minDistance: 6, maxDistance: 18, pitch: 0.38, fov: 64}),
    interior: Object.freeze({distance: 5.2, minDistance: 2.7, maxDistance: 7.2, pitch: 0.42, fov: 62}),
    mobile: Object.freeze({distance: 8, minDistance: 4, maxDistance: 12, pitch: 0.38, fov: 64}),
  }),
});

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));
const damp = (from, to, rate, dt) => from + (to - from) * (1 - Math.exp(-rate * dt));

export function normalizeAngle(angle) {
  if (!Number.isFinite(angle)) throw new Error('Camera angle must be finite');
  angle %= TAU;
  return angle > Math.PI ? angle - TAU : angle < -Math.PI ? angle + TAU : angle;
}

export function shortestAngleDelta(from, to) {
  return normalizeAngle(to - from);
}

function dampAngle(from, to, rate, dt) {
  return normalizeAngle(from + shortestAngleDelta(from, to) * (1 - Math.exp(-rate * dt)));
}

function finitePoint(point, label) {
  if (!point || ![point.x, point.y, point.z].every(Number.isFinite)) {
    throw new Error(`${label} must contain finite x, y and z`);
  }
  return {x: point.x, y: point.y, z: point.z};
}

function resolveConfig(overrides = {}) {
  const modes = {...THIRD_PERSON_CAMERA_DEFAULTS.modes, ...(overrides.modes || {})};
  return {...THIRD_PERSON_CAMERA_DEFAULTS, ...overrides, modes};
}

function resolveMode(config, requestedMode) {
  const mode = requestedMode && config.modes[requestedMode] ? requestedMode : 'world';
  const profile = config.modes[mode];
  if (!profile || ![profile.distance, profile.minDistance, profile.maxDistance, profile.pitch, profile.fov].every(Number.isFinite)) {
    throw new Error(`Invalid camera mode: ${mode}`);
  }
  return {mode, profile};
}

/**
 * Creates renderer-only camera state. No gameplay object is retained or mutated.
 * `heading` uses the Three.js player convention: 0 faces +Z, PI/2 faces +X.
 */
export function createThirdPersonCameraState({
  target = {x: 0, y: 1.6, z: 0},
  heading = 0,
  mode = 'world',
  config: overrides,
} = {}) {
  const config = resolveConfig(overrides);
  const resolved = resolveMode(config, mode);
  const focus = finitePoint(target, 'Camera target');
  if (!Number.isFinite(heading)) throw new Error('Camera heading must be finite');
  const yaw = normalizeAngle(heading);
  return {
    initialized: true,
    mode: resolved.mode,
    yaw,
    desiredYaw: yaw,
    pitch: resolved.profile.pitch,
    desiredPitch: resolved.profile.pitch,
    distance: resolved.profile.distance,
    desiredDistance: resolved.profile.distance,
    zoomScale: 1,
    target: focus,
    desiredTarget: {...focus},
    obstructed: false,
  };
}

/**
 * Advances a perspective follow camera without changing authoritative player data.
 * Pointer deltas are raw CSS pixels. `obstructionDistance` is supplied by the host
 * after a target-to-camera ray test; the pure controller only applies the result.
 */
export function stepThirdPersonCamera(previous, frame, overrides) {
  if (!previous?.initialized) throw new Error('Camera state is not initialized');
  if (!frame || !Number.isFinite(frame.dt) || frame.dt < 0) throw new Error('Camera dt must be finite and non-negative');
  const dt = Math.min(frame.dt, 0.1);
  const config = resolveConfig(overrides);
  const resolved = resolveMode(config, frame.mode || previous.mode);
  const desiredTarget = finitePoint(frame.target, 'Camera target');
  const heading = Number.isFinite(frame.heading) ? normalizeAngle(frame.heading) : previous.desiredYaw;
  const modeChanged = resolved.mode !== previous.mode;
  let desiredYaw = previous.desiredYaw;
  let desiredPitch = modeChanged ? resolved.profile.pitch : previous.desiredPitch;
  let zoomScale = modeChanged ? 1 : previous.zoomScale;

  if (frame.recenter) desiredYaw = heading;
  desiredYaw = normalizeAngle(desiredYaw + (Number.isFinite(frame.orbitX) ? frame.orbitX : 0) * config.mouseSensitivity);
  desiredPitch = clamp(
    desiredPitch + (Number.isFinite(frame.orbitY) ? frame.orbitY : 0) * config.mouseSensitivity,
    config.minPitch,
    config.maxPitch,
  );
  if (Number.isFinite(frame.zoomDelta) && frame.zoomDelta) {
    zoomScale *= Math.exp(frame.zoomDelta * config.zoomSensitivity);
  }
  const minZoomScale = resolved.profile.minDistance / resolved.profile.distance;
  const maxZoomScale = resolved.profile.maxDistance / resolved.profile.distance;
  zoomScale = clamp(zoomScale, minZoomScale, maxZoomScale);
  const desiredDistance = clamp(
    resolved.profile.distance * zoomScale,
    resolved.profile.minDistance,
    resolved.profile.maxDistance,
  );
  const obstructionDistance = Number.isFinite(frame.obstructionDistance)
    ? clamp(frame.obstructionDistance, config.minObstructionDistance, desiredDistance)
    : desiredDistance;
  const obstructed = obstructionDistance < desiredDistance - 1e-4;
  const snap = !!frame.snap || modeChanged;
  const target = snap ? desiredTarget : {
    x: damp(previous.target.x, desiredTarget.x, config.targetDamping, dt),
    y: damp(previous.target.y, desiredTarget.y, config.targetDamping, dt),
    z: damp(previous.target.z, desiredTarget.z, config.targetDamping, dt),
  };
  const yaw = snap ? desiredYaw : dampAngle(previous.yaw, desiredYaw, config.rotationDamping, dt);
  const pitch = snap ? desiredPitch : damp(previous.pitch, desiredPitch, config.rotationDamping, dt);
  // Pull in quickly when a wall is found, then ease back out to avoid popping.
  const distanceRate = obstructed ? config.obstructionDamping : config.distanceDamping;
  const distance = snap ? obstructionDistance : damp(previous.distance, obstructionDistance, distanceRate, dt);
  const horizontalDistance = Math.cos(pitch) * distance;
  const position = {
    x: target.x - Math.sin(yaw) * horizontalDistance,
    y: target.y + Math.sin(pitch) * distance,
    z: target.z - Math.cos(yaw) * horizontalDistance,
  };

  return {
    initialized: true,
    mode: resolved.mode,
    yaw,
    desiredYaw,
    pitch,
    desiredPitch,
    distance,
    desiredDistance,
    zoomScale,
    target,
    desiredTarget,
    position,
    fov: resolved.profile.fov,
    obstructed,
  };
}

export function cameraPose(state) {
  if (!state?.initialized) throw new Error('Camera state is not initialized');
  if (state.position) return {position: {...state.position}, target: {...state.target}, fov: state.fov};
  const horizontalDistance = Math.cos(state.pitch) * state.distance;
  return {
    position: {
      x: state.target.x - Math.sin(state.yaw) * horizontalDistance,
      y: state.target.y + Math.sin(state.pitch) * state.distance,
      z: state.target.z - Math.cos(state.yaw) * horizontalDistance,
    },
    target: {...state.target},
    fov: THIRD_PERSON_CAMERA_DEFAULTS.modes[state.mode]?.fov || THIRD_PERSON_CAMERA_DEFAULTS.modes.world.fov,
  };
}
