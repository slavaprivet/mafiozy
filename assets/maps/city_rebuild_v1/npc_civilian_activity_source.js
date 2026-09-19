// Existing residents only. No spawning, purchases, damage or server authority.
const _npcCivilianActivities=new Set();
let _npcCivilianActivityNextAt=0,_npcCivilianActivitySerial=0,_npcCivilianActivityCursor=0;
const _npcCivilianActivityStats={startedTalk:0,completedTalk:0,startedRead:0,startedSmoke:0,startedJog:0,startedStretch:0,startedSquat:0,startedLook:0,completed:0,interrupted:0,blocked:0};
function _npcCivilianActivityThreat(n,now){
 return !n||n.dead||n.alive===false||Number.isFinite(n.hp)&&n.hp<=0||n._medicalDowned||n._forcedCrawl||n._policeCuffed||n._evacuated||n._carriedByAmbulance||n._hostile||n._fighting||n._fightingMelee||n.snitching||n.panicUntil>now||n._knockedUntil>now||n._meleeStunnedUntil>now||n._npcSurrenderUntil>now||n._npcHelpingUntil>now||n._alertUntil>now||n._corpsePhoneCall||n._hijackReaction||n._civilianTrip||n._ambientTrafficDriver||n._residentNativeVisit||n._residentIndoors||n._playerConversationOpen;
}
function _npcCivilianActivityEligible(n,now){
 // Do not throw away an admitted/pending real journey for an optional pause.
 if(n?._routeSearchPending||n?._npcWanderSearch)return false;
 // Finish reserved visits/seats before starting optional leisure. Leaving a
 // road is also a safety movement, even if its current step reaches land.
 // Ordinary walk routes remain available for conversation and outdoor pauses.
 if(n?._route?.length&&['building_entry','civilian_bench','civilian_road_exit'].includes(n._routeKind))return false;
 if(n?._routeKind==='building_entry'&&Number.isFinite(n._routeGoalR)&&Number.isFinite(n._routeGoalC)&&Math.hypot(n.r-n._routeGoalR,n.c-n._routeGoalC)<.7)return false;
 return _residentCanSocialize(n,now)&&!_npcCivilianActivityThreat(n,now)&&!n._civilianActivity&&!n._civilianSeat&&!n._clientOfBiz&&!n._civilianPlan?.tripDestination&&now>=(n._civilianActivityCooldownUntil||0);
}
function _npcCivilianActivitySnapshot(n){const a=n._civilianActivity;return a&&!n.dead?{kind:a.kind,phase:a.phase,since:a.since,until:a.until,partnerId:a.partnerId||null}:null;}
function _npcReleaseCivilianActivity(record,reason='complete',now=performance.now()){
 if(!record||record.released)return;record.released=true;_npcCivilianActivities.delete(record);
 if(reason==='complete'){_npcCivilianActivityStats.completed++;if(record.kind==='talk')_npcCivilianActivityStats.completedTalk++;}else _npcCivilianActivityStats.interrupted++;
 for(const n of record.members){
  if(n._civilianActivity?.record!==record)continue;const resume=n._civilianActivity.resumeRoute;n._civilianActivity=null;
  n._civilianJogRunning=false;
  n._civilianActivityCooldownUntil=now+22000+_npcStableUnit(n,'activity:'+record.id)*16000;
  n._socialCooldownUntil=n._civilianActivityCooldownUntil;
  const playerTalking=n._playerConversationOpen||n._talking===Number.MAX_SAFE_INTEGER;
  if(!playerTalking){n._talking=0;n.idleUntil=0;}
  n._socialPartnerId=null;n._socialReplyAt=0;n._socialReplyText='';n.walking=false;n.tr=n.r;n.tc=n.c;
  if(!playerTalking&&['talk','read','smoke'].includes(n._lifeGesture)){n._lifeGesture='';if(n._lifeState==='social')n._lifeState='routine';n._lifeStateUntil=0;}
  if(reason!=='complete'&&n._civilianSeat)_civilianPlanCancel(n);
  // A stationary pause should not discard a route which already passed the
  // shared planner. Resume only the same journey from the same physical point;
  // threats, changed plans and new obstacles fall back to normal replanning.
  if(reason==='complete'&&!playerTalking&&resume&&!n._route&&!_npcCivilianActivityThreat(n,now)&&n._civilianPlan===resume.plan&&n._civilianPlan?.phase===resume.phase&&n._civilianPlan?.doorId===resume.doorId&&n._civilianPlan?.cycle===resume.cycle&&Math.hypot(n.r-resume.r,n.c-resume.c)<1e-6){
   const next=resume.path[0];if(next&&_npcPathPassable(n.r,n.c,next.r,next.c,npcPassableForSnitch))_setNpcRoute(n,resume.path,resume.kind);
  }
 }
}
function _npcCancelCivilianActivity(n,reason='interrupted'){if(n?._civilianActivity)_npcReleaseCivilianActivity(n._civilianActivity.record,reason);}
function _npcCivilianActivityAttach(record,n,phase,now,until,extra={}){
 const resumeRoute=['smoke','stretch','squat','lookaround'].includes(record.kind)&&!n._routeSearchPending&&['walk','building_entry'].includes(n._routeKind)&&n._route?.length
  ?{path:n._route.slice(n._routeIndex||0),kind:n._routeKind,r:n.r,c:n.c,plan:n._civilianPlan,phase:n._civilianPlan?.phase,doorId:n._civilianPlan?.doorId,cycle:n._civilianPlan?.cycle}:null;
 if(['building_entry','civilian_bench'].includes(n._routeSearchKind))_cancelNpcDirectedSearch(n);
 _clearNpcRoute(n);n.tr=n.r;n.tc=n.c;n.walking=false;n.idleUntil=0;
 n._civilianActivity={record,kind:record.kind,phase,since:now,until,resumeRoute,...extra};
}
function _npcStartCivilianConversation(a,b,now){
 if(!_npcCivilianActivityEligible(a,now)||!_npcCivilianActivityEligible(b,now))return false;
 const d=Math.hypot(a.r-b.r,a.c-b.c);if(d<.45||d>2.4)return false;
 const dr=(b.r-a.r)/d,dc=(b.c-a.c)/d,midR=(a.r+b.r)/2,midC=(a.c+b.c)/2;
 const targets=[{r:midR-dr*.24,c:midC-dc*.24},{r:midR+dr*.24,c:midC+dc*.24}];
 if(targets.some(p=>{const hit=_walkNpcNavigationResolver(p);return !hit||hit.blocked||hit.depth>.025||hit.surface==='road';})){a._socialCooldownUntil=b._socialCooldownUntil=now+4000;return false;}
 if(![a,b].every((n,i)=>_npcPathPassable(n.r,n.c,targets[i].r,targets[i].c,npcPassableForSnitch))){a._socialCooldownUntil=b._socialCooldownUntil=now+4000;_npcCivilianActivityStats.blocked++;return false;}
 const record={id:++_npcCivilianActivitySerial,kind:'talk',members:[a,b],targets,deadline:now+14000,talk:_npcConversationFor(a,b,now),phase:'approach'};
 _npcCivilianActivities.add(record);[a,b].forEach((n,i)=>_npcCivilianActivityAttach(record,n,'approach',now,record.deadline,{partnerId:record.members[1-i].id}));_npcCivilianActivityStats.startedTalk++;return true;
}
function _npcStartBenchReading(n,now){
 if(!n._civilianSeat||_npcCivilianActivityThreat(n,now)||n._civilianActivity||_npcCivilianActivities.size>=20||_npcStableUnit(n,'book:'+n._civilianPlan?.cycle)>.72)return false;
 const record={id:++_npcCivilianActivitySerial,kind:'read',members:[n],phase:'active',until:n._civilianPlan.until};_npcCivilianActivities.add(record);
 n._civilianActivity={record,kind:'read',phase:'active',since:now,until:record.until};n._lifeGesture='read';_npcCivilianActivityStats.startedRead++;return true;
}
function _npcStartStandingSmoke(n,now){
 if(!_npcCivilianActivityEligible(n,now))return false;
 const surface=_walkNpcNavigationResolver({r:n.r,c:n.c});if(!surface||surface.blocked||surface.depth>.025||surface.surface==='road')return false;
 const record={id:++_npcCivilianActivitySerial,kind:'smoke',members:[n],phase:'active',until:now+7000+_npcStableUnit(n,'smoke')*4000};_npcCivilianActivities.add(record);
 _npcCivilianActivityAttach(record,n,'active',now,record.until);n._lifeGesture='smoke';_npcCivilianActivityStats.startedSmoke++;return true;
}
function _npcOutdoorActivityPass(r,c){
 const hit=_walkNpcNavigationResolver({r,c});return !!hit&&!hit.blocked&&hit.depth<=.025&&hit.surface==='land';
}
function _npcOutdoorActivityPath(fromR,fromC,toR,toC){
 // Keep both contracts: road/water exclusion across the body and the normal
 // native continuous collision check. The custom callback alone has no sweep.
 return _npcPathPassable(fromR,fromC,toR,toC,_npcOutdoorActivityPass)&&_npcPathPassable(fromR,fromC,toR,toC,npcPassableForSnitch);
}
function _npcStartOutdoorRoutine(n,kind,now){
 if(!_npcCivilianActivityEligible(n,now)||!['jog','stretch','squat','lookaround'].includes(kind)||typeof npcCarriedGun==='function'&&npcCarriedGun(n)||!_npcOutdoorActivityPath(n.r,n.c,n.r,n.c))return false;
 if(kind!=='lookaround'&&(n._arcKey==='pensioner'||n._arcKey==='oldman'||n._arcKey==='oldwoman'||(n.hp??100)<(n.max_hp??n.maxHp??100)*.7))return false;
 let path=null;
 if(kind==='jog'){
  if(n._routeKind!=='walk'||n._routeSearchPending||!Array.isArray(n._route)||n._route.length<3)return false;
  const outward=n._route.slice(n._routeIndex||0,(n._routeIndex||0)+4);if(outward.length<3)return false;
  let from={r:n.r,c:n.c},length=0;
  for(const point of outward){const distance=Math.hypot(point.r-from.r,point.c-from.c);if(distance>1.8||!_npcOutdoorActivityPath(from.r,from.c,point.r,point.c))return false;length+=distance;from=point;}
  if(length<1.5)return false;
  path=[...outward,...outward.slice(0,-1).reverse(),{r:n.r,c:n.c}];
 }
 const duration=kind==='jog'?42000:kind==='lookaround'?4500:10000+_npcStableUnit(n,'exercise:'+kind)*3000;
 const record={id:++_npcCivilianActivitySerial,kind,members:[n],phase:'active',until:now+duration,path,index:0};
 _npcCivilianActivities.add(record);_npcCivilianActivityAttach(record,n,'active',now,record.until);n._lifeGesture='';
 _npcCivilianActivityStats[{jog:'startedJog',stretch:'startedStretch',squat:'startedSquat',lookaround:'startedLook'}[kind]]++;return true;
}
function _npcOutdoorRoutineTick(n,a,dt,now){
 if(typeof npcCarriedGun==='function'&&npcCarriedGun(n)){_npcReleaseCivilianActivity(a.record,'armed',now);return false;}
 if(now>=a.until){_npcReleaseCivilianActivity(a.record,'complete',now);return false;}
 if(a.kind!=='jog'){if(!_npcOutdoorActivityPath(n.r,n.c,n.r,n.c)){_npcReleaseCivilianActivity(a.record,'space-blocked',now);return false;}n.walking=false;n.tr=n.r;n.tc=n.c;return true;}
 const record=a.record;let budget=Math.max(0,Math.min(.5,dt))*2.6/4.1,moved=0;
 // Consume cadence time across corners too: a distant resident must not spend
 // one entire quarter-second update waiting at every waypoint. At most eight
 // copied points exist, and every traversed segment gets its own exact sweep.
 for(let i=0;i<8&&budget>1e-9;i++){
  const target=record.path[record.index];if(!target)break;
  const dr=target.r-n.r,dc=target.c-n.c,d=Math.hypot(dr,dc);if(d<1e-8){record.index++;continue;}
  const step=Math.min(d,budget),r=n.r+dr/d*step,c=n.c+dc/d*step;
  if(!_npcOutdoorActivityPath(n.r,n.c,r,c)){_npcCivilianActivityStats.blocked++;_npcReleaseCivilianActivity(record,'path-blocked',now);return false;}
  n.r=r;n.c=c;n.tr=target.r;n.tc=target.c;n.ang=Math.atan2(dr,dc);moved+=step;budget-=step;if(step>=d-1e-8)record.index++;
 }
 n.walking=moved>0;n.walkPhase=(n.walkPhase||0)+moved*11;n._civilianJogRunning=n.walking;
 if(record.index>=record.path.length){_npcReleaseCivilianActivity(record,'complete',now);return false;}return true;
}
function _npcPurposefulSocialTick(now){
 if(now<_npcCivilianActivityNextAt)return;_npcCivilianActivityNextAt=now+1400;
 for(const record of _npcCivilianActivities)if(record.members.some(n=>!NPCS.includes(n)||_npcCivilianActivityThreat(n,now)))_npcReleaseCivilianActivity(record,'interrupted',now);
 let pairs=0,smokers=0;for(const r of _npcCivilianActivities){if(r.kind==='talk')pairs++;if(r.kind==='smoke')smokers++;}
 if(pairs<Math.min(8,Math.max(3,Math.ceil(NPCS.length/48)))&&_npcCivilianActivities.size<20){const pair=_findNpcSocialPair(now,true);if(pair)_npcStartCivilianConversation(pair[0],pair[1],now);}
 if(smokers<Math.min(4,Math.max(2,Math.ceil(NPCS.length/72)))&&_npcCivilianActivities.size<20){for(let i=0;i<Math.min(24,NPCS.length);i++){const n=NPCS[(_npcCivilianActivityCursor+i)%NPCS.length];if(n?.walking&&_npcStableUnit(n,'smoker')<.3&&_npcStartStandingSmoke(n,now))break;}_npcCivilianActivityCursor=NPCS.length?(_npcCivilianActivityCursor+24)%NPCS.length:0;}
 if(_npcCivilianActivities.size<20){
  let jogging=0,stretching=0,squatting=0,looking=0;for(const record of _npcCivilianActivities){if(record.kind==='jog')jogging++;if(record.kind==='stretch')stretching++;if(record.kind==='squat')squatting++;if(record.kind==='lookaround')looking++;}
  for(let i=0;i<Math.min(12,NPCS.length);i++){
   const n=NPCS[(_npcCivilianActivityCursor+i)%NPCS.length];if(!n)continue;
   const choice=_npcStableUnit(n,'outdoor:'+Math.floor(now/45000)),kind=choice<.4?'jog':choice<.65?'stretch':choice<.85?'squat':'lookaround';
   if(kind==='jog'&&jogging>=3||kind==='lookaround'&&looking>=2||kind==='stretch'&&stretching>=2||kind==='squat'&&squatting>=2)continue;
   if(_npcStartOutdoorRoutine(n,kind,now))break;
  }
  _npcCivilianActivityCursor=NPCS.length?(_npcCivilianActivityCursor+12)%NPCS.length:0;
 }
 if(typeof _UP!=='undefined'&&(_UP.has('npcqa')||_UP.has('perfqa')||_UP.has('npccombatqa')))document.documentElement.dataset.npcCivilianActivities=JSON.stringify({..._npcCivilianActivityStats,active:[..._npcCivilianActivities].map(r=>({kind:r.kind,phase:r.phase,ids:r.members.map(n=>n.id)}))});
}
function _npcPurposefulActivityTick(n,dt,now){
 const a=n._civilianActivity;if(!a)return false;const record=a.record;
 if(record.members.some(member=>_npcCivilianActivityThreat(member,now))){_npcReleaseCivilianActivity(record,'interrupted',now);return false;}
 if(['jog','stretch','squat','lookaround'].includes(a.kind))return _npcOutdoorRoutineTick(n,a,dt,now);
 if(a.kind==='read'){
  if(!n._civilianSeat||now>=a.until){_npcReleaseCivilianActivity(record,'complete',now);return false;}
  n._lifeGesture='read';n.walking=false;return false; // Existing physical bench reservation owns sitting and release.
 }
 if(a.phase==='approach'){
  if(now>=record.deadline){_npcReleaseCivilianActivity(record,'approach-timeout',now);return false;}
  const i=record.members.indexOf(n),target=record.targets[i],dr=target.r-n.r,dc=target.c-n.c,d=Math.hypot(dr,dc),step=Math.min(d,_npcEffectiveSpeed(n)*Math.min(.1,dt));
  if(d>.025){const r=n.r+dr/d*step,c=n.c+dc/d*step;if(!_npcPathPassable(n.r,n.c,r,c,npcPassableForSnitch)){_npcCivilianActivityStats.blocked++;_npcReleaseCivilianActivity(record,'path-blocked',now);return false;}n.r=r;n.c=c;n.ang=Math.atan2(dr,dc);n.walking=step>0;n.walkPhase=(n.walkPhase||0)+step*9;n.tr=target.r;n.tc=target.c;}
  if(record.members.every((member,j)=>Math.hypot(member.r-record.targets[j].r,member.c-record.targets[j].c)<=.025)){
   record.phase='active';record.until=now+6000+_npcStableUnit(n,'talk:'+record.id)*3000;
   for(const member of record.members){Object.assign(member._civilianActivity,{phase:'active',since:now,until:record.until});member._talking=record.until;member._socialPartnerId=member===record.members[0]?record.members[1].id:record.members[0].id;member._lifeState='social';member._lifeGesture='talk';member._lifeStateSince=now;member._lifeStateUntil=record.until;member.walking=false;member.tr=member.r;member.tc=member.c;}
   const talk=record.talk;if(_npcSpeechSlots(now)>0){talk.speaker.cryText=talk.first;talk.speaker.cryUntil=now+2000;}record.replyAt=now+2700;_applyNpcConversationEffect(talk.speaker,talk.listener,talk.effect,now);
  }
  return true;
 }
 if(a.kind==='talk'){
  const other=record.members.find(member=>member!==n);n.ang=Math.atan2(other.r-n.r,other.c-n.c);n._lifeGesture='talk';
  if(record.replyAt&&now>=record.replyAt){record.replyAt=0;if(_npcSpeechSlots(now)>0){record.talk.listener.cryText=record.talk.reply;record.talk.listener.cryUntil=now+2100;}}
 }else n._lifeGesture='smoke';
 if(now>=a.until){if(a.phase==='finish'){_npcReleaseCivilianActivity(record,'complete',now);return false;}record.phase='finish';for(const member of record.members)Object.assign(member._civilianActivity,{phase:'finish',since:now,until:now+600});}
 n.walking=false;n.tr=n.r;n.tc=n.c;n.idleUntil=0;return true;
}
