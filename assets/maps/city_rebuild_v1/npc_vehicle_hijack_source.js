// NPC_VEHICLE_HIJACK_START
const _npcVehicleOccupants=new WeakMap(),_npcHijackCars=new Map(),_npcRetakeEvents=new Map();
let _nativeVehicleAction=null,_nativeVehicleExitBypass=false,_walkVehicleSeatId='front_left',_walkVehicleInputAt=0,_walkVehicleLastAction=null,_nativeVehicleExitReceipt=null;
function _npcVehicleDead(n){return !!n&&(n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0);}
function _npcRememberVehicleOccupant(car,npc){
 if(!car||!npc)return;const carId=_threeVehicleEntityId(car),previous=_npcVehicleOccupants.get(car);if(previous?.npc!==npc||previous?.carId!==carId)_npcVehicleOccupants.set(car,{npc,carId,seatId:'front_left'});
 if(_npcVehicleDead(npc)&&npc._vehicleCorpseSeat?.carId!==carId)npc._vehicleCorpseSeat={carId,seatId:'front_left'};
}
function _npcVehicleOccupant(car){
 const known=_npcVehicleOccupants.get(car);if(known&&NPCS.includes(known.npc))return known;
 const ambient=_ambientTrafficDrivers.get(car),trip=typeof _civilianTripForCar==='function'?_civilianTripForCar(car):_civilianTrip?.car===car?_civilianTrip:null;
 const boarding=ambient?.phase==='board'?ambient:trip?.phase==='board'?trip:null;if(boarding?.npc)return {npc:boarding.npc,carId:_threeVehicleEntityId(car),seatId:'front_left',transition:true};
 const n=ambient?.phase==='drive'?ambient.npc:trip?.npc?._civilianTripRiding?trip.npc:null;if(n){_npcRememberVehicleOccupant(car,n);return _npcVehicleOccupants.get(car);}return null;
}
function _nativeVehicleRecord(id){
 const key=String(id||'');if(key.startsWith('quest_')){const c=questCars.get(key.slice(6));if(c)return {car:c,kind:'quest',sourceId:String(c.id),presentationId:key};}
 for(const c of questCars.values())if(c.sourceVehicleId===key||c.previousPresentationId===key||String(c.id)===key)return {car:c,kind:'quest',sourceId:String(c.id),presentationId:`quest_${c.id}`};
 const c=CARS.find(c=>_threeVehicleEntityId(c)===key);return c?{car:c,kind:'traffic',sourceId:key,presentationId:key}:null;
}
function _nativeVehicleAccess(record,phase='query',progress=0,seatId='front_left'){
 if(typeof _walkNpcVehicleAccessResolver!=='function')return null;
 const a=_walkNpcVehicleAccessResolver({carId:record.presentationId,phase,progress,seatId});return a&&[a.outside?.r,a.outside?.c,a.seat?.r,a.seat?.c].every(Number.isFinite)?a:null;
}
const _nativeDriveControl={throttle:0,steer:0,inReverse:false,brake:false,turnStep:0};
function _walkNativeDriveControl(qc,vx,vy,dt,wantingExit,turnRate=3.4){
 const o=_nativeDriveControl,locked=wantingExit||!!_threeVehicleEntrySequence,forward=!locked&&!!_keyState.up,back=!locked&&!!_keyState.down,steer=locked?0:(+!!_keyState.right)-(+!!_keyState.left),angle=+qc.ang||0,signed=vx*Math.cos(angle)+vy*Math.sin(angle),speed=Math.hypot(vx,vy);
 o.throttle=forward||back?1:0;o.inReverse=back&&!forward;o.brake=forward&&back||back&&signed>.08||forward&&signed<-.08;o.steer=steer;
 const speedFactor=Math.min(1,Math.abs(signed)/1.2)/(1+speed*.09),reverseSign=signed<-.08?-1:1;
 o.turnStep=steer*reverseSign*turnRate*speedFactor*Math.max(0,Math.min(.1,dt))*(qc.tires_punctured?.58:1);qc.ang=angle+o.turnStep;return o;
}
function _nativeVehicleSpeedMps(record){const c=record.car,scale=typeof window!=='undefined'?Math.max(3,Math.min(5,+window.MAFIOZI_RENDERER_CONFIG?.worldScale||4.1)):4.1;return Math.hypot(record.kind==='quest'?+c.vx||0:+c.vc||0,record.kind==='quest'?+c.vy||0:+c.vr||0)*scale;}
function _getWalkVehicleState(){
 const car=myDrivingCarId?questCars.get(myDrivingCarId):null,seq=_threeVehicleEntrySequence;
 return {active:!!car||!!seq,driving:!!car,passenger:!!myIsPassenger,canDrive:!!car&&!myIsPassenger&&!seq,sourceCarId:car?`quest_${car.id}`:seq?.vehicleId||null,canonicalCarId:car?String(car.id):seq?.sourceCarId||null,sourceId:car?`quest_${car.id}`:seq?.vehicleId||null,presentationCarId:car?`quest_${car.id}`:seq?.vehicleId||null,seatId:car?(myIsPassenger?_walkVehicleSeatId==='front_left'?'front_right':_walkVehicleSeatId:'front_left'):seq?.seatId||null,r:+player.r,c:+player.c,x:car?+car.x:+player.c,y:car?+car.y:+player.r,vx:car?+car.vx||0:0,vy:car?+car.vy||0:0,angle:car?+car.ang||0:+player.ang||0,ang:car?+car.ang||0:+player.ang||0,phase:seq?.phase||(car?'driving':'foot'),progress:seq?.progress||0,vehicleEntry:seq?{...seq}:null,mode:seq?'transition':car?'vehicle':'foot',transition:seq?{...seq}:null,requestId:_walkVehicleLastAction?.requestId||null,lastAction:_walkVehicleLastAction?{..._walkVehicleLastAction}:null};
}
function _setWalkVehicleInput(input={}){
 if(!_walkRendererActive()||!myDrivingCarId||myIsPassenger||_threeVehicleEntrySequence||myDead)return {accepted:false,reason:'not-driver'};
 const c=questCars.get(myDrivingCarId);if(!c||c.driver_uid&&String(c.driver_uid)!==String(QP.uid))return {accepted:false,reason:'driver-changed'};
 if(input.nativePhysics===true){
  const p=input.pose;if(!p||![p.x,p.y,p.ang,p.vx,p.vy].every(Number.isFinite))return {accepted:false,reason:'invalid-native-pose'};
  c.x=Math.max(.5,Math.min(MAP_COLS-.5,p.x));c.y=Math.max(.5,Math.min(MAP_ROWS-.5,p.y));c.ang=p.ang;c.vx=p.vx;c.vy=p.vy;c.steer=Number.isFinite(p.steer)?p.steer:0;c.braking=!!p.braking;c._walkAdvancedPhysicsAt=performance.now();
  if(Number.isFinite(p.damageRatio))c._walkDamageRatio=Math.max(0,Math.min(1,p.damageRatio));c._walkWrecked=!!p.wrecked;c._walkBurning=!!p.burning;
  player.r=c.y;player.c=c.x;player.ang=c.ang;_keyState.up=_keyState.down=_keyState.left=_keyState.right=false;_handbrakeActive=false;joyL.active=false;joyL.dx=joyL.dy=0;_walkVehicleInputAt=c._walkAdvancedPhysicsAt;
  if(!_lastDriveSentAt)_lastDriveSentAt=0;if(!c._pendingServerHijack&&!c._offlineLocalHijack&&c._walkAdvancedPhysicsAt-_lastDriveSentAt>66){_lastDriveSentAt=c._walkAdvancedPhysicsAt;try{ws&&ws.send(JSON.stringify({t:'gta_drive',d:{car_id:c.id,x:+c.x.toFixed(3),y:+c.y.toFixed(3),ang:+c.ang.toFixed(3),vx:+c.vx.toFixed(3),vy:+c.vy.toFixed(3)}}));}catch(e){}}
  return {accepted:true,nativePhysics:true};
 }
 _keyState.up=!!input.forward;_keyState.down=!!input.back;_keyState.left=!!input.left;_keyState.right=!!input.right;_handbrakeActive=!!input.handbrake;joyL.active=false;joyL.dx=joyL.dy=0;_walkVehicleInputAt=performance.now();return {accepted:true};
}
function _getWalkVehicleAccess(input={}){
 const requestedId=String(input.carId||_getWalkVehicleState().presentationCarId||''),record=_nativeVehicleRecord(requestedId),action=input.requestId&&_walkVehicleLastAction?.requestId===input.requestId?_walkVehicleLastAction:null;
 if(!record)return {available:false,reason:'vehicle-unavailable',seats:[],lastAction:_walkVehicleLastAction,...(action?{...action}:{})};
 const c=record.car,available=_vehicleCanBeEntered(c)&&!c.gang&&!c._convoy&&!c._static&&!c.custody_owner_uid&&!c.model?.police&&!c.model?.emergency;
 const passenger=record.kind==='quest'&&!!c.driver_uid&&String(c.driver_uid)!==String(QP.uid)&&(c.passenger_uids||[]).length<1&&!c.police_patrol;
 return {available,speed:_nativeVehicleSpeedMps(record),speedUnit:'m/s',reason:available?'':'protected-or-disabled',sourceCarId:requestedId,canonicalCarId:record.sourceId,presentationCarId:record.presentationId,canDrive:available&&!passenger,occupiedSeatId:myDrivingCarId===String(c.id)?myIsPassenger?_walkVehicleSeatId==='front_left'?'front_right':_walkVehicleSeatId:'front_left':_npcVehicleOccupant(c)?'front_left':c.driver_uid?'front_left':null,seats:['front_left','front_right','rear_left','rear_right'].map(id=>({id,available:available&&(id==='front_left'?!passenger:id==='front_right'&&passenger),reason:id.startsWith('rear_')?'server-seat-unavailable':id==='front_right'&&!passenger?'no-passenger-contract':''})),transition:_threeVehicleEntrySequence?{..._threeVehicleEntrySequence}:null,lastAction:_walkVehicleLastAction,...(action?{accepted:action.accepted,pending:action.pending,requestId:action.requestId,seatId:action.seatId,sourceCarId:requestedId,presentationCarId:action.presentationCarId||record.presentationId,reason:action.reason||''}:{})};
}
function _performWalkVehicleAction(input={}){
 if(input.action==='drive')return {accepted:false,reason:'use-vehicle-input'};
 if(input.action!=='enter'&&input.action!=='exit')return {accepted:false,reason:'unknown-action'};
 if(input.action==='exit'&&!myDrivingCarId)return {accepted:false,reason:'not-in-vehicle'};
 if(input.action==='exit'&&String(input.carId)!==`quest_${myDrivingCarId}`)return {accepted:false,reason:'not-current-vehicle'};
 const access=_getWalkVehicleAccess(input),seatId=input.seatId||'front_left';
 if(input.action==='enter'&&(!access.available||!access.seats.some(s=>s.id===seatId&&s.available)))return {accepted:false,reason:access.reason||'seat-unavailable'};
 if(input.action==='enter'){const record=_nativeVehicleRecord(input.carId),door=record&&_nativeVehicleAccess(record,'query',0,seatId)?.outside;if(!door||Math.hypot(player.r-door.r,player.c-door.c)>1.1||!_civilianTripDoorPath({npc:player,carId:record.presentationId},player.r,player.c,door.r,door.c))return {accepted:false,reason:'approach-selected-door'};}
 if(input.requestId&&_walkVehicleLastAction?.requestId===input.requestId)return {..._walkVehicleLastAction};
 _walkVehicleSeatId=seatId;const result=activateNearbyVehicleFrom3D(input.carId||'',seatId);
 _walkVehicleLastAction={requestId:String(input.requestId||''),action:input.action,accepted:!!result.ok,pending:!!_threeVehicleEntrySequence,reason:result.reason||'',sourceCarId:String(input.carId||''),presentationCarId:access.presentationCarId||null,seatId};return {..._walkVehicleLastAction};
}
function _nativeVehicleStep(person,target,dt,record,ignoreOwn=false){
 const d=Math.hypot(target.r-person.r,target.c-person.c);if(d<.002)return true;
 const step=Math.min(d,Math.max(0,Math.min(.1,dt))*.85),r=person.r+(target.r-person.r)/d*step,c=person.c+(target.c-person.c)/d*step;
 const clear=ignoreOwn?_civilianTripDoorPath({npc:person,carId:record.presentationId},person.r,person.c,r,c):_npcPathPassable(person.r,person.c,r,c,npcPassableForSnitch);if(!clear)return false;
 person.r=r;person.c=c;person.walking=false;if(_npcVehicleDead(person)){person._deathR=r;person._deathC=c;}return d-step<.002;
}
function _npcVehicleRestoreSeated(s){
 const n=s.npc,c=s.record.car,b=s.seatedBinding;if(!n||s.extracted||s.seq.phase==='pull_driver'&&s.seq.progress>0)return false;
 if(_npcVehicleDead(n)){n._vehicleCorpseSeat={carId:s.record.presentationId,seatId:s.seq.seatId};n._vehicleHijack={eventId:s.seq.eventId,phase:'seated',progress:0,carId:s.record.presentationId,seatId:s.seq.seatId};return true;}
 if(!b||!CARS.includes(c)||_vehicleIsWrecked(c))return false;
 if(b.trip&&(typeof _civilianTripRegister==='function'?_civilianTripRegister(b.trip):!_civilianTrip)){if(typeof _civilianTripRegister!=='function')_civilianTrip=b.trip;c._civilianTrip=true;c._civilianNativePlan=b.nativePlan;n._civilianTrip=true;n._civilianTripRiding=true;n._civilianPlan=b.plan;c.parked=false;return true;}
 if(typeof _ambientTrafficDriverByNpc!=='undefined'){const t=b.ambient||{npc:n,car:c,carId:s.record.presentationId,phase:'drive',progress:1,access:s.access,createdAt:performance.now()};_ambientTrafficDrivers.set(c,t);_ambientTrafficDriverByNpc.set(n,t);c._ambientDriverNpcId=n.id;n._ambientTrafficDriver=true;n._ambientTrafficCarId=t.carId;n._ambientTrafficPhase='drive';n._ambientTrafficProgress=1;c.parked=false;return true;}return false;
}
function _nativeVehicleActionEnd(reason='complete'){
 const s=_nativeVehicleAction;if(!s)return;
 if(s.record.kind==='traffic'){s.record.car._hijackPending=0;s.record.car.vr=s.record.car.vc=0;s.record.car.parked=true;}
 if(s.npc){delete s.npc._vehicleHijackControlled;if(reason!=='complete'){delete s.npc._vehicleHijack;if(!_npcVehicleRestoreSeated(s)&&s.seq.phase==='pull_driver'&&s.seq.progress>0){delete s.npc._vehicleCorpseSeat;_npcVehicleOccupants.delete(s.record.car);}}}
 _nativeVehicleAccess(s.record,'release',0,s.seq.seatId);
 _walkVehicleLastAction={...(_walkVehicleLastAction||{}),accepted:reason==='complete',pending:false,reason:reason==='complete'?'':reason};
 _nativeVehicleAction=null;if(_threeVehicleEntrySequence===s.seq)_threeVehicleEntrySequence=null;
}
function _beginNativeVehicleEntry(car,kind,done){
 if(!_walkRendererActive()||_threeVehicleEntryBypass)return false;
 if(_nativeVehicleAction||_threeVehicleEntrySequence)return true;
 const record={car,kind,sourceId:kind==='quest'?String(car.id):_threeVehicleEntityId(car),presentationId:_threeVehicleEntryId(car,kind)},seatId=_walkVehicleSeatId||'front_left',access=_nativeVehicleAccess(record,'query',0,seatId);
 if(!access||Math.hypot(player.r-access.outside.r,player.c-access.outside.c)>1.1||!_civilianTripDoorPath({npc:player,carId:record.presentationId},player.r,player.c,access.outside.r,access.outside.c)){showToast('Подойди к выбранной двери со свободной стороны','🚪',1800);return true;}
 const occupant=kind==='traffic'&&seatId==='front_left'?_npcVehicleOccupant(car):null,npc=occupant?.npc,now=performance.now(),token=`hijack_${Date.now()}_${record.sourceId}`;
 const ambient=_ambientTrafficDrivers.get(car),trip=typeof _civilianTripForCar==='function'?_civilianTripForCar(car):_civilianTrip?.car===car?_civilianTrip:null;
 if(npc&&(ambient?.phase==='board'||trip?.phase==='board')){showToast('Водительское место занято','🚫',1800);return true;}
 const seatedBinding=npc?{ambient:_ambientTrafficDrivers.get(car),trip:typeof _civilianTripForCar==='function'?_civilianTripForCar(car):_civilianTrip?.car===car?_civilianTrip:null,nativePlan:car._civilianNativePlan,plan:npc._civilianPlan}:null;
 let drop=access.outside;if(npc){for(const sign of [1,-1]){const p={r:access.outside.r+Math.sin(+car.ang||0)*.45*sign,c:access.outside.c+Math.cos(+car.ang||0)*.45*sign};if(_civilianTripDoorPath({npc,carId:record.presentationId},npc.r,npc.c,p.r,p.c)){drop=p;break;}}}
 const seq={token,eventId:token,native:true,sourceCarId:record.sourceId,vehicleId:record.presentationId,carId:record.presentationId,seatId,victimId:npc?_threeNpcEntityId(npc):null,phase:'approach',progress:0,startedAt:now,duration:1,kind,r:kind==='quest'?car.y:car.r,c:kind==='quest'?car.x:car.c,ang:+car.ang||0};
 if(npc){npc._vehicleHijackControlled=true;npc._vehicleHijack={eventId:token,phase:'seated',progress:0,carId:record.presentationId,seatId,side:-1};const a=_ambientTrafficDrivers.get(car);if(a)_ambientTrafficRelease(a,'hijack-extraction');const trip=seatedBinding.trip;if(trip)_civilianTripRelease(trip,'hijack-extraction');_clearNpcRoute(npc);npc.walking=false;}
 if(kind==='traffic'){car.vr=car.vc=0;car._hijackPending=now;}
 _threeVehicleEntrySequence=seq;_nativeVehicleAction={seq,record,npc,access,drop,done,seatedBinding,phaseAt:now,blockedSince:0,extracted:false};return true;
}
function _beginNativeVehicleExit(qc,reason='manual',retake=null){
 if(!_walkRendererActive()||_nativeVehicleExitBypass)return false;if(_nativeVehicleAction)return true;
 if(!qc||Math.hypot(qc.vx||0,qc.vy||0)>.3)return false;
 const record={car:qc,kind:'quest',sourceId:String(qc.id),presentationId:`quest_${qc.id}`},seatId=myIsPassenger?_walkVehicleSeatId:'front_left',access=_nativeVehicleAccess(record,'query',0,seatId);if(!access)return true;
 const now=performance.now(),seq={native:true,sourceCarId:record.sourceId,token:`exit_${Date.now()}`,vehicleId:record.presentationId,carId:record.presentationId,seatId,phase:retake?'pulled_out':'exit',progress:0,startedAt:now,duration:1,kind:'quest',r:qc.y,c:qc.x,ang:+qc.ang||0};
 _threeVehicleEntrySequence=seq;_nativeVehicleAction={seq,record,access,exit:true,retake,phaseAt:now,blockedSince:0,done(){_nativeVehicleExitBypass=true;try{exitCar(reason);}finally{_nativeVehicleExitBypass=false;}}};return true;
}
function _npcVehicleHijackTick(dt,now){
 if(_nativeVehicleExitReceipt&&now-_nativeVehicleExitReceipt.sentAt>5000){if(_walkVehicleLastAction?.requestId===_nativeVehicleExitReceipt.requestId){_walkVehicleLastAction.pending=false;_walkVehicleLastAction.accepted=false;_walkVehicleLastAction.reason='server-timeout';}_nativeVehicleExitReceipt=null;}
 if(_walkVehicleInputAt&&now-_walkVehicleInputAt>300){_keyState.up=_keyState.down=_keyState.left=_keyState.right=false;_handbrakeActive=false;_walkVehicleInputAt=0;}
 const s=_nativeVehicleAction;if(!s)return;const {seq,record,npc}=s;
 if(myDead||_vehicleIsWrecked(record.car)||record.kind==='traffic'&&!CARS.includes(record.car)){_nativeVehicleActionEnd('interrupted');return;}
 if(record.kind==='traffic'){record.car.vr=record.car.vc=0;record.car._hijackPending=now;}else{record.car.vx=record.car.vy=0;}
 const access=_nativeVehicleAccess(record,'query',seq.progress,seq.seatId);if(!access)return;s.access=access;player.ang=seq.ang;player.walking=false;
 if(seq.phase==='approach'){
  if(_nativeVehicleStep(player,access.outside,dt,record)){seq.phase='open';seq.progress=0;s.phaseAt=now;}
 }else if(seq.phase==='open'){
  seq.progress=Math.min(1,(now-s.phaseAt)/250);_nativeVehicleAccess(record,'board',seq.progress*.3,seq.seatId);
  if(seq.progress>=1){seq.phase=npc?'pull_driver':'enter';seq.progress=0;s.phaseAt=now;s.length=Math.hypot((npc||player).r-(npc?s.drop.r:access.seat.r),(npc||player).c-(npc?s.drop.c:access.seat.c));}
 }else if(seq.phase==='pull_driver'){
  npc.ang=seq.ang;const arrived=_nativeVehicleStep(npc,s.drop,dt,record,true);seq.progress=1-Math.min(1,Math.hypot(npc.r-s.drop.r,npc.c-s.drop.c)/(s.length||1));
  npc._vehicleHijack={eventId:seq.eventId,phase:'pulled',progress:seq.progress,carId:record.presentationId,seatId:seq.seatId,side:-1};_nativeVehicleAccess(record,'exit',seq.progress,seq.seatId);
  if(arrived){delete npc._vehicleCorpseSeat;delete npc._civilianTripRiding;_npcVehicleOccupants.delete(record.car);s.extracted=true;record.car._driverEjected=true;seq.phase='enter';seq.progress=0;s.length=Math.hypot(player.r-access.seat.r,player.c-access.seat.c);delete npc._vehicleHijackControlled;npc._vehicleHijack={...npc._vehicleHijack,phase:'released',progress:1};
   const event={eventId:seq.eventId,carId:record.presentationId,r:npc.r,c:npc.c,playerR:player.r,playerC:player.c};_npcHijackCars.set(record.presentationId,{sourceCar:record.car,event});if(_npcHijackCars.size>128)_npcHijackCars.delete(_npcHijackCars.keys().next().value);if(typeof _npcVehicleHijackReleased==='function')_npcVehicleHijackReleased(npc,event,now);
  }
 }else if(seq.phase==='enter'){
  const arrived=_nativeVehicleStep(player,access.seat,dt,record,true);seq.progress=1-Math.min(1,Math.hypot(player.r-access.seat.r,player.c-access.seat.c)/(s.length||1));_nativeVehicleAccess(record,'board',seq.progress,seq.seatId);
  if(arrived){const done=s.done;_nativeVehicleActionEnd();_threeVehicleEntryBypass=true;try{done();}finally{_threeVehicleEntryBypass=false;}}
 }else if(seq.phase==='exit'||seq.phase==='pulled_out'){
  s.length??=Math.hypot(player.r-access.outside.r,player.c-access.outside.c);const arrived=_nativeVehicleStep(player,access.outside,dt,record,true);seq.progress=1-Math.min(1,Math.hypot(player.r-access.outside.r,player.c-access.outside.c)/(s.length||1));_nativeVehicleAccess(record,'exit',seq.progress,seq.seatId);
  if(arrived){const done=s.done,retake=s.retake;_nativeVehicleActionEnd();done();if(retake){retake.status=ws&&ws.readyState===1?'pending':'complete';retake.awaitingExit=retake.status==='pending';retake.exitSentAt=now;}else if(ws&&ws.readyState===1&&_walkVehicleLastAction?.action==='exit'){_walkVehicleLastAction.pending=true;_nativeVehicleExitReceipt={requestId:_walkVehicleLastAction.requestId,canonicalCarId:record.sourceId,sentAt:now};}}
 }
}
function _npcVehicleHijackClaimed(car,questId,pending=false){if(!car)return;const id=_threeVehicleEntityId(car),item=_npcHijackCars.get(id);if(item)item.questId=String(questId);if(_walkVehicleLastAction?.sourceCarId===id){_walkVehicleLastAction.presentationCarId=`quest_${questId}`;_walkVehicleLastAction.pending=!!pending;_walkVehicleLastAction.accepted=true;}}
function _npcVehicleHijackClaimDenied(car,reason){if(car&&_walkVehicleLastAction?.sourceCarId===_threeVehicleEntityId(car)){_walkVehicleLastAction.pending=false;_walkVehicleLastAction.accepted=false;_walkVehicleLastAction.reason=reason||'server-rejected';_walkVehicleLastAction.presentationCarId=_threeVehicleEntityId(car);}}
function _npcVehicleHijackExitReply(d){
 if(_nativeVehicleExitReceipt?.canonicalCarId===String(d.car_id)){if(_walkVehicleLastAction?.requestId===_nativeVehicleExitReceipt.requestId){_walkVehicleLastAction.accepted=!!d.ok;_walkVehicleLastAction.pending=false;_walkVehicleLastAction.reason=d.ok?'':d.reason||'server-rejected';}_nativeVehicleExitReceipt=null;}
 for(const state of _npcRetakeEvents.values())if(state.awaitingExit&&state.questId===String(d.car_id)){state.status=d.ok?'complete':'unavailable';state.awaitingExit=false;if(!d.ok){const qc=questCars.get(state.questId);if(qc&&!['not_driver','gone'].includes(d.reason)){myDrivingCarId=state.questId;myIsPassenger=false;qc.driver_uid=String(QP.uid);}return true;}}return false;
}
function _npcVehicleHijackRetake(n,event,dt,now=performance.now()){
 if(_npcVehicleDead(n))return {status:'unavailable',reason:'dead'};
 let state=_npcRetakeEvents.get(event.eventId);if(state?.awaitingExit&&now-state.exitSentAt>5000){state.status='unavailable';state.awaitingExit=false;}if(state?.status==='complete'||state?.status==='unavailable'||state?.awaitingExit)return {status:state.status};
 const claim=_npcHijackCars.get(event.carId),id=claim?.questId,qc=id&&questCars.get(id);
 if(!qc||myDrivingCarId!==id||myIsPassenger||String(qc.owner_uid)!==String(QP.uid)||Math.hypot(qc.vx||0,qc.vy||0)>.3)return {status:'unavailable',reason:'car-left-or-not-owned'};
 const record={car:qc,kind:'quest',presentationId:`quest_${id}`},access=_nativeVehicleAccess(record);if(!access)return {status:'pending',reason:'vehicle-loading'};
 if(Math.hypot(n.r-access.outside.r,n.c-access.outside.c)>.2)return {status:'pending',target:{...access.outside}};
 if(_nativeVehicleAction)return {status:state&&_nativeVehicleAction.retake===state?'pulling':'pending'};
 state={status:'pulling',questId:id};_npcRetakeEvents.set(event.eventId,state);if(_npcRetakeEvents.size>128)_npcRetakeEvents.delete(_npcRetakeEvents.keys().next().value);_beginNativeVehicleExit(qc,'counter-hijack',state);return {status:'pulling'};
}
// NPC_VEHICLE_HIJACK_END
