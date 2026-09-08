import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {applyBuildingDoorsGlass, BUILDING_DOORS_GLASS_PROFILES as profiles} from './building_doors_glass.mjs';

// Use the same locally bundled Three as the existing real-hero tests.
const vendor = process.env.MAFIOZI_THREE_MODULE || 'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js';
const THREE = await import(pathToFileURL(vendor));
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const catalog = JSON.parse(fs.readFileSync(path.join(here, 'buildings_catalog.v1.json')));
const placement = JSON.parse(fs.readFileSync(path.join(here, 'buildings_placement.v1.json')));
let assertions = 0;
const test = (name, fn) => { fn(); assertions++; console.log('PASS ' + name); };
const audited = new Map();
for (const entry of catalog.entries) {
  const binding = entry.lods.find(lod => lod.lod === 0);
  const bytes = fs.readFileSync(path.join(root, binding.url.slice(1)));
  assert.equal(createHash('sha256').update(bytes).digest('hex'), binding.sha256);
  audited.set(entry.assetId, {binding, gltf: JSON.parse(bytes.subarray(20, 20 + bytes.readUInt32LE(12)))});
}

test('every opted-in profile matches actual pinned LOD0 nodes and materials', () => {
  for (const [assetId, profile] of Object.entries(profiles)) {
    const {binding, gltf} = audited.get(assetId);
    assert.equal(binding.sha256, profile.sha256, assetId);
    for (const name of profile.glass) {
      const material = gltf.materials.find(m => m.name === name);
      assert.equal(material?.alphaMode, 'BLEND', assetId + ':' + name);
      assert(material.pbrMetallicRoughness.baseColorFactor[3] < 1);
    }
    for (const name of profile.hiddenNodes) assert(gltf.nodes.some(n => n.name === name));
    if (profile.knobs) {
      const knob = gltf.nodes.find(n => n.name === 'PublicDoorKnob');
      assert(knob);
      assert(gltf.meshes[knob.mesh].primitives.every(p => gltf.materials[p.material].name === 'ClayStone'));
    }
  }
});

// Actual Three materials + actual GLB material/node associations. Geometry is
// unnecessary for this module: it must not change geometry, transforms or bounds.
function fixture(assetId) {
  const {binding, gltf} = audited.get(assetId);
  const materials = gltf.materials.map(m => {
    const pbr = m.pbrMetallicRoughness ?? {}, material = new THREE.MeshStandardMaterial();
    material.name = m.name;
    material.color.fromArray(pbr.baseColorFactor ?? [1, 1, 1]);
    material.opacity = pbr.baseColorFactor?.[3] ?? 1;
    material.transparent = m.alphaMode === 'BLEND';
    material.side = m.doubleSided ? THREE.DoubleSide : THREE.FrontSide;
    material.metalness = pbr.metallicFactor ?? 1;
    material.roughness = pbr.roughnessFactor ?? 1;
    material.aoMap = new THREE.Texture();
    return material;
  });
  const source = new THREE.Group();
  for (const node of gltf.nodes) {
    const nodeMaterials = gltf.meshes[node.mesh]?.primitives.map(p => materials[p.material]);
    const object = nodeMaterials ? new THREE.Mesh(new THREE.BoxGeometry(), nodeMaterials.length === 1 ? nodeMaterials[0] : nodeMaterials) : new THREE.Group();
    object.name = node.name ?? '';
    if (node.translation) object.position.fromArray(node.translation);
    source.add(object);
  }
  return {source, visual: source.clone(true), instance: {assetId, binding}};
}

test('pavilion sign hides only in instance; original glass colour, alpha and AO survive', () => {
  const {source, visual, instance} = fixture('glass_pavilion_small_v1');
  const original = source.getObjectByName('Small_Public_Double_Door_GLASS_LEAF_L');
  const leaf = visual.getObjectByName(original.name), transform = leaf.position.toArray();
  const result = applyBuildingDoorsGlass(visual, instance);
  assert.deepEqual(result.report.hiddenNodes, ['Small_Galleria_Sign']);
  assert.equal(source.getObjectByName('Small_Galleria_Sign').visible, true);
  assert.equal(visual.getObjectByName('Small_Galleria_Sign').visible, false);
  assert.notEqual(leaf.material, original.material);
  assert.equal(leaf.material.aoMap, original.material.aoMap);
  assert.equal(leaf.material.opacity, original.material.opacity);
  assert.deepEqual(leaf.material.color.toArray(), original.material.color.toArray());
  assert.equal(leaf.material.depthWrite, false);
  assert.equal(leaf.material.side, THREE.FrontSide);
  assert.deepEqual(leaf.position.toArray(), transform);
  assert.equal(applyBuildingDoorsGlass(visual, instance), result, 'idempotent');
  let disposal = 0;
  leaf.material.addEventListener('dispose', () => disposal++);
  result.dispose(); result.dispose();
  assert.equal(disposal, 1);
  assert.equal(leaf.material, original.material);
  assert.equal(visual.getObjectByName('Small_Galleria_Sign').visible, true);
});

test('stone shared with house geometry stays stone; only the known knob becomes brass', () => {
  const {source, visual, instance} = fixture('coastal_orchard_house_v1');
  const knob = visual.getObjectByName('PublicDoorKnob');
  const stone = knob.material;
  const sameStone = visual.children.find(n => n !== knob && n.material === stone);
  assert(sameStone, 'real source exports shared stone');
  const result = applyBuildingDoorsGlass(visual, instance);
  assert.equal(result.report.brassKnobs, 1);
  assert.equal(knob.material.metalness, 0.56);
  assert.equal(sameStone.material, stone);
  assert.equal(source.getObjectByName('PublicDoorKnob').material, stone);
  assert.equal(result.report.glassMeshes, 0, 'WindowWarm must not become fake transparent glass');
  result.dispose();
});

test('unknown geometry revision and unprofiled opaque glass fail closed', () => {
  const {visual, instance} = fixture('glass_pavilion_small_v1');
  assert.equal(applyBuildingDoorsGlass(visual, {...instance, binding: {...instance.binding, sha256: 'new-revision'}}).report.status, 'binding-mismatch');
  assert.equal(visual.getObjectByName('Small_Galleria_Sign').visible, true);
  const unknown = fixture('old_town_narrow_townhouse_v1');
  assert.equal(applyBuildingDoorsGlass(unknown.visual, unknown.instance).report.status, 'not-profiled');
});

test('72 placements: exact sign/hardware counts and identity/collision records unchanged', () => {
  const before = JSON.stringify(placement);
  let hidden = 0, knobs = 0;
  for (const item of placement.instances) {
    const {source, visual} = fixture(item.assetId);
    const result = applyBuildingDoorsGlass(visual, item);
    hidden += result.report.hiddenNodes.length;
    knobs += result.report.brassKnobs;
    for (let i = 0; i < source.children.length; i++) {
      assert.equal(source.children[i].geometry, visual.children[i].geometry);
      assert.deepEqual(source.children[i].position.toArray(), visual.children[i].position.toArray());
    }
    result.dispose();
  }
  assert.equal(hidden, 4);
  assert.equal(knobs, 13);
  assert.equal(JSON.stringify(placement), before);
});
console.log(`${assertions} checks passed; 21 pinned GLBs audited. Live visual QA remains separate.`);
