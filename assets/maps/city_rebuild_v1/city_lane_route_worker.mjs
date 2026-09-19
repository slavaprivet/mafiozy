import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createCarWorld,carFits,CAR} from './car_drive.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
import {prepareDirectedLanePlan} from './city_directed_lane_router.mjs';

// The same immutable scene, predicates and navigation wrapper as the host.
// Only execution moves off the rendering thread; actors and live occupancy
// remain owned by source world and must still sweep each driven segment.
let navigation=null,generation=null,world=null,sceneSnapshot=null;
function routeClear(result,shape=CAR){
 const points=result.points||[],m=4.1;
 for(let i=0;i<points.length;i++){
  const b=points[i],a=points[Math.max(0,i-1)],yawA=Math.PI/2-a.angle,dyaw=Math.atan2(Math.sin(a.angle-b.angle),Math.cos(a.angle-b.angle));
  if(![a.r,a.c,a.angle,b.r,b.c,b.angle].every(Number.isFinite))return false;
  const steps=Math.max(1,Math.ceil((Math.hypot(b.r-a.r,b.c-a.c)*m+Math.abs(dyaw)*Math.hypot(shape.halfLength,shape.halfWidth))/.15));
  for(let j=0;j<=steps;j++){const t=j/steps;if(!carFits((a.c+(b.c-a.c)*t)*m,(a.r+(b.r-a.r)*t)*m,yawA+dyaw*t,world,shape))return false;}
 }
 return points.length>0;
}
self.onmessage=event=>{
 const message=event.data||{};
 try{
  if(message.type==='init'||message.type==='world'){
   const s=message.type==='world'&&sceneSnapshot?{...sceneSnapshot,bodies:message.bodies,rebuildPrepared:true}:message.snapshot,m=s?.metresPerCell??4.1;
   if(m!==4.1||!s?.topology?.roadMask||!s.roadPlan?.preparedLaneGraph||!Array.isArray(s.bodies))throw new TypeError('Lane worker requires the complete native static scene and prepared graph');
   navigation?.invalidate();generation=message.generation;sceneSnapshot=s;
   world=createCarWorld(s.topology,s.bodies,m);
   const isRoad=(x,z)=>!!s.topology.roadMask?.[Math.floor(z/m)]?.[Math.floor(x/m)]||isExistingTrafficBridge(s.topology,x,z,m),poseAllowed=(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape||CAR);
   const roadPlan=s.rebuildPrepared?{...s.roadPlan,preparedLaneGraph:prepareDirectedLanePlan({plan:s.roadPlan.trafficPlan,isRoad,poseAllowed})}:s.roadPlan;
   navigation=createCityRoadNavigation({getRoadPlan:()=>roadPlan,getParkingPlan:()=>s.parkingPlan,getInstances:()=>s.instances,isRoad,poseAllowed,metresPerCell:m});
   navigation.prepare();self.postMessage({type:'initialized',generation});return;
  }
  if(message.type!=='route'||message.generation!==generation)return;
  if(!navigation)throw new Error('Lane worker has not initialized');
  const start=performance.now();let result=navigation.query({...message.request,mode:'lane-route',requestId:undefined});
  if(result.status==='ready'&&!routeClear(result,message.request.vehicleProfile||CAR))result={ready:false,status:'blocked',reason:'route_static_clearance_changed',points:[]};
  const roadControls=navigation.roadControlRecords(result.controls||[]);
  self.postMessage({type:'result',generation,token:message.token,result,roadControls,workerMs:performance.now()-start});
 }catch(error){self.postMessage({type:'error',generation:message.generation,token:message.token,error:{name:error.name,message:error.message}});}
};
