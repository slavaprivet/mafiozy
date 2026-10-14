import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {createSourceVm,repo,hash,boundary,worldSHA} from './npc_startup_source_vm.mjs';

const args=process.argv.slice(2),index=args.indexOf('--config');
if(index<0||!args[index+1])throw Error('Explicit approved offline startup config required');
const configPath=path.resolve(args[index+1]),configBytes=fs.readFileSync(configPath),config=JSON.parse(configBytes);
if(config.schema!=='mafiozi.npc-full-offline-startup/v1'||JSON.stringify(config.boundary)!==JSON.stringify(boundary)||config.world_sha256!==worldSHA)throw Error('Unsupported source boundary/config');
const out=path.join(repo,'outputs/astra21_npc_full_startup',hash(configBytes));
fs.mkdirSync(out,{recursive:true});
const helpers=['npc_startup_source_vm.mjs','npc_startup_named.mjs','npc_startup_traffic.mjs','npc_startup_police_pets.mjs','export_npc_initial_placement_context.mjs'];
const moduleDir=path.dirname(fileURLToPath(import.meta.url));
const receiptFiles=()=>helpers.map(name=>({path:'tools/godot/'+name,sha256:hash(fs.readFileSync(path.join(moduleDir,name)))}));
const before=receiptFiles();
const named=await import('./npc_startup_named.mjs');
const traffic=await import('./npc_startup_traffic.mjs');
const police=await import('./npc_startup_police_pets.mjs');

function execute(){
 const s=createSourceVm({fixedDate:config.boundary.date_iso});
 const ordinarySHA=hash(s.ordinary),rngBefore=s.rng();
 const stages=[];
 const namedResult=named.installNamedAndRun(s);stages.push({name:'named',rng:s.rng(),npc_count:s.run('NPCS.length')});
 const trafficResult=traffic.installTrafficAndRun(s);stages.push({name:'traffic',rng:s.rng(),cars:s.run('CARS.length')});
 const policeResult=police.installPolicePetsAndRun(s);stages.push({name:'police_pets_spawn_safety',rng:s.rng(),city_cops:s.run('cityCops.length')});
 const snapshot=s.run(`JSON.stringify((()=>{
  const keys=new Map(),objects=[];
  const key=n=>{if(!keys.has(n)){keys.set(n,'object_'+keys.size);objects.push({object_key:keys.get(n),raw:n});}return keys.get(n);};
  const pools={NPCS:NPCS.map(key),cityCops:cityCops.map(key),worldCops:worldCops.map(key)};
  const aliases={ALL_UNIQUE_NPCS:ALL_UNIQUE_NPCS.map(key),SPECIALIST_NPCS:SPECIALIST_NPCS.map(key),SAID_NPC:key(SAID_NPC),UNIQUE_NPC_BY_ID:[...UNIQUE_NPC_BY_ID].map(([id,n])=>[id,key(n)])};
  return {objects,pools,aliases,player,MAP,CARS,PETS,
   registry_state:{prison_alarm:_prisonAlarmState,parking:{queue:_nativeParkingAdmission.queue.map(row=>({car_index:CARS.indexOf(row.car),index:row.index,retryAt:row.retryAt})),cursor:_nativeParkingAdmission.cursor,refreshAt:_nativeParkingAdmission.refreshAt,reservations:[..._nativeParkingAdmission.reservations]},npc_navigation:_npcNavigationStats},
   source_resolver_registered:typeof _walkNpcNavigationResolver==='function'};
 })())`);
 const data=JSON.parse(snapshot);
 if(data.source_resolver_registered||data.pools.worldCops.length!==0)throw Error('Offline checkpoint crossed provider/server boundary');
 return {schema:'mafiozi.npc-full-offline-startup-context/v1',boundary:config.boundary,source_world_sha256:worldSHA,immutable_ordinary_roster_sha256:ordinarySHA,
  ordinary_rng_checkpoint:rngBefore,stages,stage_results:{named:namedResult,traffic:trafficResult,police_pets:policeResult},final_rng:s.rng(),source_receipts:s.receipts,
  observation_receipts:s.instrumentationReceipts??[],source_draws:s.draws,source_queries:s.queries,named_queries:s.namedQueries??[],context:data,
  provenance:'EXACT_OFFLINE_SOURCE_CALLBACK_CONTINUATION_NOT_BROWSER_OR_AUTHENTICATED_SNAPSHOT',native_physical_admission:false};
}

try{
 const first=execute(),second=execute();
 if(JSON.stringify(first)!==JSON.stringify(second))throw Error('Independent fresh-VM continuation repetition differs');
 if(JSON.stringify(before)!==JSON.stringify(receiptFiles()))throw Error('Implementation changed during source export');
 const audit={};
 for(const [name,value] of Object.entries({source_receipts:first.source_receipts,observational_instrumentation:first.observation_receipts,source_draws:first.source_draws,source_queries:first.source_queries,named_queries:first.named_queries,stage_results:first.stage_results})){
  const contents=Buffer.from(JSON.stringify(value)+'\n'),filename=name+'.json';
  fs.writeFileSync(path.join(out,filename),contents);
  audit[name]={path:filename,sha256:hash(contents),bytes:contents.length,count:Array.isArray(value)?value.length:null};
 }
 const runtimeContext={schema:first.schema,boundary:first.boundary,source_world_sha256:first.source_world_sha256,immutable_ordinary_roster_sha256:first.immutable_ordinary_roster_sha256,
  ordinary_rng_checkpoint:first.ordinary_rng_checkpoint,stages:first.stages,final_rng:first.final_rng,context:first.context,audit_files:audit,
  provenance:first.provenance,native_physical_admission:false};
 const output=Buffer.from(JSON.stringify(runtimeContext)+'\n');
 fs.writeFileSync(path.join(out,'context.json'),output);
 fs.writeFileSync(path.join(out,'receipt.json'),JSON.stringify({status:'SOURCE_OFFLINE_CONTEXT_READY_NATIVE_PLACEMENT_PENDING',context_sha256:hash(output),context_bytes:output.length,config_sha256:hash(configBytes),helpers:before,source:worldSHA,rows:first.context.objects.length,audit_files:audit,limits:['Not browser first-registration scheduling','No server snapshot or authority','Physical/native placement not executed','Large original-query audit files are offline evidence, never per-frame or runtime context data']},null,2)+'\n');
 console.log(JSON.stringify({status:'SOURCE_OFFLINE_CONTEXT_READY_NATIVE_PLACEMENT_PENDING',output:out,sha256:hash(output),stages:first.stages,final_rng:first.final_rng}));
}catch(error){
 fs.writeFileSync(path.join(out,'HOLD.json'),JSON.stringify({status:'HOLD_SOURCE_CONTINUATION_INCOMPLETE',error:String(error.stack||error),config_sha256:hash(configBytes),boundary:config.boundary},null,2)+'\n');
 throw error;
}
