// Source-world ambulance helpers. Real NPC identities own health; these helpers
// only move the vehicle/crew and advance an arrival-gated medical operation.
function _ambulanceParkingWorkAllowed() {
  const frame=typeof prevT==='number'?prevT:Math.floor(performance.now()/16.667);
  if(_ambulanceParkingWorkAllowed.frame!==frame){_ambulanceParkingWorkAllowed.frame=frame;_ambulanceParkingWorkAllowed.used=0;}
  return _ambulanceParkingWorkAllowed.used++<4;
}
function _ambulanceCrewAvailable(n,now=performance.now()) {
  return !!n&&!n.dead&&n.alive!==false&&+n.hp>0&&!n._medicalDowned&&
    !n._evacuated&&!n._corpseExpired&&!(n._knockedUntil>now);
}
function _ambulanceNativeHospital(v) {
  if(typeof _walkTrafficNavigationResolver!=='function')return true;
  let result=null;try{result=_walkTrafficNavigationResolver({mode:'hospital',carId:`service_${v.id}`,from:{r:v.y,c:v.x}});}catch{}
  if(!result?.bay||!result?.door)return false;
  const sameHospital=v._nativeHospital?.hospitalId===result.hospitalId&&Number.isFinite(v.homeR)&&Number.isFinite(v.homeC);
  v._nativeHospital=result;
  if(!sameHospital){v.homeR=result.bay.r;v.homeC=result.bay.c;v.homeAngle=result.bay.angle||0;}
  v.hospitalId=result.hospitalId;return true;
}
function _ambulanceNativeBays() {
  let state=_ambulanceNativeBays.state;
  if(!state){
    const seed={id:'ambulance_depot',y:HOSPITAL_R,x:HOSPITAL_C};
    if(!_ambulanceNativeHospital(seed))return [];
    const offsets=[0,2.6,-2.6,5.2,-5.2,7.8,-7.8],candidates=[];
    for(const side of [0,1.5,-1.5])for(const distance of offsets){
      const b=seed._nativeHospital.bay,angle=b.angle||0;
      candidates.push({r:b.r+Math.sin(angle)*distance+Math.cos(angle)*side,
        c:b.c+Math.cos(angle)*distance-Math.sin(angle)*side,angle});
    }
    state=_ambulanceNativeBays.state={hospital:seed._nativeHospital,candidates,index:0,bays:[]};
  }
  // At most four native footprints per frame; never stack missing slots at a door.
  while(state.index<state.candidates.length&&state.bays.length<AMBULANCE_FLEET_SIZE&&_ambulanceParkingWorkAllowed()){
    const b=state.candidates[state.index++];
    if(Math.hypot(state.hospital.bay.r-b.r,state.hospital.bay.c-b.c)<2.3||state.bays.some(p=>Math.hypot(p.r-b.r,p.c-b.c)<2.3))continue;
    const result=_walkTrafficNavigationResolver({carId:'service_ambulance_depot',from:b,to:b,roadsOnly:true,halfLength:1.04,halfWidth:.5});
    if(result?.clear)state.bays.push({...b,hospitalId:state.hospital.hospitalId,nativeHospital:state.hospital});
  }
  return state.bays;
}
function _ambulanceNativeSceneParking(v,targetR,targetC,now=performance.now()) {
  const key=`${targetR.toFixed(1)}:${targetC.toFixed(1)}`;
  let job=v._ambulanceParkingJob;
  if(!job||job.key!==key)job=v._ambulanceParkingJob={key,index:0,choices:[],best:null};
  if(job.best){
    if(_walkTrafficNavigationResolver({carId:`service_${v.id}`,from:job.best,to:job.best,roadsOnly:true,halfLength:1.04,halfWidth:.5})?.clear===true)return job.best;
    job.best=null;job.index=0;
  }
  if(job.retryAt>now)return null;
  while(job.index<64&&_ambulanceParkingWorkAllowed()){
    const index=job.index++,a=(index%16)*Math.PI/8,radius=2.8+Math.floor(index/16)*1.05;
    const r=targetR+Math.sin(a)*radius,c=targetC+Math.cos(a)*radius;
    const angle=Math.atan2(r-v.y,c-v.x),p={r,c,angle};
    if(_walkTrafficNavigationResolver({carId:`service_${v.id}`,from:p,to:p,roadsOnly:true,halfLength:1.04,halfWidth:.5})?.clear!==true)continue;
    const rearR=r-Math.sin(angle)*1.48,rearC=c-Math.cos(angle)*1.48;
    if(!_ambulanceCrewBodyClear(v,rearR,rearC))continue;
    // This is only an endpoint. The vehicle route and bearer route must still
    // physically reach their goals; no direct reachability is assumed here.
    job.best={r,c,angle};return job.best;
  }
  if(job.index>=64){job.retryAt=now+1500;job.index=0;}
  return null;
}
function _ensureAmbulanceCrew(v) {
  if(v._ambulanceCrewInitialized)return;
  v._ambulanceCrewInitialized=true;
  const seats=['front_left','front_right','rear_left'];
  const crew=seats.map((seat,index)=>({
    id:`${v.id}_crew_${index}`,role:'medic',_arcKey:'medic',
    name:index===0?'Водитель скорой':index===1?'Старший врач':'Врач скорой',
    r:v.y,c:v.x,tr:v.y,tc:v.x,ang:v.ang||0,hp:100,max_hp:100,alive:true,dead:false,
    speed:_npcPacedSpeed(1.9),walkPhase:index*Math.PI,walking:false,visible:false,
    _medicalCrewVehicleId:v.id,_medicalCrewSeat:seat,_inVehicle:true,_vehicleId:v.id,
    slot:index-1,behavior:'ambulance_crew',look:{gender:index===2?1:0,skin:index%3,
      body:1,face:index+1,hair:index+1,hat:0,suit:index===0?'#b9d2da':'#e9f4f6'},
  }));
  v._ambulanceDriver=crew[0];v._medicalCrew=crew.slice(1);
  NPCS.push(...crew);
}
function _syncAmbulanceSeatedCrew(v) {
  for(const n of [v._ambulanceDriver,...(v._medicalCrew||[])]){
    if(!n||!n._inVehicle)continue;
    // Preserve a dead occupant at the stopped car; never revive a seat model.
    if(!n.dead){n.r=v.y;n.c=v.x;n.ang=v.ang||0;}
    n.walking=false;
  }
}
function _ambulanceCanDrive(v,now=performance.now()) {
  return _ambulanceCrewAvailable(v?._ambulanceDriver,now)&&
    v._ambulanceDriver._inVehicle===true&&v._ambulanceDriver._vehicleId===v.id&&
    v._medicalCrew?.length===2&&v._medicalCrew.every(n=>_ambulanceCrewAvailable(n,now)&&n._inVehicle);
}
function _ambulanceRoute(v,toR,toC,now=performance.now(),arrivalAngle=null) {
  const resolver=typeof _walkTrafficNavigationResolver==='function'?_walkTrafficNavigationResolver:null;
  if(!resolver){_setVehicleRoute(v,v.y,v.x,toR,toC);return !!v.path?.length;}
  const key=`${v.id}:${toR.toFixed(3)}:${toC.toFixed(3)}`;
  const reset=v._ambulanceNativeRouteKey!==key;
  if(reset){v._ambulanceNativeRouteKey=key;v._ambulanceNativeRouteFrom={r:v.y,c:v.x,angle:v.ang||0};}
  let result=null;
  try{result=resolver({mode:'route',requestId:key,reset,carId:`service_${v.id}`,
    from:v._ambulanceNativeRouteFrom,to:{r:toR,c:toC,angle:Number.isFinite(arrivalAngle)?arrivalAngle:v.ang||0},
    roadsOnly:true,halfLength:1.04,halfWidth:.5});}catch{}
  v.finalTarget={y:toR,x:toC};v._ambulanceRouteGoal={r:toR,c:toC,angle:arrivalAngle};
  v._ambulanceRoutePending=result?.status==='pending'||!result;
  if(result?.status==='ready'&&Array.isArray(result.points)&&result.points.length){
    v.path=result.points;v.pathIdx=0;v._ambulanceRoutePending=false;return true;
  }
  v.path=[];v.pathIdx=0;
  if(result?.status==='blocked')v._ambulanceNativeRouteKey=null;
  return false;
}
function _ambulanceVehicleStep(v,dt) {
  const now=performance.now();
  if(!_ambulanceCanDrive(v,now)){v.speed=0;v._ambulanceBlockedReason='driver-or-crew-unavailable';return false;}
  if(v._ambulanceRoutePending&&v._ambulanceRouteGoal)
    _ambulanceRoute(v,v._ambulanceRouteGoal.r,v._ambulanceRouteGoal.c,now,v._ambulanceRouteGoal.angle);
  const target=v.path?.[v.pathIdx||0];
  if(!target){
    if(v._ambulanceRoutePending||!v.finalTarget||Math.hypot(v.y-v.finalTarget.y,v.x-v.finalTarget.x)>.38)return false;
    const desired=v._ambulanceRouteGoal?.angle;
    if(Number.isFinite(desired)){
      const delta=Math.atan2(Math.sin(desired-(v.ang||0)),Math.cos(desired-(v.ang||0)));
      if(Math.abs(delta)>.035){
        const angle=(v.ang||0)+Math.max(-Math.min(.08,dt)*2.4,Math.min(Math.min(.08,dt)*2.4,delta));
        const from={r:v.y,c:v.x,angle:v.ang||0},to={r:v.y,c:v.x,angle};
        if(typeof _walkTrafficNavigationResolver==='function'&&_walkTrafficNavigationResolver({carId:`service_${v.id}`,from,to,roadsOnly:true,halfLength:1.04,halfWidth:.5})?.clear!==true)return false;
        v.ang=angle;_syncAmbulanceSeatedCrew(v);return false;
      }
    }return true;
  }
  const dr=target.r-v.y,dc=target.c-v.x,d=Math.hypot(dr,dc);
  if(d<.18){v.pathIdx=(v.pathIdx||0)+1;return false;}
  const desired=Math.atan2(dr,dc),old=v.ang||0;
  const delta=Math.atan2(Math.sin(desired-old),Math.cos(desired-old));
  const angle=old+Math.max(-dt*2.4,Math.min(dt*2.4,delta));
  const step=Math.abs(delta)>.65?0:Math.min(d,Math.max(0,v.speed)*Math.min(.08,Math.max(0,dt)));
  const r=v.y+dr/d*step,c=v.x+dc/d*step;
  let clear=false;
  if(typeof _walkTrafficNavigationResolver==='function'){
    let result=null;try{result=_walkTrafficNavigationResolver({carId:`service_${v.id}`,
      from:{r:v.y,c:v.x,angle:old},to:{r,c,angle},roadsOnly:true,halfLength:1.04,halfWidth:.5});}catch{}
    clear=result?.clear===true;v._ambulanceBlockedReason=clear?'':result?.reason||'native-not-ready';
  }else clear=_vehicleRoadPassable(r,c)&&_serviceVehicleFootprintClear(v,r,c,angle)&&!_vehicleBlockedByCar(v,r,c);
  if(!clear){v._ambulanceBlockedReason||='road-or-body-blocked';return false;}
  if(v.state==='returning'&&step>0){
    v._ambulanceReturnDistance=(v._ambulanceReturnDistance||0)+step;
    if(v._ambulanceReturnDistance>.05)v._ambulanceReturnMoveObserved=true;
  }
  v.y=r;v.x=c;v.ang=angle;v._ambulanceBlockedReason='';_syncAmbulanceSeatedCrew(v);return false;
}
function _ambulanceCrewPointClear(v,r,c) {
  if(typeof _walkNpcNavigationResolver==='function'){
    const result=_walkNpcNavigationResolver({r,c,ignoreVehicleId:`service_${v.id}`});
    return !!result&&!result.blocked&&!(result.depth>.025);
  }
  return npcPassable(r,c);
}
function _ambulanceCrewBodyClear(v,r,c) {
  // Keep both bearers and the stretcher off obstacles, not just its midpoint.
  return _ambulanceCrewPointClear(v,r,c)&&_ambulanceCrewPointClear(v,r+.55,c)&&
    _ambulanceCrewPointClear(v,r-.55,c)&&_ambulanceCrewPointClear(v,r,c+.55)&&
    _ambulanceCrewPointClear(v,r,c-.55);
}
function _ambulanceCrewMove(v,r,c,dt,now) {
  const scene=v._medicalScene,actor=scene.routeActor||(scene.routeActor={
    r:scene.centerR,c:scene.centerC,walkPhase:0,ang:scene.ang,walking:false});
  const pass=(rr,cc)=>_ambulanceCrewBodyClear(v,rr,cc);
  const distance=Math.hypot(r-actor.r,c-actor.c);
  actor.walking=false;
  if(distance<=.32)return true;
  const speed=_npcPacedSpeed(scene.phase==='returning'?1.55:1.9),step=Math.min(distance,speed*Math.min(.08,dt));
  const nr=actor.r+(r-actor.r)/distance*step,nc=actor.c+(c-actor.c)/distance*step;
  if(now>=(scene.directProbeAt||0)||Math.hypot(r-(scene.directR??r),c-(scene.directC??c))>.4){
    scene.directClear=_npcPathPassable(actor.r,actor.c,r,c,pass);
    scene.directProbeAt=now+900;scene.directR=r;scene.directC=c;
  }
  if(scene.directClear&&_npcPathPassable(actor.r,actor.c,nr,nc,pass)){
    actor.ang=Math.atan2(r-actor.r,c-actor.c);actor.r=nr;actor.c=nc;actor.walking=true;actor._route=null;
  }else{
    if(!actor._route?.length&&now>=(scene.routeRetryAt||0)){
      _planNpcRouteTo(actor,r,c,pass,.38,1800,'ambulance-bearers');
      if(!actor._routeSearchPending)scene.routeRetryAt=now+900;
    }
    const result=_npcAdvanceRoute(actor,Math.min(.08,dt),speed,pass);
    if(result==='blocked'||result==='arrived'){actor._route=null;scene.routeRetryAt=now+250;}
  }
  scene.centerR=actor.r;scene.centerC=actor.c;scene.ang=actor.ang;
  _setAmbulanceCrewPose(v,actor.r,actor.c,actor.ang,actor.walking,scene.phase==='returning',dt);
  return Math.hypot(r-actor.r,c-actor.c)<=.32;
}
function _ambulancePatientMovementLocked(patient) {
  return !!patient&&(patient._ambulanceLoading===true||patient._carriedByAmbulance===true||patient._ambulanceInTransit===true);
}
function _ambulanceSetStretcherBodyOwnership(scene,patient,owned) {
  const stretcherOwnsBody=!!owned;
  if(scene)scene.bodyVisible=stretcherOwnsBody;
  if(patient)patient._carriedByAmbulance=stretcherOwnsBody;
  return stretcherOwnsBody;
}
function _ambulanceStartBodyCrew(v,now) {
  if(!_ambulanceNeedsBodyCrew(v))return false;
  _ensureAmbulanceCrew(v);
  if(!_ambulanceCanDrive(v,now)||!v._medicalCrew.every(n=>_ambulanceCrewAvailable(n,now)))return false;
  const target=_ambulancePatientPosition(v);
  if(!target)return false;
  if(!_ambulanceReadyToDeploy(v,target)){
    v.state='go_to_scene';v.speed=AMBULANCE_RESPONSE_SPEED;
    _rerouteAmbulance(v,now,'deploy-before-vehicle-arrival');return false;
  }
  const ang=v.ang||0,rearR=v.y-Math.sin(ang)*1.48,rearC=v.x-Math.cos(ang)*1.48;
  if(!_ambulanceCrewBodyClear(v,rearR,rearC)){
    v._ambulanceBlockedReason='rear-door-blocked';return false;
  }
  const approachAng=Math.atan2(target.r-rearR,target.c-rearC);
  v._medicalScene={active:true,startedAt:now,phaseStartedAt:now,phase:'deploying',
    targetR:target.r,targetC:target.c,rearR,rearC,centerR:rearR,centerC:rearC,ang:approachAng,
    deployMs:700,assessMs:650,liftMs:850,loadMs:900,sealMs:850,
    approachMs:0,returnMs:0,total:0,approachAng,returnAng:approachAng+Math.PI,
    liftProgress:0,loadProgress:0,sealProgress:0,stretcherVisible:true,bodyVisible:false};
  // Entry/exit are bounded door transitions; travel begins at the real rear door.
  for(const n of v._medicalCrew){n._inVehicle=false;n.visible=true;n.action='deploying';}
  _setAmbulanceCrewPose(v,rearR,rearC,approachAng,false,false,0);
  const patient=v.payload.npc;patient._ambulanceLoading=true;_ambulanceSetStretcherBodyOwnership(v._medicalScene,patient,false);
  v.speed=0;v.path=[];v.pathIdx=0;v.finalTarget=null;v._ambulanceRoutePending=false;
  v.state='medical_response';v.workUntil=Infinity;return true;
}
function _ambulanceMedicalAbort(v,reason) {
  const scene=v._medicalScene,patient=v.payload?.npc;
  if(patient&&scene&&patient._carriedByAmbulance){
    patient.r=scene.centerR;patient.c=scene.centerC;
    if('x'in patient)patient.x=scene.centerC;if('y'in patient)patient.y=scene.centerR;
    if(patient.dead){patient._deathR=scene.centerR;patient._deathC=scene.centerC;}
  }
  if(patient){_ambulanceSetStretcherBodyOwnership(scene,patient,false);patient._ambulanceLoading=false;
    if(!patient._ambulanceInTransit){patient._evacuated=false;patient._ambulanceDispatched=false;}}
  if(scene){scene.active=false;scene.bodyVisible=false;scene.stretcherVisible=false;}
  for(const n of v._medicalCrew||[]){n.walking=false;n._medicalCrewWalking=false;n.carrying=false;n.action='interrupted';n._medicalBoardPhase='';}
  if(!patient?._ambulanceInTransit)v.payload={};
  v.speed=0;v.state='ambulance_disabled';v._ambulanceBlockedReason=reason;
}
function _ambulanceUpdateBodyCrew(v,dt,now) {
  const scene=v._medicalScene,patient=v.payload?.npc;
  if(!scene?.active||!patient)return false;
  v.speed=0;
  if(!_ambulanceCrewAvailable(v._ambulanceDriver,now)||
    !(v._medicalCrew?.length===2&&v._medicalCrew.every(n=>_ambulanceCrewAvailable(n,now)))){
    _ambulanceMedicalAbort(v,'medical-crew-unavailable');return false;
  }
  if(patient._corpseExpired||!patient.dead&&!patient._medicalDowned&&+patient.hp>0){
    _ambulanceMedicalAbort(v,'patient-no-longer-casualty');return false;
  }
  const advance=phase=>{scene.phase=phase;scene.phaseStartedAt=now;scene.routeActor=null;
    scene.routeRetryAt=0;scene.directProbeAt=0;};
  const age=Math.max(0,now-scene.phaseStartedAt);
  if(scene.phase==='deploying'){
    for(const n of v._medicalCrew){n._medicalBoardPhase='exit';n._medicalBoardProgress=Math.min(1,age/scene.deployMs);}
    if(age>=scene.deployMs)advance('approaching');
  }else if(scene.phase==='approaching'){
    for(const n of v._medicalCrew)n._medicalBoardPhase='';
    const target=_ambulancePatientPosition(v);
    if(!target)return false;
    scene.targetR=target.r;scene.targetC=target.c;
    if(_ambulanceCrewMove(v,target.r,target.c,dt,now))advance('assessing');
  }else if(scene.phase==='assessing'){
    const target=_ambulancePatientPosition(v);
    if(!target||Math.hypot(scene.centerR-target.r,scene.centerC-target.c)>.5)advance('approaching');
    else if(age>=scene.assessMs)advance('lifting');
  }else if(scene.phase==='lifting'){
    scene.liftProgress=Math.min(1,age/scene.liftMs);
    _ambulanceSetStretcherBodyOwnership(scene,patient,scene.liftProgress>.42);
    if(age>=scene.liftMs)advance('returning');
  }else if(scene.phase==='returning'){
    _ambulanceSetStretcherBodyOwnership(scene,patient,true);
    if(_ambulanceCrewMove(v,scene.rearR,scene.rearC,dt,now))advance('loading');
  }else if(scene.phase==='loading'){
    // Loading starts only with the actual bearers back at the vehicle door.
    if(Math.hypot(scene.centerR-scene.rearR,scene.centerC-scene.rearC)>.38){advance('returning');return false;}
    scene.loadProgress=Math.min(1,age/scene.loadMs);
    if(age>=scene.loadMs)advance('sealing');
  }else if(scene.phase==='sealing'){
    scene.sealProgress=Math.min(1,age/scene.sealMs);
    for(const n of v._medicalCrew){n._medicalBoardPhase='enter';n._medicalBoardProgress=scene.sealProgress;}
    if(age>=scene.sealMs){
      scene.active=false;scene.phase='loaded';scene.bodyVisible=false;scene.stretcherVisible=false;
      for(const n of v._medicalCrew){n._inVehicle=true;n.visible=false;n.walking=false;n._medicalCrewWalking=false;n.carrying=false;n.action='seated';n._medicalBoardPhase='';}
      patient._carriedByAmbulance=true;patient._ambulanceLoading=false;
      patient._evacuated=true;patient._evacuatedAt=0;patient._ambulanceInTransit=true;
      _syncAmbulanceSeatedCrew(v);return true;
    }
  }
  if(!['approaching','returning'].includes(scene.phase))
    _setAmbulanceCrewPose(v,scene.centerR,scene.centerC,scene.ang,false,!!patient._carriedByAmbulance,0);
  for(const n of v._medicalCrew){n.action=scene.phase;n.actionProgress=
    scene.phase==='lifting'?scene.liftProgress:scene.phase==='loading'?scene.loadProgress:
    scene.phase==='sealing'?scene.sealProgress:0;}
  return false;
}

