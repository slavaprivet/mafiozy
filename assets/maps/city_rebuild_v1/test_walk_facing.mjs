import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {runInNewContext} from 'node:vm';
import {pathToFileURL} from 'node:url';
import {movePedestrian, circleFits} from './walk_motion.mjs';
import {carCorners, pointInPolygon, CAR} from './car_drive.mjs';

const T = await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
// Exercise the actual frame adapter, including its facing and camera updates.
const source = readFileSync(new URL('./walk_preview.mjs', import.meta.url), 'utf8');
const start = source.indexOf('function moveHeroOnFoot(delta){');
const end = source.indexOf('function frame(){', start);
assert(start >= 0 && end > start);
function setup(position, allowed) {
  const hero = {object: new T.Group()};
  hero.object.position.copy(position);
  hero.object.rotation.y = -.7;
  const camera = {position: position.clone().add(new T.Vector3(3, 4, -5))};
  const controls = {target: position.clone().add(new T.Vector3(0, 1.1, 0))};
  const move = runInNewContext(source.slice(start, end) + '\nmoveHeroOnFoot;', {
    hero, camera, controls, movePedestrian,
    surfaceMotion: {state: {grounded: true}, canMove: () => true},
    pedestrianAllowed: allowed, groundHeight: () => 0,
  });
  return {hero, camera, controls, move};
}
function near(actual, expected, label) { assert(Math.abs(actual - expected) < 1e-9, label); }

for (const yaw of [0, Math.PI / 2, -.63, Math.PI]) {
  const toward = new T.Vector3(Math.sin(yaw), 0, Math.cos(yaw));
  const tangent = new T.Vector3(toward.z, 0, -toward.x);
  const wall = (x, z) => x * toward.x + z * toward.z < 0;
  const origin = toward.clone().multiplyScalar(-.360001);
  const runtime = setup(origin, wall);
  const cameraBefore = runtime.camera.position.clone();
  const targetBefore = runtime.controls.target.clone();
  // Fully blocked: a previous sideways facing must still turn toward the wall.
  assert.equal(runtime.move(toward.clone().multiplyScalar(.1)), false);
  near(runtime.hero.object.rotation.y, yaw, 'face the wall while blocked');
  assert(runtime.hero.object.position.equals(origin));
  assert(runtime.camera.position.equals(cameraBefore));
  assert(runtime.controls.target.equals(targetBefore));
  // Diagonal input at a wall can slide, but must not turn into that slide.
  const delta = toward.clone().multiplyScalar(.12).addScaledVector(tangent, .06);
  const expected = movePedestrian(origin, delta, wall);
  runtime.move(delta);
  near(runtime.hero.object.rotation.y, Math.atan2(delta.x, delta.z), 'retain requested facing during slide');
  near(runtime.hero.object.position.x, expected.x, 'same collision x');
  near(runtime.hero.object.position.z, expected.z, 'same collision z');
  near(runtime.camera.position.x - cameraBefore.x, expected.x - origin.x, 'camera follows actual x');
  near(runtime.camera.position.z - cameraBefore.z, expected.z - origin.z, 'camera follows actual z');
  const stoppedYaw = runtime.hero.object.rotation.y;
  assert.equal(runtime.move(new T.Vector3()), false);
  near(runtime.hero.object.rotation.y, stoppedYaw, 'releasing WASD retains facing');
}

for (const yaw of [0, .63, Math.PI / 2]) for (const side of [-1, 1]) {
  const car = {x: 10, z: 15, yaw};
  const outward = new T.Vector3(Math.cos(yaw) * side, 0, -Math.sin(yaw) * side);
  const origin = new T.Vector3(car.x, 0, car.z).addScaledVector(outward, CAR.halfWidth + .360001);
  const allowed = (x, z) => !pointInPolygon(x, z, carCorners(car.x, car.z, car.yaw));
  const runtime = setup(origin, allowed);
  const delta = outward.clone().multiplyScalar(-.1);
  assert(circleFits(origin.x, origin.z, allowed));
  runtime.move(delta);
  near(runtime.hero.object.rotation.y, Math.atan2(delta.x, delta.z), 'face either side of a rotated car');
  assert(circleFits(runtime.hero.object.position.x, runtime.hero.object.position.z, allowed));
}
console.log('PASS production facing: blocked walls, diagonal sliding, release, rotated cars, unchanged collision and camera displacement');
