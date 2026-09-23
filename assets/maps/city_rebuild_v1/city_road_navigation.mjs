import {createDirectedLaneRouter} from './city_directed_lane_router.mjs';
import {buildingRoadDestination} from './city_road_destinations.mjs';
import {createParkingOriginResolver,validateParkingVehicleProfile} from './city_parking_origin.mjs';
import {cityParkingCarFits} from './city_parking_plan.mjs';

const valid=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.z),distance=(a,b)=>Math.hypot(a.x-b.x,a.z-b.z),angle=(a,b)=>Math.atan2(Math.sin(b-a),Math.cos(b-a));
const pathLength=points=>points.slice(1).reduce((sum,p,i)=>sum+distance(p,points[i]),0);
const gearOf=gear=>gear==='reverse'||gear===-1?'reverse':'forward';
function pointAlong(points,metres){let remaining=Math.max(0,metres);for(let i=1;i<points.length;i++){const a=points[i-1],b=points[i],length=distance(a,b);if(length&&remaining<=length){const t=remaining/length;return {x:a.x+(b.x-a.x)*t,z:a.z+(b.z-a.z)*t}}remaining-=length;}const p=points.at(-1);return p?{x:p.x,z:p.z}:null;}
const inside=(p,r)=>r&&p.x>=r.minX&&p.x<=r.maxX&&p.z>=r.minZ&&p.z<=r.maxZ;
/** Shared source bridge and player map. This service never moves actors. */
export function createCityRoadNavigation({getRoadPlan,getParkingPlan,getInstances=()=>[],isRoad,poseAllowed,getVehicleProfile=()=>null,routeJobs=null,metresPerCell=4.1,createRouter=createDirectedLaneRouter}={}){
 let previousPlan=null,router=null,lots=[],buildings=[],parking=null,originResolver=null,queries=0,lastResult=null;
 function ensure(){const plan=getRoadPlan();if(!plan?.trafficPlan)return null;if(plan!==previousPlan){previousPlan=plan;parking=getParkingPlan();originResolver=createParkingOriginResolver({parking,isRoad,poseAllowed});lots=parking?.lots||[];buildings=getInstances().map(i=>i.userData?.instance||i).filter(i=>i.entry?.roadProbeRC||i.role==='district_detention'&&i.stopFootprint);router=createRouter({plan:plan.trafficPlan,isRoad,poseAllowed,preparedPlan:plan.preparedLaneGraph});}return router}
 function sweep(a,b,profile){if(!valid(a)||!valid(b))return false;const yawA=Number.isFinite(a.yaw)?a.yaw:Math.atan2(b.x-a.x,b.z-a.z),yawB=Number.isFinite(b.yaw)?b.yaw:yawA,n=Math.max(1,Math.ceil(distance(a,b)/.25),Math.ceil(Math.abs(angle(yawA,yawB))/.08));for(let i=0;i<=n;i++){const t=i/n;if(!poseAllowed(a.x+(b.x-a.x)*t,a.z+(b.z-a.z)*t,yawA+angle(yawA,yawB)*t,profile))return false}return true}
 function destination(target){
  const explicitBuilding=target.buildingId||buildings.some(b=>b.id===target.id);
  const lot=lots.find(l=>l.id===(target.lotId||target.id))||(!explicitBuilding&&lots.find(l=>inside(target,l.rect)));
  const building=buildings.find(b=>b.id===(target.buildingId||target.id))||buildings.find(b=>{const f=b.footprint;return f&&target.x>=f.minC*metresPerCell&&target.x<=f.maxC*metresPerCell&&target.z>=f.minR*metresPerCell&&target.z<=f.maxR*metresPerCell});
  const covered=building&&parking?.coverage?.find(c=>c.buildingId===building.id&&c.status==='served'),selected=lot||lots.find(l=>l.id===covered?.lotId);
  if(selected){
   const allowedLots=Array.isArray(target.lotIds)&&target.lotIds.length?new Set(target.lotIds):null;
   const alternatives=(lot?[{lotId:lot.id,distance:0}]:(parking.walkingAlternatives||[]).filter(r=>r.buildingId===building?.id).sort((a,b)=>a.distance-b.distance).slice(0,4)).filter(a=>!allowedLots||allowedLots.has(a.lotId));
   if(!alternatives.length&&!allowedLots)alternatives.push({lotId:selected.id,distance:covered?.walkingDistance||0});
   return {kind:'parking',buildingId:building?.id||selected.buildingId,candidates:alternatives.flatMap(a=>(parking?.access?.routes||[]).filter(r=>r.lotId===a.lotId&&r.kind==='entry').map(r=>({point:r.points[0],laneAnchor:r.laneAnchor,tail:r.points,accessRouteId:r.id,gear:r.gear,lotId:a.lotId,walkingDistance:a.distance})))};
  }
  if(building?.role==='district_detention'&&previousPlan.serviceAccess)return {kind:'service_stop',buildingId:building.id,candidates:previousPlan.serviceAccess.routes.filter(r=>r.buildingId===building.id).map(r=>({point:r.points[0],laneAnchor:r.laneAnchor,tail:r.points.map(p=>({...p,gear:p.gear<0?'reverse':'forward',speedLimitKmh:r.speedLimitKmh})),accessRouteId:r.id,serviceAccess:r}))};
  if(building)return buildingRoadDestination(building,{metresPerCell,isRoad});
  return {kind:'road_point',candidates:[{point:target,tail:[]}]};
 }
 function origins(from,profile,firstOnly=false){return originResolver.resolve({from,profile,firstOnly})}
 function changesOfGear(points){const changes=[];for(let i=1;i<points.length;i++){const a=points[i-1].gear||'forward',b=points[i].gear||'forward';if(a!==b)changes.push({pointIndex:i-1,from:a,to:b,requiresStop:true});}return changes}
 function routeWorld({from,to,maxDistance=8,vehicleProfile}={}){
  const service=ensure();queries++;if(!service)return {status:'pending',reason:'city_loading',points:[]};if(!valid(from)||!valid(to))return {status:'blocked',reason:'invalid_pose',points:[]};
  const profile=validateParkingVehicleProfile(vehicleProfile);if(!profile)return {status:'blocked',reason:'invalid_vehicle_profile',points:[]};
  const target=destination(to),starts=origins(from,profile);let best=null,failure={status:'blocked',reason:starts.length?'destination_has_no_verified_access':'parking_exit_unavailable',points:[]};
  const batches=new Map();
  function queryCandidate(start,end){
   if(typeof service.routeMany!=='function')return service.route({from:start.point,to:end.point,toAnchor:end.laneAnchor,maxDistance});
   let results=batches.get(start);if(!results){results=new Map();batches.set(start,results)}
   if(!results.has(end)){
    // Search together only the approaches currently under consideration. A
    // reachable nearby parking still avoids searching all alternative lots.
    const group=target.candidates.filter(c=>c.lotId===end.lotId);
    const routes=group.length>1?service.routeMany({from:start.point,targets:group.map(c=>({to:c.point,toAnchor:c.laneAnchor})),maxDistance}):[service.route({from:start.point,to:end.point,toAnchor:end.laneAnchor,maxDistance})];
    group.forEach((candidate,i)=>results.set(candidate,routes[i]));
   }
   return results.get(end);
  }
  for(const end of target.candidates){if(best&&end.lotId&&end.lotId!==best.destination.lotId)break;for(const start of starts){const result=queryCandidate(start,end);if(result.status!=='ready'){failure=result;continue}if(end.tail.some((p,i)=>!poseAllowed(p.x,p.z,p.yaw,profile)||i&&!sweep(end.tail[i-1],p,profile)))continue;
   const points=[...start.prefix,...result.points,...end.tail.slice(1)],distanceM=pathLength(points),prefixDistance=pathLength(start.prefix);
   const controls=(result.controls||[]).map(c=>{const requested=prefixDistance+(c.requestedDistanceM??c.distanceM);return {...c,requestedDistanceM:requested,distanceM:Math.max(0,requested),...(Number.isFinite(c.requestedDistanceM)?{startInsideApproach:requested<0}:{}),...(c.requestedDistanceM<0&&prefixDistance>0?{stopPoint:pointAlong(start.prefix,requested)}:{})}});
   for(const [id,path,base] of [[start.accessRouteId,start.prefix,0],[end.accessRouteId,end.tail,prefixDistance+pathLength(result.points)]]){
    if(!id||path.length<2)continue;
    for(const c of service.registerExternalPathControls?.({id,points:path})||[]){const requested=base+c.progressM;controls.push({...c,requestedDistanceM:requested,distanceM:Math.max(0,requested),stopPoint:pointAlong(points,requested),startInsideApproach:requested<0,accessRouteId:id});}
   }
   if(end.serviceAccess){const retained=end.serviceAccess.retainedTurnId;if(retained&&!controls.some(c=>c.turnId===retained)){failure={status:'blocked',reason:'missing_service_approach_control',points:[]};continue;}for(const control of controls)if(control.turnId===retained){control.appliesUntilM=distanceM;control.serviceAccessId=end.accessRouteId;}}
   controls.sort((a,b)=>a.distanceM-b.distanceM);
   const candidate={...result,points,gearChanges:changesOfGear(points),distanceM,distance:distanceM,controls,destination:{kind:target.kind,lotId:end.lotId,buildingId:target.buildingId,walkingDistance:end.walkingDistance||0},accessRouteIds:[start.accessRouteId,end.accessRouteId].filter(Boolean),accessLotIds:[start.lotId,end.lotId].filter(Boolean)};if(!best||distanceM<best.distanceM)best=candidate;
  }}
  lastResult=best||failure;return lastResult;
 }
 const native=p=>p&&({x:Number(p.c)*metresPerCell,z:Number(p.r)*metresPerCell,...(Number.isFinite(p.angle)?{yaw:Math.PI/2-p.angle}:{}),id:p.id,lotId:p.lotId,lotIds:p.lotIds,buildingId:p.buildingId});
 const source=p=>({r:p.z/metresPerCell,c:p.x/metresPerCell,angle:Math.PI/2-p.yaw,...(p.gear?{gear:gearOf(p.gear)}:{}),...(p.speedLimitKmh?{speedLimitKmh:p.speedLimitKmh}:{})});
 function query(request={}){
  if(request.mode==='lane-route-touch')return routeJobs?.touch(request.requestId)||{ready:false,status:'blocked',reason:'route_expired',points:[]};
  if(request.mode==='lane-route-cancel')return routeJobs?.cancel(request.requestId)||{ready:false,status:'blocked',reason:'route_cancelled',points:[]};
  if(request.mode==='lane-route'&&request.requestId!==undefined&&request.requestId!==null){
   const carId=request.carId??request.vehicleId,raw=request.vehicleProfile??(carId?getVehicleProfile(carId):undefined);
   const vehicleProfile=validateParkingVehicleProfile(raw);if(!vehicleProfile)return {ready:false,status:'blocked',reason:'invalid_vehicle_profile',points:[]};
   return routeJobs?.query({...request,vehicleProfile})||{ready:false,status:'blocked',reason:'async_routing_unavailable',points:[]};
  }
  if(!ensure())return {ready:false,status:'pending',reason:'city_loading',points:[]};
  if(request.mode==='parking-exit'){
   const from=native(request.from);if(!valid(from)||!Number.isFinite(from.yaw))return {ready:false,status:'blocked',reason:'invalid_pose',points:[]};
   const carId=request.carId??request.vehicleId;
   const raw=request.profile?{halfLength:Number(request.profile.halfLength)*metresPerCell,halfWidth:Number(request.profile.halfWidth)*metresPerCell}:carId?getVehicleProfile(carId):undefined;
   if(carId&&!request.profile&&!raw)return {ready:false,status:'pending',reason:'vehicle-profile-loading',points:[]};
   const profile=validateParkingVehicleProfile(raw);if(!profile)return {ready:false,status:'blocked',reason:'invalid_vehicle_profile',points:[]};
   const start=origins(from,profile,true).find(s=>s.accessRouteId&&s.prefix.length>1);
   return start?{ready:true,status:'ready',carId,accessRouteId:start.accessRouteId,points:start.prefix.map(source),gearChanges:changesOfGear(start.prefix),speedLimitKmh:start.speedLimitKmh||5,requiresLiveClearance:true}:{ready:false,status:'blocked',reason:'parking_exit_unavailable',points:[]};
  }
  if(request.mode==='parking-anchors')return {ready:true,status:'ready',slots:(parking?.bays||[]).map(b=>({id:b.id,lotId:b.lotId,r:b.z/metresPerCell,c:b.x/metresPerCell,angle:Math.PI/2-b.yaw,widthM:b.width,lengthM:b.length}))};
  if(request.mode==='parking-destination'){
   const target=destination(native(request.to));
   const lotIds=[...new Set((target.candidates||[]).map(candidate=>candidate.lotId).filter(Boolean))];
   return {ready:true,status:'ready',kind:target.kind,buildingId:target.buildingId,lotIds};
  }
  if(request.mode==='road-rules'){
   if(request.control?.routeJob){const control=routeJobs?.evaluateControl(request.control,request)||(!routeJobs?{allowed:false,reason:'route_expired'}:null);if(control)return {ready:true,status:'ready',control};}
   if(['pedestrian_crossing','road_end_turnaround','railway_crossing','one_way_narrow_passage'].includes(request.control?.kind)){
    const stop=request.control.stopPoint,control=router.evaluateControl({...request.control,stopPoint:stop&&{x:stop.c*metresPerCell,z:stop.r*metresPerCell}},{time:Number.isFinite(request.time)?request.time:performance.now()/1000,occupiedCrosswalkIds:request.occupiedCrosswalkIds||[],occupiedEdgeIds:request.occupiedEdgeIds||[],occupiedRailCrossingIds:request.occupiedRailCrossingIds||[]});
    return {ready:true,status:'ready',control:{...control,stopPoint:control.stopPoint?{r:control.stopPoint.z/metresPerCell,c:control.stopPoint.x/metresPerCell}:null}};
   }
   if(request.accessRouteId){const access=parking?.access?.routes?.find(r=>r.id===request.accessRouteId)||previousPlan.serviceAccess?.routes.find(r=>r.id===request.accessRouteId);return access?{ready:true,status:'ready',kind:access.kind==='service_entry'?'service_entry':'driveway',accessRouteId:access.id,lotId:access.lotId,rule:access.rule,gear:access.gear,speedLimitKmh:access.speedLimitKmh,decisionPoint:source(access.points[0]),requiresStopBeforeReverse:!!access.requiresStopBeforeReverse,retainedApproachId:access.retainedApproachId,retainedTurnId:access.retainedTurnId,retainedConflictTurnIds:access.retainedConflictTurnIds,requiresLiveClearance:true}:{ready:false,status:'blocked',reason:'unknown_driveway'};}
   const plan=previousPlan.trafficPlan,approach=router.controlIndex?.approachById.get(request.approachId);
   if(request.approachId&&!approach)return {ready:false,status:'blocked',reason:'unknown_approach'};
   const control=approach?router.evaluateControl({approachId:request.approachId,turnId:request.turnId},{time:Number.isFinite(request.time)?request.time:performance.now()/1000,occupiedTurnIds:request.occupiedTurnIds||[],occupiedCrosswalkIds:request.occupiedCrosswalkIds||[]}):null;
   return {ready:true,status:'ready',drivingSide:plan.drivingSide,speedLimitKmh:plan.speedLimitKmh,approach:approach?{id:approach.id,junctionId:approach.junctionId,rule:approach.rule,stopPoint:approach.stopPoint&&{r:approach.stopPoint.z/metresPerCell,c:approach.stopPoint.x/metresPerCell},signalId:approach.signalId,axis:approach.axis,offset:approach.offset}:null,control:control?{...control,stopPoint:control.stopPoint?{r:control.stopPoint.z/metresPerCell,c:control.stopPoint.x/metresPerCell}:null}:null};
  }
  const carId=request.carId??request.vehicleId,raw=request.vehicleProfile??(carId?getVehicleProfile(carId):undefined);
  const vehicleProfile=validateParkingVehicleProfile(raw);if(!vehicleProfile)return {ready:false,status:'blocked',reason:'invalid_vehicle_profile',points:[]};
  const result=routeWorld({from:native(request.from),to:native(request.to),maxDistance:request.maxSnapDistance??8,vehicleProfile}),snap=s=>s?{...s,point:source(s.point),...(s.connector?{connector:{...s.connector,points:s.connector.points.map(source)}}:{})}:null;return {...result,ready:result.status==='ready',points:(result.points||[]).map(source),snappedStart:snap(result.snappedStart),snappedEnd:snap(result.snappedEnd),controls:(result.controls||[]).map(c=>({...c,stopPoint:c.stopPoint?{r:c.stopPoint.z/metresPerCell,c:c.stopPoint.x/metresPerCell}:null}))};
 }
 return {query,route:routeWorld,prepare:ensure,verifyLaneSegment(request){return routeJobs?.evaluateSegment(request)||{allowed:false,reason:'route_expired'}},roadControlRecords(controls){ensure();return controls.flatMap(c=>{const canonical=router?.edgeControls?.byId.get(c.id);return canonical?[canonical]:[]})},invalidate(){previousPlan=null;router=null;originResolver?.clear();originResolver=null;lastResult=null;routeJobs?.invalidate()},diagnostics(){return {ready:!!router,queries,lastStatus:lastResult?.status,graph:router?.diagnostics,jobs:routeJobs?.diagnostics()}}};
}
