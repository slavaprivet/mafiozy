// CIVILIAN_PARKING_TRIP_START
// A single source-owned trip. No new entity, no alternate ambient traffic loop.
let _civilianTrip=null,_civilianTripNextAt=0,_civilianTripPlanningBudget=1800,_civilianTripAdmissionAfter=null;
let _walkNpcVehicleAccessResolver=null;
function _civilianTripNative(){return typeof _walkRendererActive==='function'&&_walkRendererActive();}
const _civilianTripHistory=[];let _civilianTripHistoryKey='',_civilianTripDebugAt=0,_civilianTripDebug=false;
function _civilianTripDebugEnabled(){const now=performance.now();if(now<_civilianTripDebugAt)return _civilianTripDebug;_civilianTripDebugAt=now+1000;let search='';try{search=typeof location!=='undefined'?location.search:'';if(typeof window!=='undefined'&&window.parent!==window)search+='&'+(window.parent?.location?.search||'');}catch{}return _civilianTripDebug=typeof window!=='undefined'&&window.__npcTripDiagnostics===true||/(?:npc(?:transport|combat)?qa|perfqa)=1(?:&|$)/.test(search);}
function _civilianTripSnapshot(t,now,phase=t.phase){const n=t.npc,car=t.car,job=car._civilianNativePlan,p={phase,npcId:n.id,carId:t.carId,doorId:t.plan?.goal?.door?.id||job?.doors?.[job.doorIndex]?.id||null,pedestrianPending:!!n._routeSearchPending,reason:job?.reason||null,waypoint:t.index,total:t.plan?.points?.length||0,npc:{r:n.r,c:n.c},car:{r:car.r,c:car.c,angle:car.ang}};if(_civilianTripDebugEnabled()){Object.assign(p,{atMs:now,phaseAgeMs:now-(t.since||now),door:t.door?{...t.door}:null,doorDistance:t.door?Math.hypot(n.r-t.door.r,n.c-t.door.c):null,approach:{status:t.approachStatus||null,retryAt:t.approachRetryAt||0,routeLength:n._route?.length||0,routeIndex:n._routeIndex||0,next:n._route?.[n._routeIndex||0]||null,routeKind:n._routeKind||null,pending:!!n._routeSearchPending},doorTrace:t.doorTrace||null,approachBlock:t.approachBlock||null,planning:job?{status:job.status,reason:job.reason,doorIndex:job.doorIndex,doors:job.doors?.length,attempt:job.attempt,laneRejected:job.laneRejected,from:job.from,target:job.target,requestId:job.requestId,nextAt:job.nextAt,trace:job.trace||null}:null,driving:{blockedAt:t.blockedAt||0,travelledM:t.travelledM||0,index:t.index}});}return p;}
function _civilianTripReport(t,now,phase=null){if(!t||!phase&&now<(t.reportAt||0))return;t.reportAt=now+500;const p=_civilianTripSnapshot(t,now,phase||t.phase);if(_civilianTripDebugEnabled()){const key=t.carId+':'+t.npc.id+':'+p.phase;if(phase||key!==_civilianTripHistoryKey){_civilianTripHistoryKey=key;_civilianTripHistory.push({...p});if(_civilianTripHistory.length>8)_civilianTripHistory.shift();}p.history=_civilianTripHistory.map(h=>({...h}));}document.documentElement.dataset.civilianTrip=JSON.stringify(p);}
function _civilianTripPlanTrace(job,stage,result){if(_civilianTripDebugEnabled())job.trace={stage,status:result?.status||null,reason:result?.reason||null,expanded:result?.expanded??null,points:result?.points?.length||0,startBlocked:result?.startBlocked??null,endBlocked:result?.endBlocked??null};}
function _civilianTripTraceApproachBlock(t,dt,previousIndex){if(!_civilianTripDebugEnabled()||typeof _walkNpcNavigationResolver!=='function')return;const n=t.npc,target=n._route?.[n._routeIndex||0];if(!target)return;const d=Math.hypot(target.r-n.r,target.c-n.c),step=Math.min(_npcEffectiveSpeed(n)*dt,d),r=n.r+(target.r-n.r)/Math.max(.001,d)*step,c=n.c+(target.c-n.c)/Math.max(.001,d)*step;t.approachBlock={previousIndex,currentIndex:n._routeIndex||0,skippedCorner:previousIndex!==(n._routeIndex||0),target:{r:target.r,c:target.c},attempt:{r,c},probes:_civilianDoorBody.map(([dr,dc])=>{const p={r:r+dr,c:c+dc},ordinary=_walkNpcNavigationResolver(p),withoutOwn=_walkNpcNavigationResolver({...p,ignoreVehicleId:t.carId});return {...p,blocked:!!ordinary?.blocked,blockedIgnoringOwn:!!withoutOwn?.blocked,ownVehicle:!!ordinary?.blocked&&!withoutOwn?.blocked,depth:ordinary?.depth??null,surface:ordinary?.surface||null};})};}


