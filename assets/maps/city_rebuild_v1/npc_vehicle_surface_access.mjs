const inside=(x,z,rect)=>rect&&x>=rect.minX&&x<=rect.maxX&&z>=rect.minZ&&z<=rect.maxZ;
const segmentDistance=(x,z,a,b)=>{
 const dx=b.x-a.x,dz=b.z-a.z,lengthSq=dx*dx+dz*dz;
 if(!lengthSq)return Math.hypot(x-a.x,z-a.z);
 const t=Math.max(0,Math.min(1,((x-a.x)*dx+(z-a.z)*dz)/lengthSq));
 return Math.hypot(x-a.x-dx*t,z-a.z-dz*t);
};
const onPath=(x,z,points,tolerance)=>Array.isArray(points)&&points.some((point,index)=>index?segmentDistance(x,z,points[index-1],point)<=tolerance:points.length===1&&Math.hypot(x-point.x,z-point.z)<=tolerance);

/** Semantic permission for non-road vehicle poses. Geometry and water remain
 * owned by npc_vehicle_navigation; this resolver only recognizes authored
 * parking, driveway and service-access identities.
 */
export function createNpcVehicleSurfaceAccess({getParkingPlan=()=>null,getRoadPlan=()=>null,verifyLaneSegment=()=>false,worldScale=4.1,routeToleranceM=1.35,laneToleranceM=.2}={}){
 let parkingRef=null,roadRef=null,lots=new Map(),bays=new Map(),routes=new Map();
 function refresh(){
  const parking=getParkingPlan(),road=getRoadPlan();
  if(parking===parkingRef&&road===roadRef)return;
  parkingRef=parking;roadRef=road;lots=new Map((parking?.lots||[]).map(lot=>[lot.id,lot]));bays=new Map((parking?.bays||[]).map(bay=>[bay.id,bay]));routes=new Map();
  for(const route of [...(parking?.access?.routes||[]),...(road?.serviceAccess?.routes||[])])if(route?.id)routes.set(route.id,route);
 }
 function query({x,z,request}={}){
  refresh();if(!Number.isFinite(x)||!Number.isFinite(z)||!request)return {allowed:false,reason:'vehicle_surface_forbidden'};
  const bay=request.parkingSlotId&&bays.get(request.parkingSlotId),lotIds=new Set([request.lotId,bay?.lotId,...(Array.isArray(request.accessLotIds)?request.accessLotIds:[])].filter(Boolean));
  for(const lotId of lotIds){const lot=lots.get(lotId);if(!lot)continue;
   if(inside(x,z,lot.rect))return {allowed:true,surfaceClass:'parking',lotId};
   if(inside(x,z,lot.driveway))return {allowed:true,surfaceClass:'driveway',lotId};
  }
  const ids=[request.accessRouteId,...(Array.isArray(request.accessRouteIds)?request.accessRouteIds:[])].filter(Boolean);
  for(const id of ids){
   const route=routes.get(id);if(!route||lotIds.size&&route.lotId&&!lotIds.has(route.lotId))continue;
   if(onPath(x,z,route.points,routeToleranceM))return {allowed:true,surfaceClass:route.kind?.startsWith('service_')?'service_access':'driveway',accessRouteId:id,lotId:route.lotId};
  }
  const segment=[request.from,request.to],laneProof=request.laneRouteToken&&segment.every(p=>Number.isFinite(p?.r)&&Number.isFinite(p?.c))&&segmentDistance(x,z,{x:segment[0].c*worldScale,z:segment[0].r*worldScale},{x:segment[1].c*worldScale,z:segment[1].r*worldScale})<=laneToleranceM&&verifyLaneSegment({routeJob:request.laneRouteToken,carId:request.carId,from:segment[0],to:segment[1],tolerance:laneToleranceM/worldScale});
  if(laneProof===true||laneProof?.allowed===true)return {allowed:true,surfaceClass:'lane',accessRouteId:request.laneRouteToken};
  return {allowed:false,reason:'vehicle_surface_forbidden'};
 }
 return {query,invalidate(){parkingRef=roadRef=null;lots.clear();bays.clear();routes.clear();}};
}
