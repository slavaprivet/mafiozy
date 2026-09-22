// CIVILIAN_PARKING_TRIP_START
// Bounded source-owned trips. Existing NPC/car identity and driving tick stay authoritative.
let _civilianTrip=null,_civilianTripNextAt=0,_civilianTripPlanningBudget=1800,_civilianTripAdmissionAfter=null;
const _civilianTrips=new Map(),_civilianTripByNpc=new WeakMap(),_civilianTripPlanningQueue=new Map();
let _civilianTripLaneSerial=0,_civilianTripFarLaneFrame=null;
const CIVILIAN_TRIP_LIMIT=16;let _civilianTripWorkFrame=null,_civilianTripWorkCount=0,_civilianTripWorkDeadline=0,_civilianTripReportAt=0;
function _civilianTripForCar(car){return _civilianTrips.get(car)||(_civilianTrip?.car===car?_civilianTrip:null);}
function _civilianTripForNpc(n){return _civilianTripByNpc.get(n)||(_civilianTrip?.npc===n?_civilianTrip:null);}
function _civilianTripCount(){return _civilianTrips.size||(_civilianTrip?1:0);}
function _civilianTripRegister(t){if(!t?.car||!t.npc)return false;const carTrip=_civilianTripForCar(t.car),npcTrip=_civilianTripForNpc(t.npc);if(carTrip&&carTrip!==t||npcTrip&&npcTrip!==t||!carTrip&&_civilianTripCount()>=(_civilianTripNative()?CIVILIAN_TRIP_LIMIT:1))return false;_civilianTrips.set(t.car,t);_civilianTripByNpc.set(t.npc,t);_civilianTrip||=t;t.car._civilianTrip=true;t.npc._civilianTrip=true;return true;}
function _civilianTripUnregister(t){if(_civilianTrips.get(t.car)===t)_civilianTrips.delete(t.car);if(_civilianTripByNpc.get(t.npc)===t)_civilianTripByNpc.delete(t.npc);_civilianTripPlanningQueue.delete(t.car);if(_civilianTrip===t)_civilianTrip=_civilianTrips.values().next().value||null;}
function _civilianTripReservePlan(car,now){const frame=typeof prevT==='number'?prevT:Math.floor(now/16.667);if(frame!==_civilianTripWorkFrame){_civilianTripWorkFrame=frame;_civilianTripWorkCount=0;_civilianTripWorkDeadline=0;}for(const[c,at]of _civilianTripPlanningQueue)if(now-at>1000||!CARS.includes(c))_civilianTripPlanningQueue.delete(c);_civilianTripPlanningQueue.set(car,now);if(_civilianTripWorkCount>=2||_civilianTripWorkDeadline&&performance.now()>=_civilianTripWorkDeadline||_civilianTripPlanningQueue.keys().next().value!==car)return false;_civilianTripPlanningQueue.delete(car);_civilianTripWorkCount++;_civilianTripWorkDeadline||=performance.now()+4;return true;}
let _walkNpcVehicleAccessResolver=null;
function _civilianTripNative(){return typeof _walkRendererActive==='function'&&_walkRendererActive();}
// Native parked cars are admitted before their first presentation, never moved later.
const _nativeParkingAdmission={queue:[],slots:null,reservations:new Map(),exits:new Map(),cursor:0,refreshAt:0,reportAt:0,checked:0,admitted:0,rejected:0};
function _nativeParkingPrepare(car){
 if(!_civilianTripNative()||!car||car._nativeParkingPresented||car._nativeParkingPending)return car;
 car._nativeParkingPending=true;car.vr=car.vc=0;
 _nativeParkingAdmission.queue.push({car,index:0,retryAt:0});return car;
}
function _nativeParkingUnoccupied(car){return car&&car.parked&&!car._nativeParkingPresented&&!car._civilianTrip&&!car._ambientDriverNpcId&&!car._wrecked&&!car._towed&&!car._hijackPending&&!car._static&&!car.gang&&!car._convoy&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId))&&!(typeof _npcVehicleOccupants!=='undefined'&&_npcVehicleOccupants.has(car));}
function _nativeParkingBoxesOverlap(a,b){
 const dr=b.r-a.r,dc=b.c-a.c;
 for(const angle of [a.angle,a.angle+Math.PI/2,b.angle,b.angle+Math.PI/2]){
  const sr=Math.sin(angle),sc=Math.cos(angle),extent=p=>Math.abs(Math.cos(p.angle-angle))*p.halfLength+Math.abs(Math.sin(p.angle-angle))*p.halfWidth;
  if(Math.abs(dr*sr+dc*sc)>extent(a)+extent(b)+.035)return false;
 }return true;
}
function _nativeParkingAdmissionTick(now){
 const state=_nativeParkingAdmission;if(!_civilianTripNative()||!state.queue.length||typeof _walkTrafficNavigationResolver!=='function')return;
 if(!state.slots&&now>=state.refreshAt){state.refreshAt=now+1000;const result=_walkTrafficNavigationResolver({mode:'parking-anchors'});if(result?.ready&&result.slots?.length)state.slots=result.slots.filter(p=>p.id&&[p.r,p.c,p.angle,p.widthM,p.lengthM].every(Number.isFinite));}
 if(!state.slots?.length)return;
 for(const [id,car]of state.reservations){const trip=_civilianTripForCar(car),destinationId=trip?.plan?.goal?.slot?.id||car._civilianNativePlan?.parkingSlot?.id;if(id===destinationId&&trip)continue;const anchor=car._nativeParkingAnchor;if(!CARS.includes(car)||!car.parked||car._towed||!anchor||id!==anchor.id||Math.hypot(car.r-anchor.r,car.c-anchor.c)>.8)state.reservations.delete(id);}
 const deadline=performance.now()+2;let checks=0,iterations=0;
 while(state.queue.length&&checks<2&&iterations++<16&&performance.now()<deadline){
  const row=state.queue.shift(),car=row.car;
  if(!CARS.includes(car)){continue;}
  if(!_nativeParkingUnoccupied(car)){delete car._nativeParkingPending;continue;}
  if(now<row.retryAt){state.queue.push(row);continue;}
  if(!row.shape){const model=car.model||{};row.shape=_walkTrafficNavigationResolver({mode:'initial-vehicle-shape',vehicle:{...model,model:model.name||car.modelName||'sedan'}});if(!row.shape?.ready||!Number.isFinite(row.shape.halfLength+row.shape.halfWidth)){row.shape=null;row.retryAt=now+1000;state.queue.push(row);continue;}}
  const slot=state.slots[(row.index+state.cursor)%state.slots.length];row.index++;
  const shape=row.shape,pose={...slot,halfLength:shape.halfLength,halfWidth:shape.halfWidth};
  let occupied=state.reservations.has(slot.id)||shape.halfLength*8.2>slot.lengthM+.05||shape.halfWidth*8.2>slot.widthM+.05;
  if(!occupied)for(const other of CARS){if(other===car||other._towed||other._nativeParkingPending)continue;const otherShape=other._nativeParkingShape||{halfLength:.75,halfWidth:.35},p={r:other.r,c:other.c,angle:Number.isFinite(other.ang)?other.ang:Math.atan2(other.dirDy??0,other.dirDx??1),...otherShape};if(_nativeParkingBoxesOverlap(pose,p)){occupied=true;break;}}
  if(!occupied){
   const exitKey=slot.id+':'+shape.halfLength+':'+shape.halfWidth;let exit=state.exits.get(exitKey);
   if(!exit){checks++;const result=_walkTrafficNavigationResolver({mode:'parking-exit',carId:_threeVehicleEntityId(car),from:pose,profile:{halfLength:shape.halfLength,halfWidth:shape.halfWidth}});
    if(result?.status==='ready'&&result.ready!==false)exit={clear:true};else if(result?.status==='blocked')exit={clear:false};
    if(exit)state.exits.set(exitKey,exit);else {row.index--;row.retryAt=now+250;state.queue.push(row);continue;}
   }
   if(!exit.clear){if(row.index>=state.slots.length){row.index=0;row.retryAt=now+10000;}state.queue.push(row);continue;}
   if(checks>=2||performance.now()>=deadline){row.index--;state.queue.push(row);continue;}
   checks++;state.checked++;const result=_walkTrafficNavigationResolver({carId:_threeVehicleEntityId(car),from:pose,to:pose,halfLength:shape.halfLength,halfWidth:shape.halfWidth,roadsOnly:false});
   if(result?.clear===true){Object.assign(car,{r:slot.r,c:slot.c,ang:slot.angle,dirDy:Math.sin(slot.angle),dirDx:Math.cos(slot.angle),vr:0,vc:0,_nativeParkingAnchor:{id:slot.id,lotId:slot.lotId,r:slot.r,c:slot.c},_nativeParkingShape:{halfLength:shape.halfLength,halfWidth:shape.halfWidth}});delete car._nativeParkingPending;delete car._onParking;state.reservations.set(slot.id,car);state.admitted++;state.cursor=(state.slots.indexOf(slot)+7)%state.slots.length;continue;}state.rejected++;
  }
  if(row.index>=state.slots.length){row.index=0;row.retryAt=now+10000;}state.queue.push(row);
 }
 if(now>=state.reportAt){state.reportAt=now+1000;document.documentElement.dataset.nativeParkingAdmission=JSON.stringify({pending:state.queue.length,admitted:state.admitted,checks:state.checked,rejected:state.rejected,reserved:state.reservations.size,slots:state.slots.length});}
}

