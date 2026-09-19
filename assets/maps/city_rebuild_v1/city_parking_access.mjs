import {createCarWorld,carFits} from './car_drive.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';
import {createLaneConnector} from './city_lane_connector.mjs';
// Low-speed driveway paths use the same paved rectangles as parking collision.
// Local +v enters the lot. In the city's +Z-south convention, -u is
// the right side of that direction (trafficRight = {-tz, tx}).
const local=(lot,u,v)=>({x:lot.origin.x+lot.dz*u+lot.dx*v,z:lot.origin.z-lot.dx*u+lot.dz*v});
const length=points=>points.slice(1).reduce((sum,p,i)=>sum+Math.hypot(p.x-points[i].x,p.z-points[i].z),0);
const lotCoordinates=(lot,p)=>({u:(p.x-lot.origin.x)*lot.dz-(p.z-lot.origin.z)*lot.dx,v:(p.x-lot.origin.x)*lot.dx+(p.z-lot.origin.z)*lot.dz});
export function planCityParkingAccess({plan,topology,instances=[],extraBodies=[]}){
 const raw=instances.map(i=>i.userData?.instance||i),world=createCarWorld(topology,[...raw.flatMap(i=>i.collision?.worldBodies||[]),...plan.colliders,...extraBodies],plan.metresPerCell);
 return buildCityParkingAccess({plan,roadAt:(x,z)=>!!topology.roadMask[Math.floor(z/plan.metresPerCell)]?.[Math.floor(x/plan.metresPerCell)],vehicleFits:(x,z,yaw)=>carFits(x,z,yaw,world)&&cityParkingCarFits(plan,x,z,yaw)});
}
export function buildCityParkingAccess({plan,roadAt,vehicleFits}){
 const routes=[],markings=[],issues=[];
 const safe=points=>points.every(p=>vehicleFits(p.x,p.z,p.yaw));
 function route(lot,kind,side,points,gear='forward',minRadiusM=null){if(!safe(points))return false;routes.push({id:lot.id+':'+kind+':'+side,lotId:lot.id,kind,side,gear,speedLimitKmh:gear==='reverse'?5:10,rule:kind==='exit'?lot.exitRule:lot.layout!=='parallel'&&side===1?'yield_to_oncoming_and_pedestrians':'yield_to_pedestrians',points,distance:length(points),...(minRadiusM!==null?{minRadiusM}:{})});return true}
 function driveway(lot,kind,side,roadV){
  const ownSupport={surfaceRects:[lot.rect,lot.driveway],roadSupportRects:plan.roadSupportRects};
  const allowed=(x,z,yaw)=>vehicleFits(x,z,yaw)&&cityParkingCarFits(ownSupport,x,z,yaw);
  for(const uRoad of [8,9,10,11,12])for(const landingV of [5.6,6.2,6.8]){
   const roadU=side*uRoad+(kind==='entry'?-1.65:1.65),road={...local(lot,roadU,roadV),yaw:Math.atan2((kind==='entry'?-side:side)*lot.dz,(kind==='entry'?side:-side)*lot.dx)},yard={...local(lot,kind==='entry'?-1.65:1.65,landingV),yaw:kind==='entry'?lot.yaw:lot.yaw+Math.PI};
   if(!roadAt(road.x,road.z))continue;
   const result=createLaneConnector({from:kind==='entry'?road:yard,to:kind==='entry'?yard:road,minRadius:4.3,poseAllowed:allowed,isRoad:()=>true});
   if(result&&route(lot,kind,side,result.points,'forward',result.minRadiusM))return true;
  }
  return false;
 }
 function paint(lot,kind,u,v,width,extent,yaw=lot.yaw){const p=local(lot,u,v);markings.push({id:lot.id+':paint:'+markings.length,lotId:lot.id,kind,...p,yaw,width,length:extent})}
 function segment(lot,kind,a,b,width=.12){const p=local(lot,...a),q=local(lot,...b);markings.push({id:lot.id+':paint:'+markings.length,lotId:lot.id,kind,x:(p.x+q.x)/2,z:(p.z+q.z)/2,yaw:Math.atan2(q.x-p.x,q.z-p.z),width,length:Math.hypot(q.x-p.x,q.z-p.z)})}
 function arrow(lot,u,v,direction){paint(lot,'driveway_arrow',u,v,.14,1.5);segment(lot,'driveway_arrow',[u-.48,v+direction*.22],[u,v+direction*.86]);segment(lot,'driveway_arrow',[u+.48,v+direction*.22],[u,v+direction*.86])}
 for(const lot of plan.lots){
  if(lot.layout==='parallel'){
   const points=lot.entryPaths[0];route(lot,'entry',1,points);
   // A short parallel bay has no forward turning apron. Reverse along the
   // validated manoeuvre, then resume forward in the original road direction.
   // Keep body yaw distinct from movement direction for future parking drivers.
   const exit=points.slice().reverse().map(p=>({...p}));
   if(!route(lot,'exit',1,exit,'reverse'))issues.push({lotId:lot.id,reason:'no_verified_parallel_exit'});
   continue;
  }
  let roadWidth=0;for(let v=.25;v<=40;v+=.25){const p=local(lot,0,-v);if(!roadAt(p.x,p.z))break;roadWidth=v}
  const first=routes.length;
  if(roadWidth>=6)for(const side of [1,-1]){
   const enterV=side===-1?-2.5:-roadWidth+2.5,exitV=side===1?-2.5:-roadWidth+2.5;
   driveway(lot,'entry',side,enterV);
   driveway(lot,'exit',side,exitV);
  }
  const own=routes.slice(first),hasEntry=own.some(r=>r.kind==='entry'),hasExit=own.some(r=>r.kind==='exit');
  if(!hasEntry||!hasExit){issues.push({lotId:lot.id,reason:'driveway_lane_access_incomplete',entry:hasEntry,exit:hasExit});continue}
  arrow(lot,-1.65,4.5,1);arrow(lot,1.65,5.2,-1);
  for(const v of [2.8,5,7.2])paint(lot,'driveway_center_dash',0,v,.1,1.1);
  for(const u of [2.75,2.2,1.65,1.1,.55])paint(lot,'driveway_yield_line',u,.8,.35,.22);
  segment(lot,'driveway_yield_triangle',[2.28,3.3],[1.65,1.95]);segment(lot,'driveway_yield_triangle',[1.65,1.95],[1.02,3.3]);segment(lot,'driveway_yield_triangle',[1.02,3.3],[2.28,3.3]);
 }
 return {version:1,drivingSide:'right',speedLimitKmh:10,routes,markings,issues,stats:{routes:routes.length,markings:markings.length,verifiedEntryLots:new Set(routes.filter(r=>r.kind==='entry').map(r=>r.lotId)).size,verifiedExitLots:new Set(routes.filter(r=>r.kind==='exit').map(r=>r.lotId)).size,issues:issues.length}};
}

