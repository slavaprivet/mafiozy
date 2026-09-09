import assert from 'node:assert/strict';
import { planTraversal, sampleTraversal, stepTraversal, TRAVERSAL } from './hero_traversal.mjs';

const position = { x: 0, y: 0, z: 0 }, direction = { x: 1, z: 0 };
function scene({ boxes = [], floor = () => 0, water = () => 0 } = {}) {
  const sample = (x, z) => ({ floor: floor(x, z), waterDepth: water(x, z),
    top: Math.max(-Infinity, ...boxes.filter(b => x >= b.min && x <= b.max && Math.abs(z) < 3).map(b => b.top)) });
  const canOccupy = (p, height) => p.y >= floor(p.x, p.z) - .002 && !boxes.some(b =>
    p.x + .25 > b.min && p.x - .25 < b.max && Math.abs(p.z) < 3 && p.y < b.top - .002 && p.y + height > (b.bottom ?? 0) + .002);
  return { position, direction, sample, canOccupy };
}

const wall = scene({ boxes: [{ min: .55, max: .75, top: 1.1 }] });
const vault = planTraversal(wall);
assert.equal(vault?.kind, 'vault', 'thin wall has a dry far-side landing');
assert(vault.destination.x >= 1 && vault.destination.x < 1.5);
assert.equal(sampleTraversal(vault, .2).x, 0, 'lift remains before wall');
assert(sampleTraversal(vault, .5).y > 1.22, 'carry clears wall');
assert.equal(planTraversal(scene({ boxes: [{ min: .55, max: .75, top: 2.5 }] })), null, 'tall wall cannot be crossed');
assert.equal(planTraversal(scene({ boxes: [{ min: .55, max: .75, top: 1.1 },
  { min: -.3, max: 2, bottom: 2, top: 2.15 }] })), null, 'low ceiling blocks vertical lift');
assert.equal(planTraversal(scene({ boxes: [{ min: .55, max: .75, top: 1.1 }],
  floor: x => x > .76 ? -8 : 0, water: x => x > .76 ? 8 : 0 })), null, 'no dry supported destination');

const mantle = planTraversal(scene({ boxes: [{ min: .55, max: 4, top: 1.2 }] }));
assert.equal(mantle?.kind, 'mantle', 'wide low platform accepts supported mantle');
assert(mantle.destination.y === 1.2);
assert.equal(planTraversal(scene({ boxes: [{ min: .55, max: 8, top: 8 }] })), null, 'whole building roof rejected');

const shore = { ...scene({ floor: x => x >= 1.1 ? 1.75 : -2, water: x => x >= 1.1 ? 0 : 2 }), swimming: true };
assert.equal(planTraversal(shore)?.kind, 'shore', 'high shore within reach');
assert.equal(planTraversal({ ...scene({ floor: x => x >= 1.1 ? 2.1 : -2, water: x => x >= 1.1 ? 0 : 2 }), swimming: true }), null, 'shore above max height rejected');
assert.equal(planTraversal({ ...scene({ floor: x => x >= 2.7 ? .3 : -2, water: x => x >= 2.7 ? 0 : 2 }), swimming: true }), null, 'shore beyond reach rejected');
assert.equal(planTraversal({ ...scene({ floor: x => x >= .6 ? .1 : -2, water: x => x >= .6 ? 0 : 2 }), swimming: true })?.kind, 'shore', 'low lake shore');
assert.equal(planTraversal(scene()), null, 'flat walking does not trigger traversal');
assert.equal(planTraversal({ ...scene({ floor: () => -.06, water: () => .06 }), swimming: true }), null, 'shallow water is not a dry shore destination');
assert.equal(planTraversal({ ...scene(), sample: () => ({ floor: 0, waterDepth: 0, top: Infinity }) }), null, 'unknown-height solid cannot be treated as flat ground');
assert.equal(planTraversal({ ...wall, sample: (x, z, y) => ({ ...wall.sample(x, z, y), walkable: false }) }), null, 'non-walkable destination rejected');
assert.equal(vault.edge.y, 1.1, 'edge is the obstacle top for hand contact');

let state = { ...vault, elapsed: 0 };
for (let i = 0; i < 100 && !state.done; i++) state = stepTraversal(state, .016, wall.canOccupy);
assert(state.done && !state.blocked);
assert.deepEqual({ x: state.x, y: state.y, z: state.z }, vault.destination);
const blocker = (p, height) => wall.canOccupy(p, height) && !(p.x > .43 && p.x < .445);
const interrupted = stepTraversal({ ...vault, elapsed: 0 }, 2, blocker);
assert(interrupted.done && interrupted.blocked, 'swept movement finds a dynamic blocker with large dt');
assert(interrupted.x <= .43 && interrupted.x > .38, 'stops at last safe point');
assert(wall.canOccupy(interrupted, interrupted.height));
assert.throws(() => stepTraversal({ ...vault, elapsed: 0 }, -1, wall.canOccupy));
assert.equal(sampleTraversal(vault, 1).height, TRAVERSAL.standingHeight);
console.log('PASS traversal: thin/tall wall, ceiling, unsupported destination, mantle, high/lake shore, swept dynamic blocker');
