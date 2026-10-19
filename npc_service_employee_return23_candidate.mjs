// Isolated return executor. Public access and route planning remain source-owned.
import {advanceStationaryServiceActor} from './assets/maps/city_rebuild_v1/npc_stationary_service_adapter.mjs';
const yes=(fn,...args)=>{try{return fn?.(...args)===true;}catch{return false;}};
const point=p=>p&&Number.isFinite(p.r)&&Number.isFinite(p.c);
export function createServiceEmployeeReturn23({layout,host,metresPerCell=4.1}){
 if(!yes(host.validateLayout,layout)||!Number.isFinite(metresPerCell)||metresPerCell<=0)throw Error('Certified employee return host required');
 const states=new WeakMap(),rc=p=>({r:p.z/metresPerCell,c:p.x/metresPerCell});
 let disposed=false,lastActor=null,lastControl=null;
 const hold=reason=>({status:'hold',reason,movedMetres:0});
 const advance=function(input){
  const {actor,now,dt,generation,employeeId,controlled,returning}=input;
  if(disposed||!actor)return hold('no-source-employee');
  lastActor=actor;lastControl=input.hasControl;
  let state=states.get(actor);
  if(!controlled||!returning){if(state)state.interrupted=true;return null;}
  const allowed=()=>yes(host.isCurrentSite,layout)&&yes(input.hasControl)&&actor._stationaryService?.generation===generation&&actor._stationaryService?.employmentId===employeeId;
  if(!allowed()||!Number.isFinite(now)||!Number.isFinite(dt)||dt<=0||dt>1)return hold('return-owner-or-clock');
  if(state&&now<state.now)return hold('return-clock-reversed');
  if(!state||state.interrupted||state.generation!==generation){
   host.cancelRoute(actor);if(!allowed())return hold('return-owner-changed');
   state={generation,now,stage:'select',points:null,index:0,retryAt:0};states.set(actor,state);
  }
  state.now=now;
  const clear=(a,b)=>yes(host.canSweep,a,b,actor),here=()=>({r:actor.r,c:actor.c});
  if(state.stage==='select'){
   // Initial storeroom egress and a nearby interruption already on the shop floor.
   const outside=rc(layout.doorOutside),work=rc(layout.work);
   if(yes(host.isWorkFloor,here(),layout.work.y)&&clear(here(),outside)&&clear(outside,work)){
    state.stage='inside';state.points=[outside,work];
   }else{
    let door;try{door=host.entrance(layout);}catch{}
    if(!point(door)||!point(door.inside)||door.instanceId!==layout.buildingId)return hold('original-entrance-unavailable');
    state.door={...door,inside:{...door.inside}};state.stage='outside';
   }
  }
  if(state.stage==='outside'&&!state.points){
   if(now<state.retryAt)return hold('return-route-retry');
   const target={r:state.door.r,c:state.door.c};
   if(clear(here(),target))state.points=[target];
   else{
    let route;try{route=host.planRoute(actor,target);}catch{}
    if(!allowed())return hold('return-owner-changed');
    if(route?.status==='pending')return hold('return-route-pending');
    if(route?.status!=='ready'||!Array.isArray(route.points)||!route.points.length||route.points.length>1024||!route.points.every(point)){
     state.retryAt=now+1000;return hold('return-route-blocked');
    }
    // A partial native path is not arrival. Its final edge must reach this entrance.
    state.points=route.points.map(p=>({r:p.r,c:p.c}));state.points.push(target);
   }
   state.index=0;
  }
  if(state.stage==='door'){
   let access;try{access=host.openEntrance(actor,state.door);}catch{}
   if(!allowed())return hold('return-owner-changed');
   if(access?.ready!==true)return hold('return-public-door');
   const visit={phase:'entering',door:{...state.door,inside:{...state.door.inside}}};
   try{host.entryLane(actor,visit);}catch{return hold('return-entry-lane');}
   if(!allowed())return hold('return-owner-changed');
   const aligned={r:visit.door.r,c:visit.door.c},inside=visit.door.inside;
   const via=rc(layout.customerVia);via.r+=inside.r-state.door.inside.r;via.c+=inside.c-state.door.inside.c;
   const route=[aligned,inside,via,rc(layout.doorOutside),rc(layout.work)];
   if(!route.every(point)||!route.every((p,i)=>clear(i?route[i-1]:here(),p)))return hold('return-entry-obstructed');
   state.stage='inside';state.points=route;state.index=0;
  }
  const target=state.points?.[state.index];if(!point(target))return hold('return-waypoint-unavailable');
  let y;try{y=host.groundHeight(target);}catch{}
  if(!Number.isFinite(y))return hold('return-ground-unavailable');
  const result=advanceStationaryServiceActor({actor,target:{x:target.c*metresPerCell,y,z:target.r*metresPerCell},actorId:employeeId,generation,controlToken:layout.revision+':return',dt,metresPerCell,arrivalMetres:.005},
   {identity:n=>({id:n._stationaryService?.employmentId,generation:n._stationaryService?.generation}),hasControl:allowed,
    canSweep:clear,isStationFloor:p=>yes(host.hasGround,p,actor)});
  if(result.status==='arrived'){
   if(++state.index>=state.points.length){state.points=null;state.index=0;if(state.stage==='outside')state.stage='door';else states.delete(actor);}
  }else if(result.status==='blocked'&&state.stage==='outside'){
   state.points=null;state.index=0;state.retryAt=now+500;host.cancelRoute(actor);
  }
  return{...result,returnStage:state.stage};
 };
 advance.dispose=()=>{if(disposed)return;disposed=true;if(lastActor&&yes(lastControl)){try{host.cancelRoute(lastActor);}catch{}}if(lastActor)states.delete(lastActor);lastActor=null;lastControl=null;};
 return advance;
}