// Remove directed source-only chains before offering a road anchor. A terminal
// arrival remains usable; an isolated departure cannot masquerade as an entry.
// Reachability from a specific actor still belongs to the directed router.
function parkingLaneAnchorIndex(trafficPlan){
 const connections=trafficPlan.connections||[],all=[...connections,...(trafficPlan.turns||[])],degree=new Map(),outgoing=new Map();
 for(const edge of all){if(!degree.has(edge.fromLaneId))degree.set(edge.fromLaneId,0);degree.set(edge.toLaneId,(degree.get(edge.toLaneId)||0)+1);if(!outgoing.has(edge.fromLaneId))outgoing.set(edge.fromLaneId,[]);outgoing.get(edge.fromLaneId).push(edge.toLaneId);}
 const removed=new Set(),queue=[...degree].filter(([,n])=>n===0).map(([id])=>id);for(let i=0;i<queue.length;i++){const id=queue[i];removed.add(id);for(const next of outgoing.get(id)||[]){degree.set(next,degree.get(next)-1);if(degree.get(next)===0)queue.push(next);}}
 const buckets=new Map();let count=0;
 for(const edge of connections){
  if(removed.has(edge.fromLaneId)||removed.has(edge.toLaneId)||!edge.points?.length)continue;
  let progress=0,lastSelected=-Infinity;
  for(let index=0;index<edge.points.length;index++){
   const point=edge.points[index];if(index)progress+=Math.hypot(point.x-edge.points[index-1].x,point.z-edge.points[index-1].z);
   if(index>0&&index<edge.points.length-1&&progress-lastSelected<.9)continue;
   if(![point.x,point.z,point.yaw].every(Number.isFinite))continue;lastSelected=progress;
   // A stored edge point preserves its canonical interpolated yaw exactly.
   const anchor={edgeId:edge.id,fromLaneId:edge.fromLaneId,toLaneId:edge.toLaneId,pointIndex:index,progressM:edge.cumulative?.[index]??progress,point:{x:point.x,z:point.z,yaw:point.yaw}},key=Math.floor(point.x/24)+','+Math.floor(point.z/24);
   if(!buckets.has(key))buckets.set(key,[]);buckets.get(key).push(anchor);count++;
  }
 }
 return {count,removedNodes:removed.size,near(point){const result=[];for(let x=Math.floor((point.x-30)/24);x<=Math.floor((point.x+30)/24);x++)for(let z=Math.floor((point.z-30)/24);z<=Math.floor((point.z+30)/24);z++)result.push(...(buckets.get(x+','+z)||[]));return result;}};
}

