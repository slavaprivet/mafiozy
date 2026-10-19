import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const catalogBytes=fs.readFileSync(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json'));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
assert.equal(hash(catalogBytes),'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e');
const catalog=JSON.parse(catalogBytes);
const special=catalog.objects.filter(x=>x.sourceRecord?.role==='bank_shell'||x.sourceRecord?.role==='district_detention');
assert.equal(special.length,6);
assert.equal(special.filter(x=>x.dataset==='buildings').length,3);
assert.equal(special.filter(x=>x.dataset==='detention').length,3);
const ids=special.map(x=>x.id).sort();
assert.deepEqual(ids,[
 'REBUILD-DETENTION-chinatown','REBUILD-DETENTION-iron_harbor','REBUILD-DETENTION-southside',
 'REBUILD-bank:large','REBUILD-bank:medium','REBUILD-bank:small',
].sort());
const block=JSON.parse(fs.readFileSync(path.join(root,'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk/data/block.json')));
assert.ok(special.every(x=>!block.buildings.some(b=>b.id===x.id)),'all six absent from actual main crop');
const gd=fs.readFileSync(path.join(own,'special_building_tx.gd'),'utf8');
for(const id of ids)assert.ok(gd.includes('"'+id+'"'));
for(const claim of ['visual','collisions','interior','entrance','navigation','traffic','source_id','undo'])assert.ok(gd.includes('"'+claim+'"'));
for(const seam of ['map_editor_resolve_special_building','map_editor_prepare_special_edit','_rollback','special-owner-revision-drift','missing-special-owner-api'])assert.ok(gd.includes(seam));
assert.ok(!gd.includes('registry.is_editable')&&!gd.includes('prepare_install_document'),'protected import guard not bypassed here');
console.log(JSON.stringify({status:'PASS_SOURCE_SCOPE_ONLY',specialIds:ids,banks:3,detention:3,liveInCheckpoint:0,ownerApisPresent:false,godotExecuted:false,productionInstalled:false}));