// Read-only proof for unloaded presentation: source identities remain authoritative.
function _npcLogicalVehicleRow(car,id=_threeVehicleEntityId(car),xy=false,modelOverride=null){
 const model=modelOverride||car.model||{};return {id,get viewerDistance(){return Math.hypot((xy?car.y:car.r)-player.r,(xy?car.x:car.c)-player.c)},get r(){return xy?car.y:car.r},get c(){return xy?car.x:car.c},get ang(){return Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy||0,car.dirDx||1)},helicopter:!!model.helicopter,model:car._nativeServiceVehicle?.kind==='firetruck'?'fire_engine':car._nativeServiceVehicle?.kind==='tow'?'tow_truck':model.name||car.modelName||'sedan',sport:!!model.sport,pickup:!!model.pickup,van:!!model.van,suv:!!model.suv,cabrio:!!model.cabrio,muscle:!!model.muscle,limo:!!model.limo,classic:!!model.classic,bus:typeof BUS!=='undefined'&&car===BUS,emergency:model.police?'police':model.emergency||'',halfLength:Math.max(.65,(Number(model.L)||1.8)*.5),halfWidth:Math.max(.3,(Number(model.W)||.88)*.5)};
}
function _getWalkNpcVehicleBinding(input={}){
 const id=String(input.carId||'');let trip=null;
 for(const t of _civilianTrips.values())if(t.carId===id){trip=t;break;}
 if(!trip&&typeof _ambientTrafficDrivers!=='undefined')for(const t of _ambientTrafficDrivers.values())if(t.carId===id){trip=t;break;}
 if(!trip)return null;const car=trip.car,n=trip.npc;
 if(!NPCS.includes(n)||input.npcId!==undefined&&String(_threeNpcEntityId(n))!==String(input.npcId))return null;
 const alive=!n.dead&&n.alive!==false&&(!Number.isFinite(n.hp)||n.hp>0)&&!n._medicalDowned&&!n._forcedCrawl&&!n._policeCuffed&&!(n._knockedUntil>performance.now()),owned=!!(car.driver_uid||car.owner_uid||car.ownerId||car.driverId||car._hijackPending||car._wrecked||car._towed),riding=!!n._civilianTripRiding||n._ambientTrafficPhase==='drive',access=alive&&!owned&&(riding||trip.phase==='exit'||trip.phase==='board');
 return {carId:id,npcId:String(_threeNpcEntityId(n)),phase:trip.phase,alive,riding,bound:!owned,access,ready:access&&riding&&trip.phase==='drive',vehicle:_npcLogicalVehicleRow(car,id),viewerDistance:Math.hypot(car.r-player.r,car.c-player.c),sourceFrame:typeof prevT==='number'?prevT:0};
}
function _getWalkNpcVehicleTraffic(){
 const rows=[];for(const car of CARS)if(car&&!car._nativeParkingPending&&!car._hidden&&!car._towed)rows.push(_npcLogicalVehicleRow(car));
 if(typeof questCars!=='undefined')for(const car of questCars.values()){if(car._towed)continue;const model=typeof resolveCarModel==='function'?resolveCarModel(car.model):car.model;rows.push(_npcLogicalVehicleRow(car,'quest_'+car.id,true,model));}
 if(typeof serviceVehicles!=='undefined')for(const car of serviceVehicles){if(car.state==='done'||car._towed)continue;rows.push({id:'service_'+car.id,get viewerDistance(){return Math.hypot(car.y-player.r,car.x-player.c)},get r(){return car.y},get c(){return car.x},get ang(){return car.ang||0},helicopter:/heli|aircraft|plane/i.test(car.kind||''),model:car.kind==='ambulance'?'city_ambulance':car.kind==='firetruck'?'fire_engine':car.kind==='police'?'police_interceptor':car.kind,halfLength:1.4,halfWidth:.6});}
 if(typeof BUS!=='undefined'&&BUS._nativeInitialReady){const row=_npcLogicalVehicleRow(BUS,'city_bus');row.model='city_bus';rows.push(row);}
 return {frame:typeof prevT==='number'?prevT:0,rows};
}

const _civilianTripHistory=[];let _civilianTripHistoryKey='',_civilianTripDebugAt=0,_civilianTripDebug=false;
function _civilianTripDebugEnabled(){const now=performance.now();if(now<_civilianTripDebugAt)return _civilianTripDebug;_civilianTripDebugAt=now+1000;let search='';try{search=typeof location!=='undefined'?location.search:'';if(typeof window!=='undefined'&&window.parent!==window)search+='&'+(window.parent?.location?.search||'');}catch{}return _civilianTripDebug=typeof window!=='undefined'&&window.__npcTripDiagnostics===true||/(?:npc(?:transport|combat)?qa|perfqa)=1(?:&|$)/.test(search);}
function _civilianTripSnapshot(t,now,phase=t.phase){const n=t.npc,car=t.car,job=car._civilianNativePlan,p={phase,npcId:n.id,carId:t.carId,doorId:t.plan?.goal?.door?.id||job?.doors?.[job.doorIndex]?.id||null,pedestrianPending:!!n._routeSearchPending,reason:job?.reason||null,waypoint:t.index,total:t.plan?.points?.length||0,npc:{r:n.r,c:n.c},car:{r:car.r,c:car.c,angle:car.ang}};if(_civilianTripDebugEnabled()){Object.assign(p,{atMs:now,phaseAgeMs:now-(t.since||now),door:t.door?{...t.door}:null,doorDistance:t.door?Math.hypot(n.r-t.door.r,n.c-t.door.c):null,approach:{status:t.approachStatus||null,retryAt:t.approachRetryAt||0,routeLength:n._route?.length||0,routeIndex:n._routeIndex||0,next:n._route?.[n._routeIndex||0]||null,routeKind:n._routeKind||null,pending:!!n._routeSearchPending},doorTrace:t.doorTrace||null,approachBlock:t.approachBlock||null,planning:job?{status:job.status,reason:job.reason,doorIndex:job.doorIndex,doors:job.doors?.length,attempt:job.attempt,laneRejected:job.laneRejected,from:job.from,target:job.target,requestId:job.requestId,nextAt:job.nextAt,trace:job.trace||null}:null,driving:{blockedAt:t.blockedAt||0,blockReason:car._civilianBlockReason||null,blockerId:car._civilianBlockerId||null,driverNotReady:!!car._civilianDriverNotReady,roadWaitReason:t.roadWaitReason||null,travelledM:t.travelledM||0,index:t.index}});}return p;}
function _civilianTripReport(t,now,phase=null){if(!t)return;const changed=t.reportPhase!==t.phase;if(!phase&&!changed&&now<(t.reportAt||0))return;t.reportAt=now+500;t.reportPhase=t.phase;const debug=_civilianTripDebugEnabled();if(!phase&&!changed&&now<_civilianTripReportAt)return;const p=_civilianTripSnapshot(t,now,phase||t.phase);if(t.journey)p.journey={...t.journey};if(t.physicalProgress)p.noProgressMs=Math.max(0,now-t.physicalProgress.at);if(t.recovery)p.recovery={...t.recovery};if(debug&&(phase||changed)){_civilianTripHistory.push({...p});if(_civilianTripHistory.length>8)_civilianTripHistory.shift();}if(!phase&&now<_civilianTripReportAt)return;_civilianTripReportAt=now+500;p.activeCount=_civilianTripCount();p.limit=_civilianTripNative()?CIVILIAN_TRIP_LIMIT:1;p.active=[..._civilianTrips.values()].map(q=>({npcId:q.npc.id,carId:q.carId,phase:q.phase,r:q.car.r,c:q.car.c,pending:!!q.npc._routeSearchPending,reason:q.car._civilianNativePlan?.reason||null,travelledM:q.travelledM||0,noProgressMs:q.physicalProgress?Math.max(0,now-q.physicalProgress.at):null,blockReason:q.car._civilianBlockReason||null,blockerId:q.car._civilianBlockerId||null,driverNotReady:!!q.car._civilianDriverNotReady,roadWaitReason:q.roadWaitReason||null,recovering:!!q.recovery}));if(debug)p.history=_civilianTripHistory.map(h=>({...h}));document.documentElement.dataset.civilianTrip=JSON.stringify(p);}

function _civilianTripPlanTrace(job,stage,result){if(_civilianTripDebugEnabled())job.trace={stage,status:result?.status||null,reason:result?.reason||null,expanded:result?.expanded??null,points:result?.points?.length||0,startBlocked:result?.startBlocked??null,endBlocked:result?.endBlocked??null};}
function _civilianTripTraceApproachBlock(t,dt,previousIndex){if(!_civilianTripDebugEnabled()||typeof _walkNpcNavigationResolver!=='function')return;const n=t.npc,target=n._route?.[n._routeIndex||0];if(!target)return;const d=Math.hypot(target.r-n.r,target.c-n.c),step=Math.min(_npcEffectiveSpeed(n)*dt,d),r=n.r+(target.r-n.r)/Math.max(.001,d)*step,c=n.c+(target.c-n.c)/Math.max(.001,d)*step;t.approachBlock={previousIndex,currentIndex:n._routeIndex||0,skippedCorner:previousIndex!==(n._routeIndex||0),target:{r:target.r,c:target.c},attempt:{r,c},probes:_civilianDoorBody.map(([dr,dc])=>{const p={r:r+dr,c:c+dc},ordinary=_walkNpcNavigationResolver(p),withoutOwn=_walkNpcNavigationResolver({...p,ignoreVehicleId:t.carId});return {...p,blocked:!!ordinary?.blocked,blockedIgnoringOwn:!!withoutOwn?.blocked,ownVehicle:!!ordinary?.blocked&&!withoutOwn?.blocked,depth:ordinary?.depth??null,surface:ordinary?.surface||null};})};}


