import assert from 'node:assert/strict';
import {
  THIRD_PERSON_CAMERA_DEFAULTS,
  cameraPose,
  createThirdPersonCameraState,
  normalizeAngle,
  shortestAngleDelta,
  stepThirdPersonCamera,
} from './third_person_camera.mjs';

const close = (actual, expected, tolerance = 1e-6) => {
  assert.ok(Math.abs(actual - expected) <= tolerance, `${actual} != ${expected}`);
};
const advance = (state, seconds, frame, dt = 1 / 60) => {
  let elapsed = 0;
  while (elapsed < seconds - 1e-12) {
    const step = Math.min(dt, seconds - elapsed);
    state = stepThirdPersonCamera(state, {...frame, dt: step});
    elapsed += step;
  }
  return state;
};

// Heading 0 faces +Z, so the initial camera sits behind the actor on -Z.
let state = createThirdPersonCameraState({target: {x: 10, y: 2, z: 20}, heading: 0});
let pose = cameraPose(state);
close(pose.position.x, 10);
assert.ok(pose.position.z < 20);
assert.ok(pose.position.y > 2);
assert.equal(pose.fov, THIRD_PERSON_CAMERA_DEFAULTS.modes.world.fov);

// Renderer smoothing follows a new visual target without mutating its source.
const authoritativeTarget = Object.freeze({x: 18, y: 2.2, z: 25});
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: authoritativeTarget, heading: 0});
assert.ok(state.target.x > 10 && state.target.x < 18);
assert.deepEqual(authoritativeTarget, {x: 18, y: 2.2, z: 25});
state = advance(state, 1, {target: authoritativeTarget, heading: 0});
close(state.target.x, 18, 1e-5);

// A server teleport snaps the visual camera anchor in the same frame.
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: {x: -42, y: 3, z: 9}, heading: 1.2, snap: true, recenter: true});
assert.deepEqual(state.target, {x: -42, y: 3, z: 9});
close(state.yaw, 1.2);

// Free orbit persists until an explicit recenter; normal frames do not pull it back.
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: state.target, heading: 1.2, orbitX: 120, orbitY: 30});
state = advance(state, 1, {target: state.target, heading: -0.8});
close(state.yaw, state.desiredYaw, 1e-5);
assert.ok(Math.abs(shortestAngleDelta(state.yaw, -0.8)) > 0.2);
state = advance(state, 1, {target: state.target, heading: -0.8, recenter: true});
close(state.yaw, -0.8, 1e-5);

// Pitch and wheel zoom remain inside the active mode limits.
state = stepThirdPersonCamera(state, {dt: 0.1, target: state.target, orbitY: 1e6, zoomDelta: 1e6});
close(state.desiredPitch, THIRD_PERSON_CAMERA_DEFAULTS.maxPitch);
close(state.desiredDistance, THIRD_PERSON_CAMERA_DEFAULTS.modes.world.maxDistance);
state = stepThirdPersonCamera(state, {dt: 0.1, target: state.target, orbitY: -1e6, zoomDelta: -1e6});
close(state.desiredPitch, THIRD_PERSON_CAMERA_DEFAULTS.minPitch);
close(state.desiredDistance, THIRD_PERSON_CAMERA_DEFAULTS.modes.world.minDistance);

// Vehicle/interior/mobile profiles change only renderer framing and snap cleanly.
for (const mode of ['vehicle', 'interior', 'mobile']) {
  state = stepThirdPersonCamera(state, {dt: 1 / 60, target: state.target, mode});
  close(state.distance, THIRD_PERSON_CAMERA_DEFAULTS.modes[mode].distance);
  close(state.fov, THIRD_PERSON_CAMERA_DEFAULTS.modes[mode].fov);
  assert.equal(state.mode, mode);
}

// Host raycasts may shorten the boom immediately; recovery is smooth.
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: state.target, mode: 'world'});
const clearDistance = state.distance;
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: state.target, obstructionDistance: 2});
assert.ok(state.distance < clearDistance);
assert.equal(state.obstructed, true);
const blockedDistance = state.distance;
state = stepThirdPersonCamera(state, {dt: 1 / 60, target: state.target});
assert.ok(state.distance > blockedDistance && state.distance < state.desiredDistance);
assert.equal(state.obstructed, false);

// Exponential damping gives the same result at ordinary 30/60 Hz frame rates.
const simulate = dt => {
  let sample = createThirdPersonCameraState({target: {x: 0, y: 1.6, z: 0}});
  sample = stepThirdPersonCamera(sample, {dt, target: sample.target, orbitX: 210, orbitY: 45, zoomDelta: 120});
  return advance(sample, 1, {target: {x: 12, y: 2, z: -7}}, dt);
};
const at30 = simulate(1 / 30), at60 = simulate(1 / 60);
close(at30.target.x, at60.target.x, 1e-6);
close(at30.yaw, at60.yaw, 1e-6);
close(at30.pitch, at60.pitch, 1e-6);
close(at30.distance, at60.distance, 1e-6);

close(normalizeAngle(Math.PI * 3), Math.PI);
assert.throws(() => createThirdPersonCameraState({target: {x: NaN, y: 0, z: 0}}));
assert.throws(() => stepThirdPersonCamera(state, {dt: -1, target: state.target}));
assert.throws(() => stepThirdPersonCamera(state, {dt: 0.1, target: {x: 0, y: Infinity, z: 0}}));

console.log('Third-person camera: follow, orbit, recenter, zoom, mode, obstruction, teleport and frame-rate checks passed');