// A parking space is not a clinical handoff. Only the verified hospital bay
// connects to this measured pedestrian path; depot slots remain separate.
function _ambulanceHospitalGoal(v) {
  return v.payload?.npc?._ambulanceInTransit&&v._nativeHospital?.bay
    ?v._nativeHospital.bay:{r:v.homeR,c:v.homeC,angle:v.homeAngle||0};
}
function _ambulanceStartDischarge(v,now) {
  const hospital=v._nativeHospital,route=hospital?.footRoute;
  if(!Array.isArray(route)||route.length<2||!_ambulanceCanDrive(v,now)||
    Math.hypot(v.y-hospital.bay.r,v.x-hospital.bay.c)>.55||Math.abs(Math.atan2(Math.sin((v.ang||0)-hospital.bay.angle),Math.cos((v.ang||0)-hospital.bay.angle)))>.06)return false;
  const points=route.map(p=>({r:p.r,c:p.c})),distances=[0];
  for(let i=1;i<points.length;i++)distances.push(distances[i-1]+Math.hypot(points[i].r-points[i-1].r,points[i].c-points[i-1].c));
  if(Math.hypot(points.at(-1).r-hospital.door.r,points.at(-1).c-hospital.door.c)>.05)return false;
  v._medicalScene={active:true,hospitalDischarge:true,phase:'deploying',phaseStartedAt:now,
    centerR:points[0].r,centerC:points[0].c,ang:v.ang||0,points,distances,distance:0,
    length:distances.at(-1),stretcherVisible:true,bodyVisible:true,liftProgress:1,loadProgress:0,sealProgress:0};
  for(const n of v._medicalCrew){n._inVehicle=false;n.visible=true;n._medicalBoardPhase='exit';n._medicalBoardProgress=0;}
  v.state='hospital_discharge';v.speed=0;v.path=[];v.finalTarget=null;
  return true;
}
function _ambulanceDischargePoint(scene,distance) {
  const d=Math.max(0,Math.min(scene.length,distance));
  let i=1;while(i<scene.distances.length-1&&scene.distances[i]<d)i++;
  const a=scene.points[i-1],b=scene.points[i],t=(d-scene.distances[i-1])/Math.max(.0001,scene.distances[i]-scene.distances[i-1]);
  return {r:a.r+(b.r-a.r)*t,c:a.c+(b.c-a.c)*t,ang:Math.atan2(b.r-a.r,b.c-a.c)};
}
function _ambulanceDischargeClear(v,p) {
  return [[0,0],[.18,0],[-.18,0],[0,.18],[0,-.18]].every(([dr,dc])=>_ambulanceCrewPointClear(v,p.r+dr,p.c+dc));
}
function _ambulanceUpdateDischarge(v,dt,now) {
  const scene=v._medicalScene,patient=v.payload?.npc;
  if(!scene?.hospitalDischarge)return false;
  if(!_ambulanceCrewAvailable(v._ambulanceDriver,now)||!v._medicalCrew.every(n=>_ambulanceCrewAvailable(n,now))){
    if(patient){patient._ambulanceInTransit=false;patient._evacuated=false;}
    _ambulanceMedicalAbort(v,'hospital-crew-unavailable');return false;
  }
  const age=Math.max(0,now-scene.phaseStartedAt),enter=phase=>{scene.phase=phase;scene.phaseStartedAt=now;};
  let walking=false;
  if(scene.phase==='deploying'){
    for(const n of v._medicalCrew){n._medicalBoardPhase='exit';n._medicalBoardProgress=Math.min(1,age/700);}
    if(age>=700){for(const n of v._medicalCrew)n._medicalBoardPhase='';enter('returning');}
  }else if(scene.phase==='returning'||scene.phase==='hospital_return'){
    const back=scene.phase==='hospital_return',step=Math.min(.08,Math.max(0,dt))*_npcPacedSpeed(1.55);
    const next=Math.max(0,Math.min(scene.length,scene.distance+(back?-step:step)));
    const samples=Math.max(1,Math.ceil(Math.abs(next-scene.distance)/.06));let clear=true;
    for(let i=1;i<=samples&&clear;i++)for(const offset of [0,-.34,.34])
      if(!_ambulanceDischargeClear(v,_ambulanceDischargePoint(scene,scene.distance+(next-scene.distance)*i/samples+offset))){clear=false;break;}
    if(clear){walking=Math.abs(next-scene.distance)>.00001;scene.distance=next;v._ambulanceBlockedReason='';}
    else v._ambulanceBlockedReason='hospital-foot-route-obstructed';
    if(!back&&scene.distance>=scene.length-.001){
      scene.atDoor=true;_completeAmbulanceHospitalDelivery(v,now,'foot-arrival');
      scene.bodyVisible=false;scene.stretcherVisible=false;enter('hospital_return');
    }else if(back&&scene.distance<=.001)enter('sealing');
  }else if(scene.phase==='sealing'){
    for(const n of v._medicalCrew){n._medicalBoardPhase='enter';n._medicalBoardProgress=Math.min(1,age/700);}
    if(age>=700){
      for(const n of v._medicalCrew){n._inVehicle=true;n.visible=false;n.walking=false;n._medicalCrewWalking=false;n.carrying=false;n._medicalBoardPhase='';}
      v._medicalScene=null;_syncAmbulanceSeatedCrew(v);_sendAmbulanceToHospital(v,now,'hospital-handoff-return-to-depot');return true;
    }
  }
  const center=_ambulanceDischargePoint(scene,scene.distance);scene.centerR=center.r;scene.centerC=center.c;scene.ang=center.ang;
  for(let i=0;i<v._medicalCrew.length;i++){
    const n=v._medicalCrew[i],p=_ambulanceDischargePoint(scene,scene.distance+(i?.34:-.34));
    n.r=p.r;n.c=p.c;n.ang=center.ang+(scene.phase==='hospital_return'?Math.PI:0);
    n.walking=walking;n._medicalCrewWalking=walking;n.carrying=scene.bodyVisible;
    n.action=scene.phase==='hospital_return'?'approaching':scene.phase;
    if(walking)n.walkPhase+=Math.max(0,dt)*7;
  }
  if(patient&&scene.bodyVisible){patient.r=center.r;patient.c=center.c;patient._carriedByAmbulance=true;
    if(patient.dead){patient._deathR=center.r;patient._deathC=center.c;}}
  return false;
}
