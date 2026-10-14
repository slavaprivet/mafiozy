// Pure original-source replay of a REQUIRED captured frame. Never starts Walk,
// renders, creates vehicles, advances authority, or supplies absent scene inputs.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {repo,hash,worldSHA,sourceFunction} from './npc_startup_source_vm.mjs';
import {worldTrafficProfile,trafficActorBlocks} from '../../assets/maps/city_rebuild_v1/world_traffic_presentation.mjs';
import {createNpcVehicleAccessResolver} from '../../assets/maps/city_rebuild_v1/npc_vehicle_access.mjs';

export const SCHEMA='mafiozi.npc-source-dynamic-frame/v1';
export const INPUT_SCHEMA='mafiozi.npc-dynamic-captured-input/v1';
export const CONTEXT_SHA='a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c';
export const WALK_SHA='e80ebf4be2d0404ad5b51d4bf28b756a9cba2b486c43c0797de748c37364dd47';
const ownPath=fileURLToPath(import.meta.url),modRoot='assets/maps/city_rebuild_v1/';
const read=p=>fs.readFileSync(path.join(repo,p),'utf8');
const logicalCode=read(modRoot+'npc_logical_vehicle_binding.mjs');
const walkCode=read(modRoot+'walk_preview.mjs');
if(hash(walkCode)!==WALK_SHA)throw Error('walk_source_drift');
const railCode=read(modRoot+'exploration_railway_plan.mjs');
const railBlocks=railCode.split(/\r?\n/).find(line=>line.startsWith(' function blocks(x,z,r=.36)'))?.trim();
if(!railBlocks)throw Error('rail_source_missing');
const sourceOr=walkCode.match(/blocksDynamic:(\(x,z,body\)=>[^\r\n]*?)\}\);/)?.[1];
if(!sourceOr)throw Error('dynamic_source_missing');
const functions=['_getWalkNpcVehicleTraffic','_npcLogicalVehicleRow','_threeVehicleEntityId','resolveCarModel'].map(sourceFunction);
const modulePaths=['npc_logical_vehicle_binding.mjs','world_traffic_presentation.mjs','npc_vehicle_access.mjs','car_drive.mjs','vehicle_collision_shape.mjs','vehicle_contact.mjs','vehicle_fleet_models.mjs','exploration_railway_plan.mjs','walk_preview.mjs'];
export const sourceReceipts=()=>[
 ...functions,
 ...modulePaths.map(name=>({name:modRoot+name,path:modRoot+name,code:read(modRoot+name),sha256:hash(read(modRoot+name))})),
 {name:'original_rail_blocks',code:railBlocks,sha256:hash(railBlocks)},
 {name:'original_walk_blocksDynamic',code:sourceOr,sha256:hash(sourceOr)}
];
const fail=reason=>{throw Error(reason)};
const finite=v=>typeof v==='number'&&Number.isFinite(v);
const scalarId=v=>typeof v==='string'||typeof v==='boolean'||v===null||finite(v);
const copy=v=>structuredClone(v);
function decode(data,overlays=[]){
 const result=copy(data),seen=new Set();
 for(const o of overlays){
  if(!Array.isArray(o.path)||!o.path.length||!Array.isArray(o.bytes_le)||o.bytes_le.length!==8||!o.bytes_le.every(v=>Number.isInteger(v)&&v>=0&&v<=255))fail('float64_overlay');
  const key=JSON.stringify(o.path);if(seen.has(key))fail('float64_duplicate');seen.add(key);
  let dest=result;
  for(const part of o.path.slice(0,-1)){if((typeof part!=='string'&&!Number.isInteger(part))||['__proto__','prototype','constructor'].includes(part)||dest===null||!Object.hasOwn(dest,part))fail('float64_path');dest=dest[part];}
  const last=o.path.at(-1);if(['__proto__','prototype','constructor'].includes(last)||!Object.hasOwn(dest,last))fail('float64_path');
  dest[last]=Buffer.from(o.bytes_le).readDoubleLE();
 }
 return result;
}
// Overlay EVERY number, including integers, -0, nonfinite values. JSON's
// readable null for nonfinite is never the numerical authority.
export function encodeData(data){
 const overlays=[];
 function visit(v,p){if(typeof v==='number'){const bytes=Buffer.alloc(8);bytes.writeDoubleLE(v);overlays.push({path:p,bytes_le:[...bytes]});return Number.isFinite(v)?v:null;}
  if(Array.isArray(v))return Array.from(v,(x,i)=>visit(x,[...p,i]));
  if(v&&typeof v==='object'){const out={};for(const [k,x] of Object.entries(v))if(x!==undefined)out[k]=visit(x,[...p,k]);return out;}return v;}
 return {data:visit(data,[]),data_float64:overlays};
}
export const decodeData=decode;

