import assert from 'node:assert/strict';
import {applyCloneVisibilityMask, applyTemplateVisibilityMask, maskSignature} from './template_visibility_mask.mjs';

function tree(nodes) {
  return {traverse(fn) { for (const node of nodes) fn(node); }};
}

const sourceNodes = [
  {name: 'Visible', visible: true},
  {name: 'COLLISION_BODY', visible: true},
  {name: 'ArtistHidden', visible: false},
];
const source = tree(sourceNodes);
assert.equal(maskSignature(['B', 'A', 'A']), 'A\u001fB');
assert.deepEqual(applyTemplateVisibilityMask(source, ['COLLISION_BODY']), {visited: 3, hidden: 1, tracked: true});
assert.deepEqual(sourceNodes.map(node => node.visible), [true, false, false]);
assert.deepEqual(applyTemplateVisibilityMask(source, []), {visited: 3, hidden: 0, tracked: true});
assert.deepEqual(sourceNodes.map(node => node.visible), [true, true, false], 'the authored hidden state must be restored exactly');

const cloneNodes = sourceNodes.map(node => ({...node}));
const clone = tree(cloneNodes);
assert.deepEqual(applyCloneVisibilityMask(clone, ['Visible']), {visited: 3, hidden: 1});
assert.deepEqual(cloneNodes.map(node => node.visible), [false, true, false]);
assert.deepEqual(sourceNodes.map(node => node.visible), [true, true, false], 'legacy non-uniform masks never modify the shared template');
console.log('template visibility mask PASS');