function _civilianTripPass(n,r,c){return _civilianTripNative()?npcPassableForSnitch(r,c):npcWaypointOk(n,r,c);}
function _civilianTripApproachRoute(n,door){
 const pass=(r,c)=>_civilianTripPass(n,r,c);
 if(Math.hypot(n.r-door.r,n.c-door.c)<=1.5&&_npcPathPassable(n.r,n.c,door.r,door.c,pass)){if(typeof _cancelNpcDirectedSearch==='function')_cancelNpcDirectedSearch(n);n._routeSearchPending=false;n._npcDirectedSearch=null;return _setNpcRoute(n,[{r:door.r,c:door.c}],'civilian_car');}
 const ok=_planNpcRouteTo(n,door.r,door.c,pass,.8,1200,'civilian_car');
 if(n._routeSearchPending)return false;
 const end=ok?n._route?.at(-1):{r:n.r,c:n.c};if(!end||Math.hypot(end.r-door.r,end.c-door.c)>.9||!_npcPathPassable(end.r,end.c,door.r,door.c,pass))return false;
 return _setNpcRoute(n,[...(ok?n._route:[]),{r:door.r,c:door.c}],'civilian_car');
}
// Personal travel intent is sampled once per journey, never on every pending tick.
function _civilianJourneyHash(text){let h=2166136261;for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);return h>>>0;}
function _civilianTripDestinations(car,trip,preferredDoor,now){
 if(preferredDoor)return [preferredDoor];
 const doors=_residentBuildingDoors(),local=[],far=[],origin={r:car.r,c:car.c};let nearest=null,nearestDistance=Infinity;
 const ownerId=String(car._nativeParkingAnchor?.lotId||'').replace(/^parking:/,'');
 for(const d of doors){if(d.residentEligible===false||!Number.isFinite(d.r+d.c))continue;const distance=Math.hypot(d.r-car.r,d.c-car.c);if(d.instanceId===ownerId){nearest=d;nearestDistance=-1;}else if(distance<nearestDistance){nearest=d;nearestDistance=distance;}}
 const npc=trip?.npc,sequence=npc?(npc._civilianJourneyCount=(npc._civilianJourneyCount||0)+1):0,seed=_civilianJourneyHash(String(npc?_threeNpcEntityId(npc):car.id)+':'+sequence),originDistrict=nearest?.districtId||'';
 const wantFar=!!npc&&seed%5===0&&now>=(npc._civilianFarRetryAt||0)&&[..._civilianTrips.values()].filter(t=>t!==trip&&t.interdistrict).length<3;
 const insert=(list,row,limit)=>{let i=0;while(i<list.length&&list[i].rank<=row.rank)i++;if(i<limit){list.splice(i,0,row);if(list.length>limit)list.pop();}};
 for(const d of doors){if(d.residentEligible===false||!Number.isFinite(d.r+d.c)||(npc?._civilianTripAvoid?.[d.id]||0)>now)continue;const distance=Math.hypot(d.r-origin.r,d.c-origin.c);if(distance<=3)continue;
  if(distance<65)insert(local,{door:d,rank:distance},12);
  else if(wantFar&&distance>80&&originDistrict&&d.districtId&&d.districtId!==originDistrict)insert(far,{door:d,rank:_civilianJourneyHash(seed+':'+d.id)},3);
 }
 if(trip){trip.journey={sequence,origin,originDistrict,requestedRange:far.length?'interdistrict':'local',goalId:null};trip.interdistrict=far.length>0;}
 if(local.length>1){const pick=seed%Math.min(4,local.length);local.unshift(...local.splice(pick,1));}
 return [...far,...local.slice(0,12-far.length)].map(row=>row.door);
}
function _civilianTripParkingPoseFree(car,slot){
 const shape=car._nativeParkingShape||{halfLength:Math.max(.65,(Number(car.model?.L)||1.8)*.5),halfWidth:Math.max(.3,(Number(car.model?.W)||.88)*.5)};
 if(shape.halfLength*8.2>slot.lengthM+.05||shape.halfWidth*8.2>slot.widthM+.05)return false;
 const reserved=_nativeParkingAdmission.reservations.get(slot.id);if(reserved&&reserved!==car)return false;
 const pose={...slot,halfLength:shape.halfLength,halfWidth:shape.halfWidth};
 for(const other of CARS){if(other===car||other._towed||other._nativeParkingPending)continue;const otherShape=other._nativeParkingShape||{halfLength:Math.max(.65,(Number(other.model?.L)||1.8)*.5),halfWidth:Math.max(.3,(Number(other.model?.W)||.88)*.5)},otherPose={r:other.r,c:other.c,angle:Number.isFinite(other.ang)?other.ang:Math.atan2(other.dirDy??0,other.dirDx??1),...otherShape};if(_nativeParkingBoxesOverlap(pose,otherPose))return false;}
 return true;
}
function _civilianTripParkingPreflight(car,door,job,nav){
 const target={r:door.r,c:door.c,id:door.id,buildingId:door.instanceId||door.buildingId||door.sourceId};
 const destination=nav({mode:'parking-destination',to:target});_civilianTripPlanTrace(job,'parking-destination',destination);
 if(!destination||destination.status==='pending'||destination.ready===false&&destination.status!=='blocked')return null;
 const lotIds=destination.status==='ready'&&Array.isArray(destination.lotIds)?destination.lotIds:[];
 if(!lotIds.length)return {ready:false,reason:'destination-has-no-parking'};
 let slots=_nativeParkingAdmission.slots;if(!slots){const result=nav({mode:'parking-anchors'});if(result?.ready&&result.slots?.length)_nativeParkingAdmission.slots=slots=result.slots.filter(p=>p.id&&[p.r,p.c,p.angle,p.widthM,p.lengthM].every(Number.isFinite));}
 if(!slots)return null;
 const freeLots=lotIds.filter(lotId=>slots.some(slot=>slot.lotId===lotId&&_civilianTripParkingPoseFree(car,slot)));
 if(!freeLots.length)return {ready:false,reason:'no-free-reachable-parking-bay'};
 job.parkingDoorId=door.id;job.parkingLotIds=freeLots;return {ready:true,target:{...target,lotIds:freeLots}};
}
function _civilianTripParkingCurve(car,start,slot){
 const distance=Math.hypot(slot.r-start.r,slot.c-start.c);if(!distance)return [{...slot,gear:'forward',speedLimitKmh:5,parking:true}];
 const handle=Math.max(.22,Math.min(1.15,distance*.45)),p1={r:start.r+Math.sin(start.angle)*handle,c:start.c+Math.cos(start.angle)*handle},p2={r:slot.r-Math.sin(slot.angle)*handle,c:slot.c-Math.cos(slot.angle)*handle},steps=Math.max(5,Math.ceil(distance/.055)),points=[];
 for(let i=1;i<=steps;i++){const t=i/steps,u=1-t,r=u*u*u*start.r+3*u*u*t*p1.r+3*u*t*t*p2.r+t*t*t*slot.r,c=u*u*u*start.c+3*u*u*t*p1.c+3*u*t*t*p2.c+t*t*t*slot.c,dr=3*u*u*(p1.r-start.r)+6*u*t*(p2.r-p1.r)+3*t*t*(slot.r-p2.r),dc=3*u*u*(p1.c-start.c)+6*u*t*(p2.c-p1.c)+3*t*t*(slot.c-p2.c),angle=i===steps?slot.angle:Math.atan2(dr,dc);points.push({r,c,angle,gear:'forward',speedLimitKmh:5,parking:true});}
 let previous=start;for(const point of points){if(!_civilianTripSweep(car,previous,point,[],false))return null;previous=point;}return points;
}
function _civilianTripAttachParking(car,door,lane,job){
 const lotId=lane.destination?.lotId;if(!lotId||!lane.points?.length)return null;
 let slots=_nativeParkingAdmission.slots;if(!slots){const result=_walkTrafficNavigationResolver?.({mode:'parking-anchors'});if(result?.ready&&result.slots?.length)_nativeParkingAdmission.slots=slots=result.slots.filter(p=>p.id&&[p.r,p.c,p.angle,p.widthM,p.lengthM].every(Number.isFinite));}
 const start=lane.points.at(-1),candidates=(slots||[]).filter(slot=>slot.lotId===lotId&&_civilianTripParkingPoseFree(car,slot)).sort((a,b)=>Math.hypot(a.r-start.r,a.c-start.c)-Math.hypot(b.r-start.r,b.c-start.c)||String(a.id).localeCompare(String(b.id)));
 for(const slot of candidates){const tail=_civilianTripParkingCurve(car,start,slot);if(!tail)continue;if(job.parkingSlot&&job.parkingSlot.id!==slot.id&&_nativeParkingAdmission.reservations.get(job.parkingSlot.id)===car)_nativeParkingAdmission.reservations.delete(job.parkingSlot.id);job.parkingSlot=slot;_nativeParkingAdmission.reservations.set(slot.id,car);return {native:true,points:[...lane.points,...tail],parkingStartIndex:lane.points.length,goal:{door,lot:null,slot},lots:[],controls:lane.controls||[],destination:lane.destination};}
 return null;
}
function _civilianTripCancelLane(job){if(job?.laneRequestId&&typeof _walkTrafficNavigationResolver==='function')_walkTrafficNavigationResolver({mode:'lane-route-cancel',requestId:job.laneRequestId});if(job){job.laneRequestId=null;job.laneTo=null;}}
// Keep a used worker result and its canonical controls alive during long trips.
function _civilianTripMaintainLane(trip,now){
 const job=trip.car._civilianNativePlan;if(!job?.laneRequestId||job.status!=='ready'||trip.phase==='exit'||trip.phase==='parked')return true;
 if(!job.leaseExpired&&now>=(job.touchAt||0)){job.touchAt=now+5000;const result=_walkTrafficNavigationResolver?.({mode:'lane-route-touch',requestId:job.laneRequestId});if(result?.reason==='route_expired')job.leaseExpired=true;}
 if(job.leaseExpired&&(trip.phase==='drive'||trip.phase==='approach')){
  // Replanning may choose another bay. Release this plan's reservation before
  // discarding its identity; physical occupancy remains checked separately.
  const slot=job.parkingSlot||trip.plan?.goal?.slot;if(slot&&_nativeParkingAdmission.reservations.get(slot.id)===trip.car)_nativeParkingAdmission.reservations.delete(slot.id);
  trip.destinationDoor=trip.plan?.goal?.door||trip.destinationDoor;_civilianTripCancelLane(job);delete trip.car._civilianNativePlan;trip.phase='planning';trip.car.vr=trip.car.vc=0;trip.car.braking=true;return false;
 }
 return true;
}
// A pending request keeps its exact destination and origin until the shared
// native planner finishes. A busy frame is not a failed journey.
function _civilianTripNativePlan(car,preferredDoor=null){
 const nav=typeof _walkTrafficNavigationResolver==='function'?_walkTrafficNavigationResolver:null,now=performance.now();
 let job=car._civilianNativePlan;
 const trip=_civilianTripForCar(car);
 if(!job){const doors=_civilianTripDestinations(car,trip,preferredDoor,now);job=car._civilianNativePlan={status:'pending',doors,doorIndex:0,attempt:0,nextAt:0,laneRejected:false,createdAt:now,farDeadline:now+15000};}
 if(!nav||now<job.nextAt)return null;
 if(!_civilianTripReservePlan(car,now)){job.reason='shared-plan-budget';return null;}
 const door=job.doors[job.doorIndex];if(!door){job.status='blocked';job.reason='no-reachable-building';return null;}
 const journey=trip?.journey,far=!!journey?.originDistrict&&door.districtId&&door.districtId!==journey.originDistrict&&Math.hypot(door.r-journey.origin.r,door.c-journey.origin.c)>80;
 if(trip){trip.destinationDoor=door;trip.interdistrict=far;if(journey){journey.goalId=door.id;journey.destinationDistrict=door.districtId||'';journey.range=far?'interdistrict':'local';}}
 if(far&&now>job.farDeadline){_civilianTripCancelLane(job);job.doorIndex++;job.laneRejected=false;job.from=null;trip.npc._civilianFarRetryAt=now+120000;job.reason='distant-route-deferred';return null;}
 job.status='pending';job.nextAt=now+100;
 const from=job.from||(job.from={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)}),carId=_threeVehicleEntityId(car);
 if(!job.laneRejected){
  if(!job.laneRequestId){
   const parking=_civilianTripParkingPreflight(car,door,job,nav);if(!parking){job.reason='parking-data-pending';job.nextAt=now+250;return null;}if(!parking.ready){job.reason=parking.reason;job.doorIndex++;job.from=null;job.createdAt=now;job.nextAt=now+50;job.parkingDoorId=null;job.parkingLotIds=null;return null;}
   const frame=typeof prevT==='number'?prevT:Math.floor(now/16.667);if(far&&_civilianTripFarLaneFrame===frame){job.reason='distant-plan-budget';return null;}if(far)_civilianTripFarLaneFrame=frame;job.laneRequestId=carId+':civilian-lane:'+(++_civilianTripLaneSerial);job.laneTo=parking.target;
  }
  const lane=nav({mode:'lane-route',requestId:job.laneRequestId,carId,from,to:job.laneTo,maxSnapDistance:12});
  _civilianTripPlanTrace(job,'lane-route',lane);
  if(lane?.status==='blocked'&&['route_queue_full','route_worker_uninitialized','async_routing_unavailable'].includes(lane.reason)){job.reason=lane.reason;job.nextAt=now+500;if(now-job.createdAt<30000)return null;_civilianTripCancelLane(job);job.status='blocked';return null;}
  if(lane?.status==='blocked'&&['route_worker_error','route_worker_timeout','route_worker_invalid_result','route_jobs_disposed'].includes(lane.reason)){_civilianTripCancelLane(job);job.status='blocked';job.reason=lane.reason;return null;}
  if(lane?.status==='ready'&&lane.points?.length){const parked=_civilianTripAttachParking(car,door,lane,job);if(parked){job.status='ready';job.reason='ready-to-parking-bay';return parked;}job.reason=lane.destination?.lotId?'no-free-reachable-parking-bay':'destination-has-no-parking';_civilianTripCancelLane(job);job.doorIndex++;job.from=null;job.createdAt=now;job.nextAt=now+50;job.parkingDoorId=null;job.parkingLotIds=null;return null;}
  if(lane?.status!=='blocked'){job.reason=lane?.reason||'lane-route-pending';return null;}_civilianTripCancelLane(job);if(far){job.doorIndex++;job.from=null;job.reason='distant-access-blocked';trip.npc._civilianFarRetryAt=now+120000;return null;}job.laneRejected=true;
 }
 if(!job.target){
  const result=nav({mode:'road-targets',carId,from:{r:door.r,c:door.c,angle:from.angle},minDistance:0,maxDistance:7});
  _civilianTripPlanTrace(job,'road-targets',result);
  if(!result||result.status==='pending'){job.reason='destination-pending';return null;}
  const targets=(result.points||[]).filter(p=>Math.hypot(p.r-car.r,p.c-car.c)>2).sort((a,b)=>Math.hypot(a.r-door.r,a.c-door.c)-Math.hypot(b.r-door.r,b.c-door.c));
  job.target=targets[job.attempt];
  if(!job.target){job.doorIndex++;job.attempt=0;job.laneRejected=false;job.from=null;return null;}
  job.requestId=carId+':civilian:'+door.id+':'+job.attempt+':'+now;job.first=true;
 }
 const result=nav({mode:'route',carId,requestId:job.requestId,reset:job.first,from,to:job.target,roadsOnly:true});job.first=false;_civilianTripPlanTrace(job,'route',result);
 if(result?.status==='ready'&&result.points?.length){job.status='ready';job.reason='ready';return {native:true,points:result.points,goal:{door,lot:null},lots:[],controls:[]};}
 if(result?.status==='blocked'){job.target=null;job.attempt++;if(job.attempt>=4){job.doorIndex++;job.attempt=0;job.laneRejected=false;job.from=null;}}
 job.reason=result?.reason||'route-pending';return null;
}
const _civilianDoorBody=[[0,0],[-.18,-.18],[-.18,.18],[.18,-.18],[.18,.18]];
function _civilianTripAccess(car,phase='query',progress=0){
 const carId=_threeVehicleEntityId(car),trip=_civilianTripForCar(car)||(typeof _ambientTrafficDrivers!=='undefined'?_ambientTrafficDrivers.get(car):null),npcId=trip?.npc?_threeNpcEntityId(trip.npc):undefined;
 if(_walkNpcVehicleAccessResolver){const access=_walkNpcVehicleAccessResolver({carId,npcId,phase,progress});return access&&[access.outside?.r,access.outside?.c,access.seat?.r,access.seat?.c].every(Number.isFinite)?access:null;}
 const angle=Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx);
 return {outside:{r:car.r-Math.cos(angle)*.85,c:car.c+Math.sin(angle)*.85},seat:{r:car.r,c:car.c},seatId:'front_left'};
}
// Ignore only this vehicle inside its short authored door corridor. Water,
// terrain, buildings and every other vehicle still block all five body probes.
function _civilianTripDoorPath(trip,fromR,fromC,toR,toC){
 if(typeof _walkNpcNavigationResolver!=='function')return _npcPathPassable(fromR,fromC,toR,toC,(r,c)=>npcWaypointOk(trip.npc,r,c));
 const steps=Math.max(1,Math.ceil(Math.hypot(toR-fromR,toC-fromC)/.14));
 for(let i=1;i<=steps;i++)for(const [dr,dc]of _civilianDoorBody){
  const r=fromR+(toR-fromR)*i/steps+dr,c=fromC+(toC-fromC)*i/steps+dc,ri=Math.floor(r),ci=Math.floor(c),tile=MAP[ri]?.[ci];
  if(typeof _inPrisonIslandRestrictedZone==='function'&&_inPrisonIslandRestrictedZone(r,c,.35)||typeof inArena==='function'&&inArena(ri,ci)||typeof inLair==='function'&&inLair(ri,ci))return false;
  const sample=_walkNpcNavigationResolver({r,c,ignoreVehicleId:trip.carId});if(!sample||sample.blocked||sample.depth>.025){if(_civilianTripDebugEnabled())trip.doorTrace={r,c,from:{r:fromR,c:fromC},to:{r:toR,c:toC},blocked:!!sample?.blocked,depth:sample?.depth??null,reason:sample?.reason||(!sample?'not-ready':sample.depth>.025?'water':'solid'),surface:sample?.surface||null};return false;}
  if(sample.surface!=='land'&&sample.surface!=='road'&&![0,8,9,14].includes(tile))return false;
 }return true;
}
function _civilianTripDoorStep(trip,target,dt){
 const n=trip.npc,d=Math.hypot(target.r-n.r,target.c-n.c),step=Math.min(d,Math.max(0,Math.min(.1,Number(dt)||0))*.7);
 if(d<.001)return true;if(!step)return false;
 const r=n.r+(target.r-n.r)/d*step,c=n.c+(target.c-n.c)/d*step;
 if(!_civilianTripDoorPath(trip,n.r,n.c,r,c)){n.walking=false;return false;}
 n.r=r;n.c=c;n.walking=false;return d-step<.001;
}
function _civilianTripVehicleAvailable(car){return car&&CARS.includes(car)&&!car._nativeParkingPending&&car.parked&&(_civilianTripNative()||car._onParking)&&!car._ambientDriverNpcId&&!car._civilianTrip&&!car.gang&&!car._convoy&&!car._static&&!car._wrecked&&!car._towed&&!car._towDispatched&&!car._hijackPending&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId))&&!car.model?.police&&!car.model?.emergency;}
const NPC_AGENDA_DRIVE_CANDIDATES=8,NPC_AGENDA_DRIVE_RADIUS=12,NPC_AGENDA_DRIVE_RADIUS_SQ=NPC_AGENDA_DRIVE_RADIUS**2;
const _npcAgendaDriveCarGrid={until:0,carCount:-1,cells:new Map()};
let _npcAgendaDriveFrame=null,_npcAgendaDriveAttempts=0;
function _npcAgendaDriveReserveFrame(now){const frame=typeof prevT==='number'?prevT:Math.floor(now/16.667);if(frame!==_npcAgendaDriveFrame){_npcAgendaDriveFrame=frame;_npcAgendaDriveAttempts=0;}if(_npcAgendaDriveAttempts>=4)return false;_npcAgendaDriveAttempts++;return true;}
function _npcAgendaDriveNearbyCars(n,now,parkingCars){
 const grid=_npcAgendaDriveCarGrid,cellSize=NPC_AGENDA_DRIVE_RADIUS;
 if(now>=grid.until||grid.carCount!==CARS.length){
  grid.cells.clear();grid.carCount=CARS.length;grid.until=now+500;
  for(const car of CARS){if(!_civilianTripVehicleAvailable(car)||parkingCars.has(car))continue;const key=`${Math.floor(car.r/cellSize)},${Math.floor(car.c/cellSize)}`;(grid.cells.get(key)||grid.cells.set(key,[]).get(key)).push(car);}
 }
 const candidates=[],br=Math.floor(n.r/cellSize),bc=Math.floor(n.c/cellSize);
 for(let dr=-1;dr<=1;dr++)for(let dc=-1;dc<=1;dc++)for(const car of grid.cells.get(`${br+dr},${bc+dc}`)||[]){
  if(!_civilianTripVehicleAvailable(car)||parkingCars.has(car)||now<(car._civilianTripRetryAt||0))continue;const distance=(n.r-car.r)**2+(n.c-car.c)**2;if(!Number.isFinite(distance)||distance>=NPC_AGENDA_DRIVE_RADIUS_SQ)continue;
  const row={car,distance};let at=candidates.findIndex(q=>distance<q.distance);if(at<0)at=candidates.length;candidates.splice(at,0,row);if(candidates.length>NPC_AGENDA_DRIVE_CANDIDATES)candidates.pop();
 }
 return candidates;
}
// The agenda asks for a drive; this adapter owns the atomic source reservation.
// No plan, route or seat is cancelled until the existing trip registry accepts
// both this exact resident and this exact parked car.
function _npcAgendaTryDrive(n,now=performance.now()){
 if(!_civilianTripNative()||!n||_civilianTripCount()>=CIVILIAN_TRIP_LIMIT||_civilianTripForNpc(n)||typeof _npcAgendaWantsDrive==='function'&&!_npcAgendaWantsDrive(n,now)||!_npcAgendaDriveReserveFrame(now))return false;
 const parkingOwners=typeof _parkingNpcs!=='undefined'&&Array.isArray(_parkingNpcs)?_parkingNpcs:[],parkingCars=new Set(parkingOwners.map(p=>p.car)),candidates=_npcAgendaDriveNearbyCars(n,now,parkingCars);
 for(const {car}of candidates){
  const access=_civilianTripAccess(car),door=access?.outside;if(!door||!_npcBodyPassable(door.r,door.c,(r,c)=>_civilianTripPass(n,r,c)))continue;
  const trip={car,npc:n,carId:_threeVehicleEntityId(car),plan:null,door,access,phase:'planning',index:0,since:now,agenda:true};
  if(!_civilianTripRegister(trip))continue;
  if(typeof _civilianPlanCancel==='function')_civilianPlanCancel(n);_clearNpcRoute(n);
  n._civilianPlan={phase:'walk_to_car',cycle:n._civilianPlan?.cycle||0,since:now};
  _civilianTripNextAt=Math.min(_civilianTripNextAt,now+750);_civilianTripReport(trip,now,'agenda-reserved');return true;
 }
 return false;
}
function _civilianTripSurface(r,c,lots){
 if(_trafficRoadTile(r,c))return true;
 return lots.some(l=>r>=l.r0-2&&r<l.r1+3&&c>=l.c0-2&&c<l.c1+3)&&MAP[Math.floor(r)]?.[Math.floor(c)]===9;
}
function _civilianTripPoseClear(car,r,c,angle,lots,dynamic=true){
 const dr=Math.sin(angle),dc=Math.cos(angle),L=Math.min(1.08,Math.max(.58,(car.model?.L||1.8)*.43)),W=Math.min(.48,Math.max(.30,(car.model?.W||.88)*.38));
 for(const f of [-L,0,L])for(const side of [-W,0,W]){const rr=r+dr*f-dc*side,cc=c+dc*f+dr*side;if(!_civilianTripSurface(rr,cc,lots)||_trafficHardTileAt(rr,cc)||typeof _cityV3RailBlocksCar==='function'&&_cityV3RailBlocksCar(rr,cc))return false;
  if(dynamic&&typeof _walkNpcNavigationResolver==='function'){const sample=_walkNpcNavigationResolver({r:rr,c:cc,ignoreVehicleId:_threeVehicleEntityId(car)});if(!sample||sample.blocked||sample.depth>.025)return false;}
 }
 for(const other of CARS){if(other===car||other._towed||other._nativeParkingPending)continue;const rr=other.r-r,cc=other.c-c;if(Math.abs(rr*dr+cc*dc)<L+1.1&&Math.abs(-rr*dc+cc*dr)<W+.5)return false;}
 if(dynamic){for(const p of [player,...NPCS]){if(p===_civilianTripForCar(car)?.npc||p.dead||p._residentIndoors)continue;const rr=p.r-r,cc=p.c-c;if(Math.abs(rr*dr+cc*dc)<L+.22&&Math.abs(-rr*dc+cc*dr)<W+.22)return false;}}
 return true;
}
function _civilianTripSweep(car,a,b,lots,dynamic=true){
 if(_civilianTripNative()){
  const result=typeof _walkTrafficNavigationResolver==='function'?_walkTrafficNavigationResolver({carId:_threeVehicleEntityId(car),from:a,to:b,roadsOnly:false}):null;car._civilianBlockReason=result?.clear===true?'':result?.reason||'navigation-not-ready';car._civilianBlockerId=result?.clear===true?'':result?.blockerId||'';if(result?.clear!==true)return false;
  const length=Math.max(.75,Math.min(1.2,(car.model?.L||1.8)*.5)),width=Math.max(.4,Math.min(.65,(car.model?.W||.88)*.5)),steps=Math.max(1,Math.ceil(Math.hypot(b.r-a.r,b.c-a.c)/.1)),delta=Math.atan2(Math.sin(b.angle-a.angle),Math.cos(b.angle-a.angle));
  for(let personIndex=-1;dynamic&&personIndex<NPCS.length;personIndex++){const n=personIndex<0?player:NPCS[personIndex];if(n._npcInitialPlacementPending||n===_civilianTripForCar(car)?.npc||n.dead||n._residentIndoors||n._civilianTripRiding||n._ambientTrafficPhase==='drive'||n._inVehicle||n._transportBoarded)continue;if(Math.hypot(n.r-a.r,n.c-a.c)>length+width+Math.hypot(b.r-a.r,b.c-a.c)+.4)continue;
   for(let i=0;i<=steps;i++){const f=i/steps,angle=a.angle+delta*f,dr=n.r-a.r-(b.r-a.r)*f,dc=n.c-a.c-(b.c-a.c)*f;if(Math.abs(dr*Math.sin(angle)+dc*Math.cos(angle))<length+.18&&Math.abs(-dr*Math.cos(angle)+dc*Math.sin(angle))<width+.18){car._civilianBlockReason='pedestrian';car._civilianBlockerId=personIndex<0?'player':_threeNpcEntityId(n);return false;}}
  }return true;
 }
 const delta=Math.atan2(Math.sin(b.angle-a.angle),Math.cos(b.angle-a.angle)),steps=Math.max(1,Math.ceil(Math.hypot(b.r-a.r,b.c-a.c)/.08),Math.ceil(Math.abs(delta)/.08));
 for(let i=0;i<=steps;i++){const t=i/steps;if(!_civilianTripPoseClear(car,a.r+(b.r-a.r)*t,a.c+(b.c-a.c)*t,a.angle+delta*t,lots,dynamic))return false;}return true;
}
function _civilianTripDriveway(car,start,end,lots){
 const key=p=>`${Math.round(p.r*2)}:${Math.round(p.c*2)}:${Math.round(p.angle/(Math.PI/2))}`,open=[{...start,cost:0,score:0,parent:null}],seen=new Map();let examined=0;
 while(open.length&&examined++<1800&&_civilianTripPlanningBudget-->0){open.sort((a,b)=>a.score-b.score);const p=open.shift(),k=key(p);if(seen.has(k)&&seen.get(k)<=p.cost)continue;seen.set(k,p.cost);
  if(Math.hypot(p.r-end.r,p.c-end.c)<1.51&&_civilianTripSweep(car,p,end,lots,false)){const path=[end];for(let q=p;q.parent;q=q.parent)path.unshift({r:q.r,c:q.c,angle:q.angle});return path;}
  for(const [dr,dc]of [[1,0],[-1,0],[0,1],[0,-1],[1,1],[1,-1],[-1,1],[-1,-1]]){const q={r:p.r+dr*.5,c:p.c+dc*.5,angle:Math.atan2(dr,dc),cost:p.cost+Math.hypot(dr,dc)*.5+Math.abs(Math.atan2(Math.sin(Math.atan2(dr,dc)-p.angle),Math.cos(Math.atan2(dr,dc)-p.angle)))*.2,parent:p};if(Math.hypot(q.r-start.r,q.c-start.c)>15||!_civilianTripSweep(car,p,q,lots,false))continue;q.score=q.cost+Math.hypot(q.r-end.r,q.c-end.c);open.push(q);}
 }
 return null;
}
function _civilianTripPlan(car){
 if(_civilianTripNative())return _civilianTripNativePlan(car);
 _civilianTripPlanningBudget=1800;
 const home=car._onParking,doors=_residentBuildingDoors().filter(d=>d.residentEligible!==false),graph=_getTrafficRoadGraph();
 const goals=PARKING_LOTS.filter(l=>l!==home).flatMap(l=>(l.slots||[]).map(slot=>({lot:l,slot,door:doors.filter(d=>Math.hypot(d.r-slot.r,d.c-slot.c)<9).sort((a,b)=>Math.hypot(a.r-slot.r,a.c-slot.c)-Math.hypot(b.r-slot.r,b.c-slot.c))[0]}))).filter(x=>x.door&&!CARS.some(c=>c!==car&&!c._towed&&Math.hypot(c.r-x.slot.r,c.c-x.slot.c)<2.1)).slice(0,8);
 const starts=graph.nodes.filter(n=>Math.hypot(n.r-car.r,n.c-car.c)<15).sort((a,b)=>Math.hypot(a.r-car.r,a.c-car.c)-Math.hypot(b.r-car.r,b.c-car.c)).slice(0,3);
 for(const goal of goals){const ends=graph.nodes.filter(n=>Math.hypot(n.r-goal.slot.r,n.c-goal.slot.c)<15).slice(0,4);
  for(const start of starts)for(const end of ends){const nodes=_trafficFindNodePath(start,end);if(!nodes||nodes.length<2)continue;const road=[];
   for(let i=0;i<nodes.length-1;i++){const dr=Math.sign(nodes[i+1].r-nodes[i].r),dc=Math.sign(nodes[i+1].c-nodes[i].c),angle=Math.atan2(dr,dc);for(const node of [nodes[i],nodes[i+1]])road.push({..._trafficLanePoint(node,dr,dc),angle});}
   const lots=[home,goal.lot],first={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)},last={r:goal.slot.r,c:goal.slot.c,angle:Math.atan2(goal.slot.dirDy,goal.slot.dirDx)};
   if(!_civilianTripPoseClear(car,road[0].r,road[0].c,road[0].angle,lots,false)||!_civilianTripPoseClear(car,last.r,last.c,last.angle,lots,false))continue;
   const departure=_civilianTripDriveway(car,first,road[0],lots);if(!departure)continue;
   let safe=true;for(let i=1;i<road.length;i++)if(!_civilianTripSweep(car,road[i-1],road[i],lots,false)){safe=false;break;}if(!safe)continue;
   const arrival=_civilianTripDriveway(car,road.at(-1),last,lots);if(arrival)return {points:[...departure,...road.slice(1),...arrival],goal,lots};
  }
 }
 return null;
}
function _civilianTripRelease(trip,reason){
 trip.releaseReason=reason;
 _civilianTripReport(trip,performance.now(),reason);
 if(trip.npc._routeSearchKind==='civilian_car'&&typeof _cancelNpcDirectedSearch==='function')_cancelNpcDirectedSearch(trip.npc);
 if(typeof _npcVehicleOccupants!=='undefined'&&reason!=='driver-dead'&&reason!=='hijack-extraction')_npcVehicleOccupants.delete(trip.car);
 _civilianTripAccess(trip.car,'release',0);
 const {car,npc}=trip,slot=trip.plan?.goal?.slot||car._civilianNativePlan?.parkingSlot,slotAngle=Number.isFinite(slot?.angle)?slot.angle:slot&&Math.atan2(slot.dirDy??0,slot.dirDx??1),parkedInSlot=slot&&Math.hypot(car.r-slot.r,car.c-slot.c)<.08&&Math.abs(Math.atan2(Math.sin(car.ang-slotAngle),Math.cos(car.ang-slotAngle)))<.08;if(slot?.id){if(parkedInSlot){car._nativeParkingAnchor={id:slot.id,lotId:slot.lotId,r:slot.r,c:slot.c};_nativeParkingAdmission.reservations.set(slot.id,car);}else if(_nativeParkingAdmission.reservations.get(slot.id)===car)_nativeParkingAdmission.reservations.delete(slot.id);}if(!trip.lostOwnership){car.vr=car.vc=0;car.steer=0;car.braking=true;car.parked=true;}delete car._civilianTrip;delete npc._civilianTrip;delete npc._civilianTripRiding;
 const agendaOwned=trip.agenda===true||npc._npcAgenda?.current==='drive';
 _civilianTripCancelLane(car._civilianNativePlan);delete car._civilianNativePlan;car._civilianTripRetryAt=performance.now()+(trip.recovery?120000:30000);npc.walking=false;npc._civilianPlan=agendaOwned?null:{phase:'seek_shop',cycle:(npc._civilianPlan?.cycle||0)+1,retryAt:performance.now()+3000};_clearNpcRoute(npc);
 _civilianTripUnregister(trip);if(agendaOwned&&typeof _npcAgendaComplete==='function')_npcAgendaComplete(npc,'drive',reason);_civilianTripNextAt=Math.min(_civilianTripNextAt,performance.now()+750);
}
function _civilianTripExit(trip){
 const {npc,car}=trip,access=_civilianTripAccess(car);if(!access)return false;
 const {r,c}=access.outside;if(!_civilianTripDoorPath(trip,npc.r,npc.c,r,c))return false;
 // Reversing a half-finished entry must start from that exact folded pose.
 // Exit progress normally runs 0..1, so offset it by the unused part of the
 // boarding fold and preserve the first cancellation frame.
 const fold=trip.phase==='board'?Math.max(0,Math.min(1,+trip.progress||0)):1;
 trip.access=access;trip.exit={r,c};trip.phase='exit';trip.exitProgressStart=1-fold;trip.progress=trip.exitProgressStart;trip.doorLength=Math.hypot(r-npc.r,c-npc.c);npc._civilianTripRiding=false;return true;
}
// Replanning is not physical progress. A permanently blocked car must not
// reserve a driving slot forever, or repeatedly choose the same failed errand.
function _civilianTripWatchProgress(trip,now){
 const {car,npc}=trip;
 if(trip.recovery){car.vr=car.vc=0;car.braking=true;if(trip.phase!=='exit')_civilianTripExit(trip);return trip.phase==='exit';}
 const riding=!!npc._civilianTripRiding||trip.phase==='drive',r=riding?car.r:npc.r,c=riding?car.c:npc.c;
 let progress=trip.physicalProgress;
 if(!progress){progress=trip.physicalProgress={r,c,riding,at:Number.isFinite(trip.since)?Math.min(now,trip.since):now};}
 // Entering a new phase never renews the clock by itself. Boarding really moves
 // the resident, while a drive/replan loop at the same curb cannot renew it.
 if(progress.riding!==riding){progress.r=r;progress.c=c;progress.riding=riding;}
 else if(Math.hypot(r-progress.r,c-progress.c)>.01){progress.r=r;progress.c=c;progress.at=now;}
 const driveTarget=trip.phase==='drive'?trip.plan?.points?.[trip.index]:null,driveAngle=Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy||0,car.dirDx||1),settling=driveTarget&&Math.hypot(car.r-driveTarget.r,car.c-driveTarget.c)<.03&&Math.abs(Math.atan2(Math.sin(driveTarget.angle-driveAngle),Math.cos(driveTarget.angle-driveAngle)))<.03;
 if(trip.phase==='exit'||trip.phase==='parked'||trip.phase==='drive'&&!driveTarget||settling||now-progress.at<(riding?90000:60000))return true;
 const goal=trip.destinationDoor||trip.plan?.goal?.door||car._civilianNativePlan?.doors?.[car._civilianNativePlan?.doorIndex||0];
 if(goal?.id){const avoid=npc._civilianTripAvoid||(npc._civilianTripAvoid=Object.create(null));for(const id of Object.keys(avoid))if(avoid[id]<=now)delete avoid[id];if(Object.keys(avoid).length>=8)delete avoid[Object.keys(avoid)[0]];avoid[goal.id]=now+300000;}
 trip.recovery={reason:riding?'drive-no-progress':'trip-no-progress',since:now,goalId:goal?.id||null};trip.interrupted=true;car.vr=car.vc=0;car.braking=true;
 _civilianTripCancelLane(car._civilianNativePlan);
 if(riding||trip.phase==='board'){_civilianTripExit(trip);return trip.phase==='exit';}
 _civilianTripRelease(trip,trip.recovery.reason);return false;
}
function _civilianTripDriverDied(trip){
 const n=trip.npc;if(!n.dead&&n.alive!==false&&(!Number.isFinite(n.hp)||n.hp>0))return false;
 // Death owns the exact source anchor. Never turn a corpse into a living
 // passenger following the door-exit path, even during boarding transitions.
 if(n._civilianTripRiding&&typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(trip.car,n);
 _civilianTripRelease(trip,'driver-dead');n._civilianPlan=null;n.walking=false;return true;
}
function _civilianTripTickNpc(n,dt,now){
 const t=_civilianTripForNpc(n);if(!t)return false;const car=t.car;_civilianTripReport(t,now);
 if(_civilianTripDriverDied(t))return false;
 const lost=!CARS.includes(car)||car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId||(myDrivingCarId&&String(car.id)===String(myDrivingCarId));
 if(lost){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}
 if(_civilianPlanInterrupted(n,now)){car.vr=car.vc=0;if(!n._civilianTripRiding&&t.phase!=='exit'&&t.phase!=='board'){_civilianTripRelease(t,'threat-interrupted');return false;}t.interrupted=true;if(t.phase!=='exit')_civilianTripExit(t);}
 if(!_civilianTripWatchProgress(t,now)){n.walking=false;return !!_civilianTripForNpc(n);}
 if(!_civilianTripMaintainLane(t,now)){n.walking=false;return true;}
 if(t.phase==='planning'){
  const plan=_civilianTripNativePlan(car,t.destinationDoor);n.walking=false;
  if(plan){t.plan=plan;t.phase=n._civilianTripRiding?'drive':'approach';t.index=0;t.edge=null;t.travelledM=0;car.parked=!n._civilianTripRiding;}
  else if(car._civilianNativePlan?.status==='blocked'){if(n._civilianTripRiding){t.interrupted=true;_civilianTripExit(t);}else _civilianTripRelease(t,'no-reachable-building');}
 }else if(t.phase==='approach'){
  const finalDistance=Math.hypot(n.r-t.door.r,n.c-t.door.c),finalApproach=_civilianTripNative()&&finalDistance<=1.35&&_civilianTripDoorPath(t,n.r,n.c,t.door.r,t.door.c);let status;
  if(finalApproach){if(n._routeSearchPending&&typeof _cancelNpcDirectedSearch==='function')_cancelNpcDirectedSearch(n);_clearNpcRoute(n);status=_civilianTripDoorStep(t,t.door,dt)?'arrived':'final-door';t.approachStatus=status;}
  else{
   if(_civilianTripNative()&&!n._route?.length&&now>=(t.approachRetryAt||0)){const ready=_civilianTripApproachRoute(n,t.door);t.approachStatus=ready?'route-ready':n._routeSearchPending?'route-pending':'route-not-ready';if(!ready&&!n._routeSearchPending)t.approachRetryAt=now+1500;}
   if(n._routeSearchPending){n.walking=false;return true;}
   const pass=(r,c)=>_civilianTripPass(n,r,c),previousIndex=n._routeIndex||0;status=_npcAdvanceRoute(n,dt,_npcEffectiveSpeed(n),pass);t.approachStatus=status;if(status==='blocked')_civilianTripTraceApproachBlock(t,dt,previousIndex);
   if(status==='arrived'){const d=Math.hypot(n.r-t.door.r,n.c-t.door.c),step=Math.min(d,Math.min(.1,dt)*_npcEffectiveSpeed(n)),r=d?n.r+(t.door.r-n.r)/d*step:n.r,c=d?n.c+(t.door.c-n.c)/d*step:n.c;if(_npcPathPassable(n.r,n.c,r,c,pass)){n.r=r;n.c=c;n.walking=step>0;}}
  }
  if(Math.hypot(n.r-t.door.r,n.c-t.door.c)<.02){t.access=_civilianTripAccess(car);if(!t.access||!_civilianTripDoorPath(t,n.r,n.c,t.access.seat.r,t.access.seat.c)){_civilianTripRelease(t,'door-blocked');return true;}t.phase='board';t.progress=0;t.doorLength=Math.hypot(n.r-t.access.seat.r,n.c-t.access.seat.c);t.since=now;_clearNpcRoute(n);}else if(status==='blocked')_civilianTripRelease(t,'approach-blocked');
 }else if(t.phase==='board'){
  if(_civilianTripNative()&&!_civilianTripAccess(car,'board',t.progress)){n.walking=false;car.vr=car.vc=0;return true;}
  const target=t.access?.seat||{r:car.r,c:car.c},arrived=_civilianTripDoorStep(t,target,dt);t.progress=1-Math.min(1,Math.hypot(n.r-target.r,n.c-target.c)/(t.doorLength||.85));_civilianTripAccess(car,'board',t.progress);
  if(arrived&&now-t.since>500){n._civilianTripRiding=true;t.phase='drive';t.progress=1;car.parked=false;if(car._nativeParkingAnchor&&_nativeParkingAdmission.reservations.get(car._nativeParkingAnchor.id)===car)_nativeParkingAdmission.reservations.delete(car._nativeParkingAnchor.id);delete car._nativeParkingAnchor;_civilianTripAccess(car,'drive',1);if(typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(car,n);}
 }else if(t.phase==='drive'||t.phase==='parked'){const access=_civilianTripAccess(car);n.r=access?.seat.r??car.r;n.c=access?.seat.c??car.c;n.ang=car.ang;n.walking=false;if(t.phase==='parked')_civilianTripExit(t);
 }else if(t.phase==='exit'){
  const arrived=_civilianTripDoorStep(t,t.exit,dt),physical=1-Math.min(1,Math.hypot(n.r-t.exit.r,n.c-t.exit.c)/(t.doorLength||.85)),start=Math.max(0,Math.min(1,+t.exitProgressStart||0));t.progress=start+(1-start)*physical;_civilianTripAccess(car,'exit',t.progress);
  if(arrived){if(typeof _npcVehicleOccupants!=='undefined'&&_npcVehicleOccupants.get(car)?.npc===n)_npcVehicleOccupants.delete(car);const goal=t.plan?.goal?.door,interrupted=t.interrupted;_civilianTripRelease(t,interrupted?'interrupted-exited':'arrived');n.idleUntil=0;if(!interrupted&&goal){n._residentDoor=goal;n._civilianPlan={phase:'walk_to_shop',cycle:(n._civilianPlan?.cycle||0)+1,doorId:goal.id,tripDestination:true,since:now,retryAt:0};const routed=_civilianRouteTo(n,goal.r,goal.c,'building_entry');if(!routed&&!n._routeSearchPending)n._civilianPlan.retryAt=now+250;}else if(!interrupted&&typeof pickNpcWaypoint==='function'){n._civilianPlan=null;pickNpcWaypoint(n);}}
 }
 return true;
}
function _civilianTripTickCar(car,dt){
 const t=_civilianTripForCar(car);if(!t)return false;if(_civilianTripDriverDied(t))return true;if(car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}if(!_civilianTripWatchProgress(t,performance.now()))return true;if(!_civilianTripMaintainLane(t,performance.now()))return true;if(t.phase!=='drive'||t.interrupted){car.vr=car.vc=0;return true;}
 if(t.plan.native){const n=t.npc,ready=!n.dead&&n.alive!==false&&(!Number.isFinite(n.hp)||n.hp>0)&&!n._medicalDowned&&!n._forcedCrawl&&!(n._knockedUntil>performance.now())&&n._civilianTripRiding&&typeof _walkTrafficNavigationResolver==='function'&&_walkTrafficNavigationResolver({mode:'driver',carId:t.carId,npcId:_threeNpcEntityId(n)})?.ready===true;car._civilianDriverNotReady=!ready;if(!ready){car.vr=car.vc=0;car.braking=true;return true;}}
 const target=t.plan.points[t.index];if(!target){const slot=t.plan.goal?.slot,slotAngle=Number.isFinite(slot?.angle)?slot.angle:slot&&Math.atan2(slot.dirDy??0,slot.dirDx??1),aligned=!slot||Math.hypot(car.r-slot.r,car.c-slot.c)<.04&&Math.abs(Math.atan2(Math.sin(car.ang-slotAngle),Math.cos(car.ang-slotAngle)))<.04;if(!aligned){t.index=Math.max(0,t.plan.points.length-1);car.vr=car.vc=0;car.braking=true;return true;}car.parked=true;car.steer=0;if(slot?.id){car._nativeParkingAnchor={id:slot.id,lotId:slot.lotId,r:slot.r,c:slot.c};_nativeParkingAdmission.reservations.set(slot.id,car);}if(t.plan.goal.lot)car._onParking=t.plan.goal.lot;t.phase='parked';car.vr=car.vc=0;return true;}
 const gear=target.gear==='reverse'?'reverse':'forward',gearNow=performance.now();
 if(!t.motionGear)t.motionGear=gear;
 if(t.motionGear!==gear){if(t.nextGear!==gear){t.nextGear=gear;t.gearReadyAt=gearNow+350;t.gearStops=(t.gearStops||0)+1;}car.vr=car.vc=0;car.braking=true;if(gearNow<t.gearReadyAt)return true;t.motionGear=gear;t.nextGear=null;}
 const distance=Math.hypot(target.r-car.r,target.c-car.c),current={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)};
 if(t.edge?.index!==t.index)t.edge={index:t.index,angle:current.angle,length:distance};
 const delta=Math.atan2(Math.sin(target.angle-current.angle),Math.cos(target.angle-current.angle)),turn=Math.atan2(Math.sin(target.angle-t.edge.angle),Math.cos(target.angle-t.edge.angle));if(distance<.025&&Math.abs(delta)<.025){car.r=target.r;car.c=target.c;car.ang=target.angle;car.dirDy=Math.sin(target.angle);car.dirDx=Math.cos(target.angle);car.vr=car.vc=0;car.steer=0;t.index++;return true;}const parking=!!target.parking||Number.isFinite(t.plan.parkingStartIndex)&&t.index>=t.plan.parkingStartIndex,limit=t.plan.native?(parking?(target.gear==='reverse'?.34:.46):(target.gear==='reverse'?.55:1.35)):(_trafficRoadTile(car.r,car.c)?1.35:.55),curveSlow=Math.max(.38,1-Math.min(.62,Math.abs(delta)*.75)),desired=limit*curveSlow,accel=parking ? .75 : 1.15,brake=parking?1.35:1.8;t.driveSpeed=Number.isFinite(t.driveSpeed)?t.driveSpeed:0;t.driveSpeed+=Math.max(-brake*Math.min(.1,dt),Math.min(accel*Math.min(.1,dt),desired-t.driveSpeed));if(distance<Math.max(.08,t.driveSpeed*t.driveSpeed/(2*brake)))t.driveSpeed=Math.min(t.driveSpeed,Math.max(.12,Math.sqrt(Math.max(0,2*brake*distance))));const speed=Math.max(.08,Math.min(limit,t.driveSpeed)),step=Math.min(distance,speed*Math.min(.1,dt)),progress=t.edge.length?Math.min(1,(t.edge.length-distance+step)/t.edge.length):1,angle=t.edge.length?t.edge.angle+turn*progress:current.angle+Math.max(-dt,Math.min(dt,delta));car.steer=Math.max(-.58,Math.min(.58,delta*1.6))*(gear==='reverse'?-1:1);
 const next={r:distance?car.r+(target.r-car.r)/distance*step:car.r,c:distance?car.c+(target.c-car.c)/distance*step:car.c,angle};
 if(!t.plan.native&&typeof carCanGo==='function'&&_trafficRoadTile(car.r,car.c)&&_trafficRoadTile(car.r+Math.sin(angle)*1.5,car.c+Math.cos(angle)*1.5)&&_trafficCarFootprintClear(car,next.r,next.c)){car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;if(!carCanGo(car,Math.min(.1,dt))){car.braking=true;return true;}}
 if(t.plan.native&&!_civilianTripRoadPermission(t,current,next)){car.vr=car.vc=0;car.braking=true;return true;}
 if(!_civilianTripSweep(car,current,next,t.plan.lots,true)){car.vr=car.vc=0;car.braking=true;t.driveSpeed=Math.max(0,t.driveSpeed-brake*Math.min(.1,dt));const now=performance.now();if(t.plan.native){t.blockedAt=t.blockedAt||now;if(now-t.blockedAt>(['vehicle','pedestrian'].includes(car._civilianBlockReason)?12000:1500)){const slot=t.plan.goal?.slot;if(slot&&_nativeParkingAdmission.reservations.get(slot.id)===car)_nativeParkingAdmission.reservations.delete(slot.id);t.destinationDoor=t.plan.goal.door;delete car._civilianNativePlan;t.phase='planning';t.blockedAt=0;}}return true;}t.blockedAt=0;
 car.r=next.r;car.c=next.c;car.ang=angle;car.dirDy=Math.sin(angle);car.dirDx=Math.cos(angle);car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;car.braking=false;t.travelledM=(t.travelledM||0)+Math.hypot(next.r-current.r,next.c-current.c)*4.1;if(distance<.025&&Math.abs(delta)<.025)t.index++;
 _civilianTripReport(t,performance.now());return true;
}
function _civilianTripRoadPermission(t,from,to){
 // Route controls are indexed by travelled distance, not nearest-junction guesses.
 const moved=t.travelledM||0,nextDistance=moved+Math.hypot(to.r-from.r,to.c-from.c)*4.1;
 if(t._roadControlPlan!==t.plan||moved<(t._roadControlMoved||0)){t._roadControlPlan=t.plan;t._roadControls=(t.plan.controls||[]).filter(c=>Number.isFinite(c.distanceM)).slice().sort((a,b)=>a.distanceM-b.distanceM);t._roadControlIndex=0;}t._roadControlMoved=moved;
 const controls=t._roadControls;while(t._roadControlIndex<controls.length&&controls[t._roadControlIndex].distanceM<moved-.2)t._roadControlIndex++;
 for(let i=t._roadControlIndex;i<controls.length;i++){const control=controls[i];if(control.distanceM>nextDistance+3)break;
  const point=control.stopPoint,occupied=point&&[player,...NPCS].some(n=>n!==t.npc&&!n.dead&&!n._civilianTripRiding&&!n._ambientTrafficDriver&&!n._residentIndoors&&Math.hypot(n.r-point.r,n.c-point.c)<1.8),others=point&&CARS.some(c=>c!==t.car&&!c._towed&&!c._nativeParkingPending&&Math.hypot(c.r-point.r,c.c-point.c)<2.2);
  const answer=_walkTrafficNavigationResolver({mode:'road-rules',control,approachId:control.approachId,turnId:control.turnId,time:performance.now()/1000,occupiedCrosswalkIds:occupied?(control.crosswalkIds||[]):[],occupiedTurnIds:others?(control.conflicts||control.yieldTo||[]):[],occupiedEdgeIds:others&&control.edgeId?[control.edgeId]:[]});
  if(answer?.control?.allowed!==true&&control.distanceM<=nextDistance+1.2){t.roadWaitReason=answer?.control?.reason||'road-control-wait';return false;}
 }
 t.roadWaitReason=null;return true;
}
function _civilianTripAdoptAmbient(source,now){
 if(!_civilianTripNative()||_civilianTripCount()>=CIVILIAN_TRIP_LIMIT||_civilianTripForNpc(source.npc)||_civilianTripForCar(source.car)||!CARS.includes(source.car)||source.phase!=='drive'||source.npc.dead||now<(source.visitRetryAt||0))return false;
 const {car,npc}=source;if(car.gang||car._convoy||car.model?.police||car.model?.emergency)return false;
 const access=_civilianTripAccess(car);if(!access)return false;
 _ambientTrafficRelease(source,'planning-building-visit');
 const trip={car,npc,carId:_threeVehicleEntityId(car),door:access.outside,access,phase:'planning',plan:null,index:0,since:now,agenda:source.agenda===true};
 _civilianTripRegister(trip);car.parked=false;npc._civilianTrip=true;npc._civilianTripRiding=true;npc._civilianPlan={phase:'drive_to_shop',cycle:npc._civilianPlan?.cycle||0,since:now};return true;
}
function _civilianTripSchedule(now){
 if(_civilianTripCount()>=(_civilianTripNative()?CIVILIAN_TRIP_LIMIT:1)||now<_civilianTripNextAt)return;_civilianTripNextAt=now+12000;
 const native=_civilianTripNative(),cars=CARS.filter(_civilianTripVehicleAvailable).filter(car=>!_parkingNpcs.some(p=>p.car===car)&&now>=(car._civilianTripRetryAt||0)).sort((a,b)=>Math.hypot(a.r-player.r,a.c-player.c)-Math.hypot(b.r-player.r,b.c-player.c));
 // Keep the two-car work bound, but rotate admission. Two unavailable cars
 // nearest the player must not starve every other resident's journey.
 const start=native&&cars.length?(cars.findIndex(car=>_threeVehicleEntityId(car)===_civilianTripAdmissionAfter)+1)%cars.length:0;
 const candidates=native?Array.from({length:Math.min(2,cars.length)},(_,i)=>cars[(start+i)%cars.length]):cars.slice(0,2),admission=[];
 if(native)_civilianTripNextAt=now+(cars.length?750:12000);
 for(const car of candidates){
  if(native)_civilianTripAdmissionAfter=_threeVehicleEntityId(car);
  let npc=null,nearest=144;
  for(const n of NPCS){const distance=(n.r-car.r)**2+(n.c-car.c)**2;if(distance>=nearest||!Number.isFinite(distance))continue;if(!_civilianPlanEligible(n)||_civilianPlanInterrupted(n,now)||n._residentIndoors||n._civilianTrip||native&&(typeof _npcAgendaWantsDrive==='function'?!_npcAgendaWantsDrive(n,now):n._civilianPlan?.tripDestination))continue;npc=n;nearest=distance;}
  if(!npc){admission.push({carId:_threeVehicleEntityId(car),reason:'no-available-resident'});continue;}
  const access=_civilianTripAccess(car),door=access?.outside;
  if(!door){admission.push({carId:_threeVehicleEntityId(car),reason:'vehicle-model-pending'});continue;}
  if(!(native?_npcBodyPassable(door.r,door.c,(r,c)=>_civilianTripPass(npc,r,c)):npcWaypointOk(npc,door.r,door.c))){admission.push({carId:_threeVehicleEntityId(car),reason:'door-approach-blocked'});continue;}
  if(native){const trip={car,npc,carId:_threeVehicleEntityId(car),plan:null,door,access,phase:'planning',index:0,since:now,agenda:typeof _npcAgendaWantsDrive==='function'};if(!_civilianTripRegister(trip)){admission.push({carId:trip.carId,reason:'reservation-race'});continue;}if(typeof _civilianPlanCancel==='function')_civilianPlanCancel(npc);_clearNpcRoute(npc);npc._civilianPlan={phase:'walk_to_car',cycle:npc._civilianPlan?.cycle||0,since:now};return;}
  const plan=_civilianTripPlan(car);if(!plan)continue;if(typeof _civilianPlanCancel==='function')_civilianPlanCancel(npc);if(!_civilianRouteTo(npc,door.r,door.c,'civilian_car'))continue;
  const trip={car,npc,carId:_threeVehicleEntityId(car),plan,door,phase:'approach',index:0,since:now};document.documentElement.dataset.civilianTrip=JSON.stringify({phase:'approach',npcId:npc.id,carId:trip.carId,total:plan.points.length});_civilianTripRegister(trip);npc._civilianPlan={phase:'walk_to_car',cycle:npc._civilianPlan?.cycle||0,since:now};return;
 }
 document.documentElement.dataset.civilianTrip=JSON.stringify({phase:native?'waiting-admission':'waiting-safe-route',eligibleCars:cars.length,activeCount:_civilianTripCount(),limit:native?CIVILIAN_TRIP_LIMIT:1,admission,nextAttemptMs:_civilianTripNextAt,...(_civilianTripDebugEnabled()?{history:_civilianTripHistory}:{} )});
}
// CIVILIAN_PARKING_TRIP_END
