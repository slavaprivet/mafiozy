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

const out='outputs/roads_logical_20260912/',base=new URL('../../assets/maps/city_rebuild_v1/',import.meta.url),snapshot=JSON.parse(fs.readFileSync(out+'shared_plan_snapshot.json'));
const source=fs.readFileSync(out+'city_road_dressing_plan.before.txt','utf8').replace(/from '\.\/([^']+)'/g,(_,file)=>"from '"+new URL(file,base).href+"'");
const {createCityRoadDressingPlan:before}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
const topology=JSON.parse(fs.readFileSync(new URL('topology_for_placement.json',base))),instances=[...snapshot.buildings,...snapshot.authoredDecor],landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({topology,landscape}),keepouts=[...explorationKeepouts(instances),...explorationKeepouts([{collision:{worldBodies:snapshot.decorPlan.colliders}}]),...snapshot.parkingPlan.keepouts],options={topology,instances,landscape,railPlan,keepouts,accessKeepouts:snapshot.parkingPlan.accessKeepouts,pedestrianBodies:[...snapshot.decorPlan.colliders,...snapshot.parkingPlan.colliders]};
const hash=file=>createHash('sha256').update(fs.readFileSync(new URL(file,base))).digest('hex'),manifest=['city_road_traffic_plan.mjs','city_road_dressing_plan.mjs','city_road_dressing_routes.mjs'].map(file=>({file,sha256:hash(file)})),timings={before:[],after:[]},plans={};
for(let i=0;i<6;i++)for(const name of (i%2?['after','before']:['before','after'])){const start=performance.now();plans[name]=(name==='before'?before:after)(options);if(i>0)timings[name].push(performance.now()-start);}
const controls=plan=>plan.junctionRules.map(j=>({id:j.id,complexId:j.complexId,control:j.control,approaches:j.approaches.map(a=>({id:a.id,rule:a.rule,axis:a.axis,offset:a.offset,signalId:a.signalId,allowedTurnIds:a.allowedTurnIds}))}));
assert.deepEqual(controls(plans.after),controls(plans.before),'dressing preserves every approach rule, allowed turn and real signal controller');const signalControls=plan=>plan.signals.map(({x,z,crosswalk,...signal})=>signal);assert.deepEqual(signalControls(plans.after),signalControls(plans.before));
const signalRelocations=plans.after.signals.flatMap((s,i)=>{const old=plans.before.signals[i],d=Math.hypot(s.x-old.x,s.z-old.z);return d>1e-6?[{id:s.id,approachId:s.approachId,distance:d,before:{x:old.x,z:old.z},after:{x:s.x,z:s.z}}]:[];});
for(const kind of ['edge','center_dash','lane_dash'])assert.deepEqual(plans.after.markings.filter(m=>m.kind===kind).map(({id,...m})=>m),plans.before.markings.filter(m=>m.kind===kind).map(({id,...m})=>m),kind+' content preserved');
for(const c of plans.after.trafficPlan.crosswalks){assert.ok(c.walkingAccessReady,'every selected crossing has actual sidewalk/door routes');const a=plans.after.junctionRules.flatMap(j=>j.approaches).find(a=>a.id===c.approachId);assert.ok((a.stopPoint.x-c.center.x)*c.tx+(a.stopPoint.z-c.center.z)*c.tz>=1.75,'stop line precedes the near zebra edge');if(c.signalControl){assert.equal(c.signalControl.axis,a.axis);assert.equal(c.signalControl.offset,a.offset);assert.ok(c.signalControl.clearanceSeconds<=19);}}
for(const j of plans.after.junctionRules)for(const a of j.approaches)if(a.prioritySignPlacement?.mode==='shared_direction'){const sign=plans.after.signs.find(s=>s.id===a.prioritySignPlacement.signId);assert.ok(sign&&Math.sin(sign.yaw)*a.outward.x+Math.cos(sign.yaw)*a.outward.z>.95);}
const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const drawStats={};for(const name of ['before','after']){const rendered=createCityRoadDressing({THREE,plan:plans[name]});drawStats[name]={...rendered.stats};rendered.dispose();}
const q=list=>{list.sort((a,b)=>a-b);return {p50:list[Math.floor(list.length*.5)],p95:list[Math.min(list.length-1,Math.floor(list.length*.95))],samples:list.length};};
const report={status:plans.after.placementUnresolved.length?'RULES_PRESERVED_PENDING_PHYSICAL_YIELD_SITES':'PASS',scenario:'Same shared78 topology, 164 authored and 2296 procedural colliders, 39 real parking reservations; alternating before/after planner, first pair warmup.',controlsEquivalent:true,sourceManifest:manifest,sourceStable:manifest.every(r=>hash(r.file)===r.sha256),beforeMs:q(timings.before),afterMs:q(timings.after),drawStats,unresolved:plans.after.placementUnresolved,limits:['The previous planner accepts triangles inside neighbouring junctions. These are exposed as unresolved if a legitimate replacement site does not exist.','Graph implementation is shared by both runs; graph changes owned by the navigation agent are not rolled back.','Structural draws and CPU cost are not loaded-scene GPU/FPS acceptance.']};
report.signalRelocations=signalRelocations;fs.writeFileSync(out+'dressing_plan_comparison.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report,null,2));
