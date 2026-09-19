import {getDetentionRoadStopPose} from './detention_road_stop_pose.mjs';
/** Shared worker/runtime arrival poses. These describe the public frontage,
 * not the pedestrian doorway or an arbitrary building centre. */
export function buildingRoadDestination(building,{metresPerCell=4.1,isRoad=()=>true}={}){
 if(building.role==='district_detention'&&building.stopFootprint)return {kind:'service_stop',buildingId:building.id,candidates:[{point:getDetentionRoadStopPose(building,{metresPerCell}),tail:[]}]};
 const p=building.entry?.roadProbeRC,a=building.entry?.anchorRC;if(!p)return null;
 const origin={x:p.c*metresPerCell,z:p.r*metresPerCell},dx=a?p.c-a.c:0,dz=a?p.r-a.r:0,n=Math.hypot(dx,dz);
 const candidates=(n?[0,1.5,3,4.5,-1.5]:[0]).map(offset=>({point:{x:origin.x+(n?dx/n*offset:0),z:origin.z+(n?dz/n*offset:0)},tail:[]})).filter(c=>isRoad(c.point.x,c.point.z));
 return {kind:'building_approach',buildingId:building.id,candidates};
}

/** Precompute static goal connectors once in the planning worker. Dynamic
 * starting poses and arbitrary map clicks remain queries of the same graph. */
export function cityRoadArrivalPoses({parkingPlan,instances=[],metresPerCell=4.1,isRoad=()=>true}={}){
 const points=(parkingPlan?.access?.routes||[]).filter(r=>r.kind==='entry'&&!r.laneAnchor).map(r=>r.points[0]);
 const covered=new Set((parkingPlan?.coverage||[]).filter(c=>c.status==='served').map(c=>c.buildingId));
 for(const item of instances){const building=item.userData?.instance||item;if(covered.has(building.id))continue;const destination=buildingRoadDestination(building,{metresPerCell,isRoad});if(destination)points.push(...destination.candidates.map(c=>c.point));}
 return [...new Map(points.map(p=>[[p.x,p.z,p.yaw??''].join('|'),p])).values()];
}
