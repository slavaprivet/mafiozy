// NPC_INCIDENT_REACTIONS_START
let _npcCorpseScanAt=0,_npcCorpseScanCursor=0,_npcCorpseCacheAt=0,_npcCorpseCache=[];
const _npcCorpseCells=new Map();
function _npcCorpsePool(){const pool=NPCS.slice();if(typeof _playerEmergencyPatient!=='undefined'&&_playerEmergencyPatient)pool.push(_playerEmergencyPatient);if(typeof beachgoers!=='undefined')for(const b of beachgoers.values())pool.push(b);return pool;}
function _npcCorpseKnown(n){return NPCS.includes(n)||(typeof _playerEmergencyPatient!=='undefined'&&_playerEmergencyPatient===n)||(typeof beachgoers!=='undefined'&&beachgoers.get(n.id)===n);}
function _npcCorpsePosition(n){if(Number.isFinite(n._deathR)&&Number.isFinite(n._deathC))return {r:n._deathR,c:n._deathC};if(Number.isFinite(n.r)&&Number.isFinite(n.c))return n;if(typeof _beachgoerWorldPos==='function')return _beachgoerWorldPos(n);return null;}
function _npcIncidentAlive(n){return !!n&&!n.dead&&n.alive!==false&&!(Number.isFinite(n.hp)&&n.hp<=0);}
function _npcCorpseEmsReported(n){return !!n&&n.dead===true&&Number.isFinite(n.deadAt)&&Number.isFinite(n._corpseEmsReportAt)&&n._corpseEmsReportAt>=n.deadAt&&n._corpseEmsIncidentAt===n.deadAt;}
function _npcCorpseWitnessEligible(n,now){
 return _npcIncidentAlive(n)&&_npcCanWitnessEvent(n,now)&&!n.snitching&&!(n.panicUntil>now)&&!n._forcedCrawl&&!n._residentIndoors&&!n._interiorId&&!n._civilianTrip&&!n._civilianTripRiding&&!n._ambientTrafficDriver&&!n._inVehicle&&!n._inCar&&!n._medicalCrewVehicleId&&!n._vehicleHijackControlled&&n._vehicleHijack?.phase!=='pulled'&&!n._hijackReaction;
}
function _npcCancelCorpsePhone(n,reason='interrupted'){
 const call=n?._corpsePhoneCall;if(!call)return;
 if(call.corpse._corpseEmsWitness===n){delete call.corpse._corpseEmsWitness;delete call.corpse._corpseEmsWitnessId;}
 n._corpsePhoneCall=null;n._corpsePhoneStatus=reason;n.idleUntil=0;if(n._lifeGesture==='call')n._lifeGesture='';
}
function _npcCorpsePhoneTick(n,now){
 const call=n?._corpsePhoneCall;if(!call)return false;
 const corpse=call.corpse;
 if(!_npcCorpseWitnessEligible(n,now)||!_npcCorpseKnown(corpse)||!corpse.dead||corpse.deadAt!==call.incidentAt||corpse._evacuated||corpse._carriedByAmbulance||Math.hypot(n.r-call.r,n.c-call.c)>.2){_npcCancelCorpsePhone(n);return false;}
 n.walking=false;n.walkPhase=0;n._lifeGesture='call';n._lifeState='alert';n._lifeStateSince=call.since;n._lifeStateUntil=call.until;n.idleUntil=call.until;
 if(now<call.until)return true;
 corpse._corpseEmsReportAt=now;corpse._corpseEmsIncidentAt=call.incidentAt;corpse._corpseEmsReporterId=String(n.id);
 _npcCancelCorpsePhone(n,'reported');n.cryText='Скорая, здесь человек без сознания. Приезжайте!';n.cryUntil=now+1600;
 document.documentElement.dataset.npcCorpseEmsReport=String(corpse.id)+':'+String(n.id);return true;
}
function _npcCorpseDiscoveryTick(now){
 if(now<_npcCorpseScanAt)return;_npcCorpseScanAt=now+250;
 if(now>=_npcCorpseCacheAt){_npcCorpseCacheAt=now+1000;_npcCorpseCache=_npcCorpsePool().filter(n=>n?.dead===true&&Number.isFinite(n.deadAt)&&!n._corpseExpired&&!n._evacuated&&!n._carriedByAmbulance&&!n._ambulanceInTransit&&!_npcCorpseEmsReported(n));_npcCorpseCells.clear();for(const corpse of _npcCorpseCache){const p=_npcCorpsePosition(corpse);if(!p)continue;const key=Math.floor(p.r/4.2)+':'+Math.floor(p.c/4.2),cell=_npcCorpseCells.get(key)||[];cell.push(corpse);_npcCorpseCells.set(key,cell);}}
 if(!_npcCorpseCache.length||!NPCS.length)return;
 for(let i=0;i<Math.min(8,NPCS.length);i++){
  const n=NPCS[(_npcCorpseScanCursor++)%NPCS.length];if(!_npcCorpseWitnessEligible(n,now)||n._corpsePhoneCall)continue;
  const nearby=[],row=Math.floor(n.r/4.2),col=Math.floor(n.c/4.2);for(let dr=-1;dr<=1;dr++)for(let dc=-1;dc<=1;dc++)for(const corpse of _npcCorpseCells.get((row+dr)+':'+(col+dc))||[])nearby.push(corpse);
  for(const corpse of nearby.slice(0,32)){
   if(!corpse.dead||corpse._corpseExpired||_npcCorpseEmsReported(corpse)||corpse._evacuated||corpse._carriedByAmbulance||corpse._ambulanceInTransit)continue;
   const reserved=corpse._corpseEmsWitness;if(reserved&&reserved._corpsePhoneCall?.corpse===corpse&&_npcCorpseWitnessEligible(reserved,now))continue;
   const point=_npcCorpsePosition(corpse);if(!point)continue;const {r,c}=point;
   if(!_npcCanSeePoint(n,r,c,4.2,.35))continue;
   _npcCancelHelping(n);_npcCancelSocial(n);_civilianPlanCancel(n);_clearNpcRoute(n);
   const call={corpse,incidentAt:corpse.deadAt,since:now,until:now+3200,r:n.r,c:n.c};n._corpsePhoneCall=call;n._corpsePhoneStatus='calling';
   corpse._corpseEmsWitness=n;corpse._corpseEmsWitnessId=String(n.id);n.ang=Math.atan2(r-n.r,c-n.c);n.walking=false;n._panicCowerUntil=0;
   _npcSetLifeState(n,NPC_LIFE_STATES.ALERT,now,3200,'call');n.idleUntil=call.until;n.cryText='Тут раненый! Вызываю скорую.';n.cryUntil=now+1600;
   break;
  }
 }
}
function _npcVehicleHijackReleased(n,event={},now=performance.now()){
 if(!_npcIncidentAlive(n)||!NPCS.includes(n))return {accepted:false,reason:'not-living-resident'};
 if(!event.eventId||!event.carId)return {accepted:false,reason:'event-identity-required'};
 const prior=n._hijackReactionEvents?.find(e=>e.eventId===String(event.eventId));if(prior)return {accepted:true,decision:prior.decision,duplicate:true};
 if(n._hijackReactionSeen===String(event.eventId))return {accepted:true,decision:n._hijackReactionDecision,duplicate:true};
 if(n._hijackReaction?.eventId===String(event.eventId))return {accepted:true,decision:n._hijackReaction.decision};
 if(!_npcCanWitnessEvent(n,now))return {accepted:false,reason:'role-or-combat-owned'};
 _npcCancelCorpsePhone(n);_npcCancelHelping(n);_npcCancelSocial(n);_civilianPlanCancel(n);_clearNpcRoute(n);
 const decision=_npcStableUnit(n,'hijack:'+String(event.eventId))<.20?'retake':'flee';
 n._hijackReactionEvents??=[];n._hijackReactionEvents.push({eventId:String(event.eventId),decision});if(n._hijackReactionEvents.length>8)n._hijackReactionEvents.shift();
 n._hijackReaction={eventId:String(event.eventId),carId:String(event.carId),phase:'protest',decision,since:now,until:now+900,deadline:now+11000,sourceR:Number.isFinite(event.playerR)?event.playerR:player.r,sourceC:Number.isFinite(event.playerC)?event.playerC:player.c,retakeRetryAt:0};
 n._hijackReactionSeen=String(event.eventId);n._hijackReactionDecision=decision;n._alertUntil=now+900;n._lifeGesture='protest';n._lifeState='alert';n._lifeStateSince=now;n._lifeStateUntil=now+900;
 n.cryText=decision==='retake'?'Это моя машина! Вылезай!':'Помогите! У меня отняли машину!';n.cryUntil=now+2100;n.idleUntil=now+900;
 return {accepted:true,decision};
}
function _npcHijackRetreat(n,reaction,now){
 reaction.phase='flee';reaction.since=now;reaction.until=now+6500;n.idleUntil=0;_clearNpcRoute(n);
 _npcQueueWitnessCall(n,now,reaction.sourceR,reaction.sourceC,'crime','У меня угнали машину! Вызываю полицию!');
 if(!n.snitching){_npcBeginPanic(n,now,now+6500,reaction.sourceR,reaction.sourceC,'fight');n._panicStyle='flee';n._panicFreezeUntil=n._panicCowerUntil=n._panicCallUntil=0;}
}
function _npcVehicleHijackReactionTick(n,dt,now){
 const reaction=n?._hijackReaction;if(!reaction)return false;
 if(!_npcIncidentAlive(n)||n._medicalDowned||n._forcedCrawl||n._knockedUntil>now||n._meleeStunnedUntil>now||n._policeCuffed||n._carriedByAmbulance){n._hijackReaction=null;return false;}
 if(reaction.phase==='flee'){if(now>=reaction.until)n._hijackReaction=null;return false;}
 if(reaction.phase==='protest'){
  if(now<reaction.until){n.walking=false;n.walkPhase=0;n._lifeGesture='protest';return true;}
  if(reaction.decision==='flee'){_npcHijackRetreat(n,reaction,now);return false;}
  reaction.phase='retake';reaction.since=now;reaction.until=reaction.deadline;n.idleUntil=0;
 }
 if(now>=reaction.deadline||Math.hypot(n.r-player.r,n.c-player.c)>7){_npcHijackRetreat(n,reaction,now);return false;}
 const retake=typeof _npcVehicleHijackRetake==='function'?_npcVehicleHijackRetake(n,reaction,dt,now):null;
 if(!retake||retake.status==='unavailable'){_npcHijackRetreat(n,reaction,now);return false;}
 if(retake.status==='complete'){
  if(myDrivingCarId)return true;
  n._hijackReaction=null;n._civilianFightDecision='fight';_npcTriggerFight(n);return false;
 }
 if(retake.status==='pulling'){n.walking=false;return true;}
 const target=retake.target;if(!target||![target.r,target.c].every(Number.isFinite))return true;
 const dr=target.r-n.r,dc=target.c-n.c,d=Math.hypot(dr,dc),speed=_npcEffectiveSpeed(n);
 if(d<1){const step=Math.min(d,speed*dt),r=n.r+dr/Math.max(.001,d)*step,c=n.c+dc/Math.max(.001,d)*step;if(_npcPathPassable(n.r,n.c,r,c,npcPassableForSnitch)){n.r=r;n.c=c;n.ang=Math.atan2(dr,dc);n.walking=step>.001;n.walkPhase+=dt*8;}return true;}
 if(n._routeSearchPending||now>=reaction.retakeRetryAt||n._routeKind!=='vehicle-retake'){
  _planNpcRouteTo(n,target.r,target.c,npcPassableForSnitch,.8,900,'vehicle-retake');reaction.retakeRetryAt=now+850;
 }
 _npcAdvanceRoute(n,dt,speed,npcPassableForSnitch);return true;
}
// NPC_INCIDENT_REACTIONS_END
