/** Isolated checkpoint fixture: source-only preflight by default, no Godot run. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildActivation} from '../map_editor_readonly_full_bridge_candidate/canonical_activation.mjs';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const checkpoint=path.join(root,'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const pins={
 'scripts/main.gd':'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53',
 'scenes/main.tscn':'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde',
 'project.godot':'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28'
};
const activationPin='47c8fd105dea7b87d12c63eeb0e5c10373c9832e947def2ac870f1618996d08c';
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function readRegular(file){
 const stat=fs.lstatSync(file);
 assert.ok(stat.isFile()&&!stat.isSymbolicLink(),'non-regular source '+file);
 const rel=path.relative(root,fs.realpathSync(file));
 assert.ok(rel&&!rel.startsWith('..')&&!path.isAbsolute(rel),'source escapes workspace');
 return fs.readFileSync(file);
}
function closure(){
 const rows=[];
 function walk(dir){
  for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
   const absolute=path.join(dir,entry.name),rel=path.relative(checkpoint,absolute).replaceAll('\\','/');
   assert.ok(!entry.isSymbolicLink(),'checkpoint symlink '+rel);
   if(entry.isDirectory()){
    if(entry.name==='.godot'||rel==='scripts/tests')continue;
    walk(absolute);
   }else if(entry.isFile())rows.push([rel,readRegular(absolute)]);
  }
 }
 for(const name of ['scripts','scenes','data','assets','addons'])walk(path.join(checkpoint,name));
 rows.sort((a,b)=>a[0].localeCompare(b[0]));
 return rows;
}
const original=closure();
const originalMap=new Map(original);
const project=readRegular(path.join(checkpoint,'project.godot'));
for(const [rel,wanted] of Object.entries(pins))assert.equal(sha(rel==='project.godot'?project:originalMap.get(rel)),wanted,'checkpoint source drift: '+rel);
assert.ok(original.length>100&&original.length<2000,'implausible checkpoint path set');
const sourceBytes=original.reduce((sum,[,bytes])=>sum+bytes.length,0);
assert.ok(sourceBytes<180*1024*1024,'checkpoint closure too large');
const originalDigest=sha(Buffer.from(JSON.stringify(original.map(([rel,bytes])=>[rel,bytes.length,sha(bytes)]))));
const activationPath=path.join(root,'outputs/map-editor-canonical-activation-0CYT2f/activation_manifest.json');
const activationBytes=readRegular(activationPath);
assert.equal(sha(activationBytes),activationPin,'activation manifest drift');
const activation=JSON.parse(activationBytes);
const current=buildActivation();
assert.deepEqual(current,activation,'activation sources/path set drift');
const prepared=new Map(original);
function add(rel,bytes){assert.ok(!prepared.has(rel),'stage path collision: '+rel);prepared.set(rel,bytes);}
add('data/map_editor/catalog.json',readRegular(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json')));
add('data/map_editor/activation_manifest.json',activationBytes);
for(const row of activation.rows){
 const bytes=readRegular(path.join(root,row.source));
 assert.equal(bytes.length,row.bytes);
 assert.equal(sha(bytes),row.id);
 const rel=`assets/map_editor/${row.id}.glb`;
 if(prepared.has(rel)){assert.equal(sha(prepared.get(rel)),row.id,'checkpoint canonical collision');continue;}
 add(rel,bytes);
}
add('scripts/map_editor/catalog_factory.gd',readRegular(path.join(root,'tools/godot/map_editor_assembly_candidate/catalog_factory.gd')));
add('scripts/map_editor/live_authored_owner.gd',readRegular(path.join(root,'tools/godot/map_editor_live_authored_receipt_candidate/live_authored_owner.gd')));
add('scripts/map_editor/authored_readonly_builder.gd',readRegular(path.join(own,'authored_readonly_builder.gd')));
add('test_authored_readonly_builder.gd',readRegular(path.join(own,'test_authored_readonly_builder.gd')));
const projectText=project.toString('utf8');
const isolated=projectText.replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziAuthoredReadOnly-${crypto.randomUUID()}"`);
assert.notEqual(isolated,projectText,'checkpoint user-dir setting missing');
add('project.godot',Buffer.from(isolated));
const totalBytes=[...prepared.values()].reduce((sum,bytes)=>sum+bytes.length,0);
assert.ok(totalBytes<240*1024*1024,'stage byte bound exceeded');
function recheck(){
 const after=closure();
 assert.equal(after.length,original.length,'checkpoint path-set changed');
 for(let i=0;i<after.length;i++)assert.ok(after[i][0]===original[i][0]&&after[i][1].length===original[i][1].length&&sha(after[i][1])===sha(original[i][1]),'checkpoint source drift: '+original[i][0]);
 assert.deepEqual(buildActivation(),activation,'activation source/path-set changed');
 assert.equal(sha(readRegular(activationPath)),activationPin,'activation receipt changed');
}
const args=process.argv.slice(2);
assert.ok(args.length===1&&['--dry-run','--stage'].includes(args[0]),'usage: node stage_checkpoint.mjs --dry-run|--stage');
recheck();
if(args[0]==='--dry-run')console.log(JSON.stringify({status:'PASS_DRY_RUN',checkpointFiles:original.length,checkpointBytes:sourceBytes,checkpointClosureSha256:originalDigest,stageFiles:prepared.size,stageBytes:totalBytes,authored:242,glbs:196,activationSha256:activationPin,gpu:false}));
else{
 const dest=fs.mkdtempSync(path.join(root,'outputs/map-editor-authored-readonly-'));
 const files=[...prepared].sort(([a],[b])=>a.localeCompare(b));
 for(const [rel,bytes] of files){
  const target=path.join(dest,rel);
  assert.ok(target.startsWith(dest+path.sep),'stage escape');
  fs.mkdirSync(path.dirname(target),{recursive:true});
  fs.writeFileSync(target,bytes,{flag:'wx'});
  assert.equal(sha(fs.readFileSync(target)),sha(bytes),'stage copy drift');
 }
 recheck();
 const receipt={schema:'mafiozi.map-editor-authored-readonly-stage/v1',checkpointRelative:'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk',checkpointPins:pins,checkpointClosureSha256:originalDigest,activationSha256:activationPin,sourceCatalogSha256:activation.catalogSha256,files:files.map(([rel,bytes])=>({path:rel,bytes:bytes.length,sha256:sha(bytes)})),gpu:false,productionModified:false};
 fs.writeFileSync(path.join(dest,'stage_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:'STAGED_NO_GODOT',stage:path.relative(root,dest).replaceAll('\\','/'),stageReceiptSha256:sha(fs.readFileSync(path.join(dest,'stage_receipt.json'))),checkpointClosureSha256:originalDigest,files:files.length,bytes:totalBytes,gpu:false}));
}
