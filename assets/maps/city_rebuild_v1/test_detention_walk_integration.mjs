import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {applyBuildingDoorsGlass} from './building_doors_glass.mjs';
import {createStableEntryLights} from './stable_entry_lights.mjs';
import {createWalkCollisionIndex} from './walk_collision_index.mjs';
import {createExplorationVehicleWorld} from './exploration_vehicle_support.mjs';
import {pointInPolygon} from './car_drive.mjs';
import {buildingDoorPrompt} from './building_prompt.mjs';
import {detentionShellResourceStats} from './detention_native_sites.mjs';

const here = path.dirname(fileURLToPath(import.meta.url)), root = path.resolve(here, '../../..');
const files = ['buildings_placement.v1.json', 'detention_native_sites.v1.json', 'detention_destinations.v1.json'];
const originals = new Map(files.map(name => [name, fs.readFileSync(path.join(here, name), 'utf8')]));
const ordinary = JSON.parse(originals.get(files[0]));
const manifest = JSON.parse(originals.get(files[1]));
const destinations = JSON.parse(originals.get(files[2])).destinations;
const topology = JSON.parse(fs.readFileSync(path.join(here, 'topology_for_placement.json'), 'utf8'));
const candidate = JSON.parse(fs.readFileSync(path.join(root, 'outputs/detention_native_sites_20260912/detention_native_sites.candidate.json'), 'utf8'));
const ids = ['REBUILD-DETENTION-southside', 'REBUILD-DETENTION-chinatown', 'REBUILD-DETENTION-iron_harbor'];
const M = 4.1, near = (actual, expected, label) => assert.ok(Math.abs(actual - expected) < 1e-6, label + ': ' + actual + ' / ' + expected);
const vendor = process.env.MAFIOZY_THREE_VENDOR || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier, context, next) {
  return next(specifier === 'three' ? pathToFileURL(path.join(vendor, 'build/three.module.js')).href : specifier, context);
}});
const T = await import(pathToFileURL(path.join(vendor, 'build/three.module.js')));
const {GLTFLoader} = await import(pathToFileURL(path.join(vendor, 'addons/loaders/GLTFLoader.js')));

test('canonical detention records add exactly the three audited candidates and preserve ordinary 75 identities', () => {
  assert.equal(ordinary.instances.length, 75);
  assert.equal(new Set(ordinary.instances.map(i => i.assetId)).size, 22);
  assert.deepEqual(manifest.instances.map(i => i.id), ids);
  assert.deepEqual(manifest.instances.map(i => i.id), candidate.instances.map(i => i.id));
  const all = [...ordinary.instances, ...manifest.instances];
  assert.equal(new Set(all.map(i => i.id)).size, 78);
  for (const instance of manifest.instances) {
    const planned = candidate.instances.find(i => i.id === instance.id);
    assert.equal(instance.role, 'district_detention');
    assert.equal(instance.assetId, 'police_station');
    assert.deepEqual(instance.binding, planned.binding);
    assert.deepEqual(instance.transform, planned.transform);
    assert.equal(instance.gameplayId, null);
    assert.ok(!ordinary.instances.some(i => i.id === instance.id));
    const destination = destinations.find(d => d.instanceId === instance.id);
    assert.ok(destination, instance.id + ' has the matching source destination');
    assert.equal(destination.id, instance.detentionId);
    assert.equal(destination.name, instance.name);
    const bytes = fs.readFileSync(path.join(root, instance.binding.url.slice(1)));
    assert.equal(bytes.byteLength, instance.binding.bytes);
    assert.equal(createHash('sha256').update(bytes).digest('hex'), instance.binding.sha256);
  }
});

