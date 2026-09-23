// Source positions are tiles (r,c); angles are atan2(dr,dc). Geometry callbacks
// use metres and the native vehicle yaw. No source actor is moved by this service.
import {collisionPolygon} from './vehicle_collision_shape.mjs';
import {polygonVehicleContact} from './vehicle_contact.mjs';
const finite=p=>p&&[p.r,p.c,p.angle].every(Number.isFinite), delta=(a,b)=>Math.atan2(Math.sin(b-a),Math.cos(b-a));
const directions=Array.from({length:8},(_,i)=>({r:Math.round(Math.sin(i*Math.PI/4)),c:Math.round(Math.cos(i*Math.PI/4)),angle:i*Math.PI/4}));
export function createNpcVehicleNavigation({worldScale=4.1,ready=()=>true,poseAllowed,isRoad=()=>false,vehicleAccess=()=>false,waterAt=()=>null,groundHeight=()=>0,getVehicle=()=>null,getVehicles=()=>[],clock=()=>performance.now(),frameBudgetMs=3,maxExpanded=18000,inspectRoutes=false}={}){
 if(typeof poseAllowed!=='function')throw new TypeError('Native vehicle poseAllowed is required');
 const jobs=new Map(),targetJobs=new Map();let spent=0,vehicleRecords=null,frameEpoch=0,eligible=null,lastVehicleBlocker=null;const counts={sweeps:0,poses:0,blocked:0,routeExpanded:0,completed:0,failed:0};
 function shapeFor(request){
  const actor=getVehicle(request.carId),object=actor?.object,profile=actor?.profile||object?.userData?.vehicleProfile;
  const sx=Math.abs(object?.scale?.x??1),sz=Math.abs(object?.scale?.z??1);
  const halfWidth=Math.max(.25,profile?(profile.collisionHalfWidth??profile.halfWidth)*sx:(Number(request.halfWidth)||.34)*worldScale);
  const halfLength=Math.max(.5,profile?(profile.collisionHalfLength??profile.halfLength)*sz:(Number(request.halfLength)||.7)*worldScale);
  return {halfWidth,halfLength,collisionPadding:.08};
 }
 function pose(p,request,shape,dynamic=true,semantic=true){
  counts.poses++;const x=p.c*worldScale,z=p.r*worldScale,yaw=Math.PI/2-p.angle;
  if(semantic&&!isRoad(x,z)){
   if(request.roadsOnly!==false)return 'off-road';
   const identified=!!(request.accessRouteId||request.lotId||request.parkingSlotId||request.accessRouteIds?.length||request.accessLotIds?.length||request.laneRouteToken);let access=false;
   if(identified)try{access=vehicleAccess({x,z,r:p.r,c:p.c,yaw,shape,request});}catch{return 'vehicle_surface_forbidden';}
   if(access!==true&&access?.allowed!==true)return access?.reason||'vehicle_surface_forbidden';
  }
  if(!poseAllowed(x,z,yaw,shape))return 'solid-or-surface';
  const poly=collisionPolygon(x,z,yaw,shape),floor=groundHeight(x,z);
  for(const point of [[x,z],...poly]){const water=waterAt(...point),level=water?.level,depth=Number.isFinite(level)?level-groundHeight(...point):water?.depth||0;if(depth>.12)return 'water';}
  if(dynamic)for(const record of (vehicleRecords??=getVehicles())){
   const actor=record.actor||record.car||record,object=actor.object||record.object,id=record.id??object?.userData?.sourceVehicleId;
   if(id===request.carId||!object||object.visible===false)continue;
   const profile=actor.profile||object.userData?.vehicleProfile;if(!profile)continue;
   const width=(profile.collisionHalfWidth??profile.halfWidth)*Math.abs(object.scale?.x??1),length=(profile.collisionHalfLength??profile.halfLength)*Math.abs(object.scale?.z??1);
   if(!Number.isFinite(width+length)||Math.hypot(object.position.x-x,object.position.z-z)>Math.hypot(shape.halfWidth,shape.halfLength)+Math.hypot(width,length)+.1)continue;
   if(Math.abs(object.position.y-floor)>Math.max(2,profile.height||2))continue;
   if(polygonVehicleContact(poly,collisionPolygon(object.position.x,object.position.z,object.rotation.y,{halfWidth:width,halfLength:length}))){lastVehicleBlocker=String(id??'unknown-vehicle');return 'vehicle';}
  }
  return null;
 }
 function sweep(from,to,request,shape,dynamic=true,semantic=true){
  counts.sweeps++;lastVehicleBlocker=null;const turn=delta(from.angle,to.angle),distance=Math.hypot(to.r-from.r,to.c-from.c)*worldScale;
  // Limit each corner's movement to 15 cm, including rotation. No near/far LOD bypass.
  const steps=Math.max(1,Math.ceil((distance+Math.abs(turn)*Math.hypot(shape.halfLength,shape.halfWidth))/.15));
  if(steps>1500)return {clear:false,reason:'segment-too-long'};
  for(let i=0;i<=steps;i++){const t=i/steps,reason=pose({r:from.r+(to.r-from.r)*t,c:from.c+(to.c-from.c)*t,angle:from.angle+turn*t},request,shape,dynamic,semantic);if(reason){counts.blocked++;return {clear:false,reason,...(reason==='vehicle'&&lastVehicleBlocker?{blockerId:lastVehicleBlocker}:{})};}}
  return {clear:true,reason:'clear'};
 }
 function push(heap,node){let i=heap.length;heap.push(node);while(i){const p=(i-1)>>1;if(heap[p].f<=node.f)break;heap[i]=heap[p];i=p;}heap[i]=node;}
 function pop(heap){const top=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let child=i*2+1;if(child+1<heap.length&&heap[child+1].f<heap[child].f)child++;if(last.f<=heap[child].f)break;heap[i]=heap[child];i=child;}heap[i]=last;}return top;}
 function route(request,shape){
  const identities=[request.accessRouteId,request.lotId,request.parkingSlotId,request.laneRouteToken,...(Array.isArray(request.accessRouteIds)?request.accessRouteIds:[]),...(Array.isArray(request.accessLotIds)?request.accessLotIds:[])].filter(Boolean).sort().join(','),key=[request.carId,request.requestId,request.from.r,request.from.c,request.from.angle,request.to.r,request.to.c,request.to.angle,request.roadsOnly===false?'access':'road',identities].join('|'),stamp=[shape.halfWidth,shape.halfLength,request.to.angle,identities].join('|');
  let job=jobs.get(key);
  if(request.reset||job?.stamp!==stamp){jobs.delete(key);job=null;}
  if(!job){
   if(jobs.size>=64){
    // New ambient requests must not discard an active emergency route.
    const entries=[...jobs.entries()],victim=entries.find(([,j])=>j.status!=='pending')||entries.find(([,j])=>(j.lastRequested??j.createdFrame)<frameEpoch-30);
    if(!victim)return {status:'pending',points:null,reason:'route-capacity',expanded:0};
    jobs.delete(victim[0]);
   }
   job={stamp,request:{...request,from:{...request.from},to:{...request.to}},shape,heap:[],seen:new Map(),expanded:0,status:'pending',points:null,lastServed:-1,createdFrame:frameEpoch,startBlocked:inspectRoutes?pose(request.from,request,shape):undefined,endBlocked:inspectRoutes?pose(request.to,{...request,roadsOnly:false},shape):undefined};jobs.set(key,job);
   const h=Math.round(request.from.angle/(Math.PI/4)+8)%8,start={r:request.from.r,c:request.from.c,angle:request.from.angle,h,g:0,parent:null};start.f=Math.hypot(start.r-request.to.r,start.c-request.to.c);push(job.heap,start);
  }
  job.lastRequested=frameEpoch;jobs.delete(key);jobs.set(key,job);
  if(job.status!=='pending')return {status:job.status,points:job.points,reason:job.reason,expanded:job.expanded};
  if(eligible&&job.createdFrame!==frameEpoch&&!eligible.has(job))return {status:'pending',points:null,expanded:job.expanded};
  const started=clock(),budget=Math.max(0,Math.min(frameBudgetMs/4,frameBudgetMs-spent));let iterations=0;
  if(budget>0)job.lastServed=frameEpoch;
  while(job.heap.length&&iterations<96&&clock()-started<budget){
   const current=pop(job.heap);iterations++;job.expanded++;counts.routeExpanded++;
   const d=Math.hypot(current.r-job.request.to.r,current.c-job.request.to.c);
   if(d<.8&&sweep(current,job.request.to,{...job.request,roadsOnly:false},shape).clear){const points=[job.request.to];for(let p=current;p;p=p.parent)points.push({r:p.r,c:p.c,angle:p.angle});points.reverse();job.points=points;job.status='ready';counts.completed++;break;}
   if(job.expanded>=maxExpanded){job.status='blocked';job.reason='search-budget';break;}
   for(const dh of [0,-1,1]){
    const h=(current.h+dh+8)%8,v=directions[h],next={r:current.r+v.r*.5,c:current.c+v.c*.5,angle:v.angle,h,parent:current,g:current.g+Math.hypot(v.r,v.c)*.5+Math.abs(dh)*.12};
    const id=Math.round(next.r*2)+','+Math.round(next.c*2)+','+h;if((job.seen.get(id)??Infinity)<=next.g)continue;
    // Only the short departure/arrival apron may leave road. Both still need full geometry clearance.
    const nearStart=Math.hypot(next.r-job.request.from.r,next.c-job.request.from.c)<1.5;
    if(!sweep(current,next,{...job.request,roadsOnly:!nearStart},shape).clear)continue;
    job.seen.set(id,next.g);next.f=next.g+Math.hypot(next.r-job.request.to.r,next.c-job.request.to.c);push(job.heap,next);
   }
  }
  spent+=clock()-started;
  if(job.status==='pending'&&!job.heap.length){job.status='blocked';job.reason='no-native-road-route';}
  if(job.status==='blocked')counts.failed++;
  return {status:job.status,points:job.points,reason:job.reason,expanded:job.expanded};
 }
 function query(request={}){
  if(!ready())return null;
  if(request.mode==='road-targets'){
   if(!finite(request.from))return {status:'blocked',points:[]};
   const shape=shapeFor(request),min=Math.max(0,Number.isFinite(request.minDistance)?request.minDistance:3),max=Math.max(min,Math.min(60,Number.isFinite(request.maxDistance)?request.maxDistance:40));
   const key=[request.carId,request.from.r,request.from.c,request.from.angle,min,max,shape.halfWidth,shape.halfLength].join('|');let job=targetJobs.get(key);
   if(!job){if(targetJobs.size>64)targetJobs.delete(targetJobs.keys().next().value);job={i:0,points:[]};targetJobs.set(key,job);}
   const started=clock(),budget=Math.max(0,Math.min(frameBudgetMs/4,frameBudgetMs-spent));
   while(job.i<128&&job.points.length<12&&clock()-started<budget){
    const i=job.i++,angle=(i%16)*Math.PI/8,radius=min+(max-min)*Math.floor(i/16)/7,p={r:request.from.r+Math.sin(angle)*radius,c:request.from.c+Math.cos(angle)*radius,angle};
    if(isRoad(p.c*worldScale,p.r*worldScale)&&!pose(p,{...request,roadsOnly:true},shape))job.points.push(p);
   }
   spent+=clock()-started;return {status:job.points.length>=4||job.i>=128?'ready':'pending',points:job.points};
  }
  if(!finite(request.from)||!finite(request.to))return {clear:false,status:'blocked',reason:'invalid-pose'};
  const shape=shapeFor(request);
  if(request.mode==='route')return route(request,shape);
  return sweep(request.from,request.to,request,shape);
 }
 function queryPhysical(request={}){
  if(!ready())return null;
  if(!finite(request.from)||!finite(request.to))return {clear:false,status:'blocked',reason:'invalid-pose'};
  return sweep(request.from,request.to,request,shapeFor(request),true,false);
 }
 return {query,queryPhysical,beginFrame(){spent=0;vehicleRecords=null;frameEpoch++;eligible=new Set([...jobs.values()].filter(j=>j.status==='pending'&&j.lastRequested>=frameEpoch-2).sort((a,b)=>a.lastServed-b.lastServed).slice(0,4));},invalidate(){jobs.clear();targetJobs.clear();vehicleRecords=null;eligible=null;},diagnostics:()=>({...counts,jobs:jobs.size,routeCpuMs:spent,routes:[...jobs.values()].filter(j=>j.lastRequested>=frameEpoch-2).slice(0,4).map(j=>({carId:j.request.carId,from:j.request.from,to:j.request.to,status:j.status,reason:j.reason,startBlocked:j.startBlocked,endBlocked:j.endBlocked,shape:j.shape,expanded:j.expanded,frontier:j.heap.length}))})};
}
