// Worker-built controls for crossings between junctions and checked turnarounds.
// Control requests are resolved to this index, never trusted as caller rules.
import {CAR} from './car_drive.mjs';
export function createRoadEdgeControls(edges,crossings,prepared=null,railCrossings=[]){
 const byEdge=new Map(),byId=new Map(),store=(edgeId,control)=>{if(!byEdge.has(edgeId))byEdge.set(edgeId,[]);byEdge.get(edgeId).push(control);byId.set(control.id,control);};
 if(prepared){for(const [id,controls]of prepared)for(const c of controls)store(id,c);return {byEdge,byId};}
 const hullRadius=Math.hypot(CAR.halfWidth,CAR.halfLength),allCrossings=[...crossings,...railCrossings.map(c=>({...c,rail:true,roadStart:{x:c.x-c.tx*(c.length/2+.8),z:c.z-c.tz*(c.length/2+.8)},roadEnd:{x:c.x+c.tx*(c.length/2+.8),z:c.z+c.tz*(c.length/2+.8)}}))],bands=allCrossings.flatMap(c=>{const a=c.roadStart||c.endpoints?.[0],b=c.roadEnd||c.endpoints?.[1];return a&&b?[{c,a,b,x0:Math.min(a.x,b.x)-hullRadius,x1:Math.max(a.x,b.x)+hullRadius,z0:Math.min(a.z,b.z)-hullRadius,z1:Math.max(a.z,b.z)+hullRadius}]:[];});
 for(const edge of edges){const points=edge.points,x0=Math.min(...points.map(p=>p.x)),x1=Math.max(...points.map(p=>p.x)),z0=Math.min(...points.map(p=>p.z)),z1=Math.max(...points.map(p=>p.z));
  for(const {c,a,b,...box}of bands){if(edge.edgeKind==='turn'&&!c.rail)continue;if(box.x0>x1||box.x1<x0||box.z0>z1||box.z1<z0)continue;for(let i=1;i<points.length;i++){const p=points[i-1],q=points[i],dx=q.x-p.x,dz=q.z-p.z,ux=b.x-a.x,uz=b.z-a.z,den=dx*uz-dz*ux;if(Math.abs(den)<1e-8)continue;const t=((a.x-p.x)*uz-(a.z-p.z)*ux)/den,u=((a.x-p.x)*dz-(a.z-p.z)*dx)/den;if(t<0||t>1)continue;const length=Math.hypot(ux,uz),yaw=Number.isFinite(p.yaw)&&Number.isFinite(q.yaw)?p.yaw+Math.atan2(Math.sin(q.yaw-p.yaw),Math.cos(q.yaw-p.yaw))*t:Math.atan2(dx,dz),along=Math.min(CAR.halfWidth*length/Math.max(1e-12,Math.abs(Math.cos(yaw)*ux-Math.sin(yaw)*uz)),CAR.halfLength*length/Math.max(1e-12,Math.abs(Math.sin(yaw)*ux+Math.cos(yaw)*uz)));if(u< -along/length||u>1+along/length)continue;const crossingProgressM=edge.cumulative[i-1]+Math.hypot(dx,dz)*t;store(edge.id,{id:`${edge.id}:crossing:${c.id}`,kind:c.rail?'railway_crossing':'pedestrian_crossing',edgeId:edge.id,crosswalkIds:c.rail?[]:[c.id],railCrossingIds:c.rail?[c.id]:[],progressM:crossingProgressM-4.3,crossingProgressM,rule:c.rail?'yield_to_train':'pedestrian_priority'});break;}}
  if(edge.kind==='dead_end_turnaround')store(edge.id,{id:`${edge.id}:control`,kind:'road_end_turnaround',edgeId:edge.id,progressM:edge.controlProgressM,rule:'yield_to_oncoming',speedLimitKmh:edge.speedLimitKmh,conflictingEdgeIds:edge.conflictingEdgeIds||[],crosswalkIds:(byEdge.get(edge.id)||[]).filter(c=>c.crossingProgressM>=edge.controlProgressM).flatMap(c=>c.crosswalkIds)});
  if(edge.kind==='one_way_narrow_passage')store(edge.id,{id:`${edge.id}:control`,kind:'one_way_narrow_passage',edgeId:edge.id,progressM:0,appliesUntilM:edge.cumulative.at(-1),rule:'one_way',speedLimitKmh:edge.speedLimitKmh,crosswalkIds:[],fromLaneId:edge.fromLaneId,toLaneId:edge.toLaneId});
 }
 return {byEdge,byId};
}
export function evaluateRoadEdgeControl(index,control,state={}){
 const c=index.byId.get(control?.id);if(!c||c.edgeId!==control.edgeId||c.kind!==control.kind)return {allowed:false,reason:'unknown_road_control'};
 if(c.crosswalkIds.some(id=>(state.occupiedCrosswalkIds||[]).includes(id)))return {allowed:false,reason:'pedestrian_crossing'};
 if((c.railCrossingIds||[]).some(id=>(state.occupiedRailCrossingIds||[]).includes(id)))return {allowed:false,reason:'railway_crossing_occupied'};
 if(c.kind==='road_end_turnaround'&&c.conflictingEdgeIds.some(id=>(state.occupiedEdgeIds||[]).includes(id)))return {allowed:false,reason:'yield_to_oncoming'};
 return {allowed:true,reason:'clear',rule:c.rule,speedLimitKmh:c.speedLimitKmh};
}
