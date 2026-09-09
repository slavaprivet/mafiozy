// NPC_NATIVE_WATER_ROUTING_START
const _npcNavigationStats={queries:0,solidRefusals:0,waterRefusals:0,egressSteps:0};
let _walkNpcNavigationResolver=null,_walkNpcWaterResolver=null,_npcWaterBypass=0;
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
function _npcWaterEgressPath(n,r,c){
 const distance=Math.hypot(r-n.r,c-n.c),steps=Math.max(1,Math.ceil(distance/.14));let previous=_npcRouteWaterDepth(n.r,n.c);
 for(let i=1;i<=steps;i++){const next=_npcRouteWaterDepth(n.r+(r-n.r)*i/steps,n.c+(c-n.c)*i/steps);if(next>previous+.002)return false;previous=next;}
 _npcWaterBypass++;try{return _npcPathPassable(n.r,n.c,r,c,_npcWaterEgressPassable);}finally{_npcWaterBypass--;}
}
function _npcWaterSearchStep(n,depth,now){
 if(typeof _npcReserveRouteWork==='function'&&!_npcReserveRouteWork(performance.now(),n))return;
 const deadline=performance.now()+4,expired=()=>performance.now()>=deadline||typeof _npcRouteWorkExpired==='function'&&_npcRouteWorkExpired();
 let search=n._waterEscapeSearch;if(!search||Math.hypot(n.r-search.r,n.c-search.c)>.01)search=n._waterEscapeSearch={r:n.r,c:n.c,depth,radius:.5,index:0,candidate:null};
 while(search.radius<=12&&!expired()){
  if(!search.candidate){const angle=search.index*Math.PI*2/24,r=search.r+Math.sin(angle)*search.radius,c=search.c+Math.cos(angle)*search.radius,d=_npcRouteWaterDepth(r,c);search.index++;if(search.index>=24){search.index=0;search.radius+=.5;}
   if(d>=search.depth-.02)continue;search.candidate={r,c,steps:Math.max(1,Math.ceil(Math.hypot(r-search.r,c-search.c)/.14)),i:1,previous:search.depth};
  }
  const candidate=search.candidate;let valid=true;
  while(candidate.i<=candidate.steps&&!expired()){
   const t=candidate.i/candidate.steps,r=search.r+(candidate.r-search.r)*t,c=search.c+(candidate.c-search.c)*t,d=_npcRouteWaterDepth(r,c);
   if(d>candidate.previous+.002){valid=false;break;}
   _npcWaterBypass++;try{valid=_npcBodyPassable(r,c,_npcWaterEgressPassable);}finally{_npcWaterBypass--;}
   if(!valid)break;candidate.previous=d;candidate.i++;
  }
  if(!valid){search.candidate=null;continue;}
  if(candidate.i>candidate.steps){n._waterEscapeTarget={r:candidate.r,c:candidate.c,depth:candidate.previous};n._waterEscapeSearch=null;_clearNpcRoute(n);return;}
 }
 if(search.radius>12&&!search.candidate){n._waterEscapeSearch=null;n._waterEscapeRetryAt=now+3000;}
}

function _npcWaterEscape(n,dt,now){
 if(!n||n.dead||n._civilianTrip||n._uniqueNpc||n._said||n._empireBoss||n._empireCrew||n._gang||n._guard||n._policeCuffed||n._medicalDowned||n._knockedUntil>now||n._meleeStunnedUntil>now)return false;
 const depth=_npcRouteWaterDepth(n.r,n.c);if(depth<=.025){n._waterEscapeTarget=null;n._waterEscapeSearch=null;return false;}
 // An existing wet resident walks/swims back physically; collision recovery must not snap it.
 if(!n._waterEscapeTarget&&(n._waterEscapeSearch||now>=(n._waterEscapeRetryAt||0)))_npcWaterSearchStep(n,depth,now);
 const target=n._waterEscapeTarget;if(!target){n.walking=false;return true;}
 const distance=Math.hypot(target.r-n.r,target.c-n.c);if(distance<.03){n._waterEscapeTarget=null;n._waterEscapeRetryAt=0;return true;}
 const step=Math.min(distance,Math.min(.1,Math.max(0,dt))*Math.min(_npcEffectiveSpeed(n),depth>.7?.8:1)),r=n.r+(target.r-n.r)/distance*step,c=n.c+(target.c-n.c)/distance*step;
 if(_npcWaterEgressPath(n,r,c)){_npcNavigationStats.egressSteps++;n.ang=Math.atan2(r-n.r,c-n.c);n.r=r;n.c=c;n.tr=target.r;n.tc=target.c;n.walking=step>0;n.walkPhase+=dt*7;}
 else{n._waterEscapeTarget=null;n._waterEscapeRetryAt=now+1000;n.walking=false;}
 return true;
}
// NPC_NATIVE_WATER_ROUTING_END
