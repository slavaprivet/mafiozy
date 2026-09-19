import fs from 'node:fs';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {createCityRoadDressingPlan as after} from '../../assets/maps/city_rebuild_v1/city_road_dressing_plan.mjs';
import {createCityRoadDressing} from '../../assets/maps/city_rebuild_v1/city_road_dressing.mjs';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {explorationKeepouts} from '../../assets/maps/city_rebuild_v1/exploration_scene_support.mjs';

const base=new URL('../../assets/maps/city_rebuild_v1/',import.meta.url),out=new URL('../../outputs/roads_logical_20260912/',import.meta.url),snapshot=JSON.parse(fs.readFileSync(new URL('shared_plan_snapshot.json',out))),source=fs.readFileSync(new URL('city_road_dressing_plan.mjs',base),'utf8');
const start=source.indexOf('  // Resolve the exceptional mouths'),end=source.indexOf('  // Re-route the short sidewalk continuations',start);assert(start>0&&end>start);
// The before variant removes only this independent late pole-placement pass.
// Both use the same current graph, crossing selection, paint and signal logic.
const beforeSource=(source.slice(0,start)+'  const extendedControlPoles=0;\n'+source.slice(end)).replace(/from '\.\/([^']+)'/g,(_,file)=>"from '"+new URL(file,base).href+"'");
const {createCityRoadDressingPlan:before}=await import('data:text/javascript;base64,'+Buffer.from(beforeSource).toString('base64'));
const topology=JSON.parse(fs.readFileSync(new URL('topology_for_placement.json',base))),instances=[...snapshot.buildings,...snapshot.authoredDecor],landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({topology,landscape}),keepouts=[...explorationKeepouts(instances),...explorationKeepouts([{collision:{worldBodies:snapshot.decorPlan.colliders}}]),...snapshot.parkingPlan.keepouts],options={topology,instances,landscape,railPlan,keepouts,accessKeepouts:snapshot.parkingPlan.accessKeepouts,pedestrianBodies:[...snapshot.decorPlan.colliders,...snapshot.parkingPlan.colliders]};
const hash=file=>createHash('sha256').update(fs.readFileSync(new URL(file,base))).digest('hex'),files=['city_road_dressing_plan.mjs','city_road_traffic_plan.mjs','city_road_dressing.mjs'],manifest=files.map(file=>({file,sha256:hash(file)})),timings={before:[],after:[]},plans={};
for(let i=0;i<4;i++)for(const name of (i%2?['after','before']:['before','after'])){const t=performance.now();plans[name]=(name==='before'?before:after)(options);if(i)timings[name].push(performance.now()-t)}
const controls=plan=>plan.junctionRules.map(j=>({id:j.id,control:j.control,complexId:j.complexId,approaches:j.approaches.map(a=>({id:a.id,rule:a.rule,axis:a.axis,offset:a.offset,signalId:a.signalId,stopPoint:a.stopPoint,allowedTurnIds:a.allowedTurnIds}))}));
assert.deepEqual(controls(plans.before),controls(plans.after));assert.deepEqual(plans.before.markings,plans.after.markings);assert.deepEqual(plans.before.signals,plans.after.signals);assert.deepEqual(plans.before.trafficPlan.turns,plans.after.trafficPlan.turns);assert.deepEqual(plans.before.trafficPlan.connections,plans.after.trafficPlan.connections);
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js')),draws={};
for(const name of ['before','after']){const layer=createCityRoadDressing({THREE,plan:plans[name]});draws[name]={...layer.stats};layer.dispose();}
const q=values=>{values.sort((a,b)=>a-b);return {p50:values[1],p95:values[2],samples:values.length}},report={status:'PASS_RULES_AND_ALL_EXISTING_GEOMETRY_PRESERVED',sourceManifest:manifest,sourceStable:manifest.every(r=>hash(r.file)===r.sha256),controlsEquivalent:true,allExistingPaintEquivalent:true,allExistingSignalsEquivalent:true,turnsAndConnectionsEquivalent:true,scenario:'Same shared78 inputs and current graph; only independent last-pass control poles differ. Four alternating pairs, first warmup. CPU only.',beforeMs:q(timings.before),afterMs:q(timings.after),draws,addedPoles:plans.after.signs.slice(plans.before.signs.length),remainingYield:plans.after.placementUnresolved,remainingPriority:plans.after.junctionRules.flatMap(j=>j.approaches).filter(a=>a.prioritySignPlacement?.mode==='no_safe_verge').map(a=>a.id),limits:['Draws are structural counts; no GPU renderer was created.','Loaded gameplay scene performance is not tested; LIVE/GPU queue remains with Coordinator16 and Artist16.']};
assert(report.sourceStable,'source changed while measuring; rerun after coordinator confirms stable graph');fs.writeFileSync(new URL('control_placement_comparison.json',out),JSON.stringify(report,null,2));console.log(JSON.stringify({...report,addedPoles:report.addedPoles.length,draws:Object.fromEntries(Object.entries(draws).map(([k,s])=>[k,{signs:s.signs,totalDraws:s.totalDraws,equipmentDraws:s.equipmentDraws,triangles:s.triangles}]))},null,2));
