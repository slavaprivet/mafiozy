import {createVehicleOccupantSight} from './npc_vehicle_occupant_sight.mjs';
import {createNpcNativePerception} from './npc_native_perception.mjs';

// Bound host for the first local-fleet slice. A source-car descriptor must be
// explicitly unavailable until its separate visualPivot stamp is implemented.
export function createNpcVehicleIncomingBridge({THREE,getTarget,getActors,obstacles,getVehicles,bodiesAt,groundHeight=()=>0,ready=()=>true,local=()=>false,now=()=>performance.now(),onImpact=()=>false}={}){
 const observers=new Map();let excluded=null,frame=0;
 const counters={sightCalls:0,prepareCalls:0,consumes:0,glass:0,body:0,occupant:0,miss:0,rejected:0};
 const environment=createNpcNativePerception({groundHeight,bodiesAt,ready,getVehicles:()=>getVehicles().filter(row=>(row.actor||row.car||row)!==excluded)});
 const sight=createVehicleOccupantSight({THREE,getTarget,getActors,obstacles,local,now,getObserver:id=>observers.get(id),environmentClear:({origin,target,excludeVehicle})=>{
  if(excluded!==excludeVehicle){excluded=excludeVehicle;environment.beginFrame();}
  const result=environment.query({fromR:origin.z/4.1,fromC:origin.x/4.1,toR:target.z/4.1,toC:target.x/4.1,eyeHeight:origin.y-groundHeight(origin.x,origin.z),targetHeight:target.y-groundHeight(target.x,target.z)});
  return result?.blocked===false;
 }});
 function resolve(request){
  const target=getTarget();if(!target)return null;
  if(request?.localAllowed!==true||!local())return {handled:true,ready:false,visible:false,reason:'local-authority'};
  if(target.unavailable||target.source)return {handled:true,ready:false,visible:false,reason:target.reason||'source-pose-stamp-unavailable'};
  const ref=request?.sourceRef,id=request?.sourceId;
  if(!ref||!id||id!=='city_cop:'+String(ref.id)||ref.alive===false||ref.dead||ref.hp<=0)return {handled:true,ready:false,visible:false,reason:'source-invalid'};
  observers.delete(id);observers.set(id,ref);while(observers.size>64)observers.delete(observers.keys().next().value);
  if(request.phase==='consume'){
   let result={handled:true,consumed:false,reason:'stale-proof'};
   const proof=request.proof;
   if(proof?.sourceId!==id||!Number.isFinite(request.damage)||request.damage<0)return result;
   sight.consume(proof,value=>{
    const point=value.hit?.point||value.end;
    if(value.kind==='vehicle_glass'||value.kind==='vehicle_body')onImpact({object:value.hit.object,hit:value.hit,point:value.hit.point,direction:value.direction,damage:request.damage,weaponId:'pistol',shotId:'city_cop:'+ref.id+':'+value.sequence});
    counters.consumes++;counters[value.kind==='vehicle_glass'?'glass':value.kind==='vehicle_body'?'body':value.kind]++;
    result={handled:true,consumed:true,kind:value.kind,origin:{x:value.origin.x,y:value.origin.y,z:value.origin.z},target:{x:point.x,y:point.y,z:point.z}};
   });return result;
  }
  const x=(request.phase==='prepare'?request.muzzleC:ref.x)*4.1,z=(request.phase==='prepare'?request.muzzleR:ref.y)*4.1;
  const query={sourceId:id,targetId:'player',toR:request.playerR,toC:request.playerC,origin:new THREE.Vector3(x,groundHeight(x,z)+(request.eyeHeight??1.45),z)};
  if(request.phase==='sight'){counters.sightCalls++;return {handled:true,...sight.inspect(query)};}
  if(request.phase==='prepare'){
   counters.prepareCalls++;query.aimOffset=new THREE.Vector3((request.targetC-request.playerC)*4.1,0,(request.targetR-request.playerR)*4.1);
   const proof=sight.prepareAttack(query);if(!proof.accepted)counters.rejected++;
   return {handled:true,ready:proof.accepted===true,proof:proof.accepted?proof:null,reason:proof.reason};
  }
  return {handled:true,ready:false,visible:false,reason:'unknown-phase'};
 }
 return {resolve,beginFrame(){environment.beginFrame();sight.beginFrame(++frame);},stats:()=>({...counters,...sight.stats()})};
}