function replayDynamicFrame(bytes){
 if(!Buffer.isBuffer(bytes)&&!(bytes instanceof Uint8Array))fail('input_bytes');
 if(bytes.length>32*1024*1024)fail('input_size');
 const inputHash=hash(bytes),input=JSON.parse(Buffer.from(bytes).toString('utf8'));
 const envelope={schema:SCHEMA,source_world_sha256:worldSHA,context_sha256:CONTEXT_SHA,static_component_context_sha256:CONTEXT_SHA,capture_context_sha256:input.capture_context_sha256??null,walk_module_sha256:WALK_SHA,producer_code_sha256:hash(fs.readFileSync(ownPath)),input_sha256:inputHash,session_id:input.session_id,phase:input.phase,snapshot_id:input.snapshot_id,revision:input.revision,kind:input.kind,registered_frame:false,physical_admission:false,requires_host_capture_validation:true};
 if(input.schema!==INPUT_SCHEMA||input.source_world_sha256!==worldSHA||input.context_sha256!==CONTEXT_SHA||input.walk_module_sha256!==WALK_SHA)fail('input_pins');
 if(!['SOURCE_CAPTURE','TEST_ONLY_PARAMETERIZED_ORIGINAL_CONSTRUCTORS'].includes(input.kind)||![input.session_id,input.phase,input.snapshot_id].every(v=>typeof v==='string'&&v.length>0)||!Number.isSafeInteger(input.revision)||input.revision<0)fail('input_lease');
 if(input.known!==true)return {...envelope,known:false,status:'HOLD',missing:['complete_captured_frame'],data:null,proof_receipts:input.proof_receipts||[]};
 if(input.kind==='SOURCE_CAPTURE'&&(!/^[0-9a-f]{64}$/.test(input.capture_context_sha256||'')||input.capture_context_sha256===CONTEXT_SHA||input.session_id==='godot-preview-new-session-20260927-01'))fail('fresh_capture_context');
 if(!Array.isArray(input.proof_receipts)||!input.proof_receipts.length)fail('capture_receipts');
 const d=decode(input.data,input.data_float64),missing=[];
 for(const key of ['objects','pools','identity','catalogs','player','source_frame','physical_fleet','train','ground','queries'])if(d?.[key]?.known!==true)missing.push(key);
 if(missing.length)return {...envelope,known:false,status:'HOLD',missing,data:null,proof_receipts:copy(input.proof_receipts)};
 if(input.kind==='SOURCE_CAPTURE'&&d.source_static_bindings?.known!==true)return {...envelope,known:false,status:'HOLD',missing:['captured_source_static_bindings'],data:null,proof_receipts:copy(input.proof_receipts)};
 if(!Array.isArray(d.objects.rows)||d.objects.rows.length>10000||!Array.isArray(d.queries.rows)||d.queries.rows.length>10000)fail('capture_bounds');
 const objects=new Map();for(const row of d.objects.rows){if(typeof row.object_key!=='string'||!row.object_key||objects.has(row.object_key)||!row.raw||typeof row.raw!=='object'||Array.isArray(row.raw))fail('object_table');objects.set(row.object_key,copy(row.raw));}
 const object=key=>objects.get(key)||fail('missing_object:'+key);
 const globals={Math:Object.assign(Object.create(Math),{random(){fail('forbidden_random')}}),player:copy(d.player.value),prevT:d.source_frame.value};
 if(!finite(globals.player?.r)||!finite(globals.player?.c)||!finite(globals.prevT))fail('player_clock');
 for(const key of ['CARS','questCars','serviceVehicles','BUS']){
  const p=d.pools[key];if(p?.known!==true||typeof p.present!=='boolean')fail('pool_presence:'+key);
  if(!p.present){if(key==='CARS')fail('cars_absent');continue;}
  if(key==='BUS')globals.BUS=object(p.object_key);
  else {if(!Array.isArray(p.object_keys))fail('pool_rows');const rows=p.object_keys.map(object);globals[key]=key==='questCars'?new Map(rows.map((r,i)=>[i,r])):rows;}
 }
 for(const key of ['QUEST_CAR_MODELS','CAR_MODELS','GANG_CAR_MODELS','POLICE_MODELS','_CAR_MODEL_BY_NAME']){if(!Object.hasOwn(d.catalogs,key))fail('catalog:'+key);globals[key]=copy(d.catalogs[key]);}
 const identities=new WeakMap();if(!Number.isSafeInteger(d.identity.sequence)||d.identity.sequence<0||!Array.isArray(d.identity.entries))fail('identity_state');
 const identityKeys=new Set();for(const row of d.identity.entries){if(identityKeys.has(row.object_key)||typeof row.id!=='string'||!row.id)fail('identity_entry');identityKeys.add(row.object_key);identities.set(object(row.object_key),row.id);}
 globals._threeVehicleIds=identities;globals._threeVehicleIdSeq=d.identity.sequence;
 const ctx=vm.createContext(globals);for(const f of functions)vm.runInContext(f.code,ctx,{timeout:1000,filename:f.name});
 let getterCount=0,sourceRows=[];
 function getter(){getterCount++;const result=vm.runInContext('_getWalkNpcVehicleTraffic()',ctx,{timeout:1000});if(ctx._threeVehicleIdSeq!==d.identity.sequence)fail('uncaptured_anonymous_identity');sourceRows=result.rows;return result;}
 // Ground samples are required captured original combined-support results, not
 // a permissive substitute callback. Exact x/z bit keys preserve signed zero.
 const keyXY=(x,z)=>{const b=Buffer.alloc(16);b.writeDoubleLE(x);b.writeDoubleLE(z,8);return b.toString('hex')};
 const grounds=new Map();if(!Array.isArray(d.ground.samples))fail('ground_samples');
 for(const s of d.ground.samples){if(![s.x,s.z,s.y].every(finite)||!s.proof)fail('ground_proof');const key=keyXY(s.x,s.z);if(grounds.has(key))fail('ground_duplicate');grounds.set(key,s);}
 const groundCalls=[];function groundHeight(x,z){const s=grounds.get(keyXY(x,z));if(!s)fail('missing_ground:'+keyXY(x,z));groundCalls.push(copy(s));return s.y;}
 if(typeof d.physical_fleet.present!=='boolean'||typeof d.train.present!=='boolean')fail('group_presence');
 const fleet=d.physical_fleet.present?{records:copy(d.physical_fleet.records)}:null;
 if(fleet&&!Array.isArray(fleet.records))fail('fleet_records');
 for(const row of fleet?.records||[])if(!scalarId(row.id))fail('fleet_id');
 // Offline safety envelope, not a source collision rule. Unreasonable captured
 // extents could make the original x++ bucket loops nonterminating. Reject
 // those inputs before executing ensure, never reinterpret them as clear.
 const bounded=v=>finite(v)&&Math.abs(v)<=1e6;
 for(const row of objects.values())for(const key of ['r','c','x','y'])if(typeof row[key]==='number'&&!bounded(row[key]))fail('capture_coordinate_range');
 for(const row of fleet?.records||[]){const p=row.car?.profile,s=row.car?.object?.scale;if(p)for(const key of ['halfWidth','halfLength'])if(!bounded(p[key])||p[key]<0)fail('capture_profile_range');if(s)for(const key of ['x','y','z'])if(!bounded(s[key])||Math.abs(s[key])>100)fail('capture_scale_range');}
 const currentCars=d.train.present?copy(d.train.current_cars):[];
 if(!Array.isArray(currentCars)||!currentCars.every(c=>[c.x,c.z,c.tx,c.tz,c.length,c.width].every(finite)))fail('train_cars');
 const railCtx=vm.createContext({currentCars,Math});vm.runInContext(railBlocks,railCtx);
 const rail=d.train.present?{blocks:(x,z,r)=>railCtx.blocks(x,z,r)}:null;
 // Observe actual source Map writes. Third Map is grid per the byte-pinned
 // original factory declaration. No function or insertion expressions edited.
 let mapCount=0,grid,rowToken=0,lastInsertionToken=-1,recordOrdinal=-1,gridWrites=0;
 const gridOrdinals=new WeakMap();
 class ObservedMap extends Map{
  constructor(...args){super(...args);this.observedRole=++mapCount;if(this.observedRole===3)grid=this;}
  set(key,value){
   if(this.observedRole===2)rowToken++;
   if(this.observedRole===3){if(++gridWrites>100000)fail('capture_grid_budget');if(lastInsertionToken!==rowToken){recordOrdinal++;lastInsertionToken=rowToken;}gridOrdinals.set(value.at(-1),recordOrdinal);}
   return super.set(key,value);
  }
 }
 const bindingCtx=vm.createContext({Map:ObservedMap,Math,worldTrafficProfile,trafficActorBlocks,createNpcVehicleAccessResolver});
 const executable=logicalCode.replace(/^import .*;\r?\n/gm,'').replace('export function createNpcLogicalVehicleBinding','function createNpcLogicalVehicleBinding');
 vm.runInContext(executable,bindingCtx,{timeout:1000,filename:'original_logical_factory'});
 const binding=bindingCtx.createNpcLogicalVehicleBinding({bridge:{getWalkNpcVehicleTraffic:getter},getTemplate:id=>fleet?.records.find(record=>record.car?.profile?.id===id)?.car,getVisibleVehicle(){fail('unexpected_visible_vehicle_access')},getVisibleNpc(){fail('unexpected_visible_npc_access')},groundHeight,worldScale:4.1});
 if(mapCount!==3||!grid)fail('logical_map_observer_contract');
 const orCtx=vm.createContext({explorationRailway:rail,fleet,npcVehicleBlocks:trafficActorBlocks,npcLogicalVehicles:binding});
 const blocks=vm.runInContext('('+sourceOr+')',orCtx);
 const queries=[];for(const q of d.queries.rows){if(!finite(q.x)||!finite(q.z)||!q.body||typeof q.body!=='object'||Array.isArray(q.body))fail('query_shape');if(Object.hasOwn(q.body,'ignoreId')&&!scalarId(q.body.ignoreId))fail('query_ignore');const before=getterCount;queries.push({...copy(q),blocked:blocks(q.x,q.z,copy(q.body)),getter_calls_before:before,getter_calls_after:getterCount});}
 if(!getterCount)return {...envelope,known:false,status:'HOLD',missing:['logical_first_actual_query_not_visited'],data:null,proof_receipts:copy(input.proof_receipts),partial_query_results:queries};
 const records=binding.getVehicles();records.forEach(r=>{if(!scalarId(r.id))fail('logical_id');});
 // Capture the actual wrapper's row ordinal WHEN inserted. Duplicate IDs may
 // share one actor but occupy different old buckets; never rebuild from its
 // final position or infer an ordinal from the actor identity.
 const buckets=[...grid].map(([key,bucket])=>({key,record_ordinals:bucket.map(r=>{const i=gridOrdinals.get(r);if(!Number.isInteger(i)||records[i]?.actor!==r.actor||records[i]?.id!==r.id)fail('grid_alias');return i;})}));
 const contact=actor=>{const o=actor?.object,p=actor?.profile||o?.userData?.vehicleProfile;if(!o||o.visible===false||!p)return {source_blockable:false,contact_known:true,visible:o?.visible!==false};const s=o.scale||{x:1,y:1,z:1},pos=o.position;return {source_blockable:true,contact_known:true,visible:true,x:pos.x,y:pos.y,z:pos.z,yaw:o.rotation.y,scale_x:s.x,scale_y:s.y,scale_z:s.z,half_width:p.halfWidth,half_length:p.halfLength,bounds_min_y:p.bounds?.min?.[1]||0,bounds_max_y:p.bounds?.max?.[1]??p.height??0};};
 const normalizedFleet=(fleet?.records||[]).map(r=>({id:r.id,ignore_key:'fleet:'+r.id,contact:contact(r.car),original:copy(r)}));
 const actorAlias=new Map();const logical=records.map((r,i)=>{if(!actorAlias.has(r.actor))actorAlias.set(r.actor,i);return {id:r.id,actor_alias_ordinal:actorAlias.get(r.actor),contact:contact(r.actor),profile_known:r.actor.profileKnown,profile:copy(r.actor.profile)};});
 const rows=sourceRows.map(row=>{const out={};for(const key of Object.keys(row))out[key]=row[key];return out;});
 const result={source_frame:globals.prevT,rail:{known:true,present:d.train.present,current_cars:currentCars},fleet:{known:true,present:d.physical_fleet.present,records:normalizedFleet},logical:{known:true,initialized:true,getter_calls:getterCount,rows,records:logical,grid:{cell_size:24,buckets}},object_aliases:[...objects].map(([key])=>key),identity:{sequence_before:d.identity.sequence,sequence_after:ctx._threeVehicleIdSeq,entries:copy(d.identity.entries)},ground_calls:groundCalls,query_results:queries};
 return {...envelope,known:true,status:'SOURCE_COMPONENT_REPLAY',proof_receipts:copy(input.proof_receipts),source_function_receipts:sourceReceipts().map(({code,...r})=>r),...encodeData(result)};
}

