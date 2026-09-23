import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createTraversalWorld } from './hero_traversal_world.mjs';
import { planTraversal, stepTraversal } from './hero_traversal.mjs';
import { createLandscapePlan } from './landscape_plan.mjs';
import { planExplorationDecor } from './exploration_decor_plan.mjs';
import { createExplorationRailwayPlan } from './exploration_railway_plan.mjs';
import { explorationKeepouts } from './exploration_scene_support.mjs';
import { createWalkCollisionIndex } from './walk_collision_index.mjs';
import { createSurfaceMotion } from './surface_motion.mjs';
import { movePedestrian } from './walk_motion.mjs';

const M = 4.1;
function inBody(body, x, z) {
  const p = body.polygonCR, c = x / M, r = z / M;
  let inside = false;
  for (let i = 0, j = p.length - 1; i < p.length; j = i++) {
    const a = p[i], b = p[j];
    if ((a[1] > r) !== (b[1] > r) && c < (b[0] - a[0]) * (r - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
  }
  return inside;
}
function box(minX, maxX, minZ, maxZ, minYM, maxYM) {
  return { minYM, maxYM, polygonCR: [[minX / M, minZ / M], [maxX / M, minZ / M], [maxX / M, maxZ / M], [minX / M, maxZ / M]] };
}
function worldFor(bodies = [], options = {}) {
  const index = createWalkCollisionIndex([bodies]);
  return createTraversalWorld({ groundHeight: () => 0, ceilingHeight: () => Infinity,
    bodiesAt: (x, z) => index(x / M, z / M), contains: () => true, walkable: () => true,
    waterAt: () => null, blocksDynamic: () => false, inBody, ...options });
}
function planAt(world, position = { x: 0, y: 0, z: 0 }, direction = { x: 1, z: 0 }, swimming = false) {
  return planTraversal({ position, direction, swimming, sample: world.sample, canOccupy: world.canOccupy });
}
function finish(world, plan) {
  assert(plan, 'expected supported traversal');
  let state = { ...plan, elapsed: 0 };
  for (let frame = 0; frame < 160 && !state.done; frame++) state = stepTraversal(state, 1 / 60, world.canOccupy);
  assert(state.done && !state.blocked, 'planned static trajectory completes');
  assert(world.canOccupy(state, 1.9), 'destination has standing clearance');
  assert.equal(world.supportHeight(state.x, state.z, state.y), state.y, 'landed root retains its support');
  return state;
}
let cases = 0;
function test(name, callback) { callback(); cases++; console.log('PASS', name); }

test('world bridge vaults low thin obstacle', () => {
  const world = worldFor([box(.55, .75, -3, 3, 0, 1.1)]), plan = planAt(world);
  assert.equal(plan?.kind, 'vault'); finish(world, plan);
});
test('world bridge exposes a 34 cm curb as support without weakening a medium barrier', () => {
  const curb=worldFor([box(.55,.95,-3,3,0,.34)]),medium=worldFor([box(.55,.95,-3,3,0,.5)]);
  assert.equal(curb.supportHeight(.7,0,0),.34);
  assert.equal(curb.pointFits(.7,0,.34,1.9),true);
  assert.equal(medium.supportHeight(.7,0,0),0);
  assert.equal(medium.pointFits(.7,0,0,1.9),false);
});
test('world bridge mantles broad pedestal and surface motion preserves support', () => {
  const world = worldFor([box(.55, 4, -3, 3, 0, 1.2)]), plan = planAt(world);
  assert.equal(plan?.kind, 'mantle'); const state = finish(world, plan), surface = createSurfaceMotion();
  surface.reset(state);
  for (let i = 0; i < 180; i++) {
    const next = surface.update({ x: state.x, z: state.z, dt: 1 / 60,
      floorHeight: (x, z) => world.supportHeight(x, z, surface.state.y) });
    assert.equal(next.y, 1.2); assert(next.grounded && !next.blocked);
  }
});
test('world bridge rejects tall walls, unknown-height walls, canopy and low ceiling', () => {
  assert.equal(planAt(worldFor([box(.55, .75, -3, 3, 0, 3)])), null);
  assert.equal(planAt(worldFor([box(.55, .75, -3, 3, 0, undefined)])), null);
  assert.equal(planAt(worldFor([box(.55, .75, -3, 3, 0, 1.1), box(-.4, 3, -3, 3, 2, 2.15)])), null);
  assert.equal(planAt(worldFor([box(.55, .75, -3, 3, 0, 1.1)], { ceilingHeight: () => 2.05 })), null);
});

const read = name => JSON.parse(fs.readFileSync(new URL(name, import.meta.url), 'utf8'));
const terrain = createLandscapePlan(), topology = read('./topology_for_placement.json');
const buildings = read('./buildings_placement.v1.json').instances, existingDecor = read('./decor_placement.v1.json').instances;
const railPlan = createExplorationRailwayPlan({ landscape: terrain, topology });
const decor = planExplorationDecor({ terrain, topology, railPlan,
  keepouts: explorationKeepouts([...buildings, ...existingDecor], M) });
const nativeBodies = [...buildings, ...existingDecor].flatMap(item => item.collision?.worldBodies || []);
const realWorld = worldFor([...nativeBodies, ...decor.colliders], {
  groundHeight: terrain.groundHeight, waterAt: terrain.waterAt,
  contains: (x, z) => terrain.contains(x, z) || !!topology.walkableMask?.[Math.floor(z / M)]?.[Math.floor(x / M)],
  walkable: (x, z) => terrain.contains(x, z) ? terrain.canWalk(x, z) : !!topology.walkableMask?.[Math.floor(z / M)]?.[Math.floor(x / M)],
});
const qa = {};
for (const kind of ['vault', 'mantle']) {
  test(`real generated decor provides safe ${kind}`, () => {
    const preferred = kind === 'vault' ? ['bin', 'bench'] : ['picnic', 'planter', 'rock'];
    for (const object of decor.objects.filter(object => preferred.includes(object.kind))) {
      const body = decor.colliders.find(body => body.id === object.id);
      if (!body) continue;
      for (let i = 0; i < 16; i++) {
        const angle = i * Math.PI / 8, direction = { x: Math.cos(angle), z: Math.sin(angle) };
        const position = { x: object.x - direction.x * (body.groundRadius + .45),
          y: object.y, z: object.z - direction.z * (body.groundRadius + .45) };
        const plan = planAt(realWorld, position, direction);
        if (plan?.kind !== kind) continue;
        finish(realWorld, plan); qa[kind] = { id: object.id, objectKind: object.kind, position, direction, destination: plan.destination };
        break;
      }
      if (qa[kind]) break;
    }
    assert(qa[kind], `real ${kind} QA target found`);
  });
}

// Real shoreline paths start in shallow water and continue onto dry terrain.
// Use the same capsule, .28 m ground tolerance and foot support as the host.
for (const lake of terrain.lakes) {
  test(`${lake.id}: radial shallow-water routes reach dry ground without sticking`, () => {
    let completed = 0, traversals = 0;
    const failures = [];
    for (const startDepth of [.06, 1.25]) for (let ray = 0; ray < 16; ray++) {
      const angle = ray * Math.PI / 8, direction = { x: Math.cos(angle), z: Math.sin(angle) };
      let low = 0, high = Math.max(lake.rx, lake.rz) * 1.6;
      for (let iteration = 0; iteration < 40; iteration++) {
        const distance = (low + high) / 2;
        if (terrain.groundHeight(lake.x + direction.x * distance, lake.z + direction.z * distance) < lake.level - startDepth) low = distance;
        else high = distance;
      }
      let position = { x: lake.x + direction.x * low, z: lake.z + direction.z * low };
      position.y = terrain.groundHeight(position.x, position.z);
      if (!realWorld.canOccupy(position, 1.9)) { failures.push({ ray, reason: 'start capsule blocked', position }); continue; }
      const shorePlan = planAt(realWorld, position, direction, true);
      if (shorePlan) {
        const landed = finish(realWorld, shorePlan);
        assert.equal(terrain.waterAt(landed.x, landed.z), null, 'shore destination is genuinely dry');
        if (!qa[lake.id]) qa[lake.id] = { position: { ...position }, direction, destination: shorePlan.destination };
      }
      const start = { ...position }, surface = createSurfaceMotion(); surface.reset(position);
      let stuck = false;
      for (let frame = 0; frame < 1800; frame++) {
        const water = terrain.waterAt(position.x, position.z), before = { ...position };
        const step = movePedestrian(position, { x: direction.x * .04, z: direction.z * .04 },
          (x, z) => realWorld.pointFits(x, z, before.y, 1.9) &&
            (terrain.canWalk(x, z) || !!terrain.waterAt(x, z)) &&
            terrain.groundHeight(x, z) <= before.y + .28);
        if (!step.moved) {
          const plan = planAt(realWorld, position, direction, !!water && water.depth > .05);
          if (!plan) { failures.push({ ray, reason: 'blocked without escape plan', position }); stuck = true; break; }
          const landed = finish(realWorld, plan); position = { x: landed.x, y: landed.y, z: landed.z };
          surface.reset(position); traversals++;
        } else {
          const next = surface.update({ x: step.x, z: step.z, dt: 1 / 60,
            floorHeight: (x, z) => realWorld.supportHeight(x, z, before.y) });
          if (next.blocked) { failures.push({ ray, reason: 'surface blocked', position }); stuck = true; break; }
          position = { x: next.x, y: next.y, z: next.z };
        }
        if (!terrain.waterAt(position.x, position.z) && Math.hypot(position.x - start.x, position.z - start.z) > 3) { completed++; break; }
      }
      if (!stuck && terrain.waterAt(position.x, position.z)) failures.push({ ray, reason: 'still in water', position });
    }
    assert.equal(failures.length, 0, JSON.stringify({ lake: lake.id, completed, failures }));
    assert.equal(completed, 32, 'all tested shoreline directions and starting depths complete');
    assert(qa[lake.id], 'real shoreline traversal QA target found');
    console.log('SHORE', lake.id, { completed, traversals });
  });
}
console.log('TRAVERSAL_QA', JSON.stringify(qa));
console.log(`PASS ${cases} traversal world integration cases`);
