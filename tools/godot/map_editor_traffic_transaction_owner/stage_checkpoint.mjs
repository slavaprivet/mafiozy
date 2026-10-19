import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {buildConstraints} from './build_constraints.mjs';
import {buildLinkedPacket} from './build_linked_packet.mjs';

const own=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(own,'../../..');
const source=path.join(root,'outputs/coordinator22_residents_checkpoint/godot/mafiozi_walk');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function read(file){const stat=fs.lstatSync(file);assert.ok(stat.isFile()&&!stat.isSymbolicLink());return fs.readFileSync(file);}
function inventory(){const rows=[];function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const target=path.join(dir,entry.name),rel=path.relative(source,target).replaceAll('\\','/');assert.ok(!entry.isSymbolicLink());if(entry.isDirectory()){if(entry.name==='.godot'||rel==='scripts/tests')continue;walk(target);}else if(entry.isFile())rows.push([rel,read(target)]);}}for(const dir of ['scripts','scenes','data','assets','addons'])walk(path.join(source,dir));rows.sort((a,b)=>a[0].localeCompare(b[0]));return rows;}
const original=inventory(),lookup=new Map(original),project=read(path.join(source,'project.godot'));
assert.equal(sha(lookup.get('scripts/main.gd')),'faac92194afdfac5efb4197a17a81d53738a91a46a6e41f96316f9c282112f53');
assert.equal(sha(lookup.get('data/block.json')),'1523f52e2e859c42aec208d4acfffb9714ffb99974823098bb063e31ee61c22e');
assert.equal(sha(lookup.get('data/transport/vehicle_descriptors.v1.json')),'99d328bc4a581bc65815498b265ae5eec71a25b831512b15d376e1c0f5ac031a');
const files=new Map(original);
function add(rel,bytes){assert.ok(!files.has(rel),`stage collision ${rel}`);files.set(rel,bytes);}
const catalog=read(path.join(root,'godot/mafiozi_walk/data/map_editor/catalog.json'));
assert.equal(sha(catalog),'ae089d73eb61131bc6a38ccc6a2b9b18639f7bd8b65079f7c15c1e1cda9cde6e');
add('data/map_editor/catalog.json',catalog);
const constraints=Buffer.from(JSON.stringify(buildConstraints()));
add('data/map_editor/traffic_constraints.json',constraints);
const linkedPacket=Buffer.from(JSON.stringify(buildLinkedPacket()));
assert.equal(sha(linkedPacket),'259ede19883bf73da85f3436661f77ab1ca1cba5fc7bc1d3f49c392d4671689c');
add('data/map_editor/linked_stationary_bay_packet.json',linkedPacket);
add('scripts/map_editor/traffic_owner.gd',read(path.join(own,'traffic_owner.gd')));
add('scripts/map_editor/linked_stationary_bay_owner.gd',read(path.join(own,'linked_stationary_bay_owner.gd')));
add('scripts/map_editor/native_building_inventory.gd',read(path.join(root,'tools/godot/map_editor_native_building_adoption_candidate/inventory.gd')));
add('scripts/map_editor/ordinary_building_tx.gd',read(path.join(root,'tools/godot/map_editor_ordinary_building_tx_candidate/ordinary_building_tx.gd')));
add('test_traffic_owner.gd',read(path.join(own,'test_traffic_owner.gd')));
add('test_linked_stationary_bay.gd',read(path.join(own,'test_linked_stationary_bay.gd')));
add('test_linked_ordinary_tx.gd',read(path.join(own,'test_linked_ordinary_tx.gd')));
const originalProject=project.toString('utf8');
const isolated=originalProject.replace('config/custom_user_dir_name="MafioziGodotPreview"',`config/custom_user_dir_name="MafioziTrafficTx-${crypto.randomUUID()}"`);
assert.notEqual(isolated,originalProject);
add('project.godot',Buffer.from(isolated));
function recheck(){const after=inventory();assert.equal(after.length,original.length);for(let i=0;i<after.length;i++)assert.ok(after[i][0]===original[i][0]&&sha(after[i][1])===sha(original[i][1]));}
const args=process.argv.slice(2);assert.ok(args.length===1&&['--dry-run','--stage'].includes(args[0]));recheck();
if(args[0]==='--dry-run')console.log(JSON.stringify({status:'PASS_DRY_RUN',checkpointFiles:original.length,stageFiles:files.size,stageBytes:[...files.values()].reduce((n,b)=>n+b.length,0),trafficConstraints:JSON.parse(constraints).rects.length,gpu:false}));
else {const dir=fs.mkdtempSync(path.join(root,'outputs/map-editor-traffic-owner-'));for(const [rel,bytes] of files){const target=path.join(dir,rel);assert.ok(target.startsWith(dir+path.sep));fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,bytes,{flag:'wx'});}recheck();console.log(JSON.stringify({status:'STAGED_NO_GODOT',stage:dir,files:files.size,bytes:[...files.values()].reduce((n,b)=>n+b.length,0),gpu:false}));}
