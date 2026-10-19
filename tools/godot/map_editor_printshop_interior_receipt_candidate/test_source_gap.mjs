import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';

const root = resolve('.');
const checkpoint = 'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk/';
const read = relative => readFile(resolve(root, relative));
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const pins = {
  'scripts/main.gd': 'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
  'scripts/preview_printshop_interior.gd': 'f6f082584ada23dcd55b384c629505730c80a59080768910a17c653d7eb1b5df',
  'scripts/preview_interior_finish.gd': '666bb28093d3bc9fbf17b702dda9c460d1364c64dee63c236b02fc9d80519ced',
  'data/block.json': '1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e',
  'data/printshop_interior.json': '958a2c2d8cbdc2b2e2e11a57e33bf9bf5a20ec334be8a8997bdad951f9f8086b',
  'assets/buildings/print_shop.ad7b8ef7e7e4.glb': 'ad7b8ef7e7e4143f0e989b7a585c03bb9bd1c13d5efb8689cf67ebcb92ac4d97',
};
for (const [name, expected] of Object.entries(pins)) assert.equal(sha(await read(checkpoint + name)), expected, 'immutable checkpoint: ' + name);
assert.equal(sha(await read('godot/mafiozi_walk/data/map_editor/catalog.json')), 'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e');
const block = JSON.parse(await read(checkpoint + 'data/block.json'));
const data = JSON.parse(await read(checkpoint + 'data/printshop_interior.json'));
const source = [...block.buildings, ...block.decor].filter(row => row.id === 'REBUILD-VISUAL-print_shop-001');
assert.equal(source.length, 1);
assert.equal(source[0].binding.sha256, data.assetSha256);
assert.equal(source[0].path, 'res://assets/buildings/print_shop.ad7b8ef7e7e4.glb');
assert.equal(source[0].collisionBodiesM.length, 3);
assert.equal(data.meshes.length, 41);
assert.equal(data.overrides.length, 22);
assert.equal(data.hideOriginalNames.length, 1);
assert.equal(data.staticBodies.length, 103);
assert.equal(data.meshes.filter(spec => spec.floorCollision).length, 4);
assert.equal(Object.values(data.doors).reduce((sum, door) => sum + door.bodies.length, 0), 4);
const script = (await read(checkpoint + 'scripts/preview_printshop_interior.gd')).toString();
assert.match(script, /var _mesh_cache: Dictionary = \{\}/);
assert.match(script, /var _material_cache: Dictionary = \{\}/);
assert.match(script, /var _doors: Dictionary = \{\}/);
assert.match(script, /func request_door\(/);
assert.match(script, /func advance\(/);
assert.match(script, /func restore_original\(/);
assert.doesNotMatch(script, /\b(?:revision|generation|epoch|seal)\b/i, 'no monotonic owner revision/seal exposed');
const owner = (await read('tools/godot/map_editor_printshop_interior_receipt_candidate/printshop_interior_owner.gd')).toString();
assert.match(owner, /const HOLD := "printshop-owner-revision-or-seal-required"/);
assert.match(owner, /func verified_root\(\) -> Node3D:\s*return null/);
console.log(JSON.stringify({status: 'PASS_SOURCE_GAP_ONLY', checkpointMainSha256: pins['scripts/main.gd'], packageSha256: pins['data/printshop_interior.json'], expectedInteriorBodies: 111, ownerRevisionAvailable: false, verifiedRoots: 0, godotExecuted: false}));
