// Offline, pinned source geometry only. No source population/startup replay.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {repo,html,hash,worldSHA,sourceFunction} from './npc_startup_source_vm.mjs';
const CONTEXT='a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c';
const STATIC='c5f57678912a0c18b51430ea0ef69ea2c84572d32392fa036b84c53f4933724b';
const FULL='outputs/astra21_npc_full_startup/d3d0596340658f9e5238977e99d2c900ff7cdbbe40d09c4f3096aa46089880a8';
const OUT='outputs/astra21_npc_placement_primitives_export';
const read=p=>fs.readFileSync(path.join(repo,p));
const json=p=>JSON.parse(read(p));
export class UnknownDependency extends Error {constructor(name){super(name);this.dependency=name;}}
function float64Transport(value,pathParts=[],result=[]){
 if(typeof value==='number'&&!Number.isInteger(value)){if(!Number.isFinite(value))throw Error('nonfinite_static_data');const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);result.push({path:pathParts,bytes_le:[...bytes]});}
 else if(Array.isArray(value))value.forEach((x,i)=>float64Transport(x,[...pathParts,i],result));
 else if(value&&typeof value==='object')for(const [k,x]of Object.entries(value))float64Transport(x,[...pathParts,k],result);
 return result;
}
export function exportPlacementPrimitives(){
 const bytes=read(FULL+'/context.json');if(hash(bytes)!==CONTEXT)throw Error('context_hash');
 const packet=JSON.parse(bytes),stageBytes=read(FULL+'/stage_results.json'),stage=JSON.parse(stageBytes);
 const phaseDir='outputs/astra21_npc_placement_primitives_phase';
 const manifest=json(phaseDir+'/MANIFEST.json');
 for(const receipt of manifest.files){const b=read(phaseDir+'/'+receipt.file);if(b.length!==receipt.bytes||hash(b)!==receipt.sha256)throw Error('phase_receipt:'+receipt.file);}
 const phase=json(phaseDir+'/RESULT.json');
 if(phase.context_sha256!==CONTEXT||phase.source_world_sha256!==worldSHA||phase.stage_results_sha256!==hash(stageBytes))throw Error('phase_binding');
 if(!phase.full_callback_map.unchanged||phase.full_callback_map.after!==stage.traffic.map_after_sha256||hash(JSON.stringify(packet.context.MAP)+'\n')!==stage.traffic.map_after_sha256)throw Error('phase_map');
 const source=json('outputs/astra21_npc_placement_primitives_source/SOURCE_RECEIPTS.json');
 const core=json('outputs/astra21_npc_source_body_oracle/SOURCE_SLICES.json');
 const phaseSource=json(phaseDir+'/SOURCE_RECEIPTS.json');
 for(const r of [...phaseSource.functions,...phaseSource.declarations,...phaseSource.slices])if(hash(r.code)!==r.sha256||!html.includes(r.code))throw Error('phase_source_receipt');
 const activation=['_activateCityV3BuildingPreview','_activateCityV3NextBuilding','_activateCityV3GlassBuilding','_activateCityV3AcceptedBuildingPreview'].map(sourceFunction);
 const receipts=[...source.receipts,...core.functions,...core.declarations,...activation];
 for(const r of receipts){if(hash(r.code)!==r.sha256||html.slice(r.start??html.indexOf(r.code),r.end??(html.indexOf(r.code)+r.code.length))!==r.code)throw Error('source_receipt:'+r.name);new vm.Script(r.code);}
 const staticBytes=read('outputs/astra21_npc_source_body_oracle/STATIC_GEOMETRY.json');if(hash(staticBytes)!==STATIC)throw Error('static_hash');
 const stat=JSON.parse(staticBytes).data;
 const prereqBytes=read(source.synchronous_prerequisites.path);if(hash(prereqBytes)!==source.synchronous_prerequisites.sha256)throw Error('business_receipt');
 const prereq=JSON.parse(prereqBytes),cache=stage.traffic.building_collision_cache;
 if(cache.entries.length!==204||!cache.unchanged||hash(JSON.stringify(cache.entries))!==cache.after_sha256||prereq.business_cache.length!==10||prereq.business_enabled!==true)throw Error('actual_cache');
 const ctx=vm.createContext({MAP:structuredClone(packet.context.MAP),MAP_ROWS:200,MAP_COLS:180});
 const installDeclaration=name=>{const r=source.receipts.find(x=>x.kind==='declaration'&&x.name===name);if(!r)throw Error('missing_static_declaration:'+name);vm.runInContext(r.code,ctx);};
 for(const name of ['PASSABLE','BLOCK','CITY_CANAL_C0','CITY_BRIDGE_R0','BEACH_R0','PIER_R0','PIER_C0','SHIP_R0','SHIP_C0','PORT_CONTAINER_PRESETS','TRACK_PTS','TRACK_HALF_W','_trackTiles'])installDeclaration(name);
 vm.runInContext(source.receipts.find(x=>x.name==='PORT_CONTAINER_LAYOUT_WITH_ORIGINAL_INITIALIZER').code,ctx);
 vm.runInContext(sourceFunction('_buildTrackTiles').code,ctx);vm.runInContext('_buildTrackTiles()',ctx);
 const originals=JSON.parse(vm.runInContext('JSON.stringify({passable:[...PASSABLE],block:BLOCK,bridge:{canal_c0:CITY_CANAL_C0,canal_c1:CITY_CANAL_C1,r0:CITY_BRIDGE_R0,r1:CITY_BRIDGE_R1},port:PORT_CONTAINER_LAYOUT,track:_trackPathPts,half_width:TRACK_HALF_W,beach_r1:BEACH_R1})',ctx));
 vm.runInContext(sourceFunction('_connectedBuildingParts').code,ctx);
 const resolved=new Map(structuredClone(cache.entries));
 for(let r=0;r<200;r+=10)for(let c=0;c<180;c+=10){const key=r+':'+c;if(!resolved.has(key)){ctx.__r=r;ctx.__c=c;resolved.set(key,JSON.parse(vm.runInContext('JSON.stringify(_connectedBuildingParts(__r,__c,Math.min(__r+10,MAP_ROWS),Math.min(__c+10,MAP_COLS)))',ctx)));}}
 const defaultVm=vm.createContext({URLSearchParams,location:{search:'?render=3d&renderer=walk',hostname:'localhost'}});
 for(const name of ['_cityV3NextActive','_cityV3ActiveAcceptedBuildings','_cityV3ActiveCivicPreview','_cityV3GlassActive','_cityV3DecorBodies','_cityV3RailState'])vm.runInContext(source.receipts.find(x=>x.kind==='declaration'&&x.name===name).code,defaultVm);
 const registries=JSON.parse(vm.runInContext('JSON.stringify({next_entries:[..._cityV3NextActive],accepted_entries:[..._cityV3ActiveAcceptedBuildings],civic:_cityV3ActiveCivicPreview,glass:_cityV3GlassActive,decor_entries:[..._cityV3DecorBodies],rail:_cityV3RailState})',defaultVm));
 const defaults=phase.observed_defaults_and_gates;
 if(!defaults.navNull||!defaults.waterNull||defaults.bypass!==0||defaults.nextSize!==0||defaults.decorSize!==0||!defaults.railNull||defaults.buildingGate||defaults.railGate||defaults.decorGate)throw Error('initial_defaults');
 const data={map:packet.context.MAP,map_rows:200,map_cols:180,passable_tiles:originals.passable,whole_building_collisions_enabled:stat.prison_enabled,block_size:originals.block,
  building_cache:{historical_entries:cache.entries,resolved_entries:[...resolved],derivation:'HISTORICAL_FIRST_ORIGINAL_ABSENT_ONLY_LAZY_EQUIVALENT'},
  business:{enabled:prereq.business_enabled,entries:prereq.business_cache},bridge:originals.bridge,
  port_containers:originals.port,race:{path_points:originals.track,half_width:originals.half_width,beach_r1:originals.beach_r1,pit:stat.pit},
  registries,
  resolver_defaults:{native_nav:null,water:null,water_bypass:0},prison_static_dependency:{path:'outputs/astra21_npc_source_body_oracle/STATIC_GEOMETRY.json',sha256:STATIC,bytes_utf8:staticBytes.toString('utf8'),decoded_data:stat},dynamic_unknown:['release_gate_progress','alarm_active']};
 return {schema:'mafiozi.npc-source-placement-primitives/v1',source_world_sha256:worldSHA,context_sha256:CONTEXT,stage_results_sha256:hash(stageBytes),session_id:packet.boundary.session_id,phase:packet.boundary.phase,data,
  number_transport:'DATA_NONINTEGER_FLOAT64_LE_OVERLAY_PATHS_RELATIVE_TO_DATA',data_float64:float64Transport(data),proof_receipts:{source_path:'world.html',source:receipts,phase:phaseSource,phase_manifest:manifest,phase_result:phase,prerequisites:{path:source.synchronous_prerequisites.path,sha256:hash(prereqBytes)}},limits:['Offline immutable new-session source fallback only','Historical204cache retained; only absent blocks derived from final unchanged MAP','Dynamic prison gate/alarm require visited source-bound proof; no timer execution','No NPC births/RNG/server/native physical admission']};
}
export function createPrimitiveOracle(exported){
 const d=exported.data;if(hash(d.prison_static_dependency.bytes_utf8)!==STATIC)throw Error('oracle_static_hash');const stat=JSON.parse(d.prison_static_dependency.bytes_utf8).data;
 const context=vm.createContext({MAP:structuredClone(d.map),MAP_ROWS:d.map_rows,MAP_COLS:d.map_cols,
  BLOCK:d.block_size,PASSABLE:new Set(d.passable_tiles),_THREE_WHOLE_BUILDING_COLLISIONS:d.whole_building_collisions_enabled,_threeBuildingBlockCache:new Map(structuredClone(d.building_cache.resolved_entries)),
  _businessExteriorPedCollisionEnabled:d.business.enabled,_businessExteriorCollisionCache:new Map(d.business.entries.map(x=>[x.id,structuredClone(x)])),
  CITY_CANAL_C0:d.bridge.canal_c0,CITY_CANAL_C1:d.bridge.canal_c1,CITY_BRIDGE_R0:d.bridge.r0,CITY_BRIDGE_R1:d.bridge.r1,
  PORT_CONTAINER_LAYOUT:structuredClone(d.port_containers),_trackPathPts:structuredClone(d.race.path_points),TRACK_HALF_W:d.race.half_width,BEACH_R1:d.race.beach_r1,
  _cityV3DecorBodies:new Map(),_cityV3NextActive:new Map(),_cityV3GlassActive:null,_cityV3ActiveCivicPreview:null,_cityV3ActiveAcceptedBuildings:new Map(),_cityV3RailState:null,
  JAIL_ISLAND_3D_ENABLED:stat.prison_enabled,JAIL_ISLAND_LAYOUT:structuredClone(stat.prison_layout),
  _walkNpcNavigationResolver:null,_walkNpcWaterResolver:null,_npcWaterBypass:0,_npcNavigationStats:{queries:0,solidRefusals:0,waterRefusals:0},
  _prisonReleaseGateProgress:()=>{throw new UnknownDependency('RELEASE_GATE_PROGRESS_UNAVAILABLE');},_prisonAlarmActive:()=>{throw new UnknownDependency('ALARM_ACTIVE_UNAVAILABLE');}});
 const run=code=>vm.runInContext(code,context,{timeout:10000});
 const core=json('outputs/astra21_npc_source_body_oracle/SOURCE_SLICES.json');
 for(const r of core.declarations)if(!['JAIL_ISLAND_3D_ENABLED','JAIL_ISLAND_LAYOUT'].includes(r.name))run(r.code);
 const names=['isBlockedPed','isBlocked','_cityV3DecorBlocked','_openCityBridgeSurface','_isRaceWaterEdgeBlockedForPed','_businessExteriorPedBlocked','_businessExteriorDoorCorridorAt','_isPortContainerSolid','_isThreeWholeBuildingBlocked','_connectedBuildingParts','_cityV3RailBlocksPed','_cityV3RailTrainBodyContains','_cityV3CivicSurfaceAt','_cityV3AcceptedSurfaceAt','_cityV3NextSurfaceAt','_cityV3NextCorridorAt','_cityV3GlassSurfaceAt','_cityV3RectContains','_cityV3AcceptedCorridorAt','_cityV3CivicDoorCorridorAt','_nearestRaceTrackPoint','_inPitCorridor','_distToRaceSeg'];
 for(const name of names)run(sourceFunction(name).code);
 for(const r of core.functions)if(r.name!=='_prisonAlarmActive')run(r.code);
 return {context,run};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const exported=exportPlacementPrimitives(),out=path.join(repo,OUT);fs.mkdirSync(out,{recursive:true});
 const bytes=Buffer.from(JSON.stringify(exported,null,2)+'\n');fs.writeFileSync(path.join(out,'PRIMITIVES.json'),bytes);
 const oracle=createPrimitiveOracle(exported),packet=json(FULL+'/context.json'),rows=[],trace=[];
 oracle.context.__observe=(name,r,c,value,error)=>trace.push({ordinal:trace.length,object_key:oracle.context.__owner,name,r,c,...(error?{known:false,dependency:error.dependency}:{known:true,value:structuredClone(value)})});
 const observed=['isBlockedPed','isBlocked','_cityV3DecorBlocked','_openCityBridgeSurface','_isRaceWaterEdgeBlockedForPed','_businessExteriorPedBlocked','_isPortContainerSolid','_isThreeWholeBuildingBlocked','_cityV3RailBlocksPed','_cityV3CivicSurfaceAt','_cityV3AcceptedSurfaceAt','_cityV3NextSurfaceAt','_prisonIslandCollisionAt'];
 for(const name of observed)oracle.run(`{const original=${name};${name}=function(...args){try{const value=original(...args);__observe('${name}',args[0],args[1],value,null);return value;}catch(error){__observe('${name}',args[0],args[1],null,error);throw error;}};}`);
 const objects=new Map(packet.context.objects.map(x=>[x.object_key,x.raw])),seen=new Set();
 for(const [pool,kind]of[['NPCS','resident'],['cityCops','police'],['worldCops','police']])for(const key of packet.context.pools[pool]){if(seen.has(key))continue;seen.add(key);const raw=objects.get(key),xy=kind==='police'&&Number.isFinite(raw.x)&&Number.isFinite(raw.y);oracle.context.__owner=key;oracle.context.__actor=structuredClone(raw);oracle.context.__r=xy?raw.y:raw.r;oracle.context.__c=xy?raw.x:raw.c;const traceStart=trace.length;let result;try{result={known:true,pass:oracle.run(kind==='police'?'_policeCrewBodyPassable(__r,__c)':'_npcBodyPassable(__r,__c,(r,c)=>npcWaypointOk(__actor,r,c))')};}catch(e){if(!(e instanceof UnknownDependency))throw e;result={known:false,dependency:e.dependency};}rows.push({object_key:key,actor_id:raw.id,kind,r:oracle.context.__r,c:oracle.context.__c,trace_start:traceStart,trace_end:trace.length,...result});}
 fs.writeFileSync(path.join(out,'BODY_GOLDEN.json'),JSON.stringify({schema:'mafiozi.source-placement-body-golden/v1',primitive_sha256:hash(bytes),context_sha256:CONTEXT,source_world_sha256:worldSHA,rows,native_physical_admission:false},null,2)+'\n');
 fs.writeFileSync(path.join(out,'PRIMITIVE_QUERY_GOLDEN.json'),JSON.stringify({schema:'mafiozi.source-placement-primitive-query-golden/v1',primitive_sha256:hash(bytes),source_world_sha256:worldSHA,trace,observation:'POST_RETURN_WRAPPERS_PRESERVE_SOURCE_ORDER_RETURN_AND_THROW'},null,2)+'\n');
 console.log(JSON.stringify({primitive_sha256:hash(bytes),rows:rows.length,primitive_calls:trace.length,known_pass:rows.filter(x=>x.known&&x.pass).length,known_reject:rows.filter(x=>x.known&&!x.pass).length,unknown:rows.filter(x=>!x.known).length}));
}
