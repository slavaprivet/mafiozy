// Finite resident activity agenda. Existing executors retain movement,
// reservations, commerce and vehicle authority; this helper only chooses work.
const _npcAgendaKinds=Object.freeze(['shop','walk','bench','walk','drive','walk']);
function _npcAgendaNative(){return typeof _walkNpcNavigationResolver==='function'&&(typeof _walkRendererActive!=='function'||_walkRendererActive());}
function _npcAgendaInterrupted(n,now){
 if(typeof _civilianPlanInterrupted==='function'&&_civilianPlanInterrupted(n,now))return true;
 return !!(n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._medicalDowned||n._forcedCrawl||n._policeCuffed||n._evacuated||n._carriedByAmbulance||n._hostile||n._fighting||n._fightingMelee||n.snitching||n.panicUntil>now||n._knockedUntil>now||n._meleeStunnedUntil>now||n._playerConversationOpen||n._playerConversationUntil>now||n._vehicleHijackControlled||n._corpsePhoneCall||n._hijackReaction);
}
function _npcAgendaBaseEligible(n,now){
 return !!n&&_npcAgendaNative()&&!_npcAgendaInterrupted(n,now)&&!n._npcInitialPlacementPending&&!n._uniqueNpc&&!n._said&&!n._invulnerable&&!n._empireBoss&&!n._empireCrew&&!n._gang&&!n.gang&&!n.police&&!n.isPolice&&!n._guard&&!n._cashier&&!n._clientOfBiz&&!n._medicalCrewVehicleId&&!n._policeCriminal&&!n._botCorpse&&!n._transientCorpseId&&!n._beach&&n._arcKey!=='bandit'&&(n._civilianTrip||typeof _isRespawnableResident!=='function'||_isRespawnableResident(n));
}
function _npcAgendaEnsure(n){
 if(n._npcAgenda)return n._npcAgenda;
 let h=2166136261;for(const ch of String(n.id||'')){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}
 const offset=(h>>>0)%_npcAgendaKinds.length,queue=_npcAgendaKinds.slice(offset).concat(_npcAgendaKinds.slice(0,offset));
 return n._npcAgenda={queue,index:0,current:queue[0],started:false,completed:0,lastResult:null};
}
function _npcAgendaComplete(n,kind,reason='complete'){
 const a=n?._npcAgenda;if(!a||a.current!==kind)return false;
 a.lastResult={kind,reason};a.completed++;a.index=(a.index+1)%a.queue.length;a.current=a.queue[a.index];a.started=false;
 return true;
}
function _npcAgendaAdopt(n,kind){
 const a=_npcAgendaEnsure(n);if(a.current!==kind){a.index=a.queue.indexOf(kind);a.current=kind;}a.started=true;return a;
}
function _npcAgendaUnavailable(n,kind){
 if(kind==='shop'){
  if(typeof _npcActivityCancelPending==='function')_npcActivityCancelPending(n,'activity-unavailable');
  if(n._civilianPlan){n._civilianPlan.doorId=null;n._civilianPlan.tripDestination=false;n._civilianPlan.phase='seek_shop';}
  n._residentVisitTargetId=null;n._residentDoor=null;
  if(!n._routeSearchPending&&n._routeKind==='building_entry'&&typeof _clearNpcRoute==='function')_clearNpcRoute(n);
 }
 _npcAgendaComplete(n,kind,'unavailable');
}
function _npcAgendaWantsDrive(n,now){
 return _npcAgendaBaseEligible(n,now)&&n._npcAgenda?.current==='drive'&&!n._civilianTrip&&!n._civilianTripRiding&&!n._ambientTrafficDriver&&!n._residentNativeVisit&&!n._residentIndoors&&!n._civilianSeat&&!n._civilianActivity&&!n._civilianPlan?.tripDestination&&!n._routeSearchPending&&!n._npcWanderSearch;
}
function _npcAgendaPick(n,now){
 if(!_npcAgendaBaseEligible(n,now))return null;
 // These owners may intentionally make _civilianPlanEligible false. Never
 // replace their plan, retained target or route to manufacture another task.
 if(n._civilianTrip||n._civilianTripRiding||n._ambientTrafficDriver){_npcAgendaAdopt(n,'drive');return 'ready';}
 if(n._residentNativeVisit||n._residentIndoors){if(!n._residentRespawn)_npcAgendaAdopt(n,'shop');return 'ready';}
 if(n._civilianSeat){_npcAgendaAdopt(n,'bench');return 'ready';}
 if(n._civilianActivity)return 'ready';
 if(n._civilianPlan?.tripDestination){
  _npcAgendaAdopt(n,'shop');
  if(n._routeKind==='building_entry'&&n._route?.length)return 'ready';
  if(typeof _maybePlanResidentBuildingVisit==='function'&&_maybePlanResidentBuildingVisit(n))return 'ready';
  if(n._routeSearchPending)return 'pending';
  _npcAgendaUnavailable(n,'shop');
 }
 if(n._routeSearchPending){
  const kind=n._routeSearchKind==='building_entry'?'shop':n._routeSearchKind==='civilian_bench'?'bench':null;
  if(kind)_npcAgendaAdopt(n,kind);
  const ready=kind==='shop'&&typeof _maybePlanResidentBuildingVisit==='function'?_maybePlanResidentBuildingVisit(n):kind==='bench'&&typeof _civilianPlanNext==='function'?_civilianPlanNext(n,now):false;
  if(ready)return 'ready';if(n._routeSearchPending)return 'pending';
  if(kind)_npcAgendaUnavailable(n,kind);
 }
 if(n._npcWanderSearch)return 'walk';
 if(typeof _civilianPlanEligible==='function'&&!_civilianPlanEligible(n))return null;
 const a=_npcAgendaEnsure(n);
 // A pre-agenda route is already a real undertaking. Let its arrival hook
 // complete/adopt that kind, instead of changing a moving actor's destination.
 if(!a.started&&n._route?.length&&['walk','building_entry','civilian_bench'].includes(n._routeKind)){
  const kind=n._routeKind==='walk'?'walk':n._routeKind==='building_entry'?'shop':'bench';_npcAgendaAdopt(n,kind);return kind==='walk'?'walk':'ready';
 }
 for(let attempt=0;attempt<a.queue.length;attempt++){
  const kind=a.current;
  if(kind==='walk'){a.started=true;return 'walk';}
  if(!a.started){
   a.started=true;
   if(kind==='shop'||kind==='bench'){
    const p=n._civilianPlan,phase=kind==='shop'?'seek_shop':'walk_to_bench';
    // Setup happens once per activity. Retried native searches must not change
    // plan phase/identity, chosen door, bench or wander search key each frame.
    n._civilianPlan={...(p||{}),phase,cycle:p?.cycle||0,retryAt:0,since:now,doorId:null,benchId:null,tripDestination:false};
   }
  }
  let ready=false;
  if(kind==='shop'&&typeof _maybePlanResidentBuildingVisit==='function')ready=!!_maybePlanResidentBuildingVisit(n);
  else if(kind==='bench'&&typeof _civilianPlanNext==='function')ready=!!_civilianPlanNext(n,now);
  else if(kind==='drive'&&typeof _npcAgendaTryDrive==='function')ready=_npcAgendaTryDrive(n,now)===true;
  if(ready)return 'ready';
  if(n._routeSearchPending)return 'pending';
  if(n._civilianTrip||n._civilianTripRiding||n._residentNativeVisit||n._civilianSeat)return 'ready';
  _npcAgendaUnavailable(n,kind);
 }
 return 'walk';
}
