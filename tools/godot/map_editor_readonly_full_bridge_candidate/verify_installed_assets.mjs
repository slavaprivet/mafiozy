import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {CATALOG_SHA256} from './source_index.mjs';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const catalogPath=path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json');
const canonical=path.join(root,'godot/mafiozi_walk/assets/map_editor');
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const catalogBytes=fs.readFileSync(catalogPath);
assert.equal(sha(catalogBytes),CATALOG_SHA256,'catalog drift');
const catalog=JSON.parse(catalogBytes);
assert.equal(catalog.resources.length,196,'catalog resource count');
const expected=new Set(catalog.resources.map(row=>row.id+'.glb'));
assert.equal(expected.size,196,'duplicate resource id');
const names=fs.readdirSync(canonical).filter(name=>name.endsWith('.glb'));
assert.deepEqual(names.sort(),[...expected].sort(),'canonical GLB path set');
let bytes=0;
for(const row of catalog.resources){
  assert.match(row.id,/^[0-9a-f]{64}$/);
  const target=path.join(canonical,row.id+'.glb');
  const stat=fs.lstatSync(target);
  assert.ok(stat.isFile()&&!stat.isSymbolicLink(),'not a regular asset: '+row.id);
  assert.equal(stat.size,row.bytes,'size drift: '+row.id);
  assert.equal(sha(fs.readFileSync(target)),row.sha256,'SHA drift: '+row.id);
  bytes+=stat.size;
}
console.log(JSON.stringify({status:'CANONICAL_ASSETS_VERIFIED',catalogSha256:CATALOG_SHA256,models:expected.size,bytes,project:'godot/mafiozi_walk',importVerified:false,editorConnected:false}));
