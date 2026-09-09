// CIVILIAN_PARKING_TRIP_START
// A single source-owned trip. No new entity, no alternate ambient traffic loop.
let _civilianTrip=null,_civilianTripNextAt=0,_civilianTripPlanningBudget=1800;
function _civilianTripVehicleAvailable(car){return car&&CARS.includes(car)&&car.parked&&car._onParking&&!car._civilianTrip&&!car.gang&&!car._convoy&&!car._static&&!car._wrecked&&!car._towed&&!car._towDispatched&&!car._hijackPending&&!car.driver_uid&&!car.owner_uid&&!car.ownerId&&!car.driverId&&!(myDrivingCarId&&String(car.id)===String(myDrivingCarId))&&!car.model?.police&&!car.model?.emergency;}
function _civilianTripSurface(r,c,lots){
 if(_trafficRoadTile(r,c))return true;
 return lots.some(l=>r>=l.r0-2&&r<l.r1+3&&c>=l.c0-2&&c<l.c1+3)&&MAP[Math.floor(r)]?.[Math.floor(c)]===9;
}
function _civilianTripPoseClear(car,r,c,angle,lots,dynamic=true){
 const dr=Math.sin(angle),dc=Math.cos(angle),L=Math.min(1.08,Math.max(.58,(car.model?.L||1.8)*.43)),W=Math.min(.48,Math.max(.30,(car.model?.W||.88)*.38));
 for(const f of [-L,0,L])for(const side of [-W,0,W]){const rr=r+dr*f-dc*side,cc=c+dc*f+dr*side;if(!_civilianTripSurface(rr,cc,lots)||_trafficHardTileAt(rr,cc)||typeof _cityV3RailBlocksCar==='function'&&_cityV3RailBlocksCar(rr,cc))return false;}
 for(const other of CARS){if(other===car||other._towed)continue;const rr=other.r-r,cc=other.c-c;if(Math.abs(rr*dr+cc*dc)<L+1.1&&Math.abs(-rr*dc+cc*dr)<W+.5)return false;}
 if(dynamic){for(const p of [player,...NPCS]){if(p===(_civilianTrip?.car===car?_civilianTrip.npc:null)||p.dead||p._residentIndoors)continue;const rr=p.r-r,cc=p.c-c;if(Math.abs(rr*dr+cc*dc)<L+.22&&Math.abs(-rr*dc+cc*dr)<W+.22)return false;}}
 return true;
}
function _civilianTripSweep(car,a,b,lots,dynamic=true){
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
 const {car,npc}=trip;if(!trip.lostOwnership){car.vr=car.vc=0;car.braking=true;car.parked=true;}delete car._civilianTrip;delete npc._civilianTrip;delete npc._civilianTripRiding;
 npc.walking=false;npc._civilianPlan={phase:'seek_shop',cycle:(npc._civilianPlan?.cycle||0)+1,retryAt:performance.now()+3000};_clearNpcRoute(npc);
 if(_civilianTrip===trip)_civilianTrip=null;_civilianTripNextAt=performance.now()+20000;document.documentElement.dataset.civilianTrip=JSON.stringify({phase:reason,npcId:npc.id,carId:trip.carId});
}
function _civilianTripExit(trip){
 const {npc,car}=trip,dr=Math.sin(car.ang),dc=Math.cos(car.ang);
 for(const side of [-1,1]){const r=car.r-dc*.85*side,c=car.c+dr*.85*side;if(!npcWaypointOk(npc,r,c)||!_npcPathPassable(npc.r,npc.c,r,c,(rr,cc)=>npcWaypointOk(npc,rr,cc)))continue;
  // The short door crossing is traversed over time; never teleport the rider.
  trip.exit={r,c};trip.phase='exit';npc._civilianTripRiding=false;return true;
 }return false;
}
function _civilianTripTickNpc(n,dt,now){
 const t=_civilianTrip?.npc===n?_civilianTrip:null;if(!t)return false;const car=t.car;
 const lost=!CARS.includes(car)||car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId||(myDrivingCarId&&String(car.id)===String(myDrivingCarId));
 if(lost){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}
 if(_civilianPlanInterrupted(n,now)){car.vr=car.vc=0;if(!n._civilianTripRiding){_civilianTripRelease(t,lost?'ownership-interrupted':'threat-interrupted');return false;}t.interrupted=true;if(t.phase!=='exit')_civilianTripExit(t);}
 if(t.phase==='approach'){
  const status=_npcAdvanceRoute(n,dt,_npcEffectiveSpeed(n), (r,c)=>npcWaypointOk(n,r,c));
  if(status==='arrived'){const d=Math.hypot(n.r-t.door.r,n.c-t.door.c),step=Math.min(d,Math.min(.1,dt)*_npcEffectiveSpeed(n)),r=d?n.r+(t.door.r-n.r)/d*step:n.r,c=d?n.c+(t.door.c-n.c)/d*step:n.c;if(_npcPathPassable(n.r,n.c,r,c,(rr,cc)=>npcWaypointOk(n,rr,cc))){n.r=r;n.c=c;n.walking=step>0;}}
  if(Math.hypot(n.r-t.door.r,n.c-t.door.c)<.16){t.phase='board';t.since=now;_clearNpcRoute(n);}else if(status==='blocked')_civilianTripRelease(t,'approach-blocked');
 }else if(t.phase==='board'){
  const d=Math.hypot(n.r-car.r,n.c-car.c),step=Math.min(d,dt*.7);if(d>.01){n.r+=(car.r-n.r)/d*step;n.c+=(car.c-n.c)/d*step;}else if(now-t.since>500){n._civilianTripRiding=true;t.phase='drive';car.parked=false;}
 }else if(t.phase==='drive'||t.phase==='parked'){n.r=car.r;n.c=car.c;n.ang=car.ang;n.walking=false;if(t.phase==='parked')_civilianTripExit(t);
 }else if(t.phase==='exit'){
  const d=Math.hypot(n.r-t.exit.r,n.c-t.exit.c),step=Math.min(d,dt*.7);if(d>.01){n.r+=(t.exit.r-n.r)/d*step;n.c+=(t.exit.c-n.c)/d*step;}else{const goal=t.plan.goal.door,interrupted=t.interrupted;_civilianTripRelease(t,interrupted?'interrupted-exited':'arrived');if(!interrupted&&_civilianRouteTo(n,goal.r,goal.c,'building_entry')){n._residentDoor=goal;n._civilianPlan={phase:'walk_to_shop',cycle:1,doorId:goal.id,since:now};}}
 }
 return true;
}
function _civilianTripTickCar(car,dt){
 const t=_civilianTrip?.car===car?_civilianTrip:null;if(!t)return false;if(car._wrecked||car._towed||car._towDispatched||car._hijackPending||car.driver_uid||car.owner_uid||car.ownerId||car.driverId){t.lostOwnership=true;_civilianTripRelease(t,'ownership-interrupted');return false;}if(t.phase!=='drive'||t.interrupted){car.vr=car.vc=0;return true;}
 const target=t.plan.points[t.index];if(!target){car.parked=true;car._onParking=t.plan.goal.lot;t.phase='parked';car.vr=car.vc=0;return true;}
 const distance=Math.hypot(target.r-car.r,target.c-car.c),current={r:car.r,c:car.c,angle:Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx)};
 if(t.edge?.index!==t.index)t.edge={index:t.index,angle:current.angle,length:distance};
 const delta=Math.atan2(Math.sin(target.angle-current.angle),Math.cos(target.angle-current.angle)),turn=Math.atan2(Math.sin(target.angle-t.edge.angle),Math.cos(target.angle-t.edge.angle)),speed=_trafficRoadTile(car.r,car.c)?1.35:.55,step=Math.min(distance,speed*Math.min(.1,dt)),progress=t.edge.length?Math.min(1,(t.edge.length-distance+step)/t.edge.length):1,angle=t.edge.length?t.edge.angle+turn*progress:current.angle+Math.max(-dt,Math.min(dt,delta));
 const next={r:distance?car.r+(target.r-car.r)/distance*step:car.r,c:distance?car.c+(target.c-car.c)/distance*step:car.c,angle};
 if(typeof carCanGo==='function'&&_trafficRoadTile(car.r,car.c)&&_trafficRoadTile(car.r+Math.sin(angle)*1.5,car.c+Math.cos(angle)*1.5)&&_trafficCarFootprintClear(car,next.r,next.c)){car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;if(!carCanGo(car,Math.min(.1,dt))){car.braking=true;return true;}}
 if(!_civilianTripSweep(car,current,next,t.plan.lots,true)){car.vr=car.vc=0;car.braking=true;return true;}
 car.r=next.r;car.c=next.c;car.ang=angle;car.dirDy=Math.sin(angle);car.dirDx=Math.cos(angle);car.vr=dt?(next.r-current.r)/dt:0;car.vc=dt?(next.c-current.c)/dt:0;car.braking=false;if(distance<.025&&Math.abs(delta)<.025)t.index++;
 document.documentElement.dataset.civilianTrip=JSON.stringify({phase:t.phase,npcId:t.npc.id,carId:t.carId,waypoint:t.index,total:t.plan.points.length});return true;
}
function _civilianTripSchedule(now){
 if(_civilianTrip||now<_civilianTripNextAt)return;_civilianTripNextAt=now+12000;
 const cars=CARS.filter(_civilianTripVehicleAvailable).filter(car=>!_parkingNpcs.some(p=>p.car===car)).sort((a,b)=>Math.hypot(a.r-player.r,a.c-player.c)-Math.hypot(b.r-player.r,b.c-player.c));
 for(const car of cars.slice(0,2)){
  const npc=NPCS.filter(n=>_civilianPlanEligible(n)&&!_civilianPlanInterrupted(n,now)&&!n._residentIndoors&&!n._civilianTrip&&Math.hypot(n.r-car.r,n.c-car.c)<12).sort((a,b)=>Math.hypot(a.r-car.r,a.c-car.c)-Math.hypot(b.r-car.r,b.c-car.c))[0];if(!npc)continue;
  const angle=Number.isFinite(car.ang)?car.ang:Math.atan2(car.dirDy,car.dirDx),door={r:car.r-Math.cos(angle)*.85,c:car.c+Math.sin(angle)*.85};if(!npcWaypointOk(npc,door.r,door.c))continue;
  const plan=_civilianTripPlan(car);if(!plan)continue;if(!_civilianRouteTo(npc,door.r,door.c,'civilian_car'))continue;
  const trip={car,npc,carId:_threeVehicleEntityId(car),plan,door,phase:'approach',index:0,since:now};document.documentElement.dataset.civilianTrip=JSON.stringify({phase:'approach',npcId:npc.id,carId:trip.carId,total:plan.points.length});_civilianTrip=trip;car._civilianTrip=true;npc._civilianTrip=true;npc._civilianPlan={phase:'walk_to_car',cycle:npc._civilianPlan?.cycle||0,since:now};return;
 }
 document.documentElement.dataset.civilianTrip=JSON.stringify({phase:'waiting-safe-route',eligibleCars:cars.length,nextAttemptMs:_civilianTripNextAt});
}
// CIVILIAN_PARKING_TRIP_END

