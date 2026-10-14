import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {buildVariant, controllerPath, frozenSha256, loadVariant} from './variant.mjs';

// Node policy oracle for the injected GDScript loop. This is a static negative
// test, not a substitute for the later Godot native transaction test.
const canonical = value => {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`;
  return JSON.stringify(value);
};
function admitsProtected(baseline, supplied, editable) {
  const byId = new Map(supplied.map(row => [row.id, row]));
  return baseline.every(row => editable.has(row.id) ||
    (byId.has(row.id) && canonical(row) === canonical(byId.get(row.id))));
}

const source = await readFile(controllerPath);
const variant = await loadVariant();
assert.equal(variant, buildVariant(source));
assert.notEqual(variant, source.toString('utf8'));
assert.match(variant, /if registry\.is_editable\(baseline_row\.id\): continue/);
assert.match(variant, /not supplied_rows\.has\(baseline_row\.id\) or not _json_equal\(baseline_row, supplied_rows\[baseline_row\.id\]\)/);
assert.equal(variant.split('var supplied_rows := {}').length, 2);
assert.throws(() => buildVariant(Buffer.from('not the frozen source')), /Frozen controller changed/);

const baseline = [
  {id: 'rail:protected', model: 'rail', transform: {position: [10, 0, 4], rotation: [0, 0, 0], scale: [1, 1, 1]}},
  {id: 'house:editable', model: 'house', transform: {position: [2, 0, 3], rotation: [0, 0, 0], scale: [1, 1, 1]}},
];
const editable = new Set(['house:editable']);
const copy = () => structuredClone(baseline);
assert.equal(admitsProtected(baseline, copy(), editable), true);
const tinyProtected = copy();
tinyProtected[0].transform.position[0] += 1e-7;
assert(Math.abs(tinyProtected[0].transform.position[0] - baseline[0].transform.position[0]) < 1e-5);
assert.equal(admitsProtected(baseline, tinyProtected, editable), false, 'sub-epsilon protected transform is rejected');
assert.equal(admitsProtected(baseline, [copy()[1]], editable), false, 'deleted protected source is rejected');
const editedHouse = copy();
editedHouse[1].transform.position[0] += 3;
assert.equal(admitsProtected(baseline, editedHouse, editable), true, 'ordinary editable transform is allowed');
assert.equal(admitsProtected(baseline, [copy()[0]], editable), true, 'ordinary editable deletion remains allowed');

console.log(JSON.stringify({suite: 'protected-exact-source-variant', checks: 12, frozenSha256, godotExecuted: false, productionInstalled: false}));