test('actual factory entries satisfy the walk scene consumers for all three transformed GLB copies', async t => {
  const scene = new T.Scene(), templates = new Map(), fixtures = [];
  let lights;
  t.after(() => {
    lights?.dispose();
    for (const fixture of fixtures) {
      fixture.applied.roomReveals?.dispose();
      fixture.entry.dispose();
      fixture.entry.dispose();
      fixture.applied.windows?.dispose();
      fixture.doorsGlass.dispose();
      fixture.group.removeFromParent();
    }
    const geometries = new Set(), materials = new Set();
    for (const source of templates.values()) source.traverse(node => {
      if (node.geometry) geometries.add(node.geometry);
      for (const material of [].concat(node.material ?? [])) materials.add(material);
    });
    for (const geometry of geometries) geometry.dispose();
    for (const material of materials) material.dispose();
  });
  for (const sourceInstance of manifest.instances) {
    const instance = structuredClone(sourceInstance), beforeInstance = structuredClone(instance);
    let source = templates.get(instance.binding.sha256);
    if (!source) {
      const bytes = fs.readFileSync(path.join(root, instance.binding.url.slice(1)));
      source = (await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene;
      templates.set(instance.binding.sha256, source);
    }
    const group = new T.Group(), visual = source.clone(true), transform = instance.transform;
    visual.position.fromArray(transform.modelLocalOffsetM);
    const doorsGlass = applyBuildingDoorsGlass(visual, instance);
    group.add(visual);
    group.position.fromArray(transform.positionM);
    group.rotation.y = transform.yawDegrees * Math.PI / 180;
    group.scale.setScalar(transform.uniformScale);
    group.userData.instance = instance;
    scene.add(group);
    group.updateMatrixWorld(true);
    const before = [];
    visual.traverse(node => {
      if (node.isMesh) before.push({node, parent: node.parent, geometry: node.geometry,
        material: node.material, visible: node.visible, matrix: node.matrix.clone()});
    });
    // The same public factory and clone preparation used by refresh(); the
    // detention helper is deliberately not called directly by this test.
    const applied = createWindowedBuildingEntry({THREE: T, visual, instance, metresPerCell: M});
    const entry = applied.entry;
    fixtures.push({instance, beforeInstance, group, visual, before, applied, entry, doorsGlass});
    assert.ok(entry, instance.id + ' factory returned an entry');
    assert.equal(entry.kind, 'detention');
    assert.equal(entry.instance, instance);
    assert.equal(entry.visual, visual);
    assert.equal(entry.object, entry.root);
    assert.equal(entry.contentRoot, entry.root);
    assert.equal(entry.report.sameScene, true);
    assert.equal(applied.windows, null);
    assert.equal(applied.roomReveals, null);
    assert.equal(entry.interiorDesign, undefined, 'generic furnishing must not overwrite the native holding cell');
    assert.deepEqual(instance, beforeInstance);
  }
  const entries = fixtures.map(f => f.entry);
  const sampleIndex = createWalkCollisionIndex([entries.map(entry => {
    const b = entry.sampleBounds;
    return {entry, polygonCR: [[b.min.x / M, b.min.z / M], [b.max.x / M, b.min.z / M],
      [b.max.x / M, b.max.z / M], [b.min.x / M, b.max.z / M]]};
  })]);

  await t.test('floor, ceiling, entry proximity and sampling index use the true transformed room coordinates', () => {
    for (const {instance, visual, entry} of fixtures) {
      const room = entry.roomPoint(), center = entry.roomCenterPoint(), approach = entry.approachPoint();
      assert.ok(room.isVector3 && center.isVector3 && approach.isVector3);
      assert.ok(entry.sampleBounds.isBox3);
      assert.ok(entry.sampleBounds.containsPoint(room));
      assert.equal(entry.containsInterior(room), true);
      assert.equal(entry.containsInterior(approach), false);
      assert.ok(sampleIndex(room.x / M, room.z / M).some(candidate => candidate.entry === entry));
      const destination = destinations.find(d => d.instanceId === instance.id);
      near(room.x, destination.intake.c * M, instance.id + ' intake X');
      near(room.z, destination.intake.r * M, instance.id + ' intake Z');
      const floor = visual.localToWorld(new T.Vector3(0, .33, 0)).y;
      const ceiling = visual.localToWorld(new T.Vector3(0, 3.45, 0)).y;
      near(entry.floorHeight(room.x, room.z, room.y), floor, 'floor height');
      near(entry.ceilingHeight(room), ceiling, 'ceiling height');
      assert.ok(ceiling - floor >= 2.4, 'standing headroom at approved branch scale');
      near(entry.floorHeight(approach.x, approach.z, approach.y), floor, 'entrance pavement height');
      const outside = entry.sampleBounds.max.clone().addScalar(20);
      assert.equal(entry.floorHeight(outside.x, outside.z, outside.y), null);
      assert.equal(entry.ceilingHeight(outside), null);
      assert.equal(entry.containsInterior(outside), false);
      assert.equal(entry.proximity(outside), null);
      const candidate = entry.proximity(approach);
      assert.ok(candidate?.door && candidate.distance <= 2.2);
      assert.equal(candidate.instanceId, instance.id);
      assert.equal(candidate.name, 'Вход в изолятор');
      assert.ok(candidate.anchor.isVector3);
    }
  });

  await t.test('interior containment excludes a point above the room ceiling', () => {
    for (const {instance, entry} of fixtures) {
      const point = entry.roomPoint();
      point.y = entry.ceilingHeight(point) + 1;
      assert.equal(entry.containsInterior(point), false, instance.id + ' must not treat the upper exterior as an occupied room');
    }
  });

  await t.test('the real exterior interaction carries the district name into buildingDoorPrompt', () => {
    for (const {instance, entry} of fixtures) {
      const point = entry.approachPoint();
      const candidate = {kind: 'building', entry, ...entry.proximity(point)};
      assert.ok(buildingDoorPrompt(candidate).includes(instance.name), instance.id + ': ' + buildingDoorPrompt(candidate));
      assert.ok(buildingDoorPrompt(candidate).toLowerCase().includes('открыть'));
      const gate = entry.doors.find(door => door.name === 'Решётка камеры');
      const gatePoint = entry.visual.localToWorld(new T.Vector3(gate.x + gate.width / 2, .33, gate.z + 1));
      const gateCandidate = {kind: 'building', entry, ...entry.proximity(gatePoint)};
      assert.ok(buildingDoorPrompt(gateCandidate).includes('Решётка камеры'));
    }
  });

  await t.test('door changes invalidate pedestrian bodies while static vehicle bodies keep the station mass blocked', () => {
    const carBodies = manifest.instances.flatMap(i => i.collision.worldBodies);
    const drive = createExplorationVehicleWorld({topology, bodies: carBodies, metresPerCell: M});
    const carIndex = createWalkCollisionIndex([carBodies]);
    for (const {instance, visual, entry} of fixtures) {
      const room = entry.roomPoint(), approach = entry.approachPoint(), scale = instance.transform.uniformScale;
      const before = entry.getCollisionBodies();
      assert.equal(entry.getCollisionBodies(), before, 'idle collision body array is stable');
      assert.ok(before.length > 10 && before.every(b => b.buildingEntryId === instance.id && b.detention));
      const closedDoor = before.find(b => b.movingDoor && b.detentionPart === 'Вход в изолятор');
      const doorway = visual.localToWorld(new T.Vector3(-5.1, .33, 8.04));
      assert.ok(pointInPolygon(doorway.x / M, doorway.z / M, closedDoor.polygonCR));
      assert.equal(entry.needsUpdate, false);
      assert.equal(entry.interact(approach).accepted, true);
      assert.equal(entry.needsUpdate, true);
      for (let n = 0; n < 10; n++) entry.update(.1);
      assert.equal(entry.needsUpdate, false);
      assert.equal(entry.report.openFraction, 1);
      const after = entry.getCollisionBodies();
      assert.notEqual(after, before, 'walk collision index can observe the new door pose');
      const openDoor = after.find(b => b.movingDoor && b.detentionPart === 'Вход в изолятор');
      assert.equal(pointInPolygon(doorway.x / M, doorway.z / M, openDoor.polygonCR), false);
      const pedestrianIndex = createWalkCollisionIndex([after]);
      const centerCR = openDoor.polygonCR.reduce((p, q) => [p[0] + q[0] / 4, p[1] + q[1] / 4], [0, 0]);
      assert.ok(pedestrianIndex(...centerCR).some(b => b === openDoor));
      assert.equal(drive(room.x, room.z), false, 'a car cannot enter the pedestrian intake');
      assert.ok(carIndex(room.x / M, room.z / M).some(b => b.buildingEntryId === instance.id && b.carOnly));
      const destination = destinations.find(d => d.instanceId === instance.id);
      const stop = {x: destination.stop.c * M, z: destination.stop.r * M};
      assert.equal(drive(stop.x, stop.z), true, 'real source roadside stop remains driveable');
      const heading = Math.PI / 2 - destination.stop.angle;
      assert.equal(drive.poseAllowed(stop.x, stop.z, heading, {halfWidth: 1.15, halfLength: 3.2}), true,
        'the full 6.4 by 2.3 metre convoy vehicle fits the authored stop');
      for (const body of instance.collision.worldBodies) {
        assert.equal(body.carOnly, true);
        assert.ok(body.polygonCR.flat().every(Number.isFinite));
        assert.ok(body.maxYM > body.minYM);
      }
      near(entry.report.openingWidth, 1.56 * scale, 'physical doorway metre width');
    }
  });

  await t.test('stable entry light slots accept these factory roots and preserve bounded source ownership', () => {
    const sources = [];
    for (const entry of entries) entry.object.traverse(source => {
      if (source.isPointLight && !source.castShadow) sources.push({source, parent: source.parent, mask: source.layers.mask});
    });
    lights = createStableEntryLights(T, entries, scene, {maxLights: 32, getFocus: () => entries[0].roomPoint()});
    assert.equal(lights.stats().sourceLights, sources.length);
    assert.ok(lights.stats().fixedLights <= 32);
    assert.ok(lights.stats().activeLights <= lights.stats().fixedLights);
    for (const {source, parent} of sources) { assert.equal(source.parent, parent); assert.equal(source.layers.mask, 0); }
    for (const entry of entries) entry.object.visible = false;
    lights.update();
    assert.equal(lights.stats().activeLights, 0);
    for (const entry of entries) entry.object.visible = true;
    lights.update();
    t.diagnostic('Native detention light sources: ' + sources.length + '; no renderer/GPU was created.');
    lights.dispose();
    lights.dispose();
    for (const {source, mask} of sources) assert.equal(source.layers.mask, mask);
    assert.equal(scene.getObjectByName('Stable_Entry_Light_Slots'), undefined);
  });

  await t.test('walk teardown restores the actual clone resources and releases all three shared shells once', () => {
    assert.equal(detentionShellResourceStats(T).references, 3);
    for (const {instance, beforeInstance, entry, visual, before} of fixtures) {
      entry.dispose();
      entry.dispose();
      assert.equal(entry.object.parent, null);
      assert.equal(entry.needsUpdate, false);
      assert.equal(visual.getObjectByName('Detention_Native_' + instance.id), undefined);
      for (const state of before) {
        assert.equal(state.node.parent, state.parent);
        assert.equal(state.node.geometry, state.geometry);
        assert.equal(state.node.material, state.material);
        assert.equal(state.node.visible, state.visible);
        state.node.updateMatrix();
        assert.ok(state.node.matrix.elements.every((value, i) => Math.abs(value - state.matrix.elements[i]) < 1e-8));
      }
      assert.deepEqual(instance, beforeInstance);
    }
    assert.deepEqual(detentionShellResourceStats(T), {entries: 0, references: 0, geometries: 0});
  });
});

test('QA leaves the ordinary placement, detention candidates and source destination registry unchanged', () => {
  for (const [name, original] of originals) assert.equal(fs.readFileSync(path.join(here, name), 'utf8'), original, name);
});