export function exportDynamicFrame(bytes){
 try{return replayDynamicFrame(bytes);}catch(error){
  // A visited uncaptured dependency is not a known-clear dynamic frame. The
  // original attempted replay touched only private objects; none are exposed.
  if(!/^(missing_ground:|uncaptured_anonymous_identity|missing_object:)/.test(error.message))throw error;
  const input=JSON.parse(Buffer.from(bytes).toString('utf8'));
  return {schema:SCHEMA,known:false,status:'HOLD',missing:[error.message],data:null,source_world_sha256:worldSHA,context_sha256:CONTEXT_SHA,static_component_context_sha256:CONTEXT_SHA,capture_context_sha256:input.capture_context_sha256??null,walk_module_sha256:WALK_SHA,producer_code_sha256:hash(fs.readFileSync(ownPath)),input_sha256:hash(bytes),session_id:input.session_id,phase:input.phase,snapshot_id:input.snapshot_id,revision:input.revision,kind:input.kind,proof_receipts:copy(input.proof_receipts),registered_frame:false,physical_admission:false,requires_host_capture_validation:true};
 }
}

if(process.argv[1]&&path.resolve(process.argv[1])===ownPath){
 const at=process.argv.indexOf('--input'),out=process.argv.indexOf('--out');if(at<0||out<0)throw Error('Usage: --input capture.json --out NEW-output-directory');
 const target=path.resolve(process.argv[out+1]);if(fs.existsSync(target))throw Error('Output must be new (immutable evidence)');
 const result=exportDynamicFrame(fs.readFileSync(process.argv[at+1]));fs.mkdirSync(target,{recursive:true});
 const bytes=Buffer.from(JSON.stringify(result,null,2)+'\n');fs.writeFileSync(path.join(target,'DYNAMIC_FRAME.json'),bytes);fs.writeFileSync(path.join(target,'SOURCE_RECEIPTS.json'),JSON.stringify(sourceReceipts(),null,2)+'\n');
 console.log(JSON.stringify({known:result.known,status:result.status,sha256:hash(bytes),bytes:bytes.length}));if(!result.known)process.exitCode=2;
}
