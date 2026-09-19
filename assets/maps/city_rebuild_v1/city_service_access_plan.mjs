import {CAR,createCarWorld,carFits} from './car_drive.mjs';
import {createLaneConnector} from './city_lane_connector.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {getDetentionRoadStopPose} from './detention_road_stop_pose.mjs';

// Stable lane/approach identities survive TURN numbering changes. Coordinates
// only rank nearby samples of that exact current edge; they are never anchors.
const SITES=Object.freeze({
 'REBUILD-DETENTION-southside':{
  edgeKind:'turn',kind:'straight',fromLaneId:'street-junction-456:L-SO-H-071:0:1:incoming:0',toLaneId:'street-junction-456:L-SO-H-071:0:-1:outgoing:0',reference:{x:632.0499663641804,z:433.64512734116465},gear:-1,maxLengthM:8,speedLimitKmh:4,
 },
 'REBUILD-DETENTION-iron_harbor':{
  edgeKind:'turn',kind:'straight',fromLaneId:'street-junction-65:A-WATERFRONT-W:0:-1:incoming:1',toLaneId:'street-junction-65:C-IH-02:1:1:outgoing:0',reference:{x:260.86489126576464,z:622.5157649557212},gear:1,maxLengthM:16,speedLimitKmh:6,
 },
 'REBUILD-DETENTION-chinatown':{
  edgeKind:'connection',fromLaneId:'street-junction-351:L-CH-V-044:0:-1:outgoing:0',toLaneId:'street-junction-346:L-CH-V-044:0:1:incoming:0',reference:{x:18.78086261714054,z:365.50437847961905},gear:1,maxLengthM:8,speedLimitKmh:6,
 },
});
const M=4.1,MIN_RADIUS=4.3,CONFLICT_RADIUS=2.2,MAX_CANDIDATES=48;
const dist=(a,b)=>Math.hypot(b.x-a.x,b.z-a.z),finite=p=>p&&[p.x,p.z,p.yaw].every(Number.isFinite);
const pose=p=>({x:p.x,z:p.z,yaw:p.yaw});
function bounds(points,pad=0){let minX=Infinity,minZ=Infinity,maxX=-Infinity,maxZ=-Infinity;for(const p of points){minX=Math.min(minX,p.x);minZ=Math.min(minZ,p.z);maxX=Math.max(maxX,p.x);maxZ=Math.max(maxZ,p.z);}return{minX:minX-pad,minZ:minZ-pad,maxX:maxX+pad,maxZ:maxZ+pad};}
const overlap=(a,b)=>a.minX<=b.maxX&&a.maxX>=b.minX&&a.minZ<=b.maxZ&&a.maxZ>=b.minZ;
function pointSegment(p,a,b){const x=b.x-a.x,z=b.z-a.z,l=x*x+z*z,t=l?Math.max(0,Math.min(1,((p.x-a.x)*x+(p.z-a.z)*z)/l)):0;return(p.x-a.x-x*t)**2+(p.z-a.z-z*t)**2;}
function segmentDistance(a,b,c,d){const x=b.x-a.x,z=b.z-a.z,u=d.x-c.x,v=d.z-c.z,den=x*v-z*u;if(Math.abs(den)>1e-9){const dx=c.x-a.x,dz=c.z-a.z,t=(dx*v-dz*u)/den,s=(dx*z-dz*x)/den;if(t>=0&&t<=1&&s>=0&&s<=1)return 0;}return Math.min(pointSegment(a,c,d),pointSegment(b,c,d),pointSegment(c,a,b),pointSegment(d,a,b));}
// Same 2.2m segment-distance contract as city_traffic_control_index. Only the
// source turn and short service suffix are compared with nearby current turns.
function pathsNear(a,b){const r2=CONFLICT_RADIUS**2;for(let i=1;i<a.length;i++)for(let j=1;j<b.length;j++)if(segmentDistance(a[i-1],a[i],b[j-1],b[j])<r2)return true;return false;}
function approachIndex(plan){const result=new Map();for(const j of plan.junctionRules||plan.junctions||[])for(const a of j.approaches||[])result.set(a.id,{...a,junctionId:j.id});return result;}
function stopLines(approaches){const lines=[];for(const a of approaches.values()){if(!a.stopPoint||!a.outward||!Number.isFinite(a.width))continue;const p=a.stopPoint,n=a.outward,w=a.width/2+CAR.halfWidth,points=[{x:p.x-n.z*w,z:p.z+n.x*w},{x:p.x+n.z*w,z:p.z-n.x*w}];lines.push({approach:a,box:bounds(points,.01)});}return lines;}
function crossingStopLines(points,box,lines){const ids=[];for(const{approach:a,box:lineBox}of lines){if(!overlap(box,lineBox))continue;const c=a.stopPoint,n=a.outward;for(let i=1;i<points.length;i++){const p=points[i-1],q=points[i],d0=(p.x-c.x)*n.x+(p.z-c.z)*n.z,d1=(q.x-c.x)*n.x+(q.z-c.z)*n.z;if(d0<0||d1>=0||d0-d1<1e-7)continue;const t=d0/(d0-d1),x=p.x+(q.x-p.x)*t,z=p.z+(q.z-p.z)*t,lateral=(x-c.x)*-n.z+(z-c.z)*n.x;if(Math.abs(lateral)<=a.width/2+CAR.halfWidth){ids.push(a.id);break;}}}return ids;}