/** Add at most four entry alternatives per disconnected lot after the final
 * directed graph has been prepared. Existing routes, IDs and markings survive.
 * arrivalIsConnected(point,{lotId,routeId,side}) is the initial router's cached
 * synchronous arrival check; a lot with any connected entry needs no search.
 */
export function augmentCityParkingLaneEntries({plan,access=plan?.access,topology,instances=[],extraBodies=[],trafficPlan,arrivalIsConnected}={}){
 if(!access?.routes||!plan?.lots||!trafficPlan?.connections)return access;
 const raw=instances.map(i=>i.userData?.instance||i),world=createCarWorld(topology,[...raw.flatMap(i=>i.collision?.worldBodies||[]),...plan.colliders,...extraBodies],plan.metresPerCell),roadAt=(x,z)=>!!topology.roadMask[Math.floor(z/plan.metresPerCell)]?.[Math.floor(x/plan.metresPerCell)];
 const needs=plan.lots.filter(lot=>{const entries=access.routes.filter(r=>r.lotId===lot.id&&r.kind==='entry');return entries.length&&entries.filter(r=>r.laneAnchor).length<4&&!entries.some(r=>arrivalIsConnected?.(r.points[0],{lotId:lot.id,routeId:r.id,side:r.side})===true);});
 if(!needs.length)return access;
 const index=parkingLaneAnchorIndex(trafficPlan),additions=[],existingIds=new Set(access.routes.map(r=>r.id)),audit=[];
 for(const lot of needs){
  const targets=[];for(const route of access.routes.filter(r=>r.lotId===lot.id&&r.kind==='entry'&&!r.laneAnchor))for(const index of [...new Set([route.points.length-1,Math.floor((route.points.length-1)*2/3),Math.floor((route.points.length-1)/3),0])]){const point=route.points[index];if(!targets.some(t=>Math.hypot(t.point.x-point.x,t.point.z-point.z)<1e-6&&Math.abs(Math.sin(t.point.yaw-point.yaw))<1e-6))targets.push({point,route,index});}
  const support={surfaceRects:[lot.rect,lot.driveway],roadSupportRects:plan.roadSupportRects},fits=(x,z,yaw)=>carFits(x,z,yaw,world)&&cityParkingCarFits(support,x,z,yaw),candidates={1:[],'-1':[]},seen=new Set();
  for(const anchor of index.near(lot.origin)){
   const p=anchor.point,uv=lotCoordinates(lot,p),tangent=Math.sin(p.yaw)*lot.dz-Math.cos(p.yaw)*lot.dx,side=tangent>0?-1:1;
   if(uv.v>=0||uv.v< -30||Math.abs(uv.u)>26||Math.abs(tangent)<.7||!roadAt(p.x,p.z))continue;
   const key=[p.x,p.z,p.yaw].map(n=>n.toFixed(6)).join(':');if(seen.has(key))continue;seen.add(key);
   const goals=targets.filter(t=>{const target=lotCoordinates(lot,t.point);return (target.u-uv.u)*tangent>.1&&Math.hypot(t.point.x-p.x,t.point.z-p.z)<=30&&(lot.layout!=='parallel'||Math.cos(t.point.yaw-p.yaw)>.7);});if(!goals.length)continue;
   candidates[side].push({anchor,goals,distance:Math.min(...goals.map(t=>Math.hypot(t.point.x-p.x,t.point.z-p.z)))});
  }
  const row={lotId:lot.id,candidates:0,tested:0,added:0,directions:[]};
  for(const side of [1,-1]){
   const previous=access.routes.filter(r=>r.lotId===lot.id&&r.laneAnchor&&r.side===side),acceptedEdges=new Set(previous.map(r=>r.laneAnchor.edgeId)),pool=candidates[side].sort((a,b)=>a.distance-b.distance||a.anchor.edgeId.localeCompare(b.anchor.edgeId)||a.anchor.pointIndex-b.anchor.pointIndex);row.candidates+=pool.length;let accepted=previous.length;
   for(const candidate of pool.slice(0,16)){
    if(accepted>=2)break;if(acceptedEdges.has(candidate.anchor.edgeId))continue;row.tested++;
    for(const target of candidate.goals){
     const result=createLaneConnector({from:candidate.anchor.point,to:target.point,isRoad:()=>true,poseAllowed:fits,minRadius:4.3});if(!result)continue;
     const id=lot.id+':entry:lane:'+candidate.anchor.edgeId+':'+candidate.anchor.pointIndex;if(existingIds.has(id))break;
     // A C1 join into an already verified entry preserves its final parking
     // pose and reverse exit. It can use the existing parallel-bay S curve.
     const points=[...result.points,...target.route.points.slice(target.index+1)];
     additions.push({id,lotId:lot.id,kind:'entry',side,gear:'forward',speedLimitKmh:10,rule:lot.layout!=='parallel'&&side===1?'yield_to_oncoming_and_pedestrians':'yield_to_pedestrians',points,distance:length(points),minRadiusM:Math.min(result.minRadiusM,target.route.minRadiusM??Infinity),laneAnchor:candidate.anchor,entryJoin:{routeId:target.route.id,pointIndex:target.index}});existingIds.add(id);acceptedEdges.add(candidate.anchor.edgeId);accepted++;row.added++;row.directions.push(side);break;
    }
   }
  }
  audit.push(row);
 }
 if(!additions.length)return {...access,laneEntries:{added:0,anchorCount:index.count,removedSourceNodes:index.removedNodes,lots:audit}};
 const routes=[...access.routes,...additions];return {...access,routes,laneEntries:{added:additions.length,anchorCount:index.count,removedSourceNodes:index.removedNodes,lots:audit},stats:{...access.stats,routes:routes.length,verifiedEntryLots:new Set(routes.filter(r=>r.kind==='entry').map(r=>r.lotId)).size,verifiedExitLots:new Set(routes.filter(r=>r.kind==='exit').map(r=>r.lotId)).size,laneEntries:routes.filter(r=>r.laneAnchor).length}};
}
