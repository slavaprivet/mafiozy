// Actual original deterministic static terrain. No renderer, actors or server.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import {fileURLToPath} from 'node:url';
import {repo,hash,worldSHA} from './npc_startup_source_vm.mjs';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {buildExplorationDecorPlan} from '../../assets/maps/city_rebuild_v1/exploration_decor_worker_core.mjs';
import {buildEnvironmentVisualPlans} from '../../assets/maps/city_rebuild_v1/environment_planning_worker_core.mjs';
import {explorationKeepouts} from '../../assets/maps/city_rebuild_v1/exploration_scene_support.mjs';
const OUT='outputs/astra21_npc_registered_navigation_export';
const CONTEXT='a05ad020429ea8994dba534fe2d6e0886ac02975aadc7db531ea11d93a560f9c';
const FULL='outputs/astra21_npc_full_startup_review/context.snapshot.json';
const read=p=>fs.readFileSync(path.join(repo,p));
function binary(values,kind){const width=kind==='float32_le'?4:8,b=Buffer.alloc(values.length*width);values.forEach((x,i)=>{if(!Number.isFinite(x))throw Error('nonfinite_grid');kind==='float32_le'?b.writeFloatLE(x,i*width):b.writeDoubleLE(x,i*width)});return{dtype:kind,count:values.length,bytes_base64:b.toString('base64'),sha256:hash(b)};}
function overlays(value,pathParts=[],result=[]){if(typeof value==='number'&&!Number.isInteger(value)){const b=Buffer.alloc(8);b.writeDoubleLE(value);result.push({path:pathParts,bytes_le:[...b]});}else if(Array.isArray(value))value.forEach((x,i)=>overlays(x,[...pathParts,i],result));else if(value&&typeof value==='object')for(const[k,x]of Object.entries(value))overlays(x,[...pathParts,k],result);return result;}
export function exportRegisteredTerrain(){
 const contextBytes=read(FULL);if(hash(contextBytes)!==CONTEXT)throw Error('context_hash');const context=JSON.parse(contextBytes);
 const topologyPath='assets/maps/city_rebuild_v1/topology_for_placement.json',topologyBytes=read(topologyPath),topology=JSON.parse(topologyBytes);
 if(topology.grid.length!==200||topology.grid.some(x=>x.length!==180))throw Error('full_topology_shape');
 const source_paths=['assets/maps/city_rebuild_v1/landscape_plan.mjs','assets/maps/city_rebuild_v1/landscape_terrain.mjs','assets/maps/city_rebuild_v1/exploration_railway_plan.mjs','assets/maps/city_rebuild_v1/native_pedestrian_surface.mjs','assets/maps/city_rebuild_v1/npc_native_navigation.mjs','assets/maps/city_rebuild_v1/npc_support_cache.mjs'];
 const source=source_paths.map(p=>{const b=read(p);return{path:p,sha256:hash(b),bytes:b.length,code:b.toString('utf8')}});
 const walkPath='assets/maps/city_rebuild_v1/walk_preview.mjs',walkBytes=read(walkPath),walk=walkBytes.toString('utf8');
 const source_functions=[];
 for(const[name,next]of[['waterAt','ladderPathDistance'],['groundHeight','heroGroundHeight'],['inPolygon','canWalk']]){
  const start=walk.indexOf('function '+name+'('),end=walk.indexOf('function '+next+'(',start),code=walk.slice(start,end).trimEnd();
  if(start<0||end<0)throw Error('missing_source_function');
  // inPolygon is followed by several helpers; preserve only its complete line.
  const actual=name==='inPolygon'?code.split('\n')[0].replace(/\r$/,''):code;
  new vm.Script(actual);source_functions.push({path:walkPath,name,start,sha256:hash(actual),code:actual});
 }
 const landscape=createLandscapePlan(),rail=createExplorationRailwayPlan({landscape,topology});
 const xs=binary(landscape.grid.xs,'float64_le'),zs=binary(landscape.grid.zs,'float64_le'),heights=binary(landscape.grid.heights,'float32_le');
 const data={world_scale:4.1,landscape:{bounds:landscape.bounds,city_bounds:landscape.cityBounds,grid:{width:landscape.grid.xs.length,height:landscape.grid.zs.length,xs,zs,heights},lakes:landscape.lakes},topology,
  missing:{building_entry_support_and_collision:'OWNED_SEPARATE_SOURCE_BUILDING_EXPORT',train_dynamic_frame:'SOURCE_BOUND_FRAME_REQUIRED',fleet_dynamic_frame:'SOURCE_BOUND_FRAME_REQUIRED',logical_vehicle_dynamic_frame:'SOURCE_BOUND_FRAME_REQUIRED',registered_source_resolver:'NOT_REGISTERED_BY_THIS_EXPORTER'}};
 const base={source_world_sha256:worldSHA,context_sha256:CONTEXT,session_id:context.boundary.session_id,population_phase:context.boundary.phase,phase:'OFFLINE_STATIC_NATIVE_REGISTRATION_PREREQUISITES_NO_DYNAMIC_FRAME'};
 const railData={world_scale:4.1,id:rail.id,length:rail.length,points:{fields:['x','y','z','distance'],count:rail.points.length,...binary(rail.points.flatMap(p=>[p.x,p.y,p.z,p.distance]),'float64_le')},stations:rail.stations,crossings:rail.crossings,gauge:rail.gauge,native_crossing_count:rail.nativeCrossingCount};
 const railPacket={schema:'mafiozi.npc-registered-navigation-rail-static/v1',...base,data:railData,data_float64:overlays(railData),proof_receipts:{source:source.filter(x=>x.path.endsWith('exploration_railway_plan.mjs'))},limits:['Original static railway plan including support floor; no train dynamic phase/state fabricated']};
 return{terrain:{schema:'mafiozi.npc-registered-navigation-terrain/v1',...base,data,data_float64:overlays(data),proof_receipts:{source,source_functions,walk_module:{path:walkPath,sha256:hash(walkBytes),bytes:walkBytes.length},topology:{path:topologyPath,sha256:hash(topologyBytes),bytes:topologyBytes.length,bytes_utf8:topologyBytes.toString('utf8')}},limits:['Actual original createLandscapePlan and createExplorationRailwayPlan executed offline without actors/RNG/renderer','Full source topology preserved including candidate/pending-host metadata','Static terrain/water inputs only; no invented vehicle/train/interior frame','This export does not register a resolver or claim physical/LIVE admission']},rail:railPacket};
}
export function exportRegisteredStaticScene(){
 const topologyPath='assets/maps/city_rebuild_v1/topology_for_placement.json',topologyBytes=read(topologyPath),topology=JSON.parse(topologyBytes);
 const inputPaths=['assets/maps/city_rebuild_v1/buildings_placement.v1.json','assets/maps/city_rebuild_v1/detention_native_sites.v1.json','assets/maps/city_rebuild_v1/decor_placement.v1.json'];
 const inputs=inputPaths.map(p=>{const b=read(p);return{path:p,sha256:hash(b),bytes:b.length,records:JSON.parse(b).instances}});
 const all=inputs.flatMap(x=>x.records),keepouts=explorationKeepouts(all,4.1);
 const previousRandom=Math.random;Math.random=()=>{throw Error('GLOBAL_RANDOM_FORBIDDEN_SOURCE_STATIC_EXPORT');};
 let decor,environment;try{decor=buildExplorationDecorPlan({topology,instances:all,keepouts,metresPerCell:4.1});environment=buildEnvironmentVisualPlans({topology,instances:all,keepouts,decorPlan:decor});}finally{Math.random=previousRandom;}
 const data={world_scale:4.1,body_groups:[{id:'authored-nonentry-items',mode:'REPLACED_BY_ENTRY_GROUP_IF_ENTRY_EXISTS',records:all.map(item=>({id:item.id,binding:item.binding,world_bodies:item.collision?.worldBodies||[],is_building:inputs[0].records.includes(item)||inputs[1].records.includes(item)}))},
  {id:'exploration-decor',mode:'WORLD_STATIC',bodies:decor.colliders},
  {id:'environment-roads',mode:'WORLD_STATIC',bodies:environment.roadPlan.colliders},
  {id:'environment-parking',mode:'WORLD_STATIC',bodies:environment.parkingPlan.colliders}],
  decor_seed:decor.placement.seed,decor_stats:decor.stats,missing:['Building-entry replaced bodies/support owned separate actual-template exporter','Initial mutable fences/service collision not attested','Dynamic railway/fleet/logical vehicle frame not attested']};
 const sourcePaths=['exploration_decor_worker_core.mjs','exploration_decor_plan.mjs','environment_planning_worker_core.mjs','exploration_scene_support.mjs','environment_visuals.mjs','city_road_dressing_plan.mjs','city_parking_plan.mjs'];
 return{schema:'mafiozi.npc-registered-navigation-static-scene/v1',source_world_sha256:worldSHA,context_sha256:CONTEXT,phase:'OFFLINE_DETERMINISTIC_CURRENT_SOURCE_STATIC_GEOMETRY_NO_DYNAMIC_FRAME',data,data_float64:overlays(data),proof_receipts:{inputs:inputs.map(({records,...r})=>r),topology:{path:topologyPath,sha256:hash(topologyBytes)},source:sourcePaths.map(n=>{const p='assets/maps/city_rebuild_v1/'+n,b=read(p);return{path:p,sha256:hash(b),code:b.toString('utf8')}})},limits:['Global Math.random forbidden; original local decor seed91426 retained','Actual deterministic source plans, not historical fixture adoption','Do not doublecount building-entry replacement groups with original envelope fallback','No registered resolver/dynamic snapshot/physical admission claim']};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){const out=path.join(repo,OUT);fs.mkdirSync(out,{recursive:true});const packets=exportRegisteredTerrain(),b=Buffer.from(JSON.stringify(packets.terrain)+'\n'),r=Buffer.from(JSON.stringify(packets.rail)+'\n');fs.writeFileSync(path.join(out,'TERRAIN.json'),b);fs.writeFileSync(path.join(out,'RAIL_STATIC.json'),r);console.log(JSON.stringify({terrain_sha256:hash(b),bytes:b.length,rail_sha256:hash(r),rail_bytes:r.length,width:packets.terrain.data.landscape.grid.width,height:packets.terrain.data.landscape.grid.height,rail_points:packets.rail.data.points.count/4,F64_overlays:packets.terrain.data_float64.length}));}
