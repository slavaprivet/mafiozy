/** Frozen code-only native candidate. Default --check; --stage writes outputs only. */
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
const HERE=path.dirname(fileURLToPath(import.meta.url));
const ROOT=path.resolve(HERE,'../../..');
const EXPECTED_SHA='82e6ef82a824e002d0f315972ffd3d967102b7c36256371699992bcfb76220dd';
const hash=raw=>createHash('sha256').update(raw).digest('hex');
let stage=false,source=path.join(ROOT,'outputs/map_editor_procedural_source'),target=path.join(ROOT,'outputs/map_editor_procedural_review');
for(let i=2;i<process.argv.length;i++){
 const arg=process.argv[i];
 if(arg==='--stage')stage=true;
 else if(arg==='--check')stage=false;
 else if(arg==='--source')source=path.resolve(process.argv[++i]);
 else if(arg==='--target')target=path.resolve(process.argv[++i]);
 else throw Error(`Unknown argument ${arg}`);
}
const insideOutputs=p=>p.startsWith(path.join(ROOT,'outputs')+path.sep);
assert(insideOutputs(source)&&insideOutputs(target)&&source!==target,'Only distinct outputs subdirectories admitted');
function noLinks(location){
 let cursor=location;
 while(cursor!==ROOT){
  if(fs.existsSync(cursor))assert(!fs.lstatSync(cursor).isSymbolicLink(),'Symlink/reparse target refused');
  cursor=path.dirname(cursor);
 }
}
for(const location of [source,target])noLinks(location);
const manifestBytes=fs.readFileSync(path.join(source,'manifest.json'));
assert.equal(hash(manifestBytes),EXPECTED_SHA,'Frozen manifest changed; new candidate requires review');
const manifest=JSON.parse(manifestBytes);
assert.equal(manifest.schema,'mafiozi.godot.map-editor-procedural-source/v1');
const candidates=[['manifest.json',manifestBytes]];
const seen=new Set();
let bufferBytes=0;
for(const entry of manifest.buffers){
 assert(/^[0-9a-f]{64}$/.test(entry.sha256));
 assert.equal(entry.file,`buffers/${entry.sha256}.bin`);
 assert(!seen.has(entry.file));seen.add(entry.file);
 noLinks(path.join(source,entry.file));
 const raw=fs.readFileSync(path.join(source,entry.file));
 assert.equal(raw.length,entry.bytes);assert.equal(hash(raw),entry.sha256);
 candidates.push([entry.file,raw]);bufferBytes+=raw.length;
}
const catalogReceipt=manifest.dependencies.find(d=>d.path==='godot/mafiozi_walk/data/map_editor/catalog.json');
assert(catalogReceipt);
const catalogBytes=fs.readFileSync(path.join(ROOT,catalogReceipt.path));
assert.equal(catalogBytes.length,catalogReceipt.bytes);assert.equal(hash(catalogBytes),catalogReceipt.sha256);
candidates.push(['catalog.json',catalogBytes]);
const catalog=JSON.parse(catalogBytes);
for(const dependency of manifest.dependencies){
 const location=path.isAbsolute(dependency.path)?dependency.path:path.resolve(ROOT,dependency.path);
 const raw=fs.readFileSync(location);
 assert.equal(raw.length,dependency.bytes,`Dependency size changed: ${dependency.path}`);
 assert.equal(hash(raw),dependency.sha256,`Dependency changed: ${dependency.path}`);
}
for(const file of ['project.godot','scripts/procedural_factory.gd','tests/test_procedural_factory.gd','tests/test_roads_factory.gd','tests/test_emission_transfer.gd'])candidates.push([file,fs.readFileSync(path.join(HERE,file))]);
for(const [file,bytes] of candidates){
 const destination=path.join(target,file);
 noLinks(destination);
 if(fs.existsSync(destination)){
  assert(!fs.lstatSync(destination).isSymbolicLink(),'Existing file symlink refused');
  assert.equal(hash(fs.readFileSync(destination)),hash(bytes),`Refuse overwrite changed file: ${file}`);
 }
}
if(stage){
 const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
 registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:specifier,context)}});
 const THREE=await import('three');assert.equal(THREE.REVISION,'180');
 const {RoundedBoxGeometry}=await import(pathToFileURL(path.join(ROOT,'tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs')).href);
 const {createExplorationDecor}=await import(pathToFileURL(path.join(ROOT,'assets/maps/city_rebuild_v1/exploration_decor.mjs')).href);
 const original=createExplorationDecor({THREE,RoundedBoxGeometry,plan:catalog.generatedPlans.explorationDecor});
 const bounds=original.object.children[0].userData.bounds,origin=catalog.originM,samples=[];
 for(const distance of [63,71,73,181,189,183,179,63,400]){
  const focus={x:bounds.maxX+distance,z:(bounds.minZ+bounds.maxZ)/2};original.update({focus});
  samples.push({focusNative:[focus.x-origin[0],0,focus.z-origin[2]],distance,chunks:Object.fromEntries(original.object.children.map(chunk=>[chunk.name,{level:chunk.userData.detailLevel,visible:chunk.visible}]))});
 }
 original.dispose();
 candidates.push(['lod_oracle.json',Buffer.from(JSON.stringify({source:'original Three180 createExplorationDecor.update',samples})+'\n')]);
 // Preflight every existing destination before any write. Exact matches are reused.
 for(const [file,bytes] of candidates){
  const destination=path.join(target,file);
  noLinks(destination);
  if(fs.existsSync(destination))assert.equal(hash(fs.readFileSync(destination)),hash(bytes),`Refuse overwrite ${file}`);
 }
 for(const [file,bytes] of candidates){
  const destination=path.join(target,file);fs.mkdirSync(path.dirname(destination),{recursive:true});
  if(!fs.existsSync(destination))fs.writeFileSync(destination,bytes,{flag:'wx'});
 }
}
console.log(JSON.stringify({mode:stage?'staged':'checked-read-only',manifestSha256:EXPECTED_SHA,buffers:seen.size,bufferBytes,files:candidates.length,target,tests:['448582 exploration checks','134894 road checks','1 optional staged GLB emission oracle'],pending:['GPU material/normal/depth-bias parity','source road culling and traffic phase runtime','traffic/nav/collider authority and editor UI integration','general scene p50/p95']}));