/** Construction-time service entries over an already prepared final graph.
 * Full CAR geometry stays on existing road asphalt. A source TURN keeps its
 * actual signal/priority/conflict control; no external ungoverned junction
 * crossing, different-direction snap or implicit reversing is accepted.
 * The host must include all final static bodies in instances/extraBodies and
 * route to laneAnchor before appending this suffix. This does not move actors.
 */
export function planCityServiceAccess({trafficPlan,instances=[],topology,extraBodies=[],roadSupportRects=[],metresPerCell=M}={}){
 if(metresPerCell!==M)throw new RangeError('Service access requires native 4.1 metre coordinates');
 if(!trafficPlan||!topology?.grid||!topology?.roadMask)throw new TypeError('Service access requires a prepared traffic plan and topology');
 const raw=instances.map(i=>i.userData?.instance||i),sites=raw.filter(i=>i.role==='district_detention'),routes=[],issues=[];
 if(!sites.length)return{routes,issues};
 const world=createCarWorld(topology,[...raw.flatMap(i=>i.collision?.worldBodies||[]),...extraBodies],M),isRoad=(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)],approaches=approachIndex(trafficPlan),lines=stopLines(approaches),turns=(trafficPlan.turns||[]).map(turn=>({turn,box:bounds(turn.points,CONFLICT_RADIUS)})),conflictCache=new Map();
 const nearbyConflicts=(points,sourceApproach)=>{const box=bounds(points,CONFLICT_RADIUS),ids=[];for(const{turn,box:other}of turns)if(turn.fromApproachId!==sourceApproach&&overlap(box,other)&&pathsNear(points,turn.points))ids.push(turn.id);return ids;};
 for(const building of sites){
  const spec=SITES[building.id],stop=getDetentionRoadStopPose(building),reject=reason=>issues.push({buildingId:building.id,reason});
  if(!spec){reject('unknown_service_frontage');continue;}if(!finite(stop)){reject('invalid_service_stop');continue;}if(!roadSupportRects.length){reject('missing_road_support');continue;}
  const list=spec.edgeKind==='turn'?trafficPlan.turns:trafficPlan.connections,edges=(list||[]).filter(e=>e.fromLaneId===spec.fromLaneId&&e.toLaneId===spec.toLaneId&&(!spec.kind||e.kind===spec.kind));
  if(!edges.length){reject('missing_prepared_service_edge');continue;}
  const extent=spec.maxLengthM+Math.hypot(CAR.halfWidth,CAR.halfLength)+1,region={minX:stop.x-extent,maxX:stop.x+extent,minZ:stop.z-extent,maxZ:stop.z+extent},support={surfaceRects:[],roadSupportRects:roadSupportRects.filter(r=>overlap(region,r))},fits=(x,z,yaw)=>carFits(x,z,yaw,world,CAR)&&cityParkingCarFits(support,x,z,yaw),candidates=[];
  if(!isRoad(stop.x,stop.z)||!fits(stop.x,stop.z,stop.yaw)){reject('blocked_service_stop');continue;}
  for(const edge of edges){let progressM=0;for(let i=0;i<edge.points.length;i++){const p=edge.points[i];if(i)progressM+=dist(edge.points[i-1],p);if(!finite(p)||dist(p,spec.reference)>5||dist(p,stop)>spec.maxLengthM||Math.cos(p.yaw-stop.yaw)<.7)continue;candidates.push({edge,pointIndex:i,progressM:edge.cumulative?.[i]??progressM,point:pose(p),rank:dist(p,spec.reference)});}}
  candidates.sort((a,b)=>a.rank-b.rank||a.edge.id.localeCompare(b.edge.id)||a.pointIndex-b.pointIndex);let accepted=null,lastReason='no_safe_service_curve';
  for(const c of candidates.slice(0,MAX_CANDIDATES)){
   const reverse=spec.gear<0,sourceApproach=spec.edgeKind==='turn'?c.edge.fromApproachId:c.edge.toLaneId.replace(/:incoming:\d+$/,''),approach=approaches.get(sourceApproach);
   if(spec.edgeKind==='turn'&&!approach){lastReason='missing_service_approach_control';continue;}
   if(spec.edgeKind==='connection'&&approach?.stopPoint){const p=c.point,s=approach.stopPoint,n=approach.outward;if((p.x-s.x)*n.x+(p.z-s.z)*n.z<0){lastReason='source_after_unretained_stop_line';continue;}}
   const curve=createLaneConnector({from:reverse?{...c.point,yaw:c.point.yaw+Math.PI}:c.point,to:reverse?{...stop,yaw:stop.yaw+Math.PI}:stop,isRoad,poseAllowed:reverse?(x,z,yaw)=>fits(x,z,yaw-Math.PI):fits,minRadius:MIN_RADIUS,maxDistance:spec.maxLengthM});
   if(!curve||curve.lengthM>spec.maxLengthM)continue;
   const points=curve.points.map(p=>({x:p.x,z:p.z,yaw:p.yaw-(reverse?Math.PI:0),gear:spec.gear}));points[0]={...c.point,gear:spec.gear};points[points.length-1]={...pose(stop),gear:spec.gear};if(points.some(p=>Math.cos(p.yaw-stop.yaw)<.7))continue;
   if(crossingStopLines(points,bounds(points),lines).length){lastReason='unretained_service_stop_line';continue;}
   const actualConflicts=nearbyConflicts(points,sourceApproach);let retained=[];
   if(spec.edgeKind==='turn'){if(!conflictCache.has(c.edge.id))conflictCache.set(c.edge.id,nearbyConflicts(c.edge.points,sourceApproach));retained=conflictCache.get(c.edge.id);}
   if(actualConflicts.some(id=>!retained.includes(id))){lastReason='new_service_turn_conflict';continue;}
   accepted={id:'service-access:'+building.id+':entry',buildingId:building.id,kind:'service_entry',points,gear:spec.gear,laneAnchor:{edgeId:c.edge.id,fromLaneId:c.edge.fromLaneId,toLaneId:c.edge.toLaneId,pointIndex:c.pointIndex,progressM:c.progressM,point:{...c.point}},lengthM:curve.lengthM,distance:curve.lengthM,minRadiusM:curve.minRadiusM,speedLimitKmh:spec.speedLimitKmh,requiresStopBeforeReverse:reverse,retainedApproachId:spec.edgeKind==='turn'?sourceApproach:null,retainedTurnId:spec.edgeKind==='turn'?c.edge.id:null,retainedConflictTurnIds:retained,actualConflictTurnIds:actualConflicts};break;
  }
  if(accepted)routes.push(accepted);else reject(lastReason);
 }
 return{routes,issues};
}