function _civilianTripPass(n,r,c){return _civilianTripNative()?npcPassableForSnitch(r,c):npcWaypointOk(n,r,c);}
function _civilianTripApproachRoute(n,door){
 const pass=(r,c)=>_civilianTripPass(n,r,c),ok=_planNpcRouteTo(n,door.r,door.c,pass,.8,1200,'civilian_car');
 if(n._routeSearchPending)return false;
 const end=ok?n._route?.at(-1):{r:n.r,c:n.c};if(!end||Math.hypot(end.r-door.r,end.c-door.c)>.9||!_npcPathPassable(end.r,end.c,door.r,door.c,pass))return false;
 return _setNpcRoute(n,[...(ok?n._route:[]),{r:door.r,c:door.c}],'civilian_car');
}
// A pending request keeps its exact destination and origin until the shared
// native planner finishes. A busy frame is not a failed journey.
function _civilianTripNativePlan(car,preferredDoor=null){
 const nav=typeof _walkTrafficNavigationResolver==='function'?_walkTrafficNavigationResolver:null,now=performance.now();
 let job=car._civilianNativePlan;
 if(!job){const doors=preferredDoor?[preferredDoor]:_residentBuildingDoors().filter(d=>d.residentEligible!==false&&Number.isFinite(d.r)&&Number.isFinite(d.c)&&Math.hypot(d.r-car.r,d.c-car.c)>3&&Math.hypot(d.r-car.r,d.c-car.c)<65).sort((a,b)=>Math.hypot(a.r-car.r,a.c-car.c)-Math.hypot(b.r-car.r,b.c-car.c)).slice(0,12);job=car._civilianNativePlan={status:'pending',doors,doorIndex:0,attempt:0,nextAt:0,laneRejected:!!preferredDoor};}
 if(!nav||now<job.nextAt)return null;
 const door=job.doors[job.doorIndex];if(!door){job.status='blocked';job.reason='no-reachable-building';return null;}
 job.status='pending';job.nextAt=now+100;
 const from=job.from||(job.from={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)}),carId=_threeVehicleEntityId(car);
 if(!job.laneRejected){
  const lane=nav({mode:'lane-route',carId,from,to:{r:door.r,c:door.c,id:door.id,buildingId:door.buildingId||door.sourceId},maxSnapDistance:12});
  _civilianTripPlanTrace(job,'lane-route',lane);
  if(lane?.status==='ready'&&lane.points?.length){job.status='ready';job.reason='ready';return {native:true,points:lane.points,goal:{door,lot:null},lots:[],controls:lane.controls||[],destination:lane.destination};}
  if(lane?.status!=='blocked'){job.reason=lane?.reason||'lane-route-pending';return null;}job.laneRejected=true;
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
 const carId=_threeVehicleEntityId(car);
 if(_walkNpcVehicleAccessResolver){const access=_walkNpcVehicleAccessResolver({carId,phase,progress});return access&&[access.outside?.r,access.outside?.c,access.seat?.r,access.seat?.c].every(Number.isFinite)?access:null;}
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
function _civilianTripVehicleAvailable(car){return car&&CARS.includes(car)&&car.parked&&(_civilianTripNative()||car._onParking)&&!car._ambientDriverNpcId&&!car._civilianTrip&&!car.gang&&!car._convoy&&!car._static&&!car._wrecked&&!car._towed&&!car._towDispatched&&!car._hijackPending&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId))&&!car.model?.police&&!car.model?.emergency;}
function _civilianTripSurface(r,c,lots){
 if(_trafficRoadTile(r,c))return true;
 return lots.some(l=>r>=l.r0-2&&r<l.r1+3&&c>=l.c0-2&&c<l.c1+3)&&MAP[Math.floor(r)]?.[Math.floor(c)]===9;
}
function _civilianTripPoseClear(car,r,c,angle,lots,dynamic=true){
 const dr=Math.sin(angle),dc=Math.cos(angle),L=Math.min(1.08,Math.max(.58,(car.model?.L||1.8)*.43)),W=Math.min(.48,Math.max(.30,(car.model?.W||.88)*.38));
 for(const f of [-L,0,L])for(const side of [-W,0,W]){const rr=r+dr*f-dc*side,cc=c+dc*f+dr*side;if(!_civilianTripSurface(rr,cc,lots)||_trafficHardTileAt(rr,cc)||typeof _cityV3RailBlocksCar==='function'&&_cityV3RailBlocksCar(rr,cc))return false;
  if(dynamic&&typeof _walkNpcNavigationResolver==='function'){const sample=_walkNpcNavigationResolver({r:rr,c:cc,ignoreVehicleId:_threeVehicleEntityId(car)});if(!sample||sample.blocked||sample.depth>.025)return false;}
 }
 for(const other of CARS){if(other===car||other._towed)continue;const rr=other.r-r,cc=other.c-c;if(Math.abs(rr*dr+cc*dc)<L+1.1&&Math.abs(-rr*dc+cc*dr)<W+.5)return false;}
 if(dynamic){for(const p of [player,...NPCS]){if(p===(_civilianTrip?.car===car?_civilianTrip.npc:null)||p.dead||p._residentIndoors)continue;const rr=p.r-r,cc=p.c-c;if(Math.abs(rr*dr+cc*dc)<L+.22&&Math.abs(-rr*dc+cc*dr)<W+.22)return false;}}
 return true;
}
function _civilianTripSweep(car,a,b,lots,dynamic=true){
 if(_civilianTripNative()){
  if(typeof _walkTrafficNavigationResolver!=='function'||_walkTrafficNavigationResolver({carId:_threeVehicleEntityId(car),from:a,to:b,roadsOnly:false})?.clear!==true)return false;
  const length=Math.max(.75,Math.min(1.2,(car.model?.L||1.8)*.5)),width=Math.max(.4,Math.min(.65,(car.model?.W||.88)*.5)),steps=Math.max(1,Math.ceil(Math.hypot(b.r-a.r,b.c-a.c)/.1)),delta=Math.atan2(Math.sin(b.angle-a.angle),Math.cos(b.angle-a.angle));
  const people=dynamic?[player,...NPCS]:[];
  for(const n of people){if(n===_civilianTrip?.npc||n.dead||n._residentIndoors||n._civilianTripRiding||n._ambientTrafficPhase==='drive'||n._inVehicle||n._transportBoarded)continue;if(Math.hypot(n.r-a.r,n.c-a.c)>length+width+Math.hypot(b.r-a.r,b.c-a.c)+.4)continue;
   for(let i=0;i<=steps;i++){const f=i/steps,angle=a.angle+delta*f,dr=n.r-a.r-(b.r-a.r)*f,dc=n.c-a.c-(b.c-a.c)*f;if(Math.abs(dr*Math.sin(angle)+dc*Math.cos(angle))<length+.18&&Math.abs(-dr*Math.cos(angle)+dc*Math.sin(angle))<width+.18)return false;}
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
 _civilianTripReport(trip,performance.now(),reason);
 if(trip.npc._routeSearchKind==='civilian_car'&&typeof _cancelNpcDirectedSearch==='function')_cancelNpcDirectedSearch(trip.npc);
 if(typeof _npcVehicleOccupants!=='undefined'&&reason!=='driver-dead'&&reason!=='hijack-extraction')_npcVehicleOccupants.delete(trip.car);
 _civilianTripAccess(trip.car,'release',0);
 const {car,npc}=trip;if(!trip.lostOwnership){car.vr=car.vc=0;car.braking=true;car.parked=true;}delete car._civilianTrip;delete npc._civilianTrip;delete npc._civilianTripRiding;
 delete car._civilianNativePlan;car._civilianTripRetryAt=performance.now()+30000;npc.walking=false;npc._civilianPlan={phase:'seek_shop',cycle:(npc._civilianPlan?.cycle||0)+1,retryAt:performance.now()+3000};_clearNpcRoute(npc);
 if(_civilianTrip===trip)_civilianTrip=null;_civilianTripNextAt=performance.now()+20000;
}
function _civilianTripExit(trip){
 const {npc,car}=trip,access=_civilianTripAccess(car);if(!access)return false;
 const {r,c}=access.outside;if(!_civilianTripDoorPath(trip,npc.r,npc.c,r,c))return false;
 trip.access=access;trip.exit={r,c};trip.phase='exit';trip.progress=0;trip.doorLength=Math.hypot(r-npc.r,c-npc.c);npc._civilianTripRiding=false;return true;
}
function _civilianTripDriverDied(trip){
 const n=trip.npc;if(!n.dead&&n.alive!==false&&(!Number.isFinite(n.hp)||n.hp>0))return false;
 // Death owns the exact source anchor. Never turn a corpse into a living
 // passenger following the door-exit path, even during boarding transitions.
 if(n._civilianTripRiding&&typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(trip.car,n);
 _civilianTripRelease(trip,'driver-dead');n._civilianPlan=null;n.walking=false;return true;
}
function _civilianTripTickNpc(n,dt,now){
 const t=_civilianTrip?.npc===n?_civilianTrip:null;if(!t)return false;const car=t.car;_civilianTripReport(t,now);
 if(_civilianTripDriverDied(t))return false;
 const lost=!CARS.includes(car)||car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId||(myDrivingCarId&&String(car.id)===String(myDrivingCarId));
 if(lost){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}
 if(_civilianPlanInterrupted(n,now)){car.vr=car.vc=0;if(!n._civilianTripRiding&&t.phase!=='exit'&&t.phase!=='board'){_civilianTripRelease(t,'threat-interrupted');return false;}t.interrupted=true;if(t.phase!=='exit')_civilianTripExit(t);}
 if(t.phase==='planning'){
  const plan=_civilianTripNativePlan(car,t.destinationDoor);n.walking=false;
  if(plan){t.plan=plan;t.phase=n._civilianTripRiding?'drive':'approach';t.index=0;t.edge=null;t.travelledM=0;car.parked=!n._civilianTripRiding;}
  else if(car._civilianNativePlan?.status==='blocked'){if(n._civilianTripRiding){t.interrupted=true;_civilianTripExit(t);}else _civilianTripRelease(t,'no-reachable-building');}
 }else if(t.phase==='approach'){
  if(_civilianTripNative()&&!n._route?.length&&now>=(t.approachRetryAt||0)){const ready=_civilianTripApproachRoute(n,t.door);t.approachStatus=ready?'route-ready':n._routeSearchPending?'route-pending':'route-not-ready';if(!ready&&!n._routeSearchPending)t.approachRetryAt=now+1500;}
  if(n._routeSearchPending){n.walking=false;return true;}
  const pass=(r,c)=>_civilianTripPass(n,r,c),previousIndex=n._routeIndex||0,status=_npcAdvanceRoute(n,dt,_npcEffectiveSpeed(n),pass);t.approachStatus=status;if(status==='blocked')_civilianTripTraceApproachBlock(t,dt,previousIndex);
  if(status==='arrived'){const d=Math.hypot(n.r-t.door.r,n.c-t.door.c),step=Math.min(d,Math.min(.1,dt)*_npcEffectiveSpeed(n)),r=d?n.r+(t.door.r-n.r)/d*step:n.r,c=d?n.c+(t.door.c-n.c)/d*step:n.c;if(_npcPathPassable(n.r,n.c,r,c,pass)){n.r=r;n.c=c;n.walking=step>0;}}
  if(Math.hypot(n.r-t.door.r,n.c-t.door.c)<.02){t.access=_civilianTripAccess(car);if(!t.access||!_civilianTripDoorPath(t,n.r,n.c,t.access.seat.r,t.access.seat.c)){_civilianTripRelease(t,'door-blocked');return true;}t.phase='board';t.progress=0;t.doorLength=Math.hypot(n.r-t.access.seat.r,n.c-t.access.seat.c);t.since=now;_clearNpcRoute(n);}else if(status==='blocked')_civilianTripRelease(t,'approach-blocked');
 }else if(t.phase==='board'){
  const target=t.access?.seat||{r:car.r,c:car.c},arrived=_civilianTripDoorStep(t,target,dt);t.progress=1-Math.min(1,Math.hypot(n.r-target.r,n.c-target.c)/(t.doorLength||.85));_civilianTripAccess(car,'board',t.progress);
  if(arrived&&now-t.since>500){n._civilianTripRiding=true;t.phase='drive';t.progress=1;car.parked=false;_civilianTripAccess(car,'drive',1);if(typeof _npcRememberVehicleOccupant==='function')_npcRememberVehicleOccupant(car,n);}
 }else if(t.phase==='drive'||t.phase==='parked'){const access=_civilianTripAccess(car);n.r=access?.seat.r??car.r;n.c=access?.seat.c??car.c;n.ang=car.ang;n.walking=false;if(t.phase==='parked')_civilianTripExit(t);
 }else if(t.phase==='exit'){
  const arrived=_civilianTripDoorStep(t,t.exit,dt);t.progress=1-Math.min(1,Math.hypot(n.r-t.exit.r,n.c-t.exit.c)/(t.doorLength||.85));_civilianTripAccess(car,'exit',t.progress);
  if(arrived){const goal=t.plan?.goal?.door,interrupted=t.interrupted;_civilianTripRelease(t,interrupted?'interrupted-exited':'arrived');if(!interrupted&&goal){n._residentDoor=goal;n._civilianPlan={phase:'walk_to_shop',cycle:1,doorId:goal.id,tripDestination:true,since:now,retryAt:0};_civilianRouteTo(n,goal.r,goal.c,'building_entry');}}
 }
 return true;
}
function _civilianTripTickCar(car,dt){
 const t=_civilianTrip?.car===car?_civilianTrip:null;if(!t)return false;if(_civilianTripDriverDied(t))return true;if(car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}if(t.phase!=='drive'||t.interrupted){car.vr=car.vc=0;return true;}
 if(t.plan.native){const n=t.npc,ready=!n.dead&&n.alive!==false&&(!Number.isFinite(n.hp)||n.hp>0)&&!n._medicalDowned&&!n._forcedCrawl&&!(n._knockedUntil>performance.now())&&n._civilianTripRiding&&typeof _walkTrafficNavigationResolver==='function'&&_walkTrafficNavigationResolver({mode:'driver',carId:t.carId,npcId:_threeNpcEntityId(n)})?.ready===true;if(!ready){car.vr=car.vc=0;car.braking=true;return true;}}
 const target=t.plan.points[t.index];if(!target){car.parked=true;if(t.plan.goal.lot)car._onParking=t.plan.goal.lot;t.phase='parked';car.vr=car.vc=0;return true;}
 const distance=Math.hypot(target.r-car.r,target.c-car.c),current={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)};
 if(t.edge?.index!==t.index)t.edge={index:t.index,angle:current.angle,length:distance};
 const delta=Math.atan2(Math.sin(target.angle-current.angle),Math.cos(target.angle-current.angle)),turn=Math.atan2(Math.sin(target.angle-t.edge.angle),Math.cos(target.angle-t.edge.angle)),speed=t.plan.native?(target.gear==='reverse'?.55:1.35):(_trafficRoadTile(car.r,car.c)?1.35:.55),step=Math.min(distance,speed*Math.min(.1,dt)),progress=t.edge.length?Math.min(1,(t.edge.length-distance+step)/t.edge.length):1,angle=t.edge.length?t.edge.angle+turn*progress:current.angle+Math.max(-dt,Math.min(dt,delta));
 const next={r:distance?car.r+(target.r-car.r)/distance*step:car.r,c:distance?car.c+(target.c-car.c)/distance*step:car.c,angle};
 if(!t.plan.native&&typeof carCanGo==='function'&&_trafficRoadTile(car.r,car.c)&&_trafficRoadTile(car.r+Math.sin(angle)*1.5,car.c+Math.cos(angle)*1.5)&&_trafficCarFootprintClear(car,next.r,next.c)){car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;if(!carCanGo(car,Math.min(.1,dt))){car.braking=true;return true;}}
 if(t.plan.native&&!_civilianTripRoadPermission(t,current,next)){car.vr=car.vc=0;car.braking=true;return true;}
 if(!_civilianTripSweep(car,current,next,t.plan.lots,true)){car.vr=car.vc=0;car.braking=true;const now=performance.now();if(t.plan.native){t.blockedAt=t.blockedAt||now;if(now-t.blockedAt>1500){t.destinationDoor=t.plan.goal.door;delete car._civilianNativePlan;t.phase='planning';t.blockedAt=0;}}return true;}t.blockedAt=0;
 car.r=next.r;car.c=next.c;car.ang=angle;car.dirDy=Math.sin(angle);car.dirDx=Math.cos(angle);car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;car.braking=false;t.travelledM=(t.travelledM||0)+Math.hypot(next.r-current.r,next.c-current.c)*4.1;if(distance<.025&&Math.abs(delta)<.025)t.index++;
 _civilianTripReport(t,performance.now());return true;
}
function _civilianTripRoadPermission(t,from,to){
 // Route controls are indexed by travelled distance, not nearest-junction guesses.
 const moved=t.travelledM||0,nextDistance=moved+Math.hypot(to.r-from.r,to.c-from.c)*4.1;
 for(const control of t.plan.controls||[]){
  if(!Number.isFinite(control.distanceM)||control.distanceM<moved-.2||control.distanceM>nextDistance+3)continue;
  const point=control.stopPoint,occupied=point&&[player,...NPCS].some(n=>n!==t.npc&&!n.dead&&!n._civilianTripRiding&&!n._ambientTrafficDriver&&!n._residentIndoors&&Math.hypot(n.r-point.r,n.c-point.c)<1.8),others=point&&CARS.some(c=>c!==t.car&&!c._towed&&Math.hypot(c.r-point.r,c.c-point.c)<2.2);
  const answer=_walkTrafficNavigationResolver({mode:'road-rules',control,approachId:control.approachId,turnId:control.turnId,time:performance.now()/1000,occupiedCrosswalkIds:occupied?(control.crosswalkIds||[]):[],occupiedTurnIds:others?(control.conflicts||control.yieldTo||[]):[],occupiedEdgeIds:others&&control.edgeId?[control.edgeId]:[]});
  if(answer?.control?.allowed!==true&&control.distanceM<=nextDistance+1.2)return false;
 }
 return true;
}
function _civilianTripAdoptAmbient(source,now){
 if(!_civilianTripNative()||_civilianTrip||!CARS.includes(source.car)||source.phase!=='drive'||source.npc.dead||now<(source.visitRetryAt||0))return false;
 const {car,npc}=source;if(car.gang||car._convoy||car.model?.police||car.model?.emergency)return false;
 const access=_civilianTripAccess(car);if(!access)return false;
 _ambientTrafficRelease(source,'planning-building-visit');
 const trip={car,npc,carId:_threeVehicleEntityId(car),door:access.outside,access,phase:'planning',plan:null,index:0,since:now};
 _civilianTrip=trip;car._civilianTrip=true;car.parked=false;npc._civilianTrip=true;npc._civilianTripRiding=true;npc._civilianPlan={phase:'drive_to_shop',cycle:npc._civilianPlan?.cycle||0,since:now};return true;
}
function _civilianTripSchedule(now){
 if(_civilianTrip||now<_civilianTripNextAt)return;_civilianTripNextAt=now+12000;
 const native=_civilianTripNative(),cars=CARS.filter(_civilianTripVehicleAvailable).filter(car=>!_parkingNpcs.some(p=>p.car===car)&&now>=(car._civilianTripRetryAt||0)).sort((a,b)=>Math.hypot(a.r-player.r,a.c-player.c)-Math.hypot(b.r-player.r,b.c-player.c));
 // Keep the two-car work bound, but rotate admission. Two unavailable cars
 // nearest the player must not starve every other resident's journey.
 const start=native&&cars.length?(cars.findIndex(car=>_threeVehicleEntityId(car)===_civilianTripAdmissionAfter)+1)%cars.length:0;
 const candidates=native?Array.from({length:Math.min(2,cars.length)},(_,i)=>cars[(start+i)%cars.length]):cars.slice(0,2),admission=[];
 if(native)_civilianTripNextAt=now+(cars.length?750:12000);
 for(const car of candidates){
  if(native)_civilianTripAdmissionAfter=_threeVehicleEntityId(car);
  let npc=null,nearest=144;
  for(const n of NPCS){const distance=(n.r-car.r)**2+(n.c-car.c)**2;if(distance>=nearest||!Number.isFinite(distance))continue;if(!_civilianPlanEligible(n)||_civilianPlanInterrupted(n,now)||n._residentIndoors||n._civilianTrip||native&&n._civilianPlan?.tripDestination)continue;npc=n;nearest=distance;}
  if(!npc){admission.push({carId:_threeVehicleEntityId(car),reason:'no-available-resident'});continue;}
  const access=_civilianTripAccess(car),door=access?.outside;
  if(!door){admission.push({carId:_threeVehicleEntityId(car),reason:'vehicle-model-pending'});continue;}
  if(!(native?_npcBodyPassable(door.r,door.c,(r,c)=>_civilianTripPass(npc,r,c)):npcWaypointOk(npc,door.r,door.c))){admission.push({carId:_threeVehicleEntityId(car),reason:'door-approach-blocked'});continue;}
  if(native){if(typeof _civilianPlanCancel==='function')_civilianPlanCancel(npc);const trip={car,npc,carId:_threeVehicleEntityId(car),plan:null,door,access,phase:'planning',index:0,since:now};_civilianTrip=trip;car._civilianTrip=true;npc._civilianTrip=true;_clearNpcRoute(npc);npc._civilianPlan={phase:'walk_to_car',cycle:npc._civilianPlan?.cycle||0,since:now};return;}
  const plan=_civilianTripPlan(car);if(!plan)continue;if(typeof _civilianPlanCancel==='function')_civilianPlanCancel(npc);if(!_civilianRouteTo(npc,door.r,door.c,'civilian_car'))continue;
  const trip={car,npc,carId:_threeVehicleEntityId(car),plan,door,phase:'approach',index:0,since:now};document.documentElement.dataset.civilianTrip=JSON.stringify({phase:'approach',npcId:npc.id,carId:trip.carId,total:plan.points.length});_civilianTrip=trip;car._civilianTrip=true;npc._civilianTrip=true;npc._civilianPlan={phase:'walk_to_car',cycle:npc._civilianPlan?.cycle||0,since:now};return;
 }
 document.documentElement.dataset.civilianTrip=JSON.stringify({phase:native?'waiting-admission':'waiting-safe-route',eligibleCars:cars.length,admission,nextAttemptMs:_civilianTripNextAt,...(_civilianTripDebugEnabled()?{history:_civilianTripHistory}:{} )});
}
// CIVILIAN_PARKING_TRIP_END

