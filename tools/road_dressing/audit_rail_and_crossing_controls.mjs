import fs from 'node:fs';
import {isDeepStrictEqual} from 'node:util';
import {createHash} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {createLandscapePlan} from '../../assets/maps/city_rebuild_v1/landscape_plan.mjs';
import {createExplorationRailwayPlan} from '../../assets/maps/city_rebuild_v1/exploration_railway_plan.mjs';
import {createRoadEdgeControls,evaluateRoadEdgeControl} from '../../assets/maps/city_rebuild_v1/city_road_edge_controls.mjs';
import {createTrafficControlIndex} from '../../assets/maps/city_rebuild_v1/city_traffic_control_index.mjs';
import {evaluateTrafficApproach} from '../../assets/maps/city_rebuild_v1/city_road_traffic_plan.mjs';

const out='outputs/roads_logical_20260912/',input=out+(process.argv[2]||'integration_candidate_snapshot.json'),bytes=fs.readFileSync(input),snapshot=JSON.parse(bytes),topology=JSON.parse(fs.readFileSync('assets/maps/city_rebuild_v1/topology_for_placement.json')),rail=createExplorationRailwayPlan({topology,landscape:createLandscapePlan()}),roads=snapshot.roadPlan,prepared=roads.preparedLaneGraph,plan=prepared?.plan||roads.trafficPlan,started=performance.now(),errors=[],checks={paintRailSamples:0,edgeControls:0,pedestrianDecisions:0,railDecisions:0,turnCrossingDecisions:0},expectedRail=rail.crossings.filter(c=>c.city&&c.drive).map(({signals,...c})=>c);
if(!isDeepStrictEqual(roads.trafficPlan.railCrossings,expectedRail))errors.push({kind:'rail_registry_changed_or_missing',expected:expectedRail.map(c=>c.id),actual:roads.trafficPlan.railCrossings?.map(c=>c.id)});
if(prepared&&!isDeepStrictEqual(prepared.plan.railCrossings,expectedRail))errors.push({kind:'prepared_rail_registry_mismatch'});
const railPaintFailures=[];
for(const mark of roads.markings){
 // Lipschitz distance gives a conservative fast rejection far from the track.
 const radius=Math.hypot(mark.length,mark.width)/2;if(rail.distanceToTrack(mark.x,mark.z)>10.15+radius)continue;
 const nx=-mark.tz,nz=mark.tx,along=Math.max(1,Math.ceil(mark.length/.25)),across=Math.max(1,Math.ceil(mark.width/.25));let hit=null;
 for(let i=0;i<=along&&!hit;i++)for(let j=0;j<=across;j++){const u=(i/along-.5)*mark.length,v=(j/across-.5)*mark.width,x=mark.x+mark.tx*u+nx*v,z=mark.z+mark.tz*u+nz*v;checks.paintRailSamples++;if(rail.distanceToTrack(x,z)<10.15-1e-6){hit={x,z};break;}}
 if(hit)railPaintFailures.push({id:mark.id,kind:mark.kind,...hit});
}
if(railPaintFailures.length)errors.push({kind:'paint_in_rail_keepout',count:railPaintFailures.length,examples:railPaintFailures.slice(0,8)});
const edges=[...(plan.connections||[]).map(e=>({...e,edgeKind:'connection'})),...(plan.turns||[]).map(e=>({...e,edgeKind:'turn'}))].map(e=>{if(e.cumulative)return e;const cumulative=[0];for(let i=1;i<e.points.length;i++)cumulative.push(cumulative.at(-1)+Math.hypot(e.points[i].x-e.points[i-1].x,e.points[i].z-e.points[i-1].z));return {...e,cumulative};});
const crossings=[...(plan.crosswalks||[]),...(plan.serviceCrossings||[])],edgeIndex=createRoadEdgeControls(edges,crossings,null,plan.railCrossings||[]),actualPrepared=prepared?.edgeControlData;
if(prepared&&!actualPrepared)errors.push({kind:'missing_prepared_edge_control_data'});
if(actualPrepared){const normalize=data=>data.flatMap(([,controls])=>controls).sort((a,b)=>a.id.localeCompare(b.id));if(!isDeepStrictEqual(normalize(actualPrepared),normalize([...edgeIndex.byEdge])))errors.push({kind:'prepared_edge_control_index_mismatch'});}
const index=createTrafficControlIndex(plan,prepared?.controlIndexData),crossingCoverage=new Map(crossings.map(c=>[c.id,{turns:0,connections:0}])),railCoverage=new Map(expectedRail.map(c=>[c.id,[]])),shortStops=[];
for(const control of edgeIndex.byId.values()){
 checks.edgeControls++;if(!evaluateRoadEdgeControl(edgeIndex,control,{}).allowed)errors.push({kind:'clear_edge_control_denied',id:control.id});
 if(control.kind==='pedestrian_crossing')for(const id of control.crosswalkIds){checks.pedestrianDecisions++;if(evaluateRoadEdgeControl(edgeIndex,control,{occupiedCrosswalkIds:[id]}).allowed)errors.push({kind:'occupied_crosswalk_allowed',id:control.id});if(!crossingCoverage.has(id))errors.push({kind:'unknown_crosswalk_id',id});else crossingCoverage.get(id).connections++;}
 if(control.kind==='railway_crossing')for(const id of control.railCrossingIds){checks.railDecisions++;if(control.crosswalkIds.length||evaluateRoadEdgeControl(edgeIndex,control,{occupiedRailCrossingIds:[id]}).allowed)errors.push({kind:'occupied_train_allowed_or_pedestrian_alias',id:control.id});if(!railCoverage.has(id))errors.push({kind:'invented_rail_crossing',id});else railCoverage.get(id).push(control.id);}
 if(['pedestrian_crossing','railway_crossing'].includes(control.kind)&&control.crossingProgressM-control.progressM<4.25)shortStops.push({id:control.id,kind:control.kind,edgeId:control.edgeId,crossingProgressM:control.crossingProgressM,leadM:control.crossingProgressM-control.progressM});
 if(evaluateRoadEdgeControl(edgeIndex,{...control,id:'forged-id'},{}).allowed)errors.push({kind:'forged_control_allowed',id:control.id});
}
for(const turn of plan.turns||[])for(const id of index.crosswalkIdsForTurn(turn.id)){checks.turnCrossingDecisions++;if(evaluateTrafficApproach(plan,{approachId:turn.fromApproachId,turnId:turn.id,occupiedCrosswalkIds:[id]}).allowed)errors.push({kind:'turn_ignores_pedestrian',id:turn.id,crosswalkId:id});if(crossingCoverage.has(id))crossingCoverage.get(id).turns++;}
const uncontrolledCrossings=[...crossingCoverage].filter(([,c])=>!c.turns&&!c.connections).map(([id])=>id),unusedRailCrossings=[...railCoverage].filter(([,ids])=>!ids.length).map(([id])=>id);
const stationSigns=roads.signs.filter(s=>s.kind==='rail');for(const sign of stationSigns)if(!rail.stations.some(s=>s.id===sign.stationId))errors.push({kind:'rail_station_sign_has_no_station',id:sign.id});
const report={status:errors.length?'FAIL':'PASS',input,inputSHA256:createHash('sha256').update(bytes).digest('hex'),inputStable:fs.readFileSync(input).equals(bytes),prepared:!!prepared,elapsedMs:performance.now()-started,checks,errors,railPaintFailures,shortStops,uncontrolledCrossings,unusedRailCrossings,railCrossings:[...railCoverage].map(([id,controls])=>({id,controls:controls.length,signalPosts:rail.crossings.find(c=>c.id===id).signals.length})),railwayStationSigns:stationSigns.map(s=>({id:s.id,stationId:s.stationId,x:s.x,z:s.z})),crossingCoverage:[...crossingCoverage].map(([id,c])=>({id,...c})),limits:['CPU geometry and canonical occupancy contract only; source train/player/NPC movement and loaded-scene performance are not exercised.','Unused crossing and short-stop lists require graph-owner review: geometry may belong to a closed edge or use an upstream approach control.']};fs.writeFileSync(out+(process.argv[3]||'final_rail_crossing_controls_audit.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify({...report,crossingCoverage:undefined,railPaintFailures:railPaintFailures.slice(0,8),shortStops:shortStops.slice(0,12)},null,2));if(errors.length)process.exitCode=1;
