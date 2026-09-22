// NPC_NATIVE_WATER_ROUTING_START
const _npcNavigationStats={queries:0,solidRefusals:0,waterRefusals:0,egressSteps:0};
let _walkNpcNavigationResolver=null,_walkNpcWaterResolver=null,_npcWaterBypass=0;
let _walkTrafficNavigationResolver=null;
function _npcNavigationAt(r,c){
 _npcNavigationStats.queries++;
 const navigation=_walkNpcNavigationResolver?.({r,c}),water=Number.isFinite(navigation?.depth)?navigation:_walkNpcWaterResolver?.({r,c});
 return {blocked:navigation?.blocked===true,depth:Number.isFinite(water?.depth)?Math.max(0,water.depth):(MAP[Math.floor(r)]?.[Math.floor(c)]===16?1:0)};
}
function _npcRouteWaterDepth(r,c){return _npcNavigationAt(r,c).depth;}
function _npcRouteWalkBlocked(r,c){const sample=_npcNavigationAt(r,c);if(sample.blocked){_npcNavigationStats.solidRefusals++;return true;}if(!_npcWaterBypass&&sample.depth>.025){_npcNavigationStats.waterRefusals++;return true;}return false;}
function _npcWaterEgressPassable(r,c){
 const ri=Math.floor(r),ci=Math.floor(c);
 if(ri<1||ri>=MAP_ROWS-1||ci<1||ci>=MAP_COLS-1||_npcRouteWalkBlocked(r,c))return false;
 // Native water is a swimmable surface during physical egress only. Legacy
 // MAP=16 cannot veto it; the registered native query still vetoes all solids.
 if(MAP[ri][ci]===16&&_walkNpcNavigationResolver){
  return !_inPrisonIslandRestrictedZone(r,c,.35)&&!inArena(ri,ci)&&!inLair(ri,ci);
 }
 return npcPassableForSnitch(r,c);
}
function _npcWaterEscapeDepth(r,c,options){
 if(!options?.bodyDepth)return _npcRouteWaterDepth(r,c);
 const radius=.18;
 return Math.max(_npcRouteWaterDepth(r,c),_npcRouteWaterDepth(r-radius,c-radius),_npcRouteWaterDepth(r-radius,c+radius),_npcRouteWaterDepth(r+radius,c-radius),_npcRouteWaterDepth(r+radius,c+radius));
}
function _npcWaterEgressPath(n,r,c,options){
 const distance=Math.hypot(r-n.r,c-n.c),steps=Math.max(1,Math.ceil(distance/.14));let previous=_npcWaterEscapeDepth(n.r,n.c,options);
 for(let i=1;i<=steps;i++){const next=_npcWaterEscapeDepth(n.r+(r-n.r)*i/steps,n.c+(c-n.c)*i/steps,options);if(next>previous+.002)return false;previous=next;}
 _npcWaterBypass++;try{return _npcPathPassable(n.r,n.c,r,c,_npcWaterEgressPassable)&&(!options?.bodyDepth||typeof _walkNpcNavigationResolver!=='function'||!_walkNpcNavigationResolver({mode:'sweep',from:{r:n.r,c:n.c},to:{r,c},radius:.18})?.blocked);}finally{_npcWaterBypass--;}
}
function _npcWaterSearchStep(n,depth,now,options){
 if(typeof _npcReserveRouteWork==='function'&&!_npcReserveRouteWork(performance.now(),n))return;
  try {
 const deadline=performance.now()+4,expired=()=>performance.now()>=deadline||typeof _npcRouteWorkExpired==='function'&&_npcRouteWorkExpired();
 let search=n._waterEscapeSearch;if(!search||Math.hypot(n.r-search.r,n.c-search.c)>.01)search=n._waterEscapeSearch={r:n.r,c:n.c,depth,radius:.5,index:0,candidate:null};
 while(search.radius<=12&&!expired()){
  if(!search.candidate){const angle=search.index*Math.PI*2/24,r=search.r+Math.sin(angle)*search.radius,c=search.c+Math.cos(angle)*search.radius,d=_npcWaterEscapeDepth(r,c,options);search.index++;if(search.index>=24){search.index=0;search.radius+=.5;}
   if(d>=search.depth-.02)continue;search.candidate={r,c,steps:Math.max(1,Math.ceil(Math.hypot(r-search.r,c-search.c)/.14)),i:1,previous:search.depth};
  }
  const candidate=search.candidate;let valid=true;
  while(candidate.i<=candidate.steps&&!expired()){
   const t=candidate.i/candidate.steps,r=search.r+(candidate.r-search.r)*t,c=search.c+(candidate.c-search.c)*t,d=_npcWaterEscapeDepth(r,c,options);
   if(d>candidate.previous+.002){valid=false;break;}
   _npcWaterBypass++;try{valid=_npcBodyPassable(r,c,_npcWaterEgressPassable);}finally{_npcWaterBypass--;}
   if(valid&&options?.canStep)valid=options.canStep(n,r,c);
   if(valid&&options?.bodyDepth&&typeof _walkNpcNavigationResolver==='function'){
    const previousT=(candidate.i-1)/candidate.steps;
    valid=!_walkNpcNavigationResolver({mode:'sweep',from:{r:search.r+(candidate.r-search.r)*previousT,c:search.c+(candidate.c-search.c)*previousT},to:{r,c},radius:.18})?.blocked;
   }
   if(!valid)break;candidate.previous=d;candidate.i++;
  }
  if(!valid){search.candidate=null;continue;}
  if(candidate.i>candidate.steps){n._waterEscapeTarget={r:candidate.r,c:candidate.c,depth:candidate.previous};n._waterEscapeSearch=null;_clearNpcRoute(n);return;}
 }
 if(search.radius>12&&!search.candidate){n._waterEscapeSearch=null;n._waterEscapeRetryAt=now+3000;}
  } finally { if(typeof _npcFinishRouteWork==='function')_npcFinishRouteWork(); }
}

