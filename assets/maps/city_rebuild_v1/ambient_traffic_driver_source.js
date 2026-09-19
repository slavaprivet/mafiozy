// AMBIENT_TRAFFIC_DRIVER_START
const _ambientTrafficDrivers=new Map(),_ambientTrafficDriverByNpc=new WeakMap();let _ambientTrafficAssignAt=0,_ambientTrafficReportAt=0;
const AMBIENT_TRAFFIC_ASSIGN_INTERVAL_MS=350,AMBIENT_TRAFFIC_ASSIGN_BUDGET=2;
const _ambientServiceProxies=new WeakMap();
function _ambientTrafficServiceKind(v){return !!v&&(v.kind==='firetruck'||v.kind==='tow')&&typeof _walkRendererActive==='function'&&_walkRendererActive()&&!v.driver_uid&&!v.owner_uid;}
function _ambientTrafficServiceProxy(v){let car=_ambientServiceProxies.get(v);if(car)return car;car={_nativeServiceVehicle:v,model:{},get r(){return v.y},set r(x){v.y=x},get c(){return v.x},set c(x){v.x=x},get ang(){return v.ang||0},set ang(x){v.ang=x},get _wrecked(){return v._wrecked||v.wrecked},get _towed(){return v._towed},get _hijackPending(){return v._hijackPending}};_ambientServiceProxies.set(v,car);return car;}
function _ambientTrafficCarExists(car){return CARS.includes(car)||(typeof BUS!=='undefined'&&car===BUS)||!!(car._nativeServiceVehicle&&typeof serviceVehicles!=='undefined'&&serviceVehicles.includes(car._nativeServiceVehicle)&&car._nativeServiceVehicle.state!=='done');}
function _ambientTrafficRequiresDriver(car){return typeof _walkRendererActive==='function'&&_walkRendererActive()&&!!car&&!car.parked&&!car._static&&!car._civilianTrip&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId));}
function _ambientTrafficOrdinary(car){return !!car&&!car.gang&&!car._convoy&&!car._static&&!car.model?.police&&!car.model?.emergency&&!car._civilianTrip&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId));}
function _ambientTrafficNative(car){return typeof _walkRendererActive==='function'&&_walkRendererActive()&&_ambientTrafficOrdinary(car);}
function _ambientTrafficStop(car,reason){car.vr=car.vc=0;car.braking=true;car._nativeTrafficStopReason=reason;}
function _ambientTrafficRelease(t,reason){
 if(t.phase==='drive'&&typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(t.car,t.npc);
 _civilianTripAccess(t.car,'release');_ambientTrafficStop(t.car,reason);_ambientTrafficDrivers.delete(t.car);_ambientTrafficDriverByNpc.delete(t.npc);
 delete t.car._ambientDriverNpcId;delete t.npc._ambientTrafficDriver;delete t.npc._ambientTrafficRole;delete t.npc._ambientTrafficCarId;delete t.npc._ambientTrafficPhase;delete t.npc._ambientTrafficProgress;
 _clearNpcRoute(t.npc);t.npc.walking=false;if(t.npc.dead)t.car._ambientDriverDied=true;
 if(t.agenda===true&&reason!=='planning-building-visit'&&typeof _npcAgendaComplete==='function')_npcAgendaComplete(t.npc,'drive',reason);
}
function _ambientTrafficAssign(now){
 for(const [car,t]of _ambientTrafficDrivers)if(!_ambientTrafficCarExists(car)||!NPCS.includes(t.npc)||t.npc.dead||car._wrecked||car._towed||!_ambientTrafficOrdinary(car))_ambientTrafficRelease(t,t.npc.dead?'driver-dead':'driver-unavailable');
 if(now<_ambientTrafficAssignAt)return;_ambientTrafficAssignAt=now+AMBIENT_TRAFFIC_ASSIGN_INTERVAL_MS;
 const serviceCars=typeof serviceVehicles!=='undefined'?serviceVehicles.filter(v=>_ambientTrafficServiceKind(v)&&v.state!=='done').map(_ambientTrafficServiceProxy):[];
 let assigned=0;
 for(const car of [...serviceCars,...(typeof BUS!=='undefined'?[BUS,...CARS]:CARS)]){
  if(typeof BUS!=='undefined'&&car===BUS&&typeof _nativeBusInitialAdmit==='function'&&!_nativeBusInitialAdmit())continue;
  if(!_ambientTrafficNative(car)||car.parked||car._ambientDriverDied||car._wrecked||car._towed||car._hijackPending||_ambientTrafficDrivers.has(car))continue;
  const access=_civilianTripAccess(car);if(!access)continue;
  // Only a nearby resident takes this car. Long approaches were filling the
  // shared pedestrian queue with dozens of drivers before anybody boarded.
  let npc=null,distance=6;for(const n of NPCS){const agenda=n._npcAgenda;if(n._ambientTrafficDriver||n._npcInitialPlacementPending||n._civilianTrip||n._residentIndoors||n._civilianSeat||!_civilianPlanEligible(n)||_civilianPlanInterrupted(n,now)||agenda&&(agenda.current!=='drive'||typeof _npcAgendaWantsDrive==='function'&&!_npcAgendaWantsDrive(n,now)))continue;const d=Math.hypot(n.r-access.outside.r,n.c-access.outside.c);if(d<distance){distance=d;npc=n;}}
  if(!npc)continue;
  const t={npc,car,carId:_threeVehicleEntityId(car),access,door:{...access.outside},phase:'approach',progress:0,retryAt:0,createdAt:now,agenda:npc._npcAgenda?.current==='drive'};
  _ambientTrafficDrivers.set(car,t);_ambientTrafficDriverByNpc.set(npc,t);car._cruiseSpeed=car._cruiseSpeed||Math.max(1.35,Math.hypot(car.vr||0,car.vc||0));car._ambientDriverNpcId=npc.id;npc._ambientTrafficDriver=true;npc._ambientTrafficCarId=t.carId;npc._ambientTrafficPhase='approach';if(typeof BUS!=='undefined'&&car===BUS)npc._ambientTrafficRole='bus_driver';if(car._nativeServiceVehicle)npc._ambientTrafficRole=car._nativeServiceVehicle.kind==='firetruck'?'firefighter':'tow_operator';_clearNpcRoute(npc);_ambientTrafficStop(car,'boarding-driver');if(++assigned>=AMBIENT_TRAFFIC_ASSIGN_BUDGET)break;
 }
 if(now>=_ambientTrafficReportAt){_ambientTrafficReportAt=now+1000;const phases={approach:0,board:0,drive:0};for(const t of _ambientTrafficDrivers.values())phases[t.phase]=(phases[t.phase]||0)+1;document.documentElement.dataset.ambientTrafficDrivers=JSON.stringify({total:_ambientTrafficDrivers.size,phases,assignedThisPass:assigned});}
}
function _ambientTrafficDriverTickNpc(n,dt,now){
 if(!n._ambientTrafficDriver)return false;
 const t=_ambientTrafficDriverByNpc.get(n);if(!t){delete n._ambientTrafficDriver;return false;}
 const car=t.car;if(n.dead||n._medicalDowned||n._policeCuffed||!_ambientTrafficCarExists(car)||car._wrecked||car._towed||!_ambientTrafficOrdinary(car)){_ambientTrafficRelease(t,n.dead?'driver-dead':'driver-unavailable');return false;}
 const access=_civilianTripAccess(car);if(!access){n.walking=false;_ambientTrafficStop(car,'vehicle-not-ready');return true;}
 if(t.phase==='approach'){
  if(_civilianPlanInterrupted(n,now)){_ambientTrafficRelease(t,'approach-interrupted');return false;}
  if(!n._route?.length&&now>=t.retryAt){const planned=_planNpcRouteTo(n,t.door.r,t.door.c,npcPassableForSnitch,.08,1200,'traffic_driver');if(!planned&&!n._routeSearchPending)t.retryAt=now+1500;}
  const status=_npcAdvanceRoute(n,Math.min(.1,Math.max(0,dt)),_npcEffectiveSpeed(n),npcPassableForSnitch),d=Math.hypot(n.r-t.door.r,n.c-t.door.c);
  if(status==='arrived'&&d>.01){const step=Math.min(d,.1,dt*_npcEffectiveSpeed(n)),r=n.r+(t.door.r-n.r)/d*step,c=n.c+(t.door.c-n.c)/d*step;if(_npcPathPassable(n.r,n.c,r,c,npcPassableForSnitch)){n.r=r;n.c=c;n.walking=true;}}
  if(Math.hypot(n.r-t.door.r,n.c-t.door.c)<.02&&_civilianTripDoorPath(t,n.r,n.c,access.seat.r,access.seat.c)){t.phase='board';t.doorLength=Math.hypot(n.r-access.seat.r,n.c-access.seat.c);_clearNpcRoute(n);}
  if(now-t.createdAt>60000&&t.phase==='approach'){_ambientTrafficRelease(t,'approach-unreachable');return false;}
 }else if(t.phase==='board'){
  if(!_civilianTripAccess(car,'board',t.progress)){n.walking=false;_ambientTrafficStop(car,'vehicle-not-ready');return true;}
  const done=_civilianTripDoorStep(t,access.seat,dt);t.progress=1-Math.min(1,Math.hypot(n.r-access.seat.r,n.c-access.seat.c)/(t.doorLength||1));_civilianTripAccess(car,'board',t.progress);if(done){t.phase='drive';t.progress=1;car._route=null;car._routeIdx=0;_civilianTripAccess(car,'drive',1);}
 }else if(t.phase==='drive'){
  n.r=access.seat.r;n.c=access.seat.c;n.ang=car.ang;n.walking=false;
  if(typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(car,n);
  if(typeof _civilianTripAdoptAmbient==='function'&&_civilianTripAdoptAmbient(t,now))return true;
 }
 n._ambientTrafficPhase=t.phase;n._ambientTrafficProgress=t.progress;return true;
}
function _ambientTrafficHasDriver(car){
 const t=_ambientTrafficDrivers.get(car);if(!t||t.phase!=='drive'||!NPCS.includes(t.npc)||t.npc.dead||t.npc.alive===false||(Number.isFinite(t.npc.hp)&&t.npc.hp<=0)||t.npc._knockedUntil>performance.now()||t.npc._forcedCrawl||t.npc._medicalDowned||t.npc._policeCuffed||car._hijackPending||car._wrecked||car._towed)return false;
 return typeof _walkTrafficNavigationResolver==='function'&&_walkTrafficNavigationResolver({mode:'driver',carId:t.carId,npcId:_threeNpcEntityId(t.npc)})?.ready===true;
}
function _ambientTrafficGuard(car,from,dt){
 if(!_ambientTrafficNative(car))return true;
 if(!_ambientTrafficHasDriver(car)){_ambientTrafficStop(car,'no-live-driver');return false;}
 const to={r:car.r+(car.vr||0)*Math.min(.1,dt),c:car.c+(car.vc||0)*Math.min(.1,dt),angle:car.ang},result=typeof _walkTrafficNavigationResolver==='function'?_walkTrafficNavigationResolver({carId:_threeVehicleEntityId(car),from,to,roadsOnly:true}):null;
 if(result?.clear===true){car._nativeTrafficStopReason='';return true;}
 car.ang=from.angle;_ambientTrafficStop(car,result?.reason||'native-navigation-not-ready');car._routeBlocked=true;
 const now=performance.now();if(now>=(car._nativeRouteRetryAt||0)){car._nativeRouteRetryAt=now+1500;car._route=null;car._routeIdx=0;}
 return false;
}
function _ambientTrafficPlanRoute(car,forceNewGoal){
 const t=_ambientTrafficDrivers.get(car);if(!t||!_ambientTrafficHasDriver(car))return false;
 const now=performance.now();if(now<(t.routeRetryAt||0)){_ambientTrafficStop(car,'route-cooldown');return false;}
 if(typeof _walkTrafficNavigationResolver!=='function'){_ambientTrafficStop(car,'native-navigation-not-ready');return false;}
 let job=t.routeJob;
 if(!job){
  if(forceNewGoal||!car._goal)_assignCarGoal(car);
  const nativeTargets=_walkTrafficNavigationResolver({mode:'road-targets',carId:t.carId,from:{r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:0},minDistance:3,maxDistance:40});
  const candidates=nativeTargets?.points?.filter(n=>Number.isFinite(n.r)&&Number.isFinite(n.c))||[];
  const target=candidates[(t.routeAttempt||0)%Math.max(1,candidates.length)];if(!target){_ambientTrafficStop(car,'native-road-targets-not-ready');t.routeRetryAt=now+1000;return false;}  t.routeAttempt=(t.routeAttempt||0)+1;const angle=Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx),goal={r:target.r,c:target.c,angle:Number.isFinite(target.angle)?target.angle:angle};
  job=t.routeJob={id:t.carId+':'+t.routeAttempt,from:{r:car.r,c:car.c,angle},to:goal,first:true};
 }
 const result=_walkTrafficNavigationResolver({mode:'route',requestId:job.id,reset:job.first,carId:t.carId,from:job.from,to:job.to,roadsOnly:true});job.first=false;
 if(result?.status==='ready'&&result.points?.length){car._route=result.points;car._routeIdx=0;car._destination={r:job.to.r,c:job.to.c,kind:car._goal};car._routePlannedAt=now;t.routeJob=null;return true;}
 if(result?.status==='blocked'){t.routeJob=null;t.routeRetryAt=now+1500;}
 _ambientTrafficStop(car,result?.reason||'route-pending');return false;
}
function _ambientTrafficServiceReady(v,now=performance.now()){
 const car=_ambientTrafficServiceProxy(v);if(v.speed>0)v._nativeRequestedSpeed=v.speed;
 if(!_ambientTrafficHasDriver(car)){v.speed=0;v._lastMoveT=now;v._prevX=v.x;v._prevY=v.y;v._nativeDriverReason='driver-not-ready';return false;}
 v._nativeDriverReason='';if(!/parked$/.test(v.state)&&!v.speed)v.speed=v._nativeRequestedSpeed||1.8;return true;
}
function _ambientTrafficServiceStep(v,dt){
 const now=performance.now();if(!_ambientTrafficServiceReady(v,now))return false;
 const car=_ambientTrafficServiceProxy(v),t=_ambientTrafficDrivers.get(car),destination=v.finalTarget||{y:v.homeR,x:v.homeC};
 if(!Number.isFinite(destination.y)||!Number.isFinite(destination.x))return false;
 const key=destination.y+','+destination.x;if(t.serviceTarget!==key){t.serviceTarget=key;t.serviceRoute=null;t.serviceJob=null;t.serviceRetryAt=0;}
 if(now<(t.serviceRetryAt||0))return false;
 if(!t.serviceRoute){
  if(!t.serviceJob){
   const wanted={r:destination.y,c:destination.x,angle:car.ang};let to=wanted;
   if(_walkTrafficNavigationResolver({carId:t.carId,from:wanted,to:wanted,roadsOnly:false})?.clear!==true){
    const targets=_walkTrafficNavigationResolver({mode:'road-targets',carId:t.carId,from:wanted,minDistance:0,maxDistance:5});if(!targets?.points?.length)return false;
    to=targets.points.slice().sort((a,b)=>Math.hypot(a.r-wanted.r,a.c-wanted.c)-Math.hypot(b.r-wanted.r,b.c-wanted.c))[0];
   }
   t.serviceAttempt=(t.serviceAttempt||0)+1;t.serviceJob={id:t.carId+':work:'+t.serviceAttempt,first:true,from:{r:v.y,c:v.x,angle:car.ang},to};
  }
  const job=t.serviceJob,result=_walkTrafficNavigationResolver({mode:'route',carId:t.carId,requestId:job.id,reset:job.first,from:job.from,to:job.to,roadsOnly:true});job.first=false;
  if(result?.status==='ready'&&result.points?.length){t.serviceRoute=result.points;t.serviceRouteIdx=0;t.serviceJob=null;}else{if(result?.status==='blocked'){t.serviceJob=null;t.serviceRetryAt=now+1500;}return false;}
 }
 let target=t.serviceRoute[t.serviceRouteIdx];while(target&&Math.hypot(target.r-v.y,target.c-v.x)<.025)target=t.serviceRoute[++t.serviceRouteIdx];
 if(!target){t.serviceRoute=null;return true;}
 const dr=target.r-v.y,dc=target.c-v.x,d=Math.hypot(dr,dc),step=Math.min(d,Math.max(0,Math.min(.1,dt))*Math.min(3,Math.max(.5,v.speed))),from={r:v.y,c:v.x,angle:car.ang},to={r:v.y+dr/d*step,c:v.x+dc/d*step,angle:Math.atan2(dr,dc)};
 if(_walkTrafficNavigationResolver({carId:t.carId,from,to,roadsOnly:true})?.clear!==true){t.serviceRoute=null;t.serviceRetryAt=now+1500;return false;}
 v.y=to.r;v.x=to.c;v.ang=to.angle;v._lastMoveT=now;if(typeof _syncServiceVehicleCargo==='function')_syncServiceVehicleCargo(v);return false;
}
function _ambientTrafficTickBus(dt,now){
 if(typeof _walkRendererActive!=='function'||!_walkRendererActive())return false;
 if(typeof _nativeBusInitialAdmit==='function'&&!_nativeBusInitialAdmit())return true;
 if(!_ambientTrafficHasDriver(BUS)){BUS.state='stopped';BUS._nativeDriverWaiting=true;BUS.vr=BUS.vc=0;return true;}
 const t=_ambientTrafficDrivers.get(BUS);BUS._nativeDriverWaiting=false;
 if(now<(BUS._nativeStopUntil||0)){BUS.state='stopped';return true;}
 if(BUS._nativeStopUntil){BUS._nativeStopUntil=0;BUS.routeIdx=(BUS.routeIdx+1)%BUS_STOPS.length;}
 if(now<(t.busRetryAt||0)){BUS.state='stopped';return true;}
 if(!t.busRoute){
  if(!t.busJob){
   const stop=BUS_STOPS[BUS.routeIdx],targets=_walkTrafficNavigationResolver({mode:'road-targets',carId:'city_bus',from:{r:stop.r,c:stop.c,angle:BUS.ang},minDistance:0,maxDistance:6});
   if(!targets?.points?.length){BUS.state='stopped';return true;}
   const points=targets.points.slice().sort((a,b)=>Math.hypot(a.r-stop.r,a.c-stop.c)-Math.hypot(b.r-stop.r,b.c-stop.c)),to=points[(t.busAttempt||0)%points.length];
   t.busAttempt=(t.busAttempt||0)+1;t.busJob={id:'city_bus:'+BUS.routeIdx+':'+t.busAttempt,first:true,from:{r:BUS.r,c:BUS.c,angle:BUS.ang},to};
  }
  const job=t.busJob,result=_walkTrafficNavigationResolver({mode:'route',carId:'city_bus',requestId:job.id,reset:job.first,from:job.from,to:job.to,roadsOnly:true});job.first=false;
  if(result?.status==='ready'&&result.points?.length){t.busRoute=result.points;t.busRouteIdx=0;t.busJob=null;}else{if(result?.status==='blocked'){t.busJob=null;t.busRetryAt=now+1500;}BUS.state='stopped';return true;}
 }
 let target=t.busRoute[t.busRouteIdx];while(target&&Math.hypot(target.r-BUS.r,target.c-BUS.c)<.035)target=t.busRoute[++t.busRouteIdx];
 if(!target){t.busRoute=null;BUS.state='stopped';BUS._nativeStopUntil=BUS.stopUntil=now+3200;BUS.doorPhase=1;_onBusArrival(BUS.routeIdx);return true;}
 const dr=target.r-BUS.r,dc=target.c-BUS.c,d=Math.hypot(dr,dc),step=Math.min(d,1.8*Math.max(0,Math.min(.1,dt))),angle=Math.atan2(dr,dc),from={r:BUS.r,c:BUS.c,angle:BUS.ang},to={r:BUS.r+dr/d*step,c:BUS.c+dc/d*step,angle};
 const sweep=_walkTrafficNavigationResolver({carId:'city_bus',from,to,roadsOnly:true});
 if(sweep?.clear!==true){BUS.state='stopped';BUS.vr=BUS.vc=0;if(now>=(t.busRetryAt||0)){t.busRoute=null;t.busRetryAt=now+1500;}return true;}
 BUS.r=to.r;BUS.c=to.c;BUS.ang=angle;BUS.state='driving';BUS.speed=1.8;BUS.vr=dr/d*1.8;BUS.vc=dc/d*1.8;BUS.doorPhase=Math.max(0,BUS.doorPhase-Math.min(.1,dt)*2.5);return true;
}
// AMBIENT_TRAFFIC_DRIVER_END
