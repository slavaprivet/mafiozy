import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHash} from 'node:crypto';
import {createBuildingEntry, resolveBuildingCameraPosition, BUILDING_ENTRY_PROFILE} from './building_entry.mjs';
import {movePedestrian, circleFits} from './walk_motion.mjs';

const vendor = 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s, c, next) { return next(s === 'three' ? pathToFileURL(vendor + 'build/three.module.js').href : s, c); }});
const THREE = await import(pathToFileURL(vendor + 'build/three.module.js'));
const {GLTFLoader} = await import(pathToFileURL(vendor + 'addons/loaders/GLTFLoader.js'));
const here = path.dirname(fileURLToPath(import.meta.url)), root = path.resolve(here, '../../..');
const placement = JSON.parse(fs.readFileSync(path.join(here, 'buildings_placement.v1.json')));
const items = placement.instances.filter(i => i.assetId === 'strip_club');
const bytes = fs.readFileSync(path.join(root, items[0].binding.url.slice(1)));
assert.equal(createHash('sha256').update(bytes).digest('hex'), BUILDING_ENTRY_PROFILE.sha256);
const source = (await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene;
let checks = 0;
const test = (name, fn) => { fn(); checks++; console.log('PASS ' + name); };
function fixture(item = items[1]) {
  const group = new THREE.Group(), visual = source.clone(true), t = item.transform;
  visual.position.fromArray(t.modelLocalOffsetM); group.position.fromArray(t.positionM);
  group.rotation.y = t.yawDegrees * Math.PI / 180; group.scale.setScalar(t.uniformScale);
  group.add(visual); group.updateMatrixWorld(true);
  return {group, visual, entry: createBuildingEntry({THREE, visual, instance: item}),
    world: (x, y, z) => visual.localToWorld(new THREE.Vector3(x, y, z))};
}
const visible = node => { for (let n = node; n; n = n.parent) if (!n.visible) return false; return true; };
function rayHits(f, x = 0, y = 1.6) {
  f.group.updateMatrixWorld(true);
  const origin = f.world(x, y, 8), target = f.world(x, y, 0);
  return new THREE.Raycaster(origin, target.clone().sub(origin).normalize(), 0, origin.distanceTo(target)).intersectObject(f.visual, true).filter(h => visible(h.object));
}
function inPolygon(x, z, polygon) {
  let inside = false;
  for (let i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    const a = polygon[i], b = polygon[j];
    if ((a[1] > z) !== (b[1] > z) && x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
  }
  return inside;
}
const allowed = entry => (x, z) => !entry.getCollisionBodies().some(b => b.minYM < 2.3 && b.maxYM > .5 && inPolygon(x / 4.1, z / 4.1, b.polygonCR));
const open = f => { assert(f.entry.interact(f.world(0, 0, 7.2)).accepted); for (let i = 0; i < 45; i++) f.entry.update(1 / 60, f.world(0, 0, 7.2)); };

test('actual double-door asset is pinned and unknown revisions fail closed', () => {
  assert.equal(items.length, 4);
  const visual = source.clone(true);
  assert.equal(createBuildingEntry({THREE, visual, instance: {...items[0], binding: {...items[0].binding, sha256: 'changed'}}}), null);
});

test('closed leaves are physical; opening carves shell/recess instead of crossing a wall', () => {
  const f = fixture();
  assert(rayHits(f, .5).some(h => h.object.name === 'Entrance_Door'));
  const threshold = f.world(0, .45, 4.93);
  assert.equal(circleFits(threshold.x, threshold.z, allowed(f.entry)), false);
  open(f);
  assert.equal(f.entry.report.openFraction, 1);
  assert.equal(rayHits(f, 0).length, 0, 'centre passage must contain no opaque/recess/rope triangles');
  assert.equal(rayHits(f, -.6).length, 0, 'left walking shoulder physically clear');
  assert.equal(rayHits(f, .6).length, 0, 'right walking shoulder physically clear');
  assert.equal(circleFits(threshold.x, threshold.z, allowed(f.entry)), true);
  assert(rayHits(f, 2.5).some(h => h.object.name === 'Club_First_Floor' || h.object.name.startsWith('Interior_Front')), 'wall outside actual doorway survives');
  f.entry.dispose();
});

test('real transform/yaw placements permit continuous walking in and out, walls remain solid', () => {
  for (const item of items) {
    const f = fixture(item); open(f);
    const start = f.world(0, 0, 7.3), finish = f.world(0, .45, 0);
    const move = movePedestrian(start, finish.clone().sub(start), allowed(f.entry));
    assert(Math.hypot(move.x - finish.x, move.z - finish.z) < 1e-5, item.id);
    assert(f.entry.containsInterior(move));
    const outside = movePedestrian(move, start.clone().sub(finish), allowed(f.entry));
    assert(Math.hypot(outside.x - start.x, outside.z - start.z) < 1e-5, item.id);
    const side = f.world(8, .45, 0), blocked = movePedestrian(finish, side.clone().sub(finish), allowed(f.entry));
    assert(Math.hypot(blocked.x - side.x, blocked.z - side.z) > 2, 'cannot exit through side wall');
    f.entry.dispose();
  }
});

test('both sides use single interaction; closing refuses to crush the doorway occupant', () => {
  const f = fixture(); open(f);
  const inside = f.world(0, .45, 2.65), threshold = f.world(0, .45, 4.7);
  assert(f.entry.proximity(inside)); assert(f.entry.proximity(f.world(0, 0, 7.2)));
  assert.equal(f.entry.interact(threshold).reason, 'door-sweep-occupied');
  assert(f.entry.interact(inside).accepted);
  f.entry.update(.1, threshold);
  assert.equal(f.entry.proximity(threshold).opening, true, 'closure reopens if a person enters swing area');
  assert.equal(f.entry.interact(f.world(0, .45, -3)).accepted, false);
  f.entry.dispose();
});

test('ramp is visible from above and connects sidewalk/platform without a teleport', () => {
  const f = fixture();
  const high = f.world(0, 0, 5.1), low = f.world(0, 0, 7.4), mid = f.world(0, 0, 6.25);
  assert(Math.abs(f.entry.floorHeight(high.x, high.z) - .44) < .011);
  assert(Math.abs(f.entry.floorHeight(low.x, low.z)) < 1e-6);
  assert(Math.abs(f.entry.floorHeight(mid.x, mid.z) - .22) < 1e-6);
  const ramp = f.visual.getObjectByName('Entrance_Access_Ramp');
  assert(ramp.geometry.attributes.normal.getY(0) > .9);
  const center = f.world(0, 0, 0); assert.equal(f.entry.floorHeight(center.x, center.z), .45);
  f.entry.dispose();
});

test('dispose restores original meshes/hierarchy and never changes shared GLB geometry', () => {
  const shell = source.getObjectByName('Club_First_Floor'), geometry = shell.geometry;
  const before = Array.from(geometry.attributes.position.array), placementBefore = JSON.stringify(placement);
  const f = fixture(); assert.notEqual(f.visual.getObjectByName('Club_First_Floor').geometry, geometry);
  open(f); f.entry.dispose(); f.entry.dispose();
  assert.equal(f.visual.getObjectByName('Club_First_Floor').geometry, geometry);
  assert.equal(f.visual.getObjectByName('Entrance_Deep_Recess').visible, true);
  assert.equal(f.visual.getObjectByName('Entrance_Door').parent, f.visual);
  assert.equal(f.visual.getObjectByName('Runtime_SameScene_Club_Entry'), undefined);
  assert.deepEqual(Array.from(geometry.attributes.position.array), before);
  assert.equal(JSON.stringify(placement), placementBefore);
});
test('camera stays inside real room walls/ceiling and clear open doorway preserves desired position', () => {
  const f = fixture(); open(f); f.group.updateMatrixWorld(true);
  const origin = f.world(0, 1.55, 0);
  for (const desired of [f.world(9, 2, 0), f.world(0, 8, 0), f.world(0, 2, -9)]) {
    const resolved = resolveBuildingCameraPosition({THREE, from: origin, desired, objects: [f.visual]});
    assert(resolved.distanceTo(origin) < desired.distanceTo(origin), 'wall or ceiling shortens only rendered distance');
    const p = f.visual.worldToLocal(resolved.clone());
    assert(p.x < 5.8 && p.z > -4.3 && p.y < 4.19);
  }
  const outside = f.world(0, 1.6, 8), clearOrigin = f.world(0, 1.55, 4);
  const through = resolveBuildingCameraPosition({THREE, from: clearOrigin, desired: outside, objects: [f.visual]});
  assert(through.distanceTo(outside) < 1e-6, 'camera can see the street through the physical doorway');
  f.entry.dispose();
});

test('buildingqa first entrance path is walkable against full topology and other placements', () => {
  const topology = JSON.parse(fs.readFileSync(path.join(here, 'topology_for_placement.json')));
  const decor = JSON.parse(fs.readFileSync(path.join(here, 'decor_placement.v1.json')));
  const f = fixture(items[0]); open(f);
  const other = [...placement.instances, ...decor.instances].filter(i => i.id !== items[0].id).flatMap(i => i.collision?.worldBodies ?? []);
  const integratedAllowed = (x, z) => {
    if (!topology.walkableMask[Math.floor(z / 4.1)]?.[Math.floor(x / 4.1)]) return false;
    const floor = f.entry.floorHeight(x, z) ?? 0;
    return ![...other, ...f.entry.getCollisionBodies()].some(b => b.maxYM >= floor + .05 && b.minYM <= floor + 1.9 && inPolygon(x / 4.1, z / 4.1, b.polygonCR));
  };
  const start = f.world(0, 0, 7.25), finish = f.world(0, .45, 0);
  assert(circleFits(start.x, start.z, integratedAllowed), 'visible QA approach fixture is safe');
  const walked = movePedestrian(start, finish.clone().sub(start), integratedAllowed);
  assert(Math.hypot(walked.x - finish.x, walked.z - finish.z) < 1e-5);
  assert.equal(f.entry.floorHeight(walked.x, walked.z), .45);
  f.entry.dispose();
});
console.log(`${checks} building-entry checks passed using actual pinned GLB. Live review remains separate.`);
