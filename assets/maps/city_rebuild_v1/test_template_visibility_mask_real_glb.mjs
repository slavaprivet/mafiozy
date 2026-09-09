import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {applyCloneVisibilityMask, applyTemplateVisibilityMask, maskSignature} from './template_visibility_mask.mjs';

const vendor = 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(specifier, context, next) { return next(specifier === 'three' ? pathToFileURL(vendor + 'build/three.module.js').href : specifier, context); }});
const THREE = await import(pathToFileURL(vendor + 'build/three.module.js'));
const {GLTFLoader} = await import(pathToFileURL(vendor + 'addons/loaders/GLTFLoader.js'));
const placement = JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json', import.meta.url)));
const groups = new Map();
for (const item of placement.instances) {
  if (!item.binding || !item.hideNodeNames?.length) continue;
  const current = groups.get(item.binding.sha256);
  const signature = maskSignature(item.hideNodeNames);
  if (current) {
    assert.equal(current.signature, signature, `${item.binding.sha256} must have one source-level visibility mask`);
    current.items.push(item);
  } else groups.set(item.binding.sha256, {binding: item.binding, signature, names: item.hideNodeNames, items: [item]});
}

let sourceVisits = 0, cloneVisits = 0, clones = 0;
for (const group of groups.values()) {
  const bytes = fs.readFileSync(new URL('../../..' + group.binding.url, import.meta.url));
  const loader = new GLTFLoader().register(() => ({name: 'VISIBILITY_MASK_TEXTURE_STUB', loadTexture: () => Promise.resolve(new THREE.Texture())}));
  const source = (await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength), '')).scene;
  const original = new Map();
  source.traverse(node => original.set(node.name, node.visible));
  sourceVisits += applyTemplateVisibilityMask(source, group.names).visited;
  for (const item of group.items) {
    const visual = source.clone(true), expected = source.clone(true);
    // Reconstruct the old per-instance result from the authored visibility,
    // then compare every cloned node to the template-mask result.
    applyTemplateVisibilityMask(source, []);
    const authored = source.clone(true);
    applyTemplateVisibilityMask(source, group.names);
    applyCloneVisibilityMask(authored, item.hideNodeNames);
    const actualNodes = [], expectedNodes = [];
    visual.traverse(node => actualNodes.push(node));
    authored.traverse(node => expectedNodes.push(node));
    assert.equal(actualNodes.length, expectedNodes.length, item.id + ' keeps its complete node tree');
    for (let index = 0; index < actualNodes.length; index++) assert.equal(actualNodes[index].visible, expectedNodes[index].visible, item.id + ' visibility parity at node ' + actualNodes[index].name);
    cloneVisits += expectedNodes.length;
    clones++;
  }
  applyTemplateVisibilityMask(source, []);
  for (const [name, visible] of original) assert.equal(source.getObjectByName(name)?.visible, visible, 'source restoration ' + name);
}
assert.equal(clones, 51, 'all current masked building instances are covered');
assert.ok(sourceVisits < cloneVisits, 'one verified template mask replaces repeated clone traversals');
console.log(JSON.stringify({passed: true, maskedInstances: clones, uniqueTemplates: groups.size, sourceVisits, legacyCloneVisits: cloneVisits, avoidedVisits: cloneVisits - sourceVisits}));
