/** Extends the ordinary-building immutable stage with this tools-only owner fixture. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const ordinary=path.join(root,'tools/godot/map_editor_ordinary_building_tx_candidate/stage_checkpoint.mjs');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.deepEqual(process.argv.slice(2),['--stage'],'usage: node stage_checkpoint.mjs --stage');
const result=JSON.parse(execFileSync(process.execPath,[ordinary,'--stage'],{cwd:root,encoding:'utf8',maxBuffer:1024*1024}).trim());
assert.equal(result.status,'STAGED_NO_GODOT');
const stage=path.resolve(root,result.stage);
assert.ok(stage.startsWith(path.resolve(root,'outputs')+path.sep));
const additions=[['terrain_owner.gd','scripts/map_editor/terrain_owner.gd'],['test_terrain_owner.gd','test_terrain_owner.gd']];
const files=[];
for(const [source,destination] of additions){
 const data=fs.readFileSync(path.join(own,source));
 const target=path.join(stage,destination);
 assert.ok(target.startsWith(stage+path.sep));
 fs.writeFileSync(target,data,{flag:'wx'});
 files.push({path:destination,bytes:data.length,sha256:sha(data)});
}
fs.writeFileSync(path.join(stage,'terrain_owner_stage_receipt.json'),JSON.stringify({schema:'mafiozi.map-editor-terrain-owner-stage/v1',ordinaryStageReceiptSha256:result.receiptSha256,files,productionModified:false,gpu:false},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({status:'STAGED_NO_GODOT',stage:result.stage,ordinaryStageReceiptSha256:result.receiptSha256,addedFiles:files,productionModified:false,gpu:false}));
