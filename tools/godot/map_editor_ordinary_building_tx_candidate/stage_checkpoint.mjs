/** Optional isolated native fixture stage. Never runs Godot or mutates production. */
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const source=path.join(root,'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const pins={'scripts/main.gd':'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53','data/block.json':'1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e','scenes/main.tscn':'52aa1629fe38251f27ab50e3c6c102e0d0073348d6f610319d6c6b0233618bde','project.godot':'c500a17d372f149b4b751ed4ef90a5a27bcb55e1050ba9d510d33fb5bcf6ff28'};
function read(file){const stat=fs.lstatSync(file);assert.ok(stat.isFile()&&!stat.isSymbolicLink(),'unsafe source file');const rel=path.relative(root,fs.realpathSync(file));assert.ok(rel&&!rel.startsWith('..')&&!path.isAbsolute(rel),'source outside workspace');return fs.readFileSync(file);}
function inventory(){
 const rows=[];
 function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){
  const target=path.join(dir,entry.name),rel=path.relative(source,target).replaceAll('\\','/');
  assert.ok(!entry.isSymbolicLink(),'symlink source refused');
  if(entry.isDirectory()){if(entry.name==='.godot'||rel==='scripts/tests')continue;walk(target);}
  else if(entry.isFile())rows.push([rel,read(target)]);
 }}
 for(const dir of ['scripts','scenes','data','assets','addons'])walk(path.join(source,dir));
 rows.sort((a,b)=>a[0].localeCompare(b[0]));return rows;
}
const original=inventory(),lookup=new Map(original),project=read(path.join(source,'project.godot'));
assert.ok(original.length>100&&original.length<2000,'checkpoint count bound');
for(const [rel,wanted] of Object.entries(pins))assert.equal(sha(rel==='project.godot'?project:lookup.get(rel)),wanted,'checkpoint pin drift: '+rel);
const digest=sha(Buffer.from(JSON.stringify(original.map(([rel,b])=>[rel,b.length,sha(b)]))));
const files=new Map(original);
function add(rel,bytes){assert.ok(!files.has(rel),'stage collision: '+rel);files.set(rel,bytes);}
const catalog=read(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json'));
assert.equal(sha(catalog),'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e');
add('data/map_editor/catalog.json',catalog);
add('scripts/map_editor/native_building_inventory.gd',read(path.join(root,'tools/godot/map_editor_native_building_adoption_candidate/inventory.gd')));
add('scripts/map_editor/ordinary_building_tx.gd',read(path.join(own,'ordinary_building_tx.gd')));
add('test_ordinary_building_tx.gd',read(path.join(own,'test_ordinary_building_tx.gd')));
const projectText=project.toString('utf8'),isolated=projectText.replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziOrdinaryBuildingTx-${crypto.randomUUID()}"`);
assert.notEqual(isolated,projectText,'user directory seam missing');
add('project.godot',Buffer.from(isolated));
const bytes=[...files.values()].reduce((a,b)=>a+b.length,0);
assert.ok(bytes<180*1024*1024,'stage size bound');
function recheck(){const after=inventory();assert.equal(after.length,original.length,'checkpoint path set drift');for(let i=0;i<after.length;i++)assert.ok(after[i][0]===original[i][0]&&after[i][1].length===original[i][1].length&&sha(after[i][1])===sha(original[i][1]),'checkpoint byte drift');assert.equal(sha(read(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json'))),sha(catalog),'catalog drift');}
const args=process.argv.slice(2);assert.ok(args.length===1&&['--dry-run','--stage'].includes(args[0]),'usage: node stage_checkpoint.mjs --dry-run|--stage');
recheck();
if(args[0]==='--dry-run')console.log(JSON.stringify({status:'PASS_DRY_RUN',checkpointFiles:original.length,checkpointClosureSha256:digest,stageFiles:files.size,stageBytes:bytes,gpu:false}));
else{
 const dir=fs.mkdtempSync(path.join(root,'outputs/map-editor-ordinary-building-tx-'));
 for(const [rel,data] of files){const dest=path.join(dir,rel);assert.ok(dest.startsWith(dir+path.sep),'stage escape');fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,data,{flag:'wx'});assert.equal(sha(fs.readFileSync(dest)),sha(data),'stage write drift');}
 recheck();
 const receipt={schema:'mafiozi.map-editor-ordinary-building-tx-stage/v1',checkpointClosureSha256:digest,pins,files:[...files].map(([rel,data])=>({path:rel,bytes:data.length,sha256:sha(data)})),productionModified:false,gpu:false};
 fs.writeFileSync(path.join(dir,'stage_receipt.json'),JSON.stringify(receipt,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({status:'STAGED_NO_GODOT',stage:path.relative(root,dir).replaceAll('\\','/'),receiptSha256:sha(fs.readFileSync(path.join(dir,'stage_receipt.json'))),files:files.size,bytes,gpu:false}));
}
