#!/usr/bin/env node
// Parameterized original constructor proof. No renderer, actors or user storage.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {createWalkCollisionIndex} from '../../assets/maps/city_rebuild_v1/walk_collision_index.mjs';
import {createMercenaryFences,MERCENARY_FENCE_SITE} from '../../assets/maps/city_rebuild_v1/mercenary_fences.mjs';
import {createMercenaryPowerPanel,MERCENARY_POWER_SITE} from '../../assets/maps/city_rebuild_v1/mercenary_power_panel.mjs';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const own=path.join(repo,'outputs/astra21_npc_mercenary_colliders');
export const SOURCE_WORLD_SHA='9f5cc5a1a80db37dbf3136ecab66c4cdba2bd679dbea03aa10800ac16d8a95b5';
export const CONTEXT_SHA='a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c';
export const STATIC_BINDINGS={topology_sha256:'11f256f20ea5f8f5387fa4829173e84cf688aa2ba554aa5b6aacdb85301d67b6',building_data_sha256:'dd304db781ee18da12cb3111a3f8126b89658a2562dee38ccd9c2567c9a3ca15',building_values_sha256:'1a05e2bd1d05ffb48634991c1047fc4c1e7fff873f4a0c1fa08d3cb4792a6b88',building_cache_sha256:'b024890f87a7713246aaaace5ba5a903dfb3bff2626fc525e776d354cf9885f3',ground_helper_sha256:'f0ece358320676f158416900770b43e64df12e68fcde2d80264058d7bee5a3b8'};
export const PINS={
 'assets/maps/city_rebuild_v1/walk_preview.mjs':'e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47',
 'assets/maps/city_rebuild_v1/mercenary_fences.mjs':'6c657e4dc141bcb2489af0e3f60437e2af12741f33f495f7e47f7a46eb2432f2',
 'assets/maps/city_rebuild_v1/mercenary_power_panel.mjs':'5bc7b10ee69cfb601d8b62c72946f79a89db3d97e6cc3a2058c91a39441318db',
 'tools/godot/export_npc_building_support.mjs':'b08d50254db5426461dcb4a625a7c88f2cfc4e624c92607f35ca241d0afbe0ed'
};
export const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
function pinnedSources(){return Object.entries(PINS).map(([name,expected])=>{const bytes=fs.readFileSync(path.join(repo,name));if(sha(bytes)!==expected)throw Error('source_changed:'+name);return {path:name,sha256:expected,code:bytes.toString('utf8')};});}
export function validateInput(input){
 if(!input||input.schema!=='mafiozi.npc-mercenary-constructor-input/v1')return 'schema';
 if(input.source_world_sha256!==SOURCE_WORLD_SHA||input.context_sha256!==CONTEXT_SHA||input.walk_module_sha256!==PINS['assets/maps/city_rebuild_v1/walk_preview.mjs'])return 'source_binding';
 if(typeof input.session_id!=='string'||!input.session_id||input.session_id.length>128)return 'session';
 if(typeof input.phase!=='string'||!input.phase)return 'phase';
 if(!['TEST_ONLY_PARAMETERIZED_ORIGINAL_CONSTRUCTORS','SOURCE_CAPTURE'].includes(input.kind))return 'kind';
 if(input.kind==='SOURCE_CAPTURE'){
  if(input.known!==true)return 'capture_unknown';
  if(input.fixture_only!==false)return 'fixture_cannot_be_capture';
  if(typeof input.capture_context_sha256!=='string'||!/^[0-9a-f]{64}$/.test(input.capture_context_sha256)||input.capture_context_sha256===CONTEXT_SHA)return 'capture_context';
  if(input.session_id==='godot-preview-new-session-20260927-01')return 'capture_old_session';
  if(!input.source_static_bindings||typeof input.source_static_bindings!=='object'||Object.entries(STATIC_BINDINGS).some(([key,value])=>input.source_static_bindings[key]!==value))return 'capture_static_bindings';
  if(typeof input.snapshot_id!=='string'||!input.snapshot_id||typeof input.frame!=='string'||!input.frame||!Number.isSafeInteger(input.revision)||input.revision<0)return 'capture_identity';
  if(!Array.isArray(input.proof_receipts)||input.proof_receipts.length===0||input.proof_receipts.some(x=>!x||typeof x.path!=='string'||!x.path||typeof x.sha256!=='string'||!/^[0-9a-f]{64}$/.test(x.sha256)))return 'capture_receipts';
 }
 const gate=input.data?.gate;
 if(!gate||gate.known!==true||!['absent','returned','threw'].includes(gate.status))return 'gate_unknown';
 if(gate.status==='threw')return 'gate_threw';
 if(gate.status==='returned'&&!Object.hasOwn(gate,'value'))return 'gate_value';
 if(gate.status==='returned'&&input.kind==='SOURCE_CAPTURE'&&typeof gate.value!=='boolean')return 'capture_gate_type';
 const enabled=gate.status==='returned'&&!!gate.value;
 if(enabled){const focus=input.data?.focus;if(!focus||focus.known!==true||!['hero_position','controls_target'].includes(focus.source)||!Array.isArray(focus.value)||focus.value.length!==3||!focus.value.every(Number.isFinite))return 'focus_unknown';}
 if(enabled)for(const name of ['fence','power']){
  const read=input.data?.storage_reads?.[name];
  if(!read||read.known!==true||!['returned','threw'].includes(read.status))return 'storage_unknown:'+name;
  if(read.status==='returned'&&read.value!==null&&typeof read.value!=='string')return 'storage_type:'+name;
  if(read.status==='threw'&&(typeof read.name!=='string'||typeof read.message!=='string'))return 'storage_exception:'+name;
 }
 return '';
}
export async function prepareOriginalGround(){
 const receipts=pinnedSources();fs.mkdirSync(own,{recursive:true});
 const original=receipts.find(x=>x.path==='tools/godot/export_npc_building_support.mjs').code;
 let copy=original.replace("'outputs/astra21_npc_registered_building_support'","'outputs/astra21_npc_mercenary_colliders'").replace("const originalVerify=process.argv.includes('--verify-original');","const originalVerify=true;");
 const begin=copy.indexOf('if(originalVerify){const queries='),end=copy.indexOf('const originalPaths=',begin);if(begin<0||end<0)throw Error('original_assembly_anchor');
 copy=copy.slice(0,begin)+copy.slice(end);fs.writeFileSync(path.join(own,'assembly_original.mjs'),copy);
 const {liveEntries,THREE}=await import(pathToFileURL(path.join(own,'assembly_original.mjs')));
 const topologyBytes=fs.readFileSync(path.join(repo,'assets/maps/city_rebuild_v1/topology_for_placement.json'));
 if(sha(topologyBytes)!==STATIC_BINDINGS.topology_sha256)throw Error('static_topology_changed');
 const topology=JSON.parse(topologyBytes),landscape=createLandscapePlan(),explorationRailway=createExplorationRailwayPlan({landscape,topology}),M=4.1;
 const index=createWalkCollisionIndex([liveEntries.map(entry=>{const b=entry.sampleBounds;return{entry,polygonCR:[[b.min.x/M,b.min.z/M],[b.max.x/M,b.min.z/M],[b.max.x/M,b.max.z/M],[b.min.x/M,b.max.z/M]]};})]);
 const walk=receipts.find(x=>x.path.endsWith('walk_preview.mjs')).code;
 const slices=[];
 function slice(name,next){const start=walk.indexOf('function '+name+'('),end=walk.indexOf('function '+next+'(',start);if(start<0||end<0)throw Error('slice:'+name);const code=walk.slice(start,end).trimEnd();slices.push({name,start,end,code,sha256:sha(code)});return code;}
 const groundVm=vm.createContext({landscape,explorationRailway,topology,M,sampledBuildingEntries:(x,z)=>index(x/M,z/M).map(row=>row.entry)});
 new vm.Script(slice('waterAt','ladderPathDistance')+'\n'+slice('groundHeight','heroGroundHeight')+'\nthis.ground=groundHeight;').runInContext(groundVm);
 const start=walk.indexOf(' if(window.MafioziMercenaries?.canUseLocalEffects?.()){',walk.indexOf('buildingSampleIndex=createWalkCollisionIndex'));
 const refreshEnd=walk.indexOf('\n if(performanceProbe){',start);if(start<0||refreshEnd<0)throw Error('refresh_block_anchor');
 const refresh=walk.slice(start,refreshEnd);new vm.Script(refresh);slices.push({name:'mercenary_refresh_block',start,end:refreshEnd,code:refresh,sha256:sha(refresh)});
 const sites=[MERCENARY_FENCE_SITE,MERCENARY_POWER_SITE].map(site=>({id:site.id,x:site.x,z:site.z,ground_y:groundVm.ground(site.x,site.z,0)}));
 return {THREE,refresh,ground:(x,z)=>groundVm.ground(x,z,0),sites,receipts,slices,assembly_sha256:sha(copy),topology_sha256:sha(topologyBytes)};
}
export function replayOriginal(input,original){
 const error=validateInput(input);
 const supplied=input&&typeof input==='object'?input:{};
 const base={schema:'mafiozi.npc-mercenary-colliders/v1',input_sha256:sha(JSON.stringify(input)),kind:supplied.kind??'INVALID',input_fixture_only:supplied.fixture_only===true||supplied.kind==='TEST_ONLY_PARAMETERIZED_ORIGINAL_CONSTRUCTORS',session_id:supplied.session_id??null,phase:supplied.phase??null,snapshot_id:supplied.snapshot_id??null,revision:supplied.revision??null,source_world_sha256:SOURCE_WORLD_SHA,context_sha256:CONTEXT_SHA,static_component_context_sha256:CONTEXT_SHA,capture_context_sha256:supplied.capture_context_sha256??null,source_static_bindings:{...STATIC_BINDINGS},source_pins:PINS,registered_frame:false,physical_admission:false,requires_host_capture_validation:true};
 // Preserve the exact capture envelope across Float64 encoding and native replay.
 // These are caller evidence, never an independently authenticated live capture.
 base.frame=supplied.frame??null;
 base.input_proof_receipts=Array.isArray(supplied.proof_receipts)?structuredClone(supplied.proof_receipts):[];
 if(error)return {...base,status:'HOLD',known:false,error,colliders:null};
 const reads=[],ground_queries=[];
 const gate=input.data.gate;
 const window=gate.status==='absent'?{}:{MafioziMercenaries:{canUseLocalEffects:()=>gate.value}};
 const localStorage={getItem(key){const name=key==='mafiozi.mercenary-fences.v1'?'fence':key==='mafiozi.mercenary-yard-power.v1'?'power':null;if(!name)throw Error('unexpected_key');const read=input.data.storage_reads[name];reads.push({key,...structuredClone(read)});if(read.status==='threw'){const error=new Error(read.message);error.name=read.name;throw error;}return read.value;},setItem(){throw Error('export_does_not_write_storage');}};
 const focus=input.data.focus;
 const position=focus?new original.THREE.Vector3(...focus.value):null;
 const hero=focus?.source==='hero_position'?{object:{position}}:null;
 const controls={target:focus?.source==='controls_target'?position:null};
 const sandbox=vm.createContext({THREE:original.THREE,createMercenaryFences,createMercenaryPowerPanel,groundHeight:(x,z)=>{const y=original.ground(x,z);ground_queries.push({x,z,y});return y;},window,localStorage,hero,controls,content:new original.THREE.Group(),bodies:[],carBodies:[],mercenaryFences:null,mercenaryPowerPanel:null});
 new vm.Script(original.refresh).runInContext(sandbox);
 const fence=sandbox.mercenaryFences,power=sandbox.mercenaryPowerPanel;
 const colliders=structuredClone(sandbox.bodies);
 const state={fence:fence?{cuttable:fence.getTargets()[0].object.userData.mercenaryTarget.cuttable,root_position:fence.object.position.toArray()}:null,power:power?{...power.getState(),root_position:power.object.position.toArray()}:null};
 if(JSON.stringify(sandbox.bodies)!==JSON.stringify(sandbox.carBodies))throw Error('constructor_body_order');
 fence?.dispose();power?.dispose();
 return {...base,status:input.kind.startsWith('TEST_ONLY')?'TEST_ONLY_ORIGINAL_CONSTRUCTOR_RESULT':'SOURCE_CAPTURE_REPLAY_REQUIRES_HOST_VALIDATION',known:true,colliders,storage_reads:reads,ground_queries,state,gate_enabled:gate.status==='returned'&&!!gate.value,limits:['No actual user storage read/write, source births, server, renderer or current frame capture','SOURCE_CAPTURE provenance is input evidence, not independently authenticated source/session state','Original read exceptions retain explicit proof while original catch determines defaults']};
}
export function encodeFloat64(value){const values=[];function encode(x){if(typeof x==='number'){if(!Number.isFinite(x))throw Error('nonfinite_payload');const i=values.length;values.push(x);return{$f64:i};}if(Array.isArray(x))return x.map(encode);if(x&&typeof x==='object')return Object.fromEntries(Object.entries(x).map(([k,v])=>[k,encode(v)]));return x;}const data=encode(value),bytes=Buffer.alloc(values.length*8);values.forEach((x,i)=>bytes.writeDoubleLE(x,i*8));return {data,bytes};}
async function cli(){
 const args=process.argv.slice(2),get=name=>args[args.indexOf(name)+1];
 if(!args.includes('--input')||!args.includes('--expected-input-sha256'))throw Error('Required --input path --expected-input-sha256 HASH');
 const bytes=fs.readFileSync(path.resolve(get('--input')));if(bytes.length>65536||sha(bytes)!==get('--expected-input-sha256'))throw Error('input_bytes');
 const input=JSON.parse(bytes),error=validateInput(input);fs.mkdirSync(own,{recursive:true});
 let result;
 if(error)result=replayOriginal(input,null);
 else{const original=await prepareOriginalGround();result=replayOriginal(input,original);fs.writeFileSync(path.join(own,'SOURCE_RECEIPTS.json'),JSON.stringify({receipts:original.receipts,slices:original.slices,sites:original.sites,assembly_sha256:original.assembly_sha256,topology_sha256:original.topology_sha256},null,2)+'\n');}
 result.exact_input_file_sha256=sha(bytes);
 const encoded=encodeFloat64(result);fs.writeFileSync(path.join(own,'COLLIDERS.f64.json'),JSON.stringify(encoded.data,null,2)+'\n');fs.writeFileSync(path.join(own,'COLLIDERS.f64.bin'),encoded.bytes);fs.writeFileSync(path.join(own,'RESULT.json'),JSON.stringify(result,null,2)+'\n');
 console.log(JSON.stringify({status:result.status,known:result.known,error:result.error,colliders:result.colliders?.length??null,physical_admission:false}));if(!result.known)process.exitCode=2;
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))cli().catch(error=>{console.error(error.stack);process.exitCode=1;});
