import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {CATALOG_SHA256} from './source_index.mjs';

// Read-only source check. Import success in an isolated project does not update
// catalog.resPath, install a resource into the game, or register a live owner.
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../..');
const stage=path.join(root,'outputs/map_editor_source_assembly_xzhZTw');
const game=path.join(root,'godot/mafiozi_walk');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const catalogBytes=fs.readFileSync(path.join(game,'data/map_editor/catalog.json'));
assert.equal(hash(catalogBytes),CATALOG_SHA256,'frozen catalog lineage changed');
assert.deepEqual(fs.readFileSync(path.join(stage,'data/catalog.json')),catalogBytes,'isolated import changed catalog bytes');
const catalog=JSON.parse(catalogBytes);
const receipt=JSON.parse(fs.readFileSync(path.join(stage,'source_receipt.json')));
const byId=new Map();
const receiptFiles=new Map(receipt.files.map(row=>[row.path,row]));
let stageBytes=0,prodPresent=0,canonicalPaths=0,historicalPaths=0,staleResourcePaths=0,catalogPathsVerified=0;
for(const resource of catalog.resources){
 assert.match(resource.id,/^[0-9a-f]{64}$/);
 assert.equal(resource.id,resource.sha256);
 assert.equal(byId.has(resource.id),false,'duplicate resource ID');
 byId.set(resource.id,resource);
 const rel=`assets/map_editor/${resource.id}.glb`;
 const staged=fs.readFileSync(path.join(stage,rel));
 assert.equal(staged.length,resource.bytes,`stage bytes: ${resource.id}`);
 assert.equal(hash(staged),resource.id,`stage SHA: ${resource.id}`);
 const receiptRow=receiptFiles.get(rel);
 assert.ok(receiptRow,`missing stage receipt: ${resource.id}`);
 assert.equal(receiptRow.bytes,resource.bytes);
 assert.equal(receiptRow.sha256,resource.id);
 stageBytes+=staged.length;
 const expected=`res://${rel}`;
 if(resource.resPath){
  assert.ok(resource.resPath.startsWith('res://assets/')&&!resource.resPath.includes('..'),'unsafe historical catalog path');
  if(resource.resPath===expected)canonicalPaths++;
  else historicalPaths++;
  const historical=path.join(game,resource.resPath.slice('res://'.length));
  if(fs.existsSync(historical)){
   const oldBytes=fs.readFileSync(historical);
   assert.equal(oldBytes.length,resource.bytes,`historical bytes: ${resource.id}`);
   assert.equal(hash(oldBytes),resource.id,`historical SHA: ${resource.id}`);
   catalogPathsVerified++;
  }
 }else staleResourcePaths++;
 const prodPath=path.join(game,rel);
 if(fs.existsSync(prodPath)){
  const installed=fs.readFileSync(prodPath);
  assert.equal(installed.length,resource.bytes,`production bytes: ${resource.id}`);
  assert.equal(hash(installed),resource.id,`production SHA: ${resource.id}`);
  prodPresent++;
 }
}
assert.equal(byId.size,196);
assert.equal(canonicalPaths,3);
assert.equal(historicalPaths,5);
assert.equal(catalogPathsVerified,8);
assert.equal(staleResourcePaths,188);
const buildings=catalog.objects.filter(row=>row.dataset==='buildings');
const detention=catalog.objects.filter(row=>row.dataset==='detention');
assert.equal(buildings.length,75);
assert.equal(buildings.filter(row=>row.livePresent).length,8);
assert.equal(buildings.filter(row=>row.available).length,36);
assert.ok(buildings.every(row=>row.editCapability==='requires-host-registration'));
assert.equal(detention.length,3);
assert.ok(detention.every(row=>row.editCapability==='requires-host-registration'));
assert.ok(catalog.objects.filter(row=>row.resourceId).every(row=>byId.has(row.resourceId)));
console.log(JSON.stringify({status:'PASS_READONLY_SOURCE_BOUNDARY',catalogSha256:CATALOG_SHA256,stagedResources:byId.size,stagedBytes:stageBytes,productionMapEditorVerified:prodPresent,catalogCanonicalPaths:canonicalPaths,catalogHistoricalPaths:historicalPaths,catalogPathsVerified,catalogMissingResourcePaths:staleResourcePaths,buildings:buildings.length,liveBuildings:8,catalogAvailableBuildings:36,registeredBuildingEditors:0,specialBuildings:3+detention.length}));