function _npcWaterEscape(n,dt,now,options){
 if(!n||n.dead||n.alive===false||n._civilianTrip||n._civilianTripRiding||n._residentIndoors||n._interiorId||n.interior_id||n._insideBuilding||n._inVehicle||n._inCar||n.vehicleId||n.vehicle_id||n._policeCuffed||n._medicalDowned||n._carriedByAmbulance||n._evacuated||n._knockedUntil>now||n._meleeStunnedUntil>now||n._empireDownUntil>now||n._empireHospitalUntil>Date.now())return false;
 const special=n._uniqueNpc||n._said||n._empireBoss||n._empireCrew||n._gang||n._guard;
 if(special&&typeof _walkNpcNavigationResolver!=='function')return false;
 const depth=_npcWaterEscapeDepth(n.r,n.c,options);if(depth<=.025){if(n._waterEscaping)_clearNpcRoute(n);n._waterEscaping=false;n._waterEscapeTarget=null;n._waterEscapeSearch=null;return false;}
 n._waterEscaping=true;
 // Pause locomotion recovery, not the boss's identity, orders or mission.
 // Otherwise time spent swimming can be mistaken for a stuck land route.
 if(special&&typeof _pauseEmpireMovementWatch==='function')_pauseEmpireMovementWatch(n,now);
 // An existing wet resident walks/swims back physically; collision recovery must not snap it.
 if(!n._waterEscapeTarget&&(n._waterEscapeSearch||now>=(n._waterEscapeRetryAt||0)))_npcWaterSearchStep(n,depth,now,options);
 const target=n._waterEscapeTarget;if(!target){n.walking=false;return true;}
 const distance=Math.hypot(target.r-n.r,target.c-n.c);if(distance<.03){n._waterEscapeTarget=null;n._waterEscapeRetryAt=0;return true;}
 const step=Math.min(distance,Math.min(.1,Math.max(0,dt))*Math.min((Number.isFinite(options?.speed)?Math.max(0,options.speed):_npcEffectiveSpeed(n)),depth>.7?.8:1)),r=n.r+(target.r-n.r)/distance*step,c=n.c+(target.c-n.c)/distance*step;
 if(_npcWaterEgressPath(n,r,c,options)&&(!options?.canStep||options.canStep(n,r,c))){_npcNavigationStats.egressSteps++;n.ang=Math.atan2(r-n.r,c-n.c);n.r=r;n.c=c;n.tr=target.r;n.tc=target.c;n.walking=step>0;n.walkPhase=(Number(n.walkPhase)||0)+Math.min(.1,Math.max(0,dt))*7;}
 else{n._waterEscapeTarget=null;n._waterEscapeRetryAt=now+1000;n.walking=false;}
 return true;
}
// Local police use y/x. Reuse the same actor and search queue; temporary r/c
// aliases do not leak into their snapshots or overwrite their patrol targets.
function _npcPoliceWaterEscape(cop,dt,now){
 if(!cop||!cop.alive||typeof _walkNpcNavigationResolver!=='function'||!Number.isFinite(cop.y)||!Number.isFinite(cop.x)||/^(arrest_|boarding|return|disembark)/.test(String(cop._casePhase||'')))return false;
 if(_npcRouteWaterDepth(cop.y,cop.x)<=.025){if(cop._waterEscaping&&typeof _clearPoliceFootRoute==='function')_clearPoliceFootRoute(cop);cop._waterEscaping=false;cop._waterEscapeTarget=null;cop._waterEscapeSearch=null;return false;}
 const oldR=cop.r,oldC=cop.c,hasR=Object.prototype.hasOwnProperty.call(cop,'r'),hasC=Object.prototype.hasOwnProperty.call(cop,'c'),oldTR=cop.tr,oldTC=cop.tc;
 cop.r=cop.y;cop.c=cop.x;
 try{const escaped=_npcWaterEscape(cop,dt,now);if(escaped){cop.y=cop.r;cop.x=cop.c;}return escaped;}
 finally{if(hasR)cop.r=oldR;else delete cop.r;if(hasC)cop.c=oldC;else delete cop.c;if(oldTR===undefined)delete cop.tr;else cop.tr=oldTR;if(oldTC===undefined)delete cop.tc;else cop.tc=oldTC;}
}
// NPC_NATIVE_WATER_ROUTING_END
