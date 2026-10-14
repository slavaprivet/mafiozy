/** Add an isolated split-transaction fixture to the immutable nav-owner stage. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {buildConstraints} from '../map_editor_traffic_transaction_owner/build_constraints.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
assert.deepEqual(process.argv.slice(2),['--stage']);
const navStage=path.join(root,'tools/godot/map_editor_nav_geometry_tx_candidate/stage.mjs');
const result=JSON.parse(execFileSync(process.execPath,[navStage],{cwd:root,encoding:'utf8',maxBuffer:1024*1024}).trim());
assert.equal(result.status,'STAGED_NAV_GEOMETRY_ATOMIC_OWNERS');
const stage=path.resolve(root,result.stage);
assert.ok(stage.startsWith(path.join(root,'outputs')+path.sep));
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const source=(relative)=>fs.readFileSync(path.join(root,relative));
const geometryPath=path.join(stage,'scripts/map_editor/nav_geometry_receipt.gd');
const geometryOriginal=fs.readFileSync(geometryPath,'utf8');
const geometryPin='e6a42657c66dac4126f260adf83dd762a32c9ff7fd9c8ff1f98c0ae72584af85';
assert.equal(sha(Buffer.from(geometryOriginal)),geometryPin,'navigation inspector changed; review generalization');
let geometryGeneralized=geometryOriginal;
for(const [needle,replacement] of [
  ['const HOUSE := "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"',
   'const HOUSES := ["REBUILD-VISUAL-old_town_narrow_townhouse_v1-012", "REBUILD-VISUAL-old_town_narrow_townhouse_v1-013"]'],
  ['source_id != HOUSE','source_id not in HOUSES']
]){
  assert.ok(geometryGeneralized.includes(needle));
  geometryGeneralized=geometryGeneralized.replaceAll(needle,replacement);
}
fs.writeFileSync(geometryPath,geometryGeneralized);
assert.equal(fs.readFileSync(geometryPath,'utf8'),geometryGeneralized);
const files=[
  ['scripts/map_editor/terrain_owner.gd',source('tools/godot/map_editor_terrain_owner_candidate/terrain_owner.gd')],
  ['scripts/map_editor/traffic_owner.gd',source('tools/godot/map_editor_traffic_transaction_owner/traffic_owner.gd')],
  ['scripts/map_editor/split_ordinary_building_tx.gd',source('tools/godot/map_editor_ordinary_building_split_candidate/split_ordinary_building_tx.gd')],
  ['test_split_delete.gd',source('tools/godot/map_editor_ordinary_building_split_candidate/test_split_delete.gd')],
  ['data/map_editor/traffic_constraints.json',Buffer.from(JSON.stringify(buildConstraints()))]
];
for(const [relative,bytes] of files){
  const target=path.join(stage,relative);
  assert.ok(target.startsWith(stage+path.sep));
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes,{flag:'wx'});
  assert.equal(sha(fs.readFileSync(target)),sha(bytes));
}
const receipt={schema:'mafiozi.map-editor-ordinary-split-stage/v1',source:'immutable Coordinator22 residents checkpoint',base:result.stage,
  files:files.map(([relative,bytes])=>({path:relative,sha256:sha(bytes),bytes:bytes.length})),
  overlays:[{path:'scripts/map_editor/nav_geometry_receipt.gd',baseSha256:geometryPin,sha256:sha(Buffer.from(geometryGeneralized))}],productionModified:false,gpu:false};
fs.writeFileSync(path.join(stage,'ordinary_split_stage_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:'STAGED_SPLIT_ORDINARY_BUILDING',stage:result.stage,files:files.length,
  source:'immutable Coordinator22 residents checkpoint',productionModified:false,gpu:false}));
