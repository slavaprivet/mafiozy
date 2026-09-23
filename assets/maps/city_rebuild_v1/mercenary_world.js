/* Source-world adapter; classic script has access to world lexical state. */
(function(){
 'use strict';
 const scriptUrl=document.currentScript?.src||location.origin+'/assets/maps/city_rebuild_v1/mercenary_world.js';
 const KEY='mafiozi.mercenaries.v1',failure=reason=>({ok:false,reason}),success=message=>({ok:true,message});
 const local=()=>typeof _LOCAL_PREVIEW!=='undefined'&&_LOCAL_PREVIEW&&!(typeof _serverAuthoritativeAmmo!=='undefined'&&_serverAuthoritativeAmmo)&&!(typeof _customGang!=='undefined'&&_customGang);
 const scale=()=>Number(window.MAFIOZI_RENDERER_CONFIG?.worldScale)||4.1;
 const toWorld=m=>{const x=m.c*scale(),z=m.r*scale();return{x,y:Number(targets.groundHeight?.(x,z))||0,z};};
 const now=()=>Date.now()/1000;
 const gang=()=>typeof _myGang!=='undefined'?_myGang:[];
 const npcs=()=>typeof NPCS!=='undefined'?NPCS:[];
 let core,professions,routeFactory,longFollowFactory,targets={},lastCandidates=-Infinity,lastSave=-Infinity,dismissing=false,ready=false,followAngle=null;
 let restoreBlocked=false,restoredOnce=false,safeLootBalance=0,qaRecruiting=false;const persistenceDiagnostics={restore:null,save:null,removals:[]};
 let routeWorkDeadline=0,routeFrameOffset=0;
 let catchupRecovery=null,safeDropAdvance=null,squadDropChecksRemaining=4,squadDropCrowd=null;
 const waterEscapeOptions={bodyDepth:true,speed:0,canStep:(m,r,c)=>!gang().some(other=>other!==m&&other.hp>0&&!other._mercenaryHospital&&Math.hypot(other.r-r,other.c-c)*scale()<1.1&&Math.hypot(other.r-r,other.c-c)<=Math.hypot(other.r-m.r,other.c-m.c))};
 const movementQaEnabled=(()=>{try{return ['localhost','127.0.0.1','[::1]'].includes(location.hostname)&&new URL(location.href||location.origin).searchParams.get('npcqa')==='1';}catch{return false;}})();
 let lastMovementReport=-Infinity;
 const movementQaActionHistory=[],movementQaLastActions=new WeakMap();
 let chatterListener=null,chatterSequence=0;
 let movementClockAt=null;const movementClock={elapsed:0,used:0,dropped:0,paused:false};
 function resetMovementClock(){movementClockAt=null;}
 document.addEventListener?.('visibilitychange',resetMovementClock);
 function bindChatter(listener){chatterListener=typeof listener==='function'?listener:null;return ()=>{if(chatterListener===listener)chatterListener=null;};}
 function chatterEvent(id,kind,detail={}){
  if(!chatterListener)return null;const hero=id==='player',m=hero?player:raw(id),r=hero?null:records.get(m?.id);if(!m||!hero&&!r)return null;
  const time=performance.now(),event={seq:++chatterSequence,at:Date.now(),speakerId:hero?'player':m.id,name:hero?'Босс':m.name||r.name,profession:hero?'hero':r.profession,gender:hero?0:Number(m.look?.gender)||0,kind,...(kind==='idle'?{peerCount:gang().filter(n=>n!==m&&n.hp>0&&Math.hypot(n.r-m.r,n.c-m.c)*scale()<10).length}:{}),...detail,alive:hero?!(typeof myDead!=='undefined'&&myDead):m.hp>0&&!m.dead&&!m._mercenaryHospital,distance:hero?0:Math.hypot(m.r-player.r,m.c-player.c)*scale(),busy:!hero&&!!m._mercenaryAction&&!['completed','cancelled'].includes(m._mercenaryAction.phase),anyCombat:gang().some(n=>n.hp>0&&(n._mercenaryDefending||n.targetKind||time<(n._threatUntil||0)))};
  try{return chatterListener(event)===true;}catch{return false;}
 }
 function greetMember(id){
  const m=raw(id);if(!ready||!local()||!m||!record(m.id)||m.hp<=0||m.dead||m._mercenaryHospital||core.getAction(m.id)||m._mercenarySafeExit||Math.hypot(m.r-player.r,m.c-player.c)*scale()>3.5||gang().some(n=>n.hp>0&&(n._mercenaryDefending||n.targetKind||performance.now()<(n._threatUntil||0))))return false;
  if(now()<(m._mercenaryNextGreetingAt||0))return false;m._mercenaryNextGreetingAt=now()+18;m._mercenaryGreetingUntil=now()+2.5;
  chatterEvent(m.id,'greeting');return true;
 }
 function facePlayer(m,elapsed){const desired=Math.atan2(player.r-m.r,player.c-m.c),delta=Math.atan2(Math.sin(desired-(m.ang||0)),Math.cos(desired-(m.ang||0)));m.ang=(m.ang||0)+Math.max(-elapsed*5,Math.min(elapsed*5,delta));m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;}
 function movementElapsed(dt){
  const stamp=performance.now(),elapsed=movementClockAt===null?Math.min(.05,Math.max(0,Number(dt)||0)):Math.max(0,(stamp-movementClockAt)/1000);movementClockAt=stamp;
  const paused=document.hidden===true||!Number.isFinite(elapsed)||elapsed>.75,used=paused?0:Math.min(.3,elapsed);Object.assign(movementClock,{elapsed,used,dropped:Math.max(0,elapsed-used),paused});return used;
 }
 function advanceMember(m,elapsed){m._mercenaryMoveSubsteps=0;if(elapsed<=0){m._followSpeed=0;return;}for(let step=0;step<6&&elapsed>1e-6;step++){const seconds=Math.min(.05,elapsed);move(m,seconds);m._mercenaryMoveSubsteps++;elapsed-=seconds;if(!m._mercenaryMove||m._followSpeed<=0)break;}}
 function reportPersistence(){if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryPersistence=JSON.stringify(persistenceDiagnostics);}
 function reportMovement(){
  if(!movementQaEnabled||!document.documentElement?.dataset)return;
  const stamp=performance.now();if(stamp-lastMovementReport<1000)return;lastMovementReport=stamp;
  const at=Date.now();
  const nativeConnected=typeof _walkNpcNavigationResolver==='function',bodyDepth=typeof _npcWaterEscapeDepth==='function'&&nativeConnected;
  const crew=gang().map(m=>{
   const goal=m._mercenaryMove?.position,active=core?.getAction(m.id),last=m._mercenaryLastAction;
   const lastAction=last?{kind:last.kind,phase:last.phase,reason:last.reason||null,at:last.at}:null;
   const lastKey=last?JSON.stringify([last.kind,last.phase,last.reason,last.at,last.targetId]):null,lastChanged=!!last&&movementQaLastActions.get(m)!==lastKey;
   movementQaLastActions.set(m,lastKey);
   const targetId=active?.targetId||last?.targetId,target=targetId?getTarget(targetId):null;
   const sourceTarget=targetId?(findNpc(targetId)||raw(targetId)||(targetId==='player'||targetId==='npc_player'?player:null)):null;
   const position=target?.position,targetR=Number.isFinite(position?.z)?position.z/scale():null,targetC=Number.isFinite(position?.x)?position.x/scale():null;
   const targetWalking=sourceTarget?!!(sourceTarget.walking||sourceTarget.moving||sourceTarget.isMoving||sourceTarget._moving||sourceTarget._followSpeed>0):typeof target?.walking==='boolean'?target.walking:null;
   const action=active?{kind:active.kind,phase:active.phase,progress:Number.isFinite(active.progress)?active.progress:0,targetId:active.targetId,targetR,targetC,targetWalking}:null;
   if(action||lastChanged){
    const sample=action||{kind:last.kind,phase:last.phase,progress:last.phase==='completed'?1:0,targetId:last.targetId,targetR,targetC,targetWalking};
    movementQaActionHistory.push({at,memberId:m.id,memberR:m.r,memberC:m.c,...sample});
    if(movementQaActionHistory.length>16)movementQaActionHistory.splice(0,movementQaActionHistory.length-16);
   }
   return {id:m.id,r:m.r,c:m.c,waterEscaping:!!m._waterEscaping,bodyDepth:bodyDepth?_npcWaterEscapeDepth(m.r,m.c,waterEscapeOptions):null,moveReason:m._mercenaryMoveReason||'idle',order:m._mercenaryOrder||'follow',goal:goal?{r:goal.z/scale(),c:goal.x/scale(),stopDistance:m._mercenaryMove.stopDistance}:null,followSpeed:Number(m._followSpeed)||0,catchup:m._mercenaryCatchup||null,catchupStatus:catchupRecovery?.inspect(m.id)||null,action,lastAction};
  });
  document.documentElement.dataset.mercenaryMovement=JSON.stringify({version:'water-follow23-v1',actionHistoryVersion:1,at,local:local(),nativeConnected,hero:{r:player.r,c:player.c},crew,actionHistory:movementQaActionHistory});
 }
 const candidates=new Map(),records=new Map(),recruitedResidents=new Map(),inventorySeen=new WeakSet(),appliedBlasts=new Set();
 const conversations=new Map();
 const savedIdentities=new Map();
 const memberKey=id=>{const key=String(id||'').replace(/^npc:/,'');return key.startsWith('npc_crew_')?key.slice(9):key.startsWith('crew_')?key.slice(5):key;};
 const raw=id=>gang().find(m=>String(m.id)===memberKey(id));
 const record=id=>core?.getRecord(id);
 const permitted=()=>local()?null:failure('На сервере найм и выдача оружия пока недоступны.');
 const quantity=i=>Math.max(0,Number(i.qty??i.count??i.quantity)||0);
 function personalName(id,look){
  const first=Number(look?.gender)===1?['Лючия','Мария','Анна','Джулия','София','Кьяра','Франческа','Паола','Елена','Роза','Валентина','Изабелла','Карла','Джованна','Анджела','Сильвия']:['Лука','Марко','Карло','Антонио','Винченцо','Паоло','Марио','Франко','Джованни','Сальваторе','Энцо','Роберто','Дарио','Бруно','Пьетро','Анджело'];
  const last=['Рицци','Моретти','Конти','Романо','Ломбарди','Марино','Греко','Ферраро','Коста','Фонтана','Беллини','Риччи','Манчини','Коломбо','Витале','Де Лука'];
  let hash=2166136261;for(const char of String(id))hash=Math.imul(hash^char.charCodeAt(0),16777619)>>>0;
  return first[hash%first.length]+' '+last[Math.floor(hash/first.length)%last.length];
 }
 function inventory(){return typeof _inventoryItems!=='undefined'?_inventoryItems:[];}
 function setQuantity(i,n){i.qty=n;if('count'in i)i.count=n;if('quantity'in i)i.quantity=n;}
 function reconcileInventory(items){
  if(!ready||!local()||!Array.isArray(items))return items;
  const reserved=new Map();
  for(const r of core.getRoster())if(r.weapon)reserved.set(String(r.weapon.id),(reserved.get(String(r.weapon.id))||0)+1);
  for(const item of items){
   if(!item||typeof item!=='object'||item.type!=='weapon'||inventorySeen.has(item))continue;
   inventorySeen.add(item);
   const id=String(item.id||item.item_id),remaining=reserved.get(id)||0;
   if(remaining){const available=quantity(item),used=Math.min(available,remaining);setQuantity(item,available-used);reserved.set(id,remaining-used);}
  }
  return items;
 }
 function syncInventory(){if(typeof _syncMyWeaponsFromInventory==='function')_syncMyWeaponsFromInventory(inventory());if(typeof currentWeapon!=='undefined'&&currentWeapon&&!inventory().some(i=>i.type==='weapon'&&i.id===currentWeapon&&quantity(i)>0)){currentWeapon=null;if(typeof _saveCurrentWeaponChoice==='function')_saveCurrentWeaponChoice();if(typeof renderWeaponHud==='function')renderWeaponHud();}}
 function returnWeapon(weapon){if(!weapon)return;let existing=inventory().find(i=>i.id===weapon.id&&i.type==='weapon');if(existing)setQuantity(existing,quantity(existing)+1);else{existing={...weapon,qty:1,count:1,quantity:1};inventory().push(existing);}inventorySeen.add(existing);}
 function takeWeapon(id){const item=inventory().find(i=>String(i.id)===String(id)&&i.type==='weapon'&&quantity(i)>0);if(!item)return null;const copy={...item,qty:1,count:1,quantity:1};setQuantity(item,quantity(item)-1);inventorySeen.add(item);return copy;}
 function persist(saveGang=false){if(!local()||!core||restoreBlocked)return;try{const rows=core.getRoster().map(r=>{const m=raw(r.id);return m?{id:r.id,sourceBotId:m.sourceBotId,name:m.name,look:m.look,r:m.r,c:m.c,hp:m.hp,max_hp:m.max_hp,weapon:m.weapon,faction:m.faction,gangName:m.gangName,baseHp:m._mercenaryBaseHp,_mercenaryOrder:m._mercenaryOrder||'follow',_mercenaryRally:m._mercenaryRally||null,...(qaSupported()&&Number.isFinite(m._mercenaryQaRescueUntil)&&m._mercenaryQaRescueUntil>now()?{_mercenaryQaRescueUntil:Math.min(now()+600,m._mercenaryQaRescueUntil)}:{})}:null;}).filter(Boolean);const text=JSON.stringify({core:core.snapshot(),rows});localStorage.setItem(KEY,text);persistenceDiagnostics.save={ok:true,at:now(),ids:rows.map(r=>r.id),bytes:text.length};if(saveGang&&typeof _saveGang==='function')_saveGang();}catch(e){persistenceDiagnostics.save={ok:false,at:now(),error:String(e.message||e)};console.warn('Mercenary save failed',e);}lastSave=now();reportPersistence();}
 function recruitableResident(n){
  const combatTarget=document.getElementById?.('npc-combat-session')?.dataset?.npcId;if(combatTarget&&String(n?.id)===String(combatTarget))return false;
  if(!n||n.id==null||n.dead||n.hp<=0||n._empireBoss||n._empireGuard||n._specialistId||n._medicalDowned||n._hostile||n._fighting||n._fightingMelee||n.gang||n.snitching)return false;
  if(n._invulnerable||n._guard||n._cashier||n._empireCrew||n._policeCriminal||n._clientOfBiz||n._botCorpse||n._transientCorpseId||n._said||n._civilianTrip||n._civilianTripRiding||n._ambientTrafficDriver||n._civilianSeat)return false;
  if(n.vehicleId||n.vehicle_id||n._inVehicle||n._inCar||n._insideBuilding||n._residentIndoors||n._interiorId||n.interior_id||n._evacuated||n._carriedByAmbulance)return false;
  return typeof _isRespawnableResident!=='function'||_isRespawnableResident(n);
 }
 function candidateIndoors(n){return !!(n&&!n.dead&&n.hp>0&&n._residentIndoors&&typeof RESIDENTS_INDOORS!=='undefined'&&RESIDENTS_INDOORS.includes(n));}
 function candidateInTransit(n){return !!(n&&!n.dead&&n.hp>0&&npcs().includes(n)&&(n._civilianTrip||n._civilianTripRiding||n._ambientTrafficDriver||n._civilianSeat||n._npcInitialPlacementPending));}
 function holdConversation(n){
  if(typeof _beginNpcPlayerConversation==='function')return _beginNpcPlayerConversation(n);
  n._playerConversationOpen=true;n._playerConversationUntil=Number.MAX_SAFE_INTEGER;n._talking=Number.MAX_SAFE_INTEGER;n.walking=false;n.walkPhase=0;n.tr=n.r;n.tc=n.c;return true;
 }
 function beginConversation(id){
  if(!ready||!local())return failure('Разговор недоступен.');const own=raw(id);if(own&&record(own.id)){if(own.hp<=0||own.dead||own._mercenaryHospital||Math.hypot(own.r-player.r,own.c-player.c)*scale()>2.5)return failure('Подойдите к бойцу ближе 2,5 м.');own._mercenaryConversation=true;conversations.set(String(id),own);return success('Разговор начат.');}const n=candidates.get(String(id))?.npc;
  if(!n||!npcs().includes(n)||!recruitableResident(n)||Math.hypot(n.r-player.r,n.c-player.c)*scale()>3)return failure('Подойдите ближе к собеседнику.');
  if(!holdConversation(n))return failure('Собеседник недоступен.');conversations.set(String(id),n);return success('Разговор начат.');
 }
 function endConversation(id){
  const n=conversations.get(String(id))||candidates.get(String(id))?.npc;conversations.delete(String(id));if(!n)return false;if(record(n.id)){delete n._mercenaryConversation;return true;}
  if(demoSupported()&&n._mercenaryDemoLineup&&npcs().includes(n)&&recruitableResident(n)&&!(n.panicUntil>performance.now())){holdConversation(n);return true;}
  if(typeof _endNpcPlayerConversation==='function')_endNpcPlayerConversation(n);
  if(typeof _resumeNpcAfterPlayerConversation==='function')_resumeNpcAfterPlayerConversation(n,npcs().includes(n));
  else{n._playerConversationOpen=false;n._playerConversationUntil=0;n._talking=0;}
  return true;
 }
 function protectedCombatRole(n){return !!(n?.police||n?._police||n?._guard||n?._empireGuard||n?._empireBoss||n?._empireCrew||n?.gang||n?.empireBoss||n?.empireGuard);}
 function candidateCombat(n){return !protectedCombatRole(n)&&!!(n?._fighting||n?._fightingMelee||n?._hostile);}
 function weaponDrawn(n){const t=performance.now();return !!n&&n.hp!==0&&!n.dead&&(n._mercenaryDefending||candidateCombat(n)||(+n._shotAt>0&&t-n._shotAt>=0&&t-n._shotAt<500));}
 function adoptCandidates(){if(!professions||!local()||now()-lastCandidates<2)return;lastCandidates=now();for(const[id,c]of candidates)if(!candidateIndoors(c.npc)&&!candidateInTransit(c.npc)&&(!npcs().includes(c.npc)||!recruitableResident(c.npc)&&!candidateCombat(c.npc))){if(!protectedCombatRole(c.npc)&&c.npc.weapon==='pistol'&&c.npc._mercenaryProfession)c.npc.weapon=null;candidates.delete(id);}const occupied=new Set([...records.values()].map(r=>r.profession));for(const c of candidates.values())occupied.add(c.profession);const hired=new Set(gang().map(m=>String(m.sourceBotId)));const choices=npcs().filter(n=>recruitableResident(n)&&!hired.has(String(n.id))).sort((a,b)=>Math.hypot(a.r-player.r,a.c-player.c)-Math.hypot(b.r-player.r,b.c-player.c)||String(a.id).localeCompare(String(b.id)));for(const p of Object.keys(professions)){if(occupied.has(p))continue;const n=choices.find(n=>(!n._mercenaryProfession||n._mercenaryProfession===p)&&![...candidates.values()].some(c=>c.npc===n));if(!n)break;n._mercenaryProfession=p;n._mercenaryOwnWeapon='pistol';n.weapon='pistol';if(!String(n.name||'').trim())n.name=personalName(n.id,n.look);candidates.set(String(n.id),{npc:n,profession:p});}}
 function releaseAsResident(m){
  if(!m||m.hp<=0||m.dead||m._mercenaryHospital)return null;
  const sourceId=String(m.sourceBotId??savedIdentities.get(m.id)??'').trim();if(!sourceId)return null;
  let n=recruitedResidents.get(m.id)||npcs().find(row=>String(row.id)===sourceId);
  if(!n)n={id:sourceId,look:{...m.look},_arcKey:'worker',_relation:0,_beach:false,_allowBeach:false};
  // A dismissal changes ownership, not identity. The same living person returns
  // to the city scheduler at the fighter's last safe world position.
  const worldSpace=typeof _gangSpaceKey!=='function'||_gangSpaceKey()==='world',r=worldSpace&&Number.isFinite(m.r)?m.r:(Number.isFinite(n.r)?n.r:m.r),c=worldSpace&&Number.isFinite(m.c)?m.c:(Number.isFinite(n.c)?n.c:m.c),stamp=performance.now();
  const personalWeapon=String(n._mercenaryOwnWeapon||'pistol');
  Object.assign(n,{id:sourceId,name:m.name||n.name,look:{...(n.look||{}),...(m.look||{})},r,c,tr:r,tc:c,ang:Number(m.ang)||0,walkPhase:0,walking:false,idleUntil:stamp+350,hp:Math.max(1,Math.min(Number(m.hp)||1,Number(n.max_hp)||Number(m.max_hp)||80)),max_hp:Math.max(1,Number(n.max_hp)||Number(m.max_hp)||80),alive:true,dead:false,_hostile:false,_fighting:false,_fightingMelee:false,snitching:false,panicUntil:0,_relation:0,_beach:false,weapon:personalWeapon,_fightWeapon:'',_formerMercenary:true,_formerMercenaryWeapon:personalWeapon,_civilianPlan:{phase:'seek_shop',cycle:(n._civilianPlan?.cycle||0)+1,retryAt:stamp+800},_buildingVisitCooldownUntil:stamp+800});
  n.speed=Number.isFinite(n.speed)&&n.speed>0?n.speed:1.2;n._arcKey=n._arcKey&&n._arcKey!=='bandit'?n._arcKey:'worker';if(typeof NPC_ARCHETYPES!=='undefined')n._arc=NPC_ARCHETYPES[n._arcKey]||NPC_ARCHETYPES.worker||n._arc;
  for(const key of ['_residentIndoors','_residentNativeVisit','_civilianSeat','_civilianTrip','_civilianTripRiding','_ambientTrafficDriver','_ambientTrafficCarId','_ambientTrafficPhase','_ambientTrafficProgress','_npcInitialPlacementPending','_playerConversationOpen','_mercenaryDemoLineup','_mercenaryQaInvite'])delete n[key];
  n._talking=0;if(typeof _clearNpcRoute==='function')_clearNpcRoute(n);if(typeof _initNpcEmotions==='function'&&n._fear==null)_initNpcEmotions(n);
  if(!npcs().includes(n))npcs().push(n);if(typeof _hiredBotIds!=='undefined')_hiredBotIds.delete(sourceId);recruitedResidents.delete(m.id);lastCandidates=-Infinity;return n;
 }
 function rescueContact(position,angle=0){const a=Number(angle)||0,dx=Math.cos(a),dz=Math.sin(a);return {workRange:.75,workPoint:{x:position.x+dx*.15,y:position.y+.35,z:position.z+dz*.15},workNormal:{x:-dz,y:0,z:dx},supportPoint:{x:position.x+dx*.15-dz*.16,y:position.y+.35,z:position.z+dz*.15+dx*.16}};}
 function squadPosture(m){if(!m||m.hp<=0||m._mercenaryHospital||['working','awaiting'].includes(m._mercenaryAction?.phase))return 'stand';const value=typeof _effectivePlayerStance==='function'?_effectivePlayerStance():'stand';return value==='crouch'||value==='prone'?value:'stand';}
 function movementSnapshot(m){const route=m._mercenaryPath;return {reason:m._mercenaryHospital?'hospital':m.hp<=0?'downed':m._mercenaryMoveReason||(!m._mercenaryMove?'idle':'moving'),clock:{...movementClock,substeps:m._mercenaryMoveSubsteps||0},search:route?.search?{...route.search.stats}:route?.stats?{...route.stats}:null,pathLength:route?.path?.length||0,pathIndex:route?.index||0,goal:m._mercenaryMove?.position?{...m._mercenaryMove.position}:null,routeGoal:route?.goal?{...route.goal}:null,lastAction:m._mercenaryLastAction?{...m._mercenaryLastAction}:null};}
 const squadPassengerSeats=['front_right','rear_left','rear_right'];
 function squadDoorPath(m,id,from,to){
  return targets.squadTransport?.canCross?.(id,from,to)===true&&typeof _civilianTripDoorPath==='function'&&_civilianTripDoorPath({npc:m,carId:id},from.r,from.c,to.r,to.c);
 }
 function squadSourceCar(id){const key=String(id).replace(/^quest_/,''),numeric=Number(key);return typeof questCars!=='undefined'?questCars.get(key)||(String(numeric)===key?questCars.get(numeric):null):null;}
 function squadVehicleById(id){
  const vehicle=targets.squadTransport?.getVehicle?.(id);if(!vehicle||!vehicle.source)return vehicle;
  const car=squadSourceCar(id);if(!car||![car.x,car.y].every(Number.isFinite))return null;
  return {...vehicle,r:+car.y,c:+car.x,ang:+car.ang||0,speed:Math.hypot(+car.vx||0,+car.vy||0)*scale()};
 }
 function playerSquadVehicle(){
  const vehicle=targets.squadTransport?.getPlayerVehicle?.();if(!vehicle||vehicle.blocked)return null;
  const reserved=new Set(vehicle.occupied||[]);
  if(vehicle.source&&typeof questCars!=='undefined'){
   const car=squadSourceCar(vehicle.id);
   if(!car||![car.x,car.y].every(Number.isFinite)||car._hidden||car._towed||car._wrecked||car._walkWrecked||car.wrecked)return null;
   vehicle.r=+car.y;vehicle.c=+car.x;vehicle.ang=+car.ang||0;vehicle.speed=Math.hypot(+car.vx||0,+car.vy||0)*scale();
   // Existing source contract has exactly one passenger slot. Unexpected
   // anonymous additional occupants fail closed rather than sharing a seat.
   const passengers=car.passenger_uids||[];if(passengers.length>1)for(const seat of vehicle.seats)reserved.add(seat);
   else if(passengers.length)reserved.add('front_right');
  }
  return {...vehicle,seats:vehicle.seats.filter(seat=>squadPassengerSeats.includes(seat)&&!reserved.has(seat))};
 }
 function squadVehicleDrop(m,index,vehicle){
  if(!vehicle||vehicle.speed>.5||typeof findSquadSafeDrop!=='function')return null;
  const access=targets.squadTransport?.access?.({carId:vehicle.id,seatId:m._mercenaryVehicleSeat});if(!access)return null;
  m._mercenaryVehicleDropState??={};
  const drop=findSquadSafeDrop(m,index,toWorld(access.outside),vehicle.ang,m._mercenaryVehicleDropState);
  const point=drop?.point||drop;if(drop?.status&&drop.status!=='ready'||![point?.x,point?.z].every(Number.isFinite))return null;
  const result={r:point.z/scale(),c:point.x/scale()};
  if(!canMoveMember(m.id,m._mercenaryVehicleExitPlan?.stage==='body'?m:access.outside,result)){Object.assign(m._mercenaryVehicleDropState,{attempt:(m._mercenaryVehicleDropState.attempt||0)+1,pending:null,status:'pending'});return null;}return result;
 }
 function clearSquadVehicle(m,index,vehicle,elapsed=0){
  if(!m?._mercenaryVehicleSeat)return false;
  m._followSpeed=0;m.walking=false;
  m._mercenaryVehicleExitPending=true;if(!vehicle||vehicle.speed>.5)return false;
  const access=targets.squadTransport?.access?.({carId:vehicle.id,seatId:m._mercenaryVehicleSeat});if(!access)return false;
  let plan=m._mercenaryVehicleExitPlan;
  if(!plan){const drop=squadVehicleDrop(m,index,vehicle);if(!drop||!squadDoorPath(m,vehicle.id,m,access.outside))return false;
   plan=m._mercenaryVehicleExitPlan={drop,stage:'door',doorDistance:Math.max(.01,Math.hypot(m.r-access.outside.r,m.c-access.outside.c)*scale())};m._mercenaryVehiclePhase='exit';m._mercenaryVehicleProgress=0;
  }
  if(!plan.drop){if(now()<(plan.retryAt||0))return false;plan.drop=squadVehicleDrop(m,index,vehicle);if(!plan.drop)return false;}
  const target=plan.stage==='door'?access.outside:plan.drop,d=Math.hypot(target.r-m.r,target.c-m.c),step=Math.min(d,Math.max(0,elapsed)*3/scale());
  const next=d>1e-8?{r:m.r+(target.r-m.r)*step/d,c:m.c+(target.c-m.c)*step/d}:{r:target.r,c:target.c};
  if(plan.stage==='door'?!squadDoorPath(m,vehicle.id,m,next):!canMoveMember(m.id,m,next)){if(plan.stage==='body')invalidateSquadExit(m,plan);return false;}
  const arrived=d-step<1e-5;
  if(arrived&&plan.stage==='body'){
   const budget=typeof squadDropChecksRemaining==='number'?squadDropChecksRemaining:0,valid=typeof validateSquadSafeDrop==='function'?validateSquadSafeDrop(m,toWorld(plan.drop)):null;
   if(!valid||![valid.x,valid.y,valid.z].every(Number.isFinite)){if(budget>0)invalidateSquadExit(m,plan);return false;}
  }
  const heading=Math.atan2(next.r-m.r,next.c-m.c);m.r=m.tr=next.r;m.c=m.tc=next.c;m._followSpeed=elapsed>0?step*scale()/elapsed:0;m.walkPhase+=elapsed*6;if(plan.stage==='body'&&step>0){m.walking=true;m.ang=heading;}
  if(plan.stage==='door'){m._mercenaryVehicleProgress=Math.min(1,Math.max(0,1-(d-step)*scale()/plan.doorDistance));if(arrived){plan.stage='body';m._mercenaryVehicleProgress=1;}}
  targets.squadTransport?.access?.({carId:vehicle.id,seatId:m._mercenaryVehicleSeat,phase:'exit',progress:m._mercenaryVehicleProgress});
  if(!arrived||target!==plan.drop)return false;
  targets.squadTransport?.access?.({carId:m._mercenaryVehicleId,seatId:m._mercenaryVehicleSeat,phase:'release'});
  m.ang=vehicle.ang;
  for(const key of ['_mercenaryVehicleSeat','_mercenaryVehicleId','_mercenaryVehicleChaseAt','_mercenaryVehiclePhase','_mercenaryVehicleProgress','_mercenaryVehicleExitPending','_mercenaryVehicleDropState','_mercenaryVehicleExitPlan','_mercenaryVehicleMove','_mercenaryVehicleReservedSeat','_mercenaryVehicleReservedId'])delete m[key];
  m._mercenaryVehicleChase=false;m._mercenaryPath=null;m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;return true;
 }
 function invalidateSquadExit(m,plan){
  plan.drop=null;plan.retryAt=now()+.2;m._followSpeed=0;m.walking=false;
  const state=m._mercenaryVehicleDropState||(m._mercenaryVehicleDropState={});Object.assign(state,{attempt:(state.attempt||0)+1,pending:null,status:'pending'});
 }
 function catchupSquadVehicle(m,index,vehicle,access,elapsed){
  const stamp=now(),position=toWorld(m),origin=toWorld(vehicle),distance=Math.hypot(position.x-origin.x,position.z-origin.z);
  let state=m._mercenaryVehicleCatchup;
  if(!state||state.vehicleId!==vehicle.id)state=m._mercenaryVehicleCatchup={vehicleId:vehicle.id,progressAt:stamp,position,farAt:distance>65?stamp:null,search:{}};
  const interrupted=elapsed<=0||document.hidden===true||state.lastAt!==undefined&&stamp-state.lastAt>1;
  state.lastAt=stamp;
  if(interrupted||m._mercenaryConversation||m._playerConversationOpen||m._mercenarySafeExit||m._carriedByAmbulance||m._ambulanceInTransit||m._ambulanceLoading||m._evacuated||m._carriedBy||m.carrying||m._carrying||m._carriedNpc||m._residentIndoors||m._insideBuilding||m._interiorId||m.interior_id){state.progressAt=stamp;state.position=position;state.farAt=null;state.search={};return false;}
  if(Math.hypot(position.x-state.position.x,position.z-state.position.z)>=1.25){state.progressAt=stamp;state.position=position;}
  if(distance>65){state.farAt??=stamp;}else state.farAt=null;
  if(Math.hypot(m.r-access.outside.r,m.c-access.outside.c)*scale()<=1.5){state.progressAt=stamp;state.search={};return false;}
  if(vehicle.speed>.5||stamp<(m._mercenaryVehicleCatchupUntil||0)||!(state.farAt!==null&&stamp-state.farAt>=6||stamp-state.progressAt>=10))return false;
  const point=typeof findSquadSafeDrop==='function'?findSquadSafeDrop(m,index,origin,vehicle.ang,state.search):null;if(!point)return false;
  // A safe point must also connect to this reserved door. Failed candidates
  // advance the bounded search; there is no car-centre or seat fallback.
  const target={r:point.z/scale(),c:point.x/scale()};
  if(!canMoveMember(m.id,target,access.outside)){Object.assign(state.search,{attempt:(state.search.attempt||0)+1,pending:null,status:'pending'});return false;}
  m.r=m.tr=target.r;m.c=m.tc=target.c;if(typeof _clearNpcRoute==='function')_clearNpcRoute(m);m._mercenaryPath=null;m._mercenaryFollowGoal=null;m._mercenaryFollowAt=0;m._mercenaryDetourUntil=0;m._followSpeed=0;m.walkPhase=0;m.walking=false;m._mercenaryVehicleCatchupUntil=stamp+20;
  m._waterEscaping=false;m._waterEscapeTarget=null;m._waterEscapeSearch=null;m._waterEscapeRetryAt=0;
  state.progressAt=stamp;state.position=point;state.farAt=null;state.search={};return true;
 }
 function squadVehicleTick(roster,elapsed=0){
  const vehicle=playerSquadVehicle(),members=roster.map(row=>({row,m:raw(row.id)})).filter(item=>item.m),assigned=new Set(),transport=targets.squadTransport;let teleported=0;
  for(let index=0;index<members.length;index++){const {m}=members[index];if(!m._mercenaryVehicleSeat)continue;
   const own=squadVehicleById(m._mercenaryVehicleId);
   // A wound or a firing order never changes occupied-seat ownership.
   const exit=m._mercenaryVehiclePhase==='exit'||!vehicle||vehicle.id!==m._mercenaryVehicleId||!vehicle.seats.includes(m._mercenaryVehicleSeat)||(m._mercenaryOrder||'follow')!=='follow'||!!core.getAction(m.id);
   if(!exit&&m._mercenaryVehicleExitPending){delete m._mercenaryVehicleExitPending;delete m._mercenaryVehicleDropState;}
   if(exit&&m.hp>0&&!m.dead&&!m._mercenaryHospital&&clearSquadVehicle(m,index,own,elapsed))continue;
   if(vehicle?.id===m._mercenaryVehicleId)assigned.add(m._mercenaryVehicleSeat);
   if(m._mercenaryVehiclePhase==='exit')continue;
   if(!own)continue;
   const access=transport.access({carId:own.id,seatId:m._mercenaryVehicleSeat,phase:m._mercenaryVehiclePhase||'drive',progress:m._mercenaryVehicleProgress??1});
   if(!access)continue;
   if(m._mercenaryVehiclePhase==='board'){
    if(own.speed>.5){
     // Keep the source body where it is. Once the moving hull has cleared it,
     // return to ordinary door approach while retaining this exact reservation.
     m._followSpeed=0;m.walkPhase=0;
     if(canMoveMember(m.id,m,m)){
      assigned.delete(m._mercenaryVehicleSeat);transport.access({carId:own.id,seatId:m._mercenaryVehicleSeat,phase:'release'});
      m._mercenaryVehicleReservedId=own.id;m._mercenaryVehicleReservedSeat=m._mercenaryVehicleSeat;
      delete m._mercenaryVehicleSeat;delete m._mercenaryVehicleId;delete m._mercenaryVehiclePhase;delete m._mercenaryVehicleProgress;m._mercenaryPath=null;
     }continue;
    }
    const progress=Math.min(1,(m._mercenaryVehicleProgress||0)+Math.max(0,elapsed)/.75),goalR=access.outside.r+(access.seat.r-access.outside.r)*progress,goalC=access.outside.c+(access.seat.c-access.outside.c)*progress,distance=Math.hypot(goalR-m.r,goalC-m.c),step=Math.min(distance,Math.max(0,elapsed)*3/scale()),factor=distance>1e-8?step/distance:1,r=m.r+(goalR-m.r)*factor,c=m.c+(goalC-m.c)*factor;
    if(!squadDoorPath(m,own.id,m,{r,c}))continue;
    if(distance-step<1e-6)m._mercenaryVehicleProgress=progress;m.r=m.tr=r;m.c=m.tc=c;if(m._mercenaryVehicleProgress>=1){m._mercenaryVehiclePhase='drive';transport.access({carId:own.id,seatId:m._mercenaryVehicleSeat,phase:'release'});}
   }else{m.r=m.tr=access.seat.r;m.c=m.tc=access.seat.c;}
   m.ang=own.ang;m._mercenaryMove=null;m._mercenaryPath=null;m._followSpeed=0;m.walkPhase=0;m._mercenaryMoveReason=m._mercenaryVehicleExitPending?'vehicle_exit_pending':'vehicle_passenger';
  }
  const reservedOwners=new Map();for(const {row,m}of members){const seat=m._mercenaryVehicleReservedSeat;if(vehicle&&row.status==='active'&&m.hp>0&&!m.dead&&!m._mercenaryHospital&&!core.getAction(row.id)&&(m._mercenaryOrder||'follow')==='follow'&&!m._mercenaryDefending&&!m._mercenaryVehicleSeat&&m._mercenaryVehicleReservedId===vehicle.id&&vehicle.seats.includes(seat)&&!assigned.has(seat)&&!reservedOwners.has(seat))reservedOwners.set(seat,m.id);}
  for(const {row,m}of members){if(m._mercenaryVehicleSeat)continue;
   const eligible=vehicle&&row.status==='active'&&m.hp>0&&!m.dead&&!m._mercenaryHospital&&!core.getAction(row.id)&&(m._mercenaryOrder||'follow')==='follow'&&!m._mercenaryDefending;
   const previous=m._mercenaryVehicleReservedId===vehicle?.id?m._mercenaryVehicleReservedSeat:null,available=id=>!assigned.has(id)&&(!reservedOwners.has(id)||reservedOwners.get(id)===m.id),seat=eligible&&(vehicle.seats.includes(previous)&&available(previous)?previous:vehicle.seats.find(available));
   if(!seat){m._mercenaryVehicleChase=false;delete m._mercenaryVehicleMove;delete m._mercenaryVehicleReservedId;delete m._mercenaryVehicleReservedSeat;delete m._mercenaryVehicleCatchup;continue;}
   assigned.add(seat);m._mercenaryVehicleReservedSeat=seat;m._mercenaryVehicleReservedId=vehicle.id;
   const access=transport.access({carId:vehicle.id,seatId:seat});if(!access)continue;
   m._mercenaryVehicleChase=true;m._mercenaryVehicleMove={position:toWorld(access.outside),stopDistance:.12};
   if(catchupSquadVehicle(m,members.findIndex(item=>item.m===m),vehicle,access,elapsed)){teleported++;continue;}
   if(vehicle.speed>.5||Math.hypot(m.r-access.outside.r,m.c-access.outside.c)*scale()>.45)continue;
   if(!squadDoorPath(m,vehicle.id,m,access.seat))continue;
   m._mercenaryVehicleSeat=seat;m._mercenaryVehicleId=vehicle.id;m._mercenaryVehiclePhase='board';m._mercenaryVehicleProgress=0;m._mercenaryVehicleChase=false;m._mercenaryMove=null;m._mercenaryPath=null;m._followSpeed=0;m.walkPhase=0;
  }
  transport?.setReservations(members.map(({m})=>({vehicleId:m._mercenaryVehicleId||m._mercenaryVehicleReservedId,seatId:m._mercenaryVehicleSeat||m._mercenaryVehicleReservedSeat})));
  if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryVehicle=JSON.stringify({vehicleId:vehicle?.id||null,seated:members.filter(({m})=>m._mercenaryVehicleSeat).map(({m})=>({id:m.id,vehicleId:m._mercenaryVehicleId,seatId:m._mercenaryVehicleSeat,phase:m._mercenaryVehiclePhase,exitPending:!!m._mercenaryVehicleExitPending})),chasing:members.filter(({m})=>m._mercenaryVehicleChase).map(({m})=>m.id),teleported});
  return vehicle;
 }
 function getMember(id){const m=raw(id);if(!m)return null;const r=record(m.id);return{id:m.id,kind:'npc',queued:r?.queued||[],posture:squadPosture(m),revivable:r?.status!=='hospital',approachMoving:!!m._mercenaryPath?.path&&m._followSpeed>0,approachSearching:!!m._mercenaryPath?.search&&now()-(m._mercenaryPath.lastSearchProgressAt||0)<2,...(qaSupported()?{movement:movementSnapshot(m)}:{}),qaRescueUntil:m._mercenaryQaRescueUntil&&qaSupported()?m._mercenaryQaRescueUntil:0,intimidatable:false,position:toWorld(m),...(m.hp<=0?rescueContact(toWorld(m),m.ang):{}),hp:+m.hp||0,dead:false,downed:m.hp<=0,available:r?.status!=='hospital',followArrived:Math.hypot(m.r-player.r,m.c-player.c)*scale()<7};}
 function getTarget(id){const key=String(id||'').replace(/^npc:/,'');if(key==='player'||key==='npc_player')return{id:'player',kind:'player',position:toWorld(player),hp:typeof myHp!=='undefined'?myHp:100,downed:typeof myDead!=='undefined'&&myDead,...(typeof myDead!=='undefined'&&myDead?rescueContact(toWorld(player),player.ang):{}),revivable:canRevivePlayer()};const member=getMember(id);if(member)return member;const npc=findNpc(id);if(npc)return{id:String(id),kind:'npc',position:toWorld(npc),hp:npc.hp,dead:!!npc.dead,fearActive:!npc.dead&&npc.hp>0&&performance.now()<(npc._intimidatedUntil||0),fearExpiresAt:!npc.dead&&npc.hp>0&&performance.now()<(npc._intimidatedUntil||0)?Date.now()+npc._intimidatedUntil-performance.now():0,revivable:false,intimidatable:!npc._empireBoss&&!npc._guard&&!npc._invulnerable};return targets.get?.(id)||null;}
 function queueSafeExit(m,action){
  if(action.kind!=='unlock_safe'||action.phase!=='completed'||m.hp<=0||m._mercenaryHospital)return;
  const target=getTarget(action.targetId),normal=target?.workNormal||m._mercenaryAction?.workNormal,len=Math.hypot(normal?.x||0,normal?.z||0);
  if(!Number.isFinite(len)||len<.01)return;
  const origin=toWorld(m),nx=normal.x/len,nz=normal.z/len;
  for(const side of [0,.55,-.55]){
   const position={x:origin.x+nx*1.2-nz*side,y:origin.y,z:origin.z+nz*1.2+nx*side};
   if(!canMoveMember(m.id,{r:position.z/scale(),c:position.x/scale()},{r:position.z/scale(),c:position.x/scale()}))continue;
   m._mercenarySafeExit={position,stopDistance:.08,phase:'safe_exit',targetId:action.targetId,expires:now()+12};m._mercenaryPath=null;return;
  }
 }
 function moveMember(id,target,options={}){const m=raw(id);if(m){m._mercenaryReturnMove=false;const previous=m._mercenaryMove;if(!target||previous?.targetId!==target.id||previous?.phase!==options.phase){m._mercenaryPath=null;m._mercenaryDetourUntil=0;}m._mercenaryMove=target?{targetId:target.id,phase:options.phase,tracksMovingTarget:options.phase==='approach'&&target.kind==='vehicle'&&core?.getAction(id)?.kind==='plant_bomb',position:{...target.position},stopDistance:options.stopDistance||0}:null;}}
 function focusTarget(id){
  if(!local()||raw(id))return null;const key=String(id||'').replace(/^npc:/,'');let ref=findNpc(key),kind='street_npc';
  if(!ref&&typeof cityCops!=='undefined'){ref=cityCops.find(n=>String(n.id)===key||`npc_city_cop_${n.id}`===key);kind='city_cop';}
  if(!ref&&typeof _buildingInt!=='undefined'&&(_buildingInt?.robbery||(typeof _majorInteriorObjectId!=='undefined'&&_majorInteriorObjectId))){ref=_buildingInt?.npcs?.find(n=>String(n.id)===key||typeof _threeNpcEntityId==='function'&&String(_threeNpcEntityId(n))===key);kind='interior_guard';}
  if(!ref&&typeof _bankInt!=='undefined'&&_bankInt){ref=_bankInt.npcs?.find(n=>String(n.id)===key||typeof _threeNpcEntityId==='function'&&String(_threeNpcEntityId(n))===key);kind='bank_guard';}
  if(!ref||ref.dead||ref.alive===false||ref.hp<=0||ref.downed||ref._medicalDowned||ref._empireDownUntil>performance.now()||ref._invulnerable||ref._allied||ref._friendly||ref.hired||gang().includes(ref)||gang().some(m=>String(m.sourceBotId)===String(ref.id)))return null;
  if(kind==='interior_guard'&&ref.role!=='biz_guard'&&!ref.majorGuard)return null;
  const r=Number(ref.r??ref.y),c=Number(ref.c??ref.x);if(!Number.isFinite(r)||!Number.isFinite(c))return null;
  return {kind,ref,id:ref.id??key,sourceId:key};
 }
 function clearFocus(m){if(m){delete m._mercenarySafeExit;delete m._mercenaryConversation;delete m._mercenaryGreetingUntil;}const focus=m?._mercenaryFocus;if(!focus)return;if(m.targetRef===focus.ref){m.targetKind=null;m.targetRef=null;m.targetId=null;}delete m._mercenaryFocus;m._mercenaryDefending=false;}
 function getFocusedTarget(id){const m=raw(id),focus=m?._mercenaryFocus;if(!focus)return null;const live=focusTarget(focus.sourceId);if(!live||live.ref!==focus.ref){clearFocus(m);return null;}return live;}
 function focusPosition(focus){return toWorld({r:Number(focus.ref.r??focus.ref.y),c:Number(focus.ref.c??focus.ref.x)});}
 const vehicleFireWeapons=new Set(['pistol','pistol_heavy','nagan','tt_pistol','revolver','deagle','golden_colt','golden_pistol','pistol_gold','smg','uzi','golden_uzi','tommy_gun','golden_tommy','rifle','golden_ak','ak74','m16','sawn_off','shotgun','sniper']);
 const vehicleAttackReceipts=new Map();let vehicleDefenseEnabled=false,vehicleDefenseId=null,vehicleAttackSequence=0;
 function defenseVehicle(){const vehicle=local()&&!(typeof myDead!=='undefined'&&myDead)&&playerSquadVehicle();if(!vehicle||vehicleDefenseId&&vehicle.id!==vehicleDefenseId){vehicleDefenseEnabled=false;vehicleDefenseId=null;vehicleAttackReceipts.clear();}return vehicle||null;}
 function vehicleWeaponReason(weapon){return weapon==='rpg'||weapon==='bazooka'?'Для РПГ из машины ещё нет подтверждаемого запуска ракеты.':!weapon||['none','melee','fists','unarmed'].includes(weapon)?'Нужно огнестрельное оружие в руках.':'Это оружие нельзя использовать из окна.';}
 function vehicleFireMember(id){
  if(!ready||!local()||typeof myDead!=='undefined'&&myDead)return null;
  const m=raw(id),r=m&&record(m.id);if(!m||r?.status!=='active'||m.hp<=0||m.dead||m._mercenaryHospital||core.getAction(m.id)||!vehicleFireWeapons.has(m.weapon)||m._mercenaryVehiclePhase!=='drive'||m._mercenaryVehicleExitPending||!squadPassengerSeats.includes(m._mercenaryVehicleSeat))return null;
  const vehicle=targets.squadTransport?.getVehicle?.(m._mercenaryVehicleId),playerVehicle=playerSquadVehicle();
  if(!vehicle||vehicle.blocked||playerVehicle?.id!==vehicle.id||!vehicle.seats?.includes(m._mercenaryVehicleSeat)||![vehicle.r,vehicle.c,vehicle.ang].every(Number.isFinite))return null;
  return {m,vehicle};
 }
 function getVehicleDefenseFireState(){
  const vehicle=defenseVehicle(),roster=core?.getRoster()||[],eligible=vehicle?roster.filter(r=>!!vehicleFireMember(r.id)).length:0;
  const unsupportedWeapons=vehicle?roster.map(r=>raw(r.id)).filter(m=>m?._mercenaryVehicleId===vehicle.id&&m._mercenaryVehicleSeat&&!vehicleFireWeapons.has(m.weapon)).map(m=>({memberId:m.id,weaponId:m.weapon||'none',reason:vehicleWeaponReason(m.weapon)})):[];
  return {enabled:vehicleDefenseEnabled,available:!!vehicle&&(vehicleDefenseEnabled||eligible>0),eligible,unsupportedWeapons,vehicleId:vehicle?.id||null,reason:!vehicle?'Нужно находиться в машине.':eligible?'':unsupportedWeapons[0]?.reason||'Нет готового вооружённого пассажира.'};
 }
 function setVehicleDefenseFire(enabled){
  if(!enabled){vehicleDefenseEnabled=false;vehicleDefenseId=null;return {...success('Ответный огонь выключен.'),enabled:false};}
  const state=getVehicleDefenseFireState();if(!state.available||!state.eligible)return failure(state.reason);
  vehicleDefenseEnabled=true;vehicleDefenseId=state.vehicleId;return {...success('Ответный огонь включён · ждём атакующих.'),enabled:true};
 }
 function toggleVehicleDefenseFire(){return setVehicleDefenseFire(!getVehicleDefenseFireState().enabled);}
 function qaVehicleDefenseAttack(){
  const qa=local()&&['localhost','127.0.0.1','[::1]'].includes(location.hostname)&&(qaSupported()||new URL(location.href||location.origin).searchParams.get('carqa')==='1');
  if(!qa||!defenseVehicle()||typeof _cityCopEngagePlayerAfterHit!=='function'||typeof _policeWorldLineClear!=='function')return failure('Проверка доступна только в локальной машине.');
  const cop=(typeof cityCops!=='undefined'?cityCops:[]).filter(c=>c?.alive&&!c.dead&&c.hp>0&&!c._allied&&!c._friendly&&Math.hypot(c.y-player.r,c.x-player.c)>.7&&Math.hypot(c.y-player.r,c.x-player.c)<50).sort((a,b)=>Math.hypot(a.y-player.r,a.x-player.c)-Math.hypot(b.y-player.r,b.x-player.c))[0];
  if(!cop)return failure('В радиусе проверки нет живого патрульного.');
  const distance=Math.hypot(cop.y-player.r,cop.x-player.c),pursuitRange=Math.max(24,typeof CITYCOP_PURSUE_R==='number'?CITYCOP_PURSUE_R:24);
  _cityCopEngagePlayerAfterHit(cop);return {...success(distance>pursuitRange?'Патрульный спровоцирован · приблизьтесь к нему для настоящей погони.':'Патрульный спровоцирован · ждём подхода и настоящей атаки.'),copId:cop.id,distanceMeters:Math.round(distance*scale())};
 }
 function canIssueVehicleFireCommand(){return getVehicleDefenseFireState().available;}
 // Only real incoming attack paths call this. Generic gang alerts also contain
 // player-selected targets and must never be treated as defensive provenance.
 function noteVehicleAttack(event){
  const vehicle=defenseVehicle();if(!vehicle||!event?.ref||!['player','member','vehicle'].includes(event.victimKind))return false;
  if(event.victimKind==='player'&&event.victimId&&event.victimId!=='player'||event.victimKind==='member'&&!raw(event.victimId)||event.victimKind==='vehicle'&&String(event.victimId)!==String(vehicle.id))return false;
  const sourceId=event.kind==='city_cop'?`npc_city_cop_${event.ref.id}`:typeof _threeNpcEntityId==='function'?_threeNpcEntityId(event.ref):String(event.ref.id??event.id??'');
  const focus=focusTarget(sourceId);if(!focus||focus.ref!==event.ref||focus.kind!==event.kind)return false;
  const key=focus.kind+':'+sourceId;vehicleAttackReceipts.delete(key);vehicleAttackReceipts.set(key,{...focus,at:performance.now(),vehicleId:vehicle.id,sequence:++vehicleAttackSequence});
  while(vehicleAttackReceipts.size>16)vehicleAttackReceipts.delete(vehicleAttackReceipts.keys().next().value);return true;
 }
 function vehicleAttacker(m,vehicle,rangeMeters){
  let best=null,bestDistance=Infinity;const stamp=performance.now(),yaw=Math.PI/2-vehicle.ang,side=m._mercenaryVehicleSeat.endsWith('left')?1:-1;
  for(const [key,receipt]of vehicleAttackReceipts){
   const live=focusTarget(receipt.sourceId);if(stamp<receipt.at||stamp-receipt.at>6000||receipt.vehicleId!==vehicle.id||!live||live.ref!==receipt.ref){vehicleAttackReceipts.delete(key);continue;}
   const position=focusPosition(live),dx=position.x-m.c*scale(),dz=position.z-m.r*scale(),distance=Math.hypot(dx,dz);
   if(distance>.01&&distance<=rangeMeters&&distance<bestDistance&&(dx*Math.cos(yaw)-dz*Math.sin(yaw))*side/distance>=.45){best={...live,attackSequence:receipt.sequence};bestDistance=distance;}
  }return best;
 }
 function getVehicleFireReadiness(id){
  if(!defenseVehicle()||!vehicleDefenseEnabled)return null;const member=vehicleFireMember(id);if(!member)return null;
  return {sourceVehicleId:member.vehicle.id,seatId:member.m._mercenaryVehicleSeat,weaponId:member.m.weapon};
 }
 function getVehicleFireIntent(id){
  if(!defenseVehicle()||!vehicleDefenseEnabled)return null;
  const member=vehicleFireMember(id);if(!member)return null;
  const {m,vehicle}=member,rangeMeters=(typeof GANG_ENGAGE_R==='number'?GANG_ENGAGE_R:10)*scale(),focus=vehicleAttacker(m,vehicle,rangeMeters);if(!focus)return null;
  const targetPosition=focusPosition(focus);
  targetPosition.y+=(Number(focus.ref.elevation)||0)+1.05;
  if(Math.hypot(targetPosition.x-m.c*scale(),targetPosition.z-m.r*scale())>rangeMeters)return null;
  const targetId=focus.kind==='city_cop'?`npc_city_cop_${focus.ref.id}`:typeof _threeNpcEntityId==='function'?_threeNpcEntityId(focus.ref):focus.sourceId;
  return {memberId:m.id,sourceVehicleId:vehicle.id,presentationVehicleId:vehicle.id,seatId:m._mercenaryVehicleSeat,weaponId:m.weapon,targetId,targetKind:focus.kind,targetRef:focus.ref,targetPosition,rangeMeters,attackSequence:focus.attackSequence,
   vehiclePose:{x:vehicle.c*scale(),y:0,z:vehicle.r*scale(),yaw:Math.PI/2-vehicle.ang}};
 }
 function validateVehicleFireIntent(intent){
  if(!intent)return false;const live=getVehicleFireIntent(intent.memberId);if(!live)return false;
  return live.sourceVehicleId===intent.sourceVehicleId&&live.presentationVehicleId===intent.presentationVehicleId&&live.seatId===intent.seatId&&live.weaponId===intent.weaponId&&live.targetId===intent.targetId&&live.targetKind===intent.targetKind&&live.targetRef===intent.targetRef&&live.attackSequence===intent.attackSequence&&
   ['x','y','z'].every(key=>Number.isFinite(intent.targetPosition?.[key])&&Math.abs(live.targetPosition[key]-intent.targetPosition[key])<1e-6)&&
   ['x','z','yaw'].every(key=>Number.isFinite(intent.vehiclePose?.[key])&&Math.abs(live.vehiclePose[key]-intent.vehiclePose[key])<1e-6);
 }
 function focusOrderCheck(focus){
  const from=targets.playerPosition?.()||toWorld(player),to=focusPosition(focus);if(Math.hypot(to.x-from.x,to.z-from.z)>60)return failure('Цель дальше 60 м. Подойдите ближе.');
  let visible=true;try{if(typeof targets.hasLineOfSight==='function')visible=targets.hasLineOfSight(from,to,focus.sourceId)===true;else if(typeof _policeWorldLineClear==='function')visible=_policeWorldLineClear(from.z/scale(),from.x/scale(),to.z/scale(),to.x/scale());}catch{visible=false;}
  return visible?{ok:true}:failure('Цель закрыта препятствием.');
 }
 function focusActions(target){const focus=focusTarget(target?.id);if(!focus)return [];const check=focusOrderCheck(focus),armed=core.getRoster().some(r=>{const m=raw(r.id);return m&&m.hp>0&&!m._mercenaryHospital&&!!m.weapon&&!['none','fists'].includes(m.weapon);});return [{id:'eliminate',kind:'eliminate',label:'Устранить',enabled:check.ok&&armed,disabledReason:!check.ok?check.reason:armed?undefined:'Нет доступных вооружённых бойцов.'}];}
 function eliminate(target){
  if(!ready||!local())return failure('Приказ недоступен.');const focus=focusTarget(target?.id);if(!focus)return failure('Эту цель нельзя атаковать.');const check=focusOrderCheck(focus);if(!check.ok)return check;let count=0,deferred=0;
  for(const r of core.getRoster()){const m=raw(r.id);if(!m||m.hp<=0||m._mercenaryHospital||!m.weapon||['none','fists'].includes(m.weapon))continue;core.clearQueue(r.id);const action=core.getAction(r.id);if(action){if(action.armed||action.phase==='awaiting')deferred++;else core.cancel(r.id);}clearFocus(m);m._mercenaryFocus=focus;if(!action||!action.armed&&action.phase!=='awaiting'){m.targetKind=focus.kind;m.targetRef=focus.ref;m.targetId=focus.id;m._mercenaryDefending=true;m._mercenaryMove=null;}count++;}
  return count?{ok:true,count,deferred,message:'Отряд атакует указанную цель.'}:failure('Нет доступных бойцов.');
 }
 function cancelCommand(id){
  if(!ready||!local())return failure('Приказ недоступен.');let cancelled=0;const blocked=[];
  for(const r of core.getRoster()){if(id&&r.id!==memberKey(id))continue;const action=core.getAction(r.id);if(!action&&!core.getQueue(r.id).length&&!r.resumeWork)continue;const receipt=core.cancel(r.id);if(receipt.ok||receipt.queuedCleared)cancelled++;else blocked.push({memberId:r.id,reason:receipt.reason});}
  if(cancelled)persist();return {ok:cancelled>0,cancelled,blocked,message:cancelled?'Приказ отменён.':blocked.length?'Заряд установлен или действие уже ожидает подтверждения.':'Активного приказа нет.'};
 }
 function rally(point){
  if(!ready||!local()||!Number.isFinite(point?.x)||!Number.isFinite(point?.z)||typeof targets.canMove!=='function')return failure('Место сбора недоступно.');
  if(Math.hypot(point.x-player.c*scale(),point.z-player.r*scale())>80)return failure('Выберите место ближе 80 м.');
  const positions=[],blocked=[];let count=0,cancelled=0,deferred=0;
  for(const r of core.getRoster()){
   const m=raw(r.id);if(!m||m.hp<=0||m._mercenaryHospital){blocked.push(r.id);continue;}
   let chosen=null;
   for(const radius of [0,2.4,4.8,7.2]){for(let i=0;i<(radius?16:1);i++){
    const x=point.x+Math.cos(i*Math.PI/8)*radius,z=point.z+Math.sin(i*Math.PI/8)*radius;
    if(positions.some(p=>Math.hypot(p.x-x,p.z-z)<2.1))continue;
    if(typeof _npcBodyPassable!=='function'||!_npcBodyPassable(z/scale(),x/scale(),typeof npcPassableForSnitch==='function'?npcPassableForSnitch:undefined))continue;
    const p={x,y:Number(targets.groundHeight?.(x,z))||0,z};if(!targets.canMove(p,p,m.id))continue;
    chosen=p;break;
   }if(chosen)break;}
   if(!chosen){blocked.push(r.id);continue;}
   core.clearQueue(r.id);const action=core.getAction(r.id);if(action){if(action.armed||action.phase==='awaiting')deferred++;else if(core.cancel(r.id).ok)cancelled++;}
   clearFocus(m);if(m._mercenaryPath?.stagedFollow)m._mercenaryPath=null;positions.push(chosen);m._mercenaryOrder='rally';m._mercenaryRally=chosen;m._mercenaryReturnMove=false;count++;
  }
  if(count){persist();chatterEvent('player','rally');}return {ok:count>0,count,cancelled,deferred,blocked,positions,message:count?(deferred?'Отряд идёт к месту сбора. Занятые бойцы присоединятся после безопасного отхода или подтверждения действия.':'Отряд идёт к месту сбора.'):'Рядом нет свободных мест.'};
 }
 function follow(){if(!ready||!local())return failure('Приказ недоступен.');let completing=0;for(const r of core.getRoster()){const m=raw(r.id);if(m){clearFocus(m);core.clearQueue(r.id);const action=core.getAction(r.id);if(action){if(action.armed||action.phase==='awaiting')completing++;else core.cancel(r.id);}if(m._mercenaryPath?.stagedFollow)m._mercenaryPath=null;m._mercenaryOrder='follow';m._mercenaryRally=null;m._mercenaryFollowAt=0;}}persist();if(core.getRoster().length)chatterEvent('player','follow');return success(completing?'Отряд следует за вами. Занятые бойцы завершат безопасный отход или подтверждение действия.':'Отряд следует за вами.');}
 function canCollectSafeLoot(safe){
  if(!ready||!local()||typeof myDead!=='undefined'&&myDead)return false;
  const target=targets.get?.(safe?.id),position=target?.lootPosition||target?.position,origin=targets.playerPosition?.()||toWorld(player);
  if(!target?.valid||!position||!origin||!Number.isFinite(position.x)||!Number.isFinite(position.z)||Math.abs((position.y||0)-(origin.y||0))>1.8||Math.hypot(position.x-origin.x,position.z-origin.z)>3)return false;
  return !targets.canMove||targets.canMove(origin,position,'player')===true;
 }
 function syncSafeLootBalance(balance){
  if(!ready||!local()||!Number.isSafeInteger(balance)||balance<safeLootBalance||typeof QP==='undefined'||!Number.isFinite(Number(QP.cash)))return false;
  QP.cash=Number(QP.cash)+balance-safeLootBalance;safeLootBalance=balance;return true;
 }
 function defend(m){
  const focus=getFocusedTarget(m.id);if(focus){m.targetKind=focus.kind;m.targetRef=focus.ref;m.targetId=focus.id;const position=focusPosition(focus),engage=(typeof GANG_ENGAGE_R==='number'?GANG_ENGAGE_R:10)*scale();if(Math.hypot(position.x-m.c*scale(),position.z-m.r*scale())>engage-.75){m._mercenaryDefending=false;m._mercenaryMove={phase:'focus_approach',targetId:focus.sourceId,position,stopDistance:Math.max(1,engage-1)};return 'approach';}m._mercenaryDefending=true;m._mercenaryMove=null;return true;}
  const t=performance.now(),target=m.targetRef||m._threatRef;
  const active=t<(m._threatUntil||0)&&(!target||target.dead!==true&&target.alive!==false&&target.hp!==0&&!target._wrecked);
  if(active&&typeof _resolveGangAlertTarget==='function'){
   const resolved=_resolveGangAlertTarget(m);if(resolved){m.targetKind=resolved.kind;m.targetRef=resolved.ref;m.targetId=resolved.id;m._mercenaryDefending=true;m._mercenaryMove=null;return true;}
  }
  if(m._mercenaryDefending){m.targetKind=null;m.targetRef=null;m.targetId=null;m._threatUntil=0;m._mercenaryDefending=false;}
  return false;
 }
 function peacefulGoal(m,index){
  if(m._mercenaryOrder==='rally'&&m._mercenaryRally)return {position:m._mercenaryRally,stopDistance:.35};
  const t=now();if(t<(m._mercenaryFollowAt||0)&&m._mercenaryFollowGoal)return m._mercenaryFollowGoal;
  const offsets=[[-2.5,-1.3],[-2.5,1.3],[-4.8,-2.2],[-4.8,0],[-4.8,2.2]],offset=offsets[index%offsets.length],a=followAngle??(Number(player.ang)||0),origin=toWorld(player);
  const free=position=>{
   if(Math.hypot(position.x-origin.x,position.z-origin.z)>7||!canMoveMember(m.id,player,{r:position.z/scale(),c:position.x/scale()}))return false;
   return !gang().some(other=>other!==m&&other.hp>0&&!other._mercenaryHospital&&other._mercenaryOrder!=='rally'&&other._mercenaryFollowGoal&&Math.hypot(position.x-other._mercenaryFollowGoal.position.x,position.z-other._mercenaryFollowGoal.position.z)<1.4);
  };
  const point=(turn=0,factor=1)=>{const angle=a+turn,x=origin.x+(Math.cos(angle)*offset[0]-Math.sin(angle)*offset[1])*factor,z=origin.z+(Math.sin(angle)*offset[0]+Math.cos(angle)*offset[1])*factor;return{x,y:Number(targets.groundHeight?.(x,z))||0,z};};
  let position=point();
  // The formation is a preference, not an instruction to stand inside a wall
  // or walk around an entire building merely to reach its far side.
  if(!free(position)){
   const previous=m._mercenaryFollowGoal?.position;
   position=previous&&free(previous)?previous:null;
   if(!position)outer:for(const factor of [1,.65])for(const turn of [Math.PI/4,-Math.PI/4,Math.PI/2,-Math.PI/2,3*Math.PI/4,-3*Math.PI/4,Math.PI]){const candidate=point(turn,factor);if(free(candidate)){position=candidate;break outer;}}
   // A crowded/narrow spot may offer no formation slot. Stay in a valid place
   // and retry; do not dispatch an exhaustive search into blocked geometry.
   if(!position)position=toWorld(m);
  }
  m._mercenaryFollowAt=t+.4;return m._mercenaryFollowGoal={position,stopDistance:.6};
 }
 function canMoveMember(id,from,to){
  const m=raw(id);
  if(!ready||!local()||!m||m.hp<=0||m.dead||m._mercenaryHospital||![from?.r,from?.c,to?.r,to?.c].every(Number.isFinite))return false;
  const passFn=typeof npcPassableForSnitch==='function'?npcPassableForSnitch:undefined;
  if(typeof _npcPathPassable==='function'?!_npcPathPassable(from.r,from.c,to.r,to.c,passFn):typeof _npcBodyPassable!=='function'||!_npcBodyPassable(to.r,to.c,passFn))return false;
  return !targets.canMove||!!targets.canMove(toWorld(from),toWorld(to),m.id);
 }
 function move(m,dt){
  if(m.hp<=0||m.dead||m._mercenaryHospital){m._mercenaryPath=null;m._mercenaryMove=null;m._mercenaryReturnMove=false;m._followSpeed=0;m._mercenaryMoveReason=m._mercenaryHospital?'hospital':'downed';return;}
  let goal=m._mercenaryMove;if(!goal)return;
  // An existing wet follower must physically finish leaving the water before
  // ordinary dry-only routing can take ownership again. Keep source orders.
  if(typeof _walkNpcNavigationResolver==='function'&&typeof _npcWaterEscape==='function'&&!(typeof _bankInt!=='undefined'&&_bankInt)&&!(typeof _buildingInt!=='undefined'&&_buildingInt)){
   const wasEscaping=m._waterEscaping,r=m.r,c=m.c;
   waterEscapeOptions.speed=1.5/scale();
   if(_npcWaterEscape(m,dt,performance.now(),waterEscapeOptions)){
    m._mercenaryPath=null;m._followSpeed=dt>0?Math.hypot(m.r-r,m.c-c)*scale()/dt:0;
    m._mercenaryMoveReason=m._followSpeed>0?'water_egress':'water_egress_pending';
    return;
   }
   if(wasEscaping){m._mercenaryPath=null;m.walking=false;}
  }
  const from=toWorld(m);if(routeFactory){goal=approachWaypoint(m,from,goal);if(!goal){m._followSpeed=0;m.walkPhase=0;return;}}
  const dx=goal.position.x-from.x,dz=goal.position.z-from.z,d=Math.hypot(dx,dz),posture=squadPosture(m),speed=posture==='prone'?.65:posture==='crouch'?1.5:d>8?5.5:3,actualSpeed=m._mercenaryVehicleChase?(d>12?8:6):speed;
  const step=Math.min(Math.max(0,d-goal.stopDistance),actualSpeed*Math.min(.05,Math.max(0,dt)));if(step<=1e-6){m._followSpeed=0;m.walkPhase=0;m._mercenaryMoveReason='arrived';return;}
  const heading=Math.atan2(dz,dx),passFn=typeof npcPassableForSnitch==='function'?npcPassableForSnitch:undefined;
  const detouring=now()<(m._mercenaryDetourUntil||0),turns=goal.routed?[0]:detouring?[m._mercenaryDetourTurn,0,.65,-.65,1.25,-1.25,1.8,-1.8,2.4,-2.4]:[0,.65,-.65,1.25,-1.25,1.8,-1.8,2.4,-2.4];
  for(const turn of turns){
   const a=heading+turn,r=m.r+Math.sin(a)*step/scale(),c=m.c+Math.cos(a)*step/scale();
   if(typeof _npcPathPassable==='function'?!_npcPathPassable(m.r,m.c,r,c,passFn):typeof _npcBodyPassable!=='function'||!_npcBodyPassable(r,c,passFn)){m._mercenaryMoveReason='source_blocked';continue;}
   if(gang().some(other=>other!==m&&other.hp>0&&!other._mercenaryHospital&&Math.hypot(other.r-r,other.c-c)*scale()<1.1&&Math.hypot(other.r-r,other.c-c)<=Math.hypot(other.r-m.r,other.c-m.c))){m._mercenaryMoveReason='crew_blocked';continue;}
   if(targets.canMove&&!targets.canMove(from,toWorld({r,c}),m.id)){m._mercenaryMoveReason='native_blocked';continue;}
   if(turn!==0&&!detouring){m._mercenaryDetourTurn=turn;m._mercenaryDetourUntil=now()+.5;}
   m.r=r;m.c=c;m.ang=a;m.walkPhase=(m.walkPhase||0)+step*2.4;m._followSpeed=actualSpeed;m._mercenaryMoveReason=goal.routed?'route_moving':'moving';if(goal.routed)m._mercenaryPath.blockedAt=0;return;
  }
  m._followSpeed=0;m.walkPhase=0;if(goal.routed){const route=m._mercenaryPath;route.blockedAt=route.blockedAt||now();if(now()-route.blockedAt>.5){if(route.stagedFollow){route.stagedFollow.blocked();route.blockedAt=0;}else m._mercenaryPath=null;}}
 }
 function approachWaypoint(m,from,goal){
  let route=m._mercenaryPath;const purpose=(goal.phase||m._mercenaryOrder||'follow')+':'+(goal.targetId||''),following=!goal.phase&&m._mercenaryOrder!=='rally',tracking=following||goal.tracksMovingTarget===true,threshold=goal.phase?.35:.8,drift=route?Math.hypot(route.goal.x-goal.position.x,route.goal.z-goal.position.z):0;
  // Moving leaders and bomb targets must not reset an unfinished search on
  // every update. Use its safe prefix, then reconnect to the current contact.
  const replace=route&&(route.purpose!==purpose||route.stagedFollow&&(!following||m._mercenaryVehicleChase)||!route.stagedFollow&&drift>threshold&&(!tracking||route.direct||drift>12||route.search&&now()-route.createdAt>6||route.path&&Math.hypot(from.x-route.goal.x,from.z-route.goal.z)<=goal.stopDistance+.1));
  if(replace)route=m._mercenaryPath=null;
  const clear=(a,b)=>{
   if(!canMoveMember(m.id,{r:a.z/scale(),c:a.x/scale()},{r:b.z/scale(),c:b.x/scale()}))return false;
   const dx=b.x-a.x,dz=b.z-a.z,length2=dx*dx+dz*dz;
   for(const other of gang()){if(other===m||other.hp<=0||other._mercenaryHospital)continue;const x=other.c*scale()-a.x,z=other.r*scale()-a.z,start=Math.hypot(x,z),projection=length2?(x*dx+z*dz)/length2:0;if(start<1.1&&projection<=0)continue;const t=Math.max(0,Math.min(1,projection));if(Math.hypot(x-dx*t,z-dz*t)<1.1)return false;}
   return true;
  };
  // Far followers use local stages before any whole-distance sweep. The
  // ordinary short-range, rally and specialist route contracts stay intact.
  if(following&&!m._mercenaryVehicleChase&&longFollowFactory&&(route?.stagedFollow||Math.hypot(from.x-goal.position.x,from.z-goal.position.z)>32)){
   if(!route?.stagedFollow)route=m._mercenaryPath={purpose,goal:{...goal.position},blockedAt:0,stagedFollow:longFollowFactory({canMove:clear,groundHeight:(x,z)=>Number(targets.groundHeight?.(x,z))||0,clock:()=>performance.now()})};
   const result=route.stagedFollow.advance(from,goal.position,{arrivalRadius:goal.stopDistance,maxExpanded:8,budgetMs:Math.min(.75,routeWorkDeadline-performance.now())});
   route.goal={...goal.position};route.stats=route.stagedFollow.stats;
   if(result.status==='arrived'){m._mercenaryPath=null;return {...goal,routed:false};}
   if(result.waypoint)return {position:result.waypoint,stopDistance:result.stopDistance,routed:true};
   m._mercenaryMoveReason=result.status==='blocked'?'no_route':result.status==='budget'?'search_budget':'search_pending';return null;
  }
  if(!route){
   route=m._mercenaryPath={purpose,createdAt:now(),goal:{...goal.position},path:null,index:0,blockedAt:0,direct:clear(from,goal.position),search:null,retryAt:0,lastSearchProgressAt:now()};
   if(!route.direct)route.search=routeFactory({canMove:clear,groundHeight:(x,z)=>Number(targets.groundHeight?.(x,z))||0}).start(from,goal.position,{arrivalRadius:goal.stopDistance});
  }
  if(tracking&&!route.direct&&drift>threshold&&now()>=(route.nextGoalCheckAt||0)){route.nextGoalCheckAt=now()+.5;if(clear(from,goal.position)){route.goal={...goal.position};route.direct=true;route.search=null;route.path=null;}}
  if(route.direct)return {...goal,routed:true};
  if(route.search){m._mercenaryMoveReason='search_pending';const budgetMs=Math.min(.75,routeWorkDeadline-performance.now());if(budgetMs<=0){m._mercenaryMoveReason='search_budget';return null;}const before=route.search.stats.expanded;route.search.advance({maxExpanded:8,budgetMs});if(route.search.stats.expanded>before)route.lastSearchProgressAt=now();if(!route.search.done)return null;route.path=route.search.path;route.stats=route.search.stats;route.search=null;route.retryAt=now()+2;}
  if(!route.path){m._mercenaryMoveReason='no_route';if(now()>=route.retryAt)m._mercenaryPath=null;return null;}
  while(route.index<route.path.length-1&&Math.hypot(from.x-route.path[route.index].x,from.z-route.path[route.index].z)<.09)route.index++;
  if(now()>=(route.nextShortcutAt||0)){route.nextShortcutAt=now()+.5;const ahead=Math.min(route.path.length-1,route.index+6);if(ahead>route.index&&clear(from,route.path[ahead]))route.index=ahead;}
  const last=route.index===route.path.length-1,exact=last&&Math.hypot(route.path[route.index].x-route.goal.x,route.path[route.index].z-route.goal.z)<1e-6;
  return {position:exact?(tracking?route.goal:goal.position):route.path[route.index],stopDistance:exact?goal.stopDistance:.04,routed:true};
 }


 function findNpc(id){const key=String(id||'').replace(/^npc:/,'');return npcs().find(n=>String(n.id)===key||'npc_'+n.id===key||(typeof _threeNpcEntityId==='function'&&String(_threeNpcEntityId(n))===key));}
 function blastVehicle(sourceId,e){
  if(!local()||!e||e.kind!=='plant_bomb'||!Number.isFinite(e.actionId)||typeof _startCarGunDestruction!=='function')return false;
  const active=core?.getAction(e.memberId);if(!active?.armed||active.id!==e.actionId||active.targetId!==e.targetId)return false;
  const token=String(e.memberId)+':'+e.actionId;if(appliedBlasts.has(token))return false;
  const key=String(sourceId||'').replace(/^traffic:/,'');let car=(typeof CARS!=='undefined'?CARS:[]).find(c=>c&&typeof _threeVehicleEntityId==='function'&&String(_threeVehicleEntityId(c))===key),service=false;
  if(!car){car=(typeof serviceVehicles!=='undefined'?serviceVehicles:[]).find(v=>'service_'+v.id===key);service=!!car;}
  if(!car&&typeof questCars!=='undefined'){car=[...questCars.values()].find(v=>'quest_'+v.id===key);service=!!car;}
  if(!car||car._hidden||car._towed||car._destroySequenceAt||car._shotWrecked||car._wrecked||car.wrecked||car._explosionT)return false;
  const r=Number(service?car.y:car.r),c=Number(service?car.x:car.c);if(!Number.isFinite(r)||!Number.isFinite(c))return false;
  _startCarGunDestruction({r,c,car},car,380);if(!car._destroySequenceAt)return false;
  car.speed=0;car.v=0;car._ballisticHp=0;appliedBlasts.add(token);if(appliedBlasts.size>256)appliedBlasts.delete(appliedBlasts.values().next().value);return true;
 }
 function canRevivePlayer(){
  if(!local()||!(typeof myDead!=='undefined'&&myDead))return false;
  const patient=typeof _playerEmergencyPatient!=='undefined'?_playerEmergencyPatient:null;
  return !(patient?._ambulanceInTransit||patient?._carriedByAmbulance||(typeof _murderPoliceArrest!=='undefined'&&_murderPoliceArrest)||(typeof myJailIn!=='undefined'&&myJailIn>0));
 }
 function revivePlayer(e){
  if(!canRevivePlayer())return false;
  const patient=typeof _playerEmergencyPatient!=='undefined'?_playerEmergencyPatient:null;
  if(patient){if(typeof _setPlayerEmergencyTransport==='function')_setPlayerEmergencyTransport(false);if(typeof _cancelAmbulanceCallForPatient==='function')_cancelAmbulanceCallForPatient(patient);}
  myDead=false;myHp=Math.max(1,Math.ceil((typeof PVP!=='undefined'?PVP.max_hp||100:100)*(e.stats?.reviveFraction||.35)));
  if(typeof _localDeath!=='undefined')_localDeath=false;if(typeof myDeathBy!=='undefined')myDeathBy='';if(typeof myDeathLeft!=='undefined')myDeathLeft=0;
  if(typeof _localHpHurtAt!=='undefined')_localHpHurtAt=0;if(typeof _selfHpBarUntil!=='undefined')_selfHpBarUntil=0;
  if(typeof _deathOv!=='undefined')_deathOv?.classList.remove('show');
  if(patient){patient._medicalDowned=false;patient._medicalBleedoutAt=0;patient._ambulanceLoading=false;patient._ambulanceDispatched=false;patient._ambulanceDeliveredAt=performance.now();_playerEmergencyPatient=null;}
  player.walking=false;player.vr=0;player.vc=0;if(typeof showToast==='function')showToast('Медик поднял вас.','🩺',2200);return true;
 }
 function effect(e){if(!local())return false;const armed=core.getAction(e.memberId);if(e.kind==='plant_bomb'&&armed?.armed&&armed.id===e.actionId)return targets.performEffect?.(e)||false;const m=raw(e.memberId);if(!m||!record(e.memberId))return false;if(e.kind==='hospitalize'){m.hp=0;m._mercenaryHospital=true;m._mercenaryPath=null;m._mercenaryMove=null;return true;}if(e.kind==='discharge'){const door=typeof _hospitalDoor==='function'?_hospitalDoor():null;if(!door||!_npcBodyPassable(door.r,door.c))return false;m.r=door.r;m.c=door.c;m.hp=m.max_hp;m._mercenaryDownAt=0;m.dead=false;m._mercenaryHospital=false;m._mercenaryAction=null;return true;}if(e.kind==='revive'){if(e.targetId==='player'){return revivePlayer(e);}const ally=raw(e.targetId);if(!ally||!record(ally.id)||record(ally.id).status==='hospital'||ally.hp>0)return false;ally.hp=Math.max(1,Math.round(ally.max_hp*(e.stats?.reviveFraction||.35)));ally.dead=false;delete ally._mercenaryQaRescueUntil;ally._mercenaryDownAt=0;ally._mercenaryHospital=false;return true;}if(e.kind==='intimidate'){const n=findNpc(e.targetId);if(!n||n.dead||n.hp<=0||n._empireBoss||n._guard||n._invulnerable)return false;const t=performance.now();if(typeof _npcApplyIntimidation==='function'){if(!_npcApplyIntimidation(n,m.r,m.c,t))return false;}else{n._intimidatedUntil=t+60000;n.snitching=false;n.snitchUntil=0;n._witnessCallUntil=0;n.panicUntil=t+8000;n.panicSrcR=m.r;n.panicSrcC=m.c;n._hostile=false;n._fighting=false;n._fightingMelee=false;n._panicStyle='flee';}n.cryText='Не трогай меня!';n.cryUntil=t+3000;return true;}return targets.performEffect?.(e)||false;}
 function restore(){restoredOnce=true;try{
  const text=localStorage.getItem(KEY);if(text==null){persistenceDiagnostics.restore={ok:true,missing:true,ids:[]};return;}
  const save=JSON.parse(text);if(!save?.core||save.core.version!==1||!Array.isArray(save.core.members)||!Array.isArray(save.rows))throw Error('unsupported_or_incomplete_save');
  for(const r of save.core.members){const row=save.rows.find(row=>row?.id===r?.id);if(!row||!Number.isFinite(row.r)||!Number.isFinite(row.c)||!Number.isFinite(row.hp)||!Number.isFinite(row.max_hp))throw Error('missing_or_invalid_member_row');}
  for(const row of save.rows)if(row?.id&&row.sourceBotId!=null)savedIdentities.set(row.id,String(row.sourceBotId));
  const result=core.restore(save.core);if(!result.ok)throw Error(result.reason||'core_restore_rejected');
   for(const row of save.rows){const rec=record(row.id);if(!rec)continue;let m=gang().find(g=>g.id===row.id||(String(g.sourceBotId)===String(row.sourceBotId)&&row.sourceBotId!=null));if(!m){if(gang().length>=Math.max(5,typeof GANG_MAX==='number'?GANG_MAX:5))continue;m={};gang().push(m);}Object.assign(m,row,{id:row.id,weapon:rec.weapon?.id||row.weapon||'pistol',walkPhase:0,ang:0,_nextShootAt:0,_threatUntil:0,_mercenaryBaseHp:row.baseHp||80,_mercenaryHospital:rec.status==='hospital',_mercenaryQaRescueUntil:qaSupported()&&Number.isFinite(row._mercenaryQaRescueUntil)?Math.min(now()+600,Math.max(0,row._mercenaryQaRescueUntil)):0});records.set(row.id,rec);const index=npcs().findIndex(n=>String(n.id)===String(row.sourceBotId));if(index>=0){recruitedResidents.set(row.id,npcs()[index]);npcs().splice(index,1);}if(typeof _hiredBotIds!=='undefined')_hiredBotIds.add(String(row.sourceBotId));}
  persistenceDiagnostics.restore={ok:true,storedIds:save.core.members.map(r=>r.id),ids:core.getRoster().filter(r=>raw(r.id)).map(r=>r.id),bytes:text.length};
 }catch(e){restoreBlocked=true;persistenceDiagnostics.restore={ok:false,error:String(e.message||e),preserved:true};console.warn('Mercenary restore failed',e);}finally{reportPersistence();}}
 function recruit(id,weaponId){const blocked=permitted();if(blocked)return blocked;adoptCandidates();const candidate=candidates.get(String(id));if(!candidate||!npcs().includes(candidate.npc)||!recruitableResident(candidate.npc))return failure('Наёмник больше недоступен.');const n=candidate.npc;if(!qaRecruiting&&Math.hypot(n.r-player.r,n.c-player.c)*scale()>3)return failure('Подойдите к наёмнику ближе 3 м.');if(gang().length>=Math.max(5,typeof GANG_MAX==='number'?GANG_MAX:5))return failure('В отряде нет места.');if(weaponId&&!inventory().some(i=>i.type==='weapon'&&String(i.id)===String(weaponId)&&quantity(i)>0))return failure('Оружия нет в инвентаре.');const memberId='merc_'+String(n.id),result=core.recruit({id:memberId,profession:candidate.profession,name:n.name||professions[candidate.profession].name});if(!result.ok)return failure('Отряд заполнен или боец уже нанят.');const baseHp=n.max_hp||n.hp||80,maxHp=Math.round(baseHp*core.stats(memberId).hpMultiplier),weapon=weaponId?takeWeapon(weaponId):null;const m={id:memberId,name:n.name||professions[candidate.profession].name,look:{...n.look},r:n.r,c:n.c,ang:n.ang||0,walkPhase:n.walkPhase||0,hp:maxHp,max_hp:maxHp,level:1,fighterXp:0,kills:0,damageDone:0,sourceBotId:String(n.id),weapon:weapon?.id||'pistol',_mercenaryBaseHp:baseHp,_nextShootAt:0,_threatUntil:0};gang().push(m);savedIdentities.set(memberId,String(n.id));recruitedResidents.set(memberId,n);npcs().splice(npcs().indexOf(n),1);if(typeof _hiredBotIds!=='undefined')_hiredBotIds.add(String(n.id));core.setWeapon(memberId,weapon);records.set(memberId,record(memberId));candidates.delete(String(id));syncInventory();persist(true);chatterEvent(memberId,'hire');return success('Боец принят в отряд.');}
 function equip(id,weaponId){const blocked=permitted();if(blocked)return blocked;const m=raw(id),r=record(id);if(!m||!r||r.status==='hospital')return failure('Боец недоступен.');if(!weaponId)return failure('Выберите оружие из инвентаря.');const weapon=takeWeapon(weaponId);if(!weapon)return failure('Оружия нет в инвентаре.');returnWeapon(r.weapon);core.setWeapon(id,weapon);m.weapon=weapon.id;syncInventory();persist(true);return success('Оружие передано.');}
 function dismiss(id){const blocked=permitted();if(blocked)return blocked;const r=record(id),m=raw(id);if(!r||!m)return failure('Боец уже уволен.');if(typeof _dismissGangMember!=='function')return failure('Увольнение недоступно.');dismissing=true;let ok;try{ok=_dismissGangMember(id);}finally{dismissing=false;}if(!ok)return failure('Не удалось уволить бойца.');const sourceId=String(m.sourceBotId??savedIdentities.get(m.id)??'');if(typeof _formerGang!=='undefined'&&Array.isArray(_formerGang)){const former=_formerGang.findLastIndex(row=>String(row?.sourceBotId||'')===sourceId);if(former>=0)_formerGang.splice(former,1);}returnWeapon(r.weapon);core.dismiss(id);records.delete(id);const resident=releaseAsResident(m);syncInventory();persist(true);return success(resident?'Боец уволен и вернулся к жизни города.':'Боец уволен. Выданное оружие возвращено.');}
 function upgrade(id,skill){const blocked=permitted();if(blocked)return blocked;const r=record(id),m=raw(id);if(!r||!m)return failure('Боец недоступен.');const chosen=skill||Object.keys(r.skills).find(k=>r.skills[k]<5);const result=core.upgrade(id,chosen);if(!result.ok)return failure('Нужны очки навыков, полученные за приказы.');m.max_hp=Math.round((m._mercenaryBaseHp||80)*core.stats(id).hpMultiplier);m.hp=Math.min(m.hp,m.max_hp);persist(true);return success('Навык улучшен.');}
 function getRoster(){if(!ready)return{members:[],candidates:[],weapons:[]};adoptCandidates();return{capacity:Math.max(5,typeof GANG_MAX==='number'?GANG_MAX:5),cash:typeof QP!=='undefined'?QP.cash:undefined,weapons:inventory().filter(i=>i.type==='weapon'&&quantity(i)>0).map(i=>({id:i.id,label:i.name||i.id,count:quantity(i)})),members:core.getRoster().map(r=>{const m=raw(r.id),a=core.getAction(r.id),countdownRemainingSeconds=a?.armed?Math.max(0,Math.ceil(a.detonateAt-now())):undefined;return{...r,countdownRemainingSeconds,phaseLabel:a?.armed?(a.waitingForSafety?'Ждёт безопасного отхода':(a.phase==='retreat'?'Отходит · взрыв через ':'Взрыв через ')+countdownRemainingSeconds+' с'):undefined,weaponId:m?.weapon||'pistol',weaponLabel:r.weapon?.name||((m?.weapon||'pistol')==='pistol'?'Пистолет':m.weapon),weaponOrigin:r.weapon?'player':'personal',order:m?._mercenaryOrder||'follow',rallyPosition:m?._mercenaryRally||null,defending:!!m?._mercenaryDefending,name:m?.name||r.name,hp:m?.hp||0,maxHp:m?.max_hp,phase:a?.phase||r.status,progress:a?.progress,hospitalRemainingSeconds:r.hospitalRemaining,canUpgrade:r.skillPoints>0,skills:Object.entries(r.skills).map(([id,level])=>({id,label:{medicine:'Медицина',fitness:'Выносливость',melee:'Рукопашный бой',intimidation:'Запугивание',lockpicking:'Взлом',cutting:'Резка',explosives:'Подрыв'}[id],level}))};}),candidates:[...candidates].filter(([,c])=>npcs().includes(c.npc)&&recruitableResident(c.npc)).map(([id,{npc:n,profession}])=>({id,name:n.name||professions[profession].name,profession,weaponId:n.weapon||'pistol',weaponLabel:(n.weapon||'pistol')==='pistol'?'Пистолет':n.weapon,distanceMeters:Math.hypot(n.r-player.r,n.c-player.c)*scale(),hp:n.hp,maxHp:n.max_hp||n.hp,level:1,canRecruit:Math.hypot(n.r-player.r,n.c-player.c)*scale()<=3,disabledReason:Math.hypot(n.r-player.r,n.c-player.c)*scale()>3?'Подойдите ближе 3 м':undefined}))};}

 function reconcileMembers(){
  let changed=false;for(const r of core.getRoster()){
   if(raw(r.id))continue;
   const sourceId=savedIdentities.get(r.id),renamed=sourceId==null?null:gang().find(m=>String(m.sourceBotId)===sourceId&&!record(m.id));
   if(renamed){renamed.id=r.id;records.set(r.id,r);changed=true;continue;}
   // Police/disband and other source owners may remove a fighter independently.
   // End the metadata membership once; an already attached bomb keeps its fuse.
   persistenceDiagnostics.removals.push({id:r.id,reason:'source_member_missing',at:now()});if(persistenceDiagnostics.removals.length>12)persistenceDiagnostics.removals.shift();reportPersistence();
   returnWeapon(r.weapon);core.dismiss(r.id);records.delete(r.id);changed=true;
  }
  if(changed){syncInventory();persist();}return changed;
 }
 function awardCombatXp(memberId,actualDamage,killed=false,targetLevel=1){
  if(!ready||!local()||!Number.isFinite(actualDamage)||actualDamage<=0)return false;
  const m=raw(memberId),r=m&&record(m.id);if(!r)return false;
  const level=Number.isFinite(targetLevel)?Math.max(1,Math.min(25,Math.floor(targetLevel))):1;
  const amount=Math.max(1,Math.floor(actualDamage/7))+(killed?30+level*2:0);
  if(!core.addXP(m.id,amount))return false;const updated=record(m.id);m.fighterXp=updated.xp;m.level=updated.level;return true;
 }
 function demoSupported(){return local()&&['localhost','127.0.0.1','[::1]'].includes(location.hostname)&&new URL(location.href||location.origin).searchParams.get('mercenarydemo')==='1';}
 function qaSupported(){return demoSupported()||(local()&&['localhost','127.0.0.1','[::1]'].includes(location.hostname)&&new URL(location.href||location.origin).searchParams.get('mercenaryqa')==='1');}
 function qaPointStatus(point,ignore){
  if(!Number.isFinite(point?.x)||!Number.isFinite(point?.z))return {ok:false,code:'invalid_point',reason:'Не задана точка для специалиста.'};
  if(typeof targets.canMove!=='function')return {ok:false,code:'collision_not_ready',reason:'Площадка ещё загружается.'};
  const ground=Number(targets.groundHeight?.(point.x,point.z))||0;if(Number.isFinite(point.y)&&Math.abs(point.y-ground)>1.8)return {ok:false,code:'wrong_floor',reason:'Точка находится на другом этаже.'};
  const r=point.z/scale(),c=point.x/scale(),position={x:point.x,y:ground,z:point.z};
  if(typeof _npcBodyPassable!=='function'||!_npcBodyPassable(r,c,typeof npcPassableForSnitch==='function'?npcPassableForSnitch:undefined))return {ok:false,code:'source_blocked',reason:'В этой части площадки нет проходимой земли.'};
  if(!targets.canMove(position,position,ignore?.id))return {ok:false,code:'native_blocked',reason:'Место перекрыто объектом или машиной.'};
  const occupant=[...npcs(),...gang()].find(n=>n!==ignore&&n.hp>0&&!n.dead&&!n._mercenaryHospital&&Math.hypot(n.r-r,n.c-c)*scale()<1.4-1e-6);
  if(occupant)return {ok:false,code:'occupied',reason:'Место занято другим персонажем.',blockerId:String(occupant.id)};
  return {ok:true,r,c,position};
 }
 function qaCheckedPoint(point,ignore){const result=qaPointStatus(point,ignore);return result.ok?result:null;}
 function qaNearestPoint(point,ignore){
  const first=qaPointStatus(point,ignore);if(first.ok||['invalid_point','collision_not_ready','wrong_floor'].includes(first.code))return first;
  for(const radius of [1.6,3.2,4.8])for(let i=0;i<16;i++){const angle=i*Math.PI/8,result=qaPointStatus({x:point.x+Math.cos(angle)*radius,y:point.y,z:point.z+Math.sin(angle)*radius},ignore);if(result.ok)return {...result,offset:radius};}
  return {...first,reason:first.reason+' Рядом тоже нет свободного места.'};
 }
 function qaAvailableCandidate(profession){
  const known=[...candidates.values()].find(c=>c.profession===profession&&npcs().includes(c.npc)&&recruitableResident(c.npc));if(known)return known;
  // Preserve residents owned by indoor visits/transport. A local QA request may
  // adopt another existing eligible citizen; it never creates or extracts one.
  const spare=npcs().filter(n=>recruitableResident(n)&&(!n._mercenaryProfession||n._mercenaryProfession===profession)&&![...candidates.values()].some(c=>c.npc===n)&&!gang().some(m=>String(m.sourceBotId)===String(n.id))).sort((a,b)=>Math.hypot(a.r-player.r,a.c-player.c)-Math.hypot(b.r-player.r,b.c-player.c)||String(a.id).localeCompare(String(b.id)))[0];
  if(!spare)return null;spare._mercenaryProfession=profession;spare._mercenaryOwnWeapon='pistol';spare.weapon='pistol';if(!String(spare.name||'').trim())spare.name=personalName(spare.id,spare.look);const adopted={npc:spare,profession};candidates.set(String(spare.id),adopted);return adopted;
 }
 function qaPrepareProfessions({positions}={}){
  if(!ready||!qaSupported())return failure('Проверка недоступна.');adoptCandidates();const placed=[],skipped=[],rejected=[];
  for(const profession of Object.keys(professions)){
   if(core.getRoster().some(r=>r.profession===profession)){skipped.push(profession);continue;}
   const candidate=[...candidates.values()].find(c=>c.profession===profession&&recruitableResident(c.npc)),n=candidate?.npc,point=n&&qaCheckedPoint(positions?.[profession],n);
   if(!point){rejected.push(profession);continue;}
   const previousSpeed=Object.hasOwn(n,'_mercenaryQaRestoreSpeed')?n._mercenaryQaRestoreSpeed:n.speed,token=performance.now();n._mercenaryQaRestoreSpeed=previousSpeed;n.r=n.tr=point.r;n.c=n.tc=point.c;n.walkPhase=0;n.speed=0;n._talking=token+30000;n._mercenaryQaInvite=token;
   setTimeout(()=>{if(n._mercenaryQaInvite===token){n.speed=previousSpeed;n._talking=0;delete n._mercenaryQaInvite;delete n._mercenaryQaRestoreSpeed;}},30000);
   placed.push({id:String(n.id),profession,position:point.position});
  }
  return {ok:placed.length+skipped.length===Object.keys(professions).length,placed,skipped,rejected,message:'Специалисты расставлены для проверки. Наймите доступных через E.'};
 }
 function qaAssembleProfessions({positions,patientPosition}={}){
  if(!ready||!qaSupported())return failure('Проверка недоступна.');adoptCandidates();const assembled=[],rejected=[];const cashBefore=Number(typeof QP!=='undefined'?QP.cash:0)||0;
  for(const profession of Object.keys(professions)){
   const row=core.getRoster().find(r=>r.profession===profession);let member=row&&raw(row.id);const work=row&&core.getAction(row.id),candidate=!row&&qaAvailableCandidate(profession);
   if(row&&(!member||row.status==='hospital'&&!(profession==='bruiser'&&patientPosition)||work?.armed||work?.phase==='awaiting')){rejected.push({profession,reason:'Боец недоступен или завершает действие.'});continue;}
   if(!member&&!candidate){rejected.push({profession,code:'no_available_resident',reason:'Специалист сейчас в здании, в пути или занят. Свободного жителя для этой роли пока нет.'});continue;}
   const point=qaNearestPoint(positions?.[profession],member||candidate?.npc);if(!point.ok){rejected.push({profession,code:point.code,reason:point.reason,...(point.blockerId?{blockerId:point.blockerId}:{})});continue;}
   if(!member){let receipt;qaRecruiting=true;try{receipt=recruit(String(candidate.npc.id));}finally{qaRecruiting=false;}if(!receipt.ok){rejected.push({profession,reason:receipt.reason});continue;}member=gang().find(m=>m.sourceBotId===String(candidate.npc.id));}
   core.clearQueue(member.id);if(work)core.cancel(member.id);if(member.name==='Проверка урона')member.name=personalName(member.sourceBotId||member.id,member.look);member.r=point.r;member.c=point.c;member._mercenaryOrder='rally';member._mercenaryRally=point.position;member._mercenaryMove=null;member._mercenaryReturnMove=false;member._mercenaryFollowAt=0;member._mercenaryDetourUntil=0;member._followSpeed=0;
   assembled.push({profession,memberId:member.id,hired:!row,position:point.position});
  }
  const patient=patientPosition?qaPlacePatient({position:patientPosition}):null;persist(true);
  return {ok:rejected.length===0&&(!patient||patient.ok),assembled,rejected,patient,charged:cashBefore-(Number(typeof QP!=='undefined'?QP.cash:0)||0),message:rejected.length?'Отряд подготовлен частично — проверьте недоступные роли.':'Отряд подготовлен для проверки действий.'};
 }
 function qaPlacePatient({position}={}){
  if(!ready||!qaSupported())return failure('Проверка недоступна.');const r=core.getRoster().find(r=>r.profession==='bruiser'),m=r&&raw(r.id),action=r&&core.getAction(r.id);
  if(!m||action?.armed||action?.phase==='awaiting')return failure('Нужен нанятый доступный громила.');const point=qaCheckedPoint(position,m);if(!point)return failure('Для раненого нет свободного места.');
  if(!core.resetQaPatient(m.id).ok)return failure('Не удалось подготовить раненого.');
  // Keep QA rescue explicit: a medic must wait for X rather than consuming the
  // scenario in the automatic scan before the player can select the patient.
  for(const row of core.getRoster()){const member=raw(row.id);if(!member||member.hp<=0||row.status==='hospital')continue;const work=core.getAction(row.id);if(work?.armed||work?.phase==='awaiting')continue;core.clearQueue(row.id);if(work)core.cancel(row.id);member._mercenaryOrder='rally';member._mercenaryRally=toWorld(member);member._mercenaryMove=null;}
  m.r=point.r;m.c=point.c;m.hp=0;m.dead=false;m._mercenaryDownAt=performance.now();m._mercenaryQaRescueUntil=now()+600;m._mercenaryHospital=false;m._mercenaryMove=null;m._followSpeed=0;m._threatUntil=0;m._mercenaryDefending=false;persist();
  return {ok:true,memberId:m.id,position:point.position,message:'Боец ранен. Наведитесь на него и прикажите медику помочь.'};
 }
 function qaLineup(){
  if(!ready||!demoSupported())return failure('Демонстрация недоступна.');adoptCandidates();
  if(typeof targets.canMove!=='function'||document.documentElement?.dataset?.worldWalkReady!=='first-populated-frame')return {...failure('Город ещё загружается.'),count:0,placed:0};
  const selected=[...candidates.values()].filter(c=>recruitableResident(c.npc)),angle=Number(player.ang)||0;
  const diagnostics={sourceRejected:0,nativeRejected:0,occupied:0,tested:0,roadPlacements:0,initialPlacementPending:0,origin:{r:player.r,c:player.c,...toWorld(player)},positions:[]};
  let count=0,placed=0,anchor=selected.find(c=>c.npc._mercenaryDemoLineup)?.npc||null;
  for(let slot=0;slot<selected.length;slot++){
   const n=selected[slot].npc;if(n._npcInitialPlacementPending){diagnostics.initialPlacementPending++;continue;}if(n._mercenaryDemoLineup){count++;continue;}
   const points=[];
   if(anchor)for(const radius of [2.2,3.2,4.4,6.6])for(let i=0;i<16;i++){const a=angle+i*Math.PI/8,r=anchor.r+Math.sin(a)*radius/scale(),c=anchor.c+Math.cos(a)*radius/scale();if(Math.hypot(r-player.r,c-player.c)*scale()<=20)points.push({r,c});}
   // A shallow five-person arc in front of the player, with bounded fallbacks.
   for(const radius of [5.5,7,9])for(let i=0;i<15;i++){const offset=i===0?(slot-(selected.length-1)/2)*.42:(i%2?1:-1)*Math.ceil(i/2)*.2;points.push({r:player.r+Math.sin(angle+offset)*radius/scale(),c:player.c+Math.cos(angle+offset)*radius/scale()});}
   for(const radius of [3.5,5.5,7.5,9.5,11.5,13.5,15.5,17.5,19.5])for(let i=0;i<36;i++){const a=angle+i*Math.PI/18;points.push({r:player.r+Math.sin(a)*radius/scale(),c:player.c+Math.cos(a)*radius/scale()});}
   let chosen=null;
   {
    for(const p of points){
    diagnostics.tested++;
    // The existing snitch predicate permits road tiles while preserving source
    // solids, body radius, water and restricted zones. Native vehicles stay solid.
    const ordinary=typeof _npcBodyPassable==='function'&&_npcBodyPassable(p.r,p.c);
    const roadAllowed=!ordinary&&typeof npcPassableForSnitch==='function'&&_npcBodyPassable(p.r,p.c,npcPassableForSnitch);
    if(!ordinary&&!roadAllowed){diagnostics.sourceRejected++;continue;}
    if([...npcs(),...gang()].some(other=>other!==n&&!other.dead&&other.hp>0&&Math.hypot(other.r-p.r,other.c-p.c)*scale()<2)){diagnostics.occupied++;continue;}
    const position=toWorld(p);if(!targets.canMove(position,position,n.id)){diagnostics.nativeRejected++;continue;}
    chosen=p;if(roadAllowed)diagnostics.roadPlacements++;break;
    }
   }
   if(chosen){const p=chosen;
    n.r=n.tr=p.r;n.c=n.tc=p.c;n.ang=angle+Math.PI;n.walkPhase=0;n._mercenaryDemoLineup=true;holdConversation(n);
    if(!anchor)anchor=n;diagnostics.positions.push({id:n.id,r:p.r,c:p.c,...toWorld(n)});count++;placed++;
   }
  }
  const hired=core.getRoster().length;
  if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryDemoPlacement=JSON.stringify({...diagnostics,count,placed,hired});
  return {ok:count+hired>=5,count,placed,hired,diagnostics,message:`Рядом ${count} специалистов, нанято ${hired}. Подойдите ближе 3 м и нажмите E.`};
 }
 function qaInvite(profession){
  if(!ready||!qaSupported())return failure('Проверка недоступна.');adoptCandidates();
  const selected=[...candidates.values()].find(c=>c.profession===profession&&recruitableResident(c.npc));if(!selected)return failure('Нет свободного специалиста этой профессии.');
  const distance=2.4/scale(),angle=Number(player.ang)||0;
  for(let i=0;i<12;i++){const a=angle+i*Math.PI/6,r=player.r+Math.sin(a)*distance,c=player.c+Math.cos(a)*distance;
   // QA placement validates the complete destination body; the player may be
   // standing on a road which a civilian would not use as an approach route.
   if(typeof _npcBodyPassable!=='function'||!_npcBodyPassable(r,c))continue;
   if([...npcs(),...gang()].some(other=>other!==selected.npc&&!other.dead&&other.hp>0&&Math.hypot(other.r-r,other.c-c)*scale()<2))continue;
   const point=toWorld({r,c});if(targets.canMove&&!targets.canMove(point,point,selected.npc.id))continue;
   const n=selected.npc,previousSpeed=Object.hasOwn(n,'_mercenaryQaRestoreSpeed')?n._mercenaryQaRestoreSpeed:n.speed,token=performance.now();n._mercenaryQaRestoreSpeed=previousSpeed;n.r=n.tr=r;n.c=n.tc=c;n.speed=0;n.walkPhase=0;n._talking=token+10000;n._mercenaryQaInvite=token;
   setTimeout(()=>{if(n._mercenaryQaInvite===token){n.speed=previousSpeed;n._talking=0;delete n._mercenaryQaInvite;delete n._mercenaryQaRestoreSpeed;}},10000);
   return success('Специалист рядом на 10 секунд. Наймите через E.');
  }return failure('Рядом нет свободного места для проверки.');
 }
 // Shared with vehicle dismount: one bounded geometry allowance for the whole crew.
 function squadDropOccupied(point,id){
  const near=n=>n&&String(n.id)!==String(id)&&Number.isFinite(n.r)&&Number.isFinite(n.c)&&Math.hypot(n.c*scale()-point.x,n.r*scale()-point.z)<1.6;
  if(near({...player,id:'player'}))return true;
  if(gang().some(n=>!n._mercenaryHospital&&!n._mercenaryVehicleSeat&&near(n)))return true;
  // Source has no shared pedestrian proximity index. Snapshot once only on an
  // actual recovery attempt; an unexpected population overflow fails closed.
  if(!squadDropCrowd){const source=npcs();if(source.length>1024)return true;squadDropCrowd=source.filter(n=>n&&!n.dead&&(n.hp??100)>0&&!n._civilianSeat&&!n._inVehicle&&!n._inCar).map(n=>({id:n.id,r:n.r,c:n.c}));}
  return squadDropCrowd.some(near);
 }
 function checkSquadDropPoint(point,id){
  if(squadDropOccupied(point,id))return {ok:false,reason:'occupied'};
  return targets.safeCatchupPoint?.(point,id)||{ok:false,reason:'resolver_unavailable'};
 }
 function validateSquadSafeDrop(m,point){
  if(!ready||!local()||!m||!record(m.id)||m.hp<=0||m.dead||squadDropChecksRemaining<=0||![point?.x,point?.z].every(Number.isFinite))return null;
  squadDropChecksRemaining--;const result=checkSquadDropPoint(point,m.id);return result.ok&&[result.point?.x,result.point?.y,result.point?.z].every(Number.isFinite)?result.point:null;
 }
 function findSquadSafeDrop(m,index,origin,yaw,state){
  if(!safeDropAdvance||!ready||!local()||!m||!record(m.id)||m.hp<=0||m.dead||!targets.safeCatchupPoint)return null;
  const occupied=gang().filter(n=>n!==m&&!n._mercenaryHospital&&!n._mercenaryVehicleSeat).map(n=>({id:n.id,x:n.c*scale(),z:n.r*scale()}));
  const result=safeDropAdvance(state,{origin,yaw,memberId:m.id,slot:index,occupied,validate:checkSquadDropPoint,now:performance.now(),maxChecks:squadDropChecksRemaining});
  squadDropChecksRemaining=Math.max(0,squadDropChecksRemaining-result.checks);return result.point;
 }
 function bindCatchupModule(module){
  safeDropAdvance=module.advanceMercenarySafeDrop;
  catchupRecovery=module.createMercenaryCatchup({placement:{check:(point,member)=>checkSquadDropPoint(point,member.id)}});
 }
 function recoverFollowers(roster){
  if(!catchupRecovery)return;
  const stamp=performance.now(),heroInterior=!!(typeof _bankInt!=='undefined'&&_bankInt||typeof _buildingInt!=='undefined'&&_buildingInt||typeof _majorInteriorObjectId!=='undefined'&&_majorInteriorObjectId),heroInCar=!!(typeof myDrivingCarId!=='undefined'&&myDrivingCarId)||targets.squadTransport?.isPlayerInVehicle?.()===true||!!targets.squadTransport?.getPlayerVehicle?.();
  const members=roster.map(row=>{
   const m=raw(row.id);if(!m)return null;
   return {id:m.id,owned:!!record(m.id),status:row.status,hp:m.hp,dead:!!m.dead,position:toWorld(m),order:m._mercenaryOrder||'follow',action:core.getAction(m.id),queued:!!row.queued?.length,
    combat:!!(m._mercenaryDefending||m._mercenaryFocus||m.targetKind||m.targetId||m._fighting||m._fightingMelee||m._hostile||m._threatUntil>stamp||m._shotAt>0&&stamp-m._shotAt<500),
    carried:!!(m._carriedByAmbulance||m._ambulanceInTransit||m._ambulanceLoading||m._evacuated||m._carriedBy),carrying:!!(m.carrying||m._carrying||m._carriedNpc),
    seated:!!(m._mercenaryVehicleSeat||m._inVehicle||m._inCar||m.vehicleId||m.vehicle_id||m._civilianSeat),vehicleChase:!!m._mercenaryVehicleChase,
    interior:!!(m._residentIndoors||m._insideBuilding||m._interiorId||m.interior_id),safeExit:!!m._mercenarySafeExit,
    conversation:!!(m._mercenaryConversation||m._playerConversationOpen||m._mercenaryGreetingUntil>now())};
  }).filter(Boolean);
  const result=catchupRecovery.update({now:stamp,enabled:ready&&local()&&document.hidden!==true,hero:{position:toWorld(player),angle:player.ang||0,alive:!(typeof myDead!=='undefined'&&myDead),interior:heroInterior,inVehicle:heroInCar},members,maxChecks:squadDropChecksRemaining});
  squadDropChecksRemaining=Math.max(0,squadDropChecksRemaining-result.checks);
  for(const relocation of result.relocations){
   const m=raw(relocation.id);if(!m)continue;
   const from={r:m.r,c:m.c};m.r=m.tr=relocation.point.z/scale();m.c=m.tc=relocation.point.x/scale();
   if(typeof _clearNpcRoute==='function')_clearNpcRoute(m);
   m._mercenaryPath=null;m._mercenaryMove=null;m._mercenaryFollowGoal=null;m._mercenaryFollowAt=0;m._mercenaryDetourUntil=0;m._followSpeed=0;m.walkPhase=0;m.walking=false;
   m._waterEscaping=false;m._waterEscapeTarget=null;m._waterEscapeSearch=null;m._waterEscapeRetryAt=0;
   m._mercenaryCatchup={at:stamp,reason:relocation.reason,fromR:from.r,fromC:from.c,r:m.r,c:m.c};m._mercenaryMoveReason='catchup_'+relocation.reason;
  }
 }
 function tick(dt){
  squadDropChecksRemaining=4;squadDropCrowd=null;
  if(!ready||!local()){resetMovementClock();reportMovement();return;}if(!restoredOnce){restore();reconcileInventory(inventory());}reconcileMembers();adoptCandidates();const elapsed=movementElapsed(dt);
  const wantedAngle=Number(player.ang)||0,maxTurn=1.45*Math.min(.05,elapsed);
  if(followAngle===null)followAngle=wantedAngle;
  else{const turn=Math.atan2(Math.sin(wantedAngle-followAngle),Math.cos(wantedAngle-followAngle));followAngle+=Math.max(-maxTurn,Math.min(maxTurn,turn));}
  for(const r of core.getRoster()){const m=raw(r.id);if(m){if(m.hp<=0&&!m._mercenaryDownAt)m._mercenaryDownAt=performance.now();else if(m.hp>0)m._mercenaryDownAt=0;}}
  core.update();let lifecycleChanged=false;
  const moveRoster=core.getRoster();squadVehicleTick(moveRoster,elapsed);recoverFollowers(moveRoster);routeWorkDeadline=performance.now()+1.5;routeFrameOffset=(routeFrameOffset+1)%Math.max(1,moveRoster.length);
  for(let offset=0;offset<moveRoster.length;offset++){const index=(offset+routeFrameOffset)%moveRoster.length,r=moveRoster[index];
   if(records.get(r.id)?.status!==r.status){records.set(r.id,r);lifecycleChanged=true;}
   const m=raw(r.id);if(!m)continue;m.level=r.level;m.fighterXp=r.xp;const action=core.getAction(r.id);if(m._mercenaryPath?.stagedFollow&&(action||r.status==='hospital'||r.status==='downed'||m._mercenaryVehicleSeat||m._mercenaryVehicleChase))m._mercenaryPath=null;if(m._mercenaryVehicleSeat){m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;continue;}
   if(m._mercenaryVehicleChase&&m._mercenaryVehicleMove){m._mercenaryMove=m._mercenaryVehicleMove;advanceMember(m,elapsed);continue;}
   if(!action&&r.status!=='hospital'&&r.status!=='downed'){const defense=defend(m);if(defense){if(defense==='approach')advanceMember(m,elapsed);continue;}}
   if(!action&&m._mercenarySafeExit){const exit=m._mercenarySafeExit,p=toWorld(m),arrived=Math.hypot(p.x-exit.position.x,p.z-exit.position.z)<=exit.stopDistance+1e-6;if(arrived&&!exit.arrivedAt)exit.arrivedAt=now();if(r.status==='active'&&now()<exit.expires&&(!arrived||now()-exit.arrivedAt<1)){m._mercenaryMove=exit;advanceMember(m,elapsed);continue;}delete m._mercenarySafeExit;m._mercenaryPath=null;}
   if(!action&&m._mercenaryGreetingUntil){if(now()<m._mercenaryGreetingUntil&&m.hp>0&&!m._mercenaryHospital&&Math.hypot(m.r-player.r,m.c-player.c)*scale()<=3.5){facePlayer(m,elapsed);continue;}delete m._mercenaryGreetingUntil;}
   if(!action&&m._mercenaryConversation){if(Math.hypot(m.r-player.r,m.c-player.c)*scale()<=2.5){facePlayer(m,elapsed);continue;}delete m._mercenaryConversation;}
   if(r.status==='returning'&&!action){m._mercenaryReturnMove=true;m._mercenaryMove={position:toWorld(player),stopDistance:5};}
   else if(m._mercenaryReturnMove){m._mercenaryMove=null;m._mercenaryReturnMove=false;m._followSpeed=0;}
   if(!action&&r.status==='active'&&r.queued.length){m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;continue;}
   if(!action&&r.status==='active')m._mercenaryMove=peacefulGoal(m,index);
   advanceMember(m,elapsed);
  }
  if(lifecycleChanged||now()-lastSave>=2)persist();reportMovement();
 }

 function decorateEntities(value){if(!ready||!value)return value;const list=Array.isArray(value)?value:value.npcs;if(!Array.isArray(list))return value;const result=[];for(const n of list){const id=String(n.id||'').replace(/^npc_/,'');const memberId=id.startsWith('crew_')?id.slice(5):null;const r=memberId?record(memberId):null;if(r?.status==='hospital')continue;const c=candidates.get(id);if(r){const m=raw(memberId),riding=!!m?._mercenaryVehicleSeat,exitWalk=m?._mercenaryVehiclePhase==='exit'&&m?._mercenaryVehicleExitPlan?.stage==='body',vehicleFire=riding&&typeof getVehicleFireIntent==='function'?getVehicleFireIntent(m.id):null,vehicleReady=riding?getVehicleFireReadiness(m.id):null,downed=r.status==='downed'&&n.deathConfirmed!==true&&m?.dead!==true;result.unshift({...n,crouching:!riding&&squadPosture(m)==='crouch',prone:!riding&&squadPosture(m)==='prone',...(riding?{civilianTripRiding:!exitWalk&&m._mercenaryVehiclePhase!=='board',civilianTripCarId:m._mercenaryVehicleId,civilianTripPhase:exitWalk?'exit_walk':m._mercenaryVehiclePhase||'drive',civilianTripProgress:m._mercenaryVehicleProgress??1,vehicleSeatId:m._mercenaryVehicleSeat,...(exitWalk?{moving:!!m.walking,walking:!!m.walking}:{}),...(vehicleReady?{mercenaryVehicleReady:vehicleReady}:{}),...(vehicleFire?{mercenaryVehicleFire:{targetId:vehicleFire.targetId,targetPosition:vehicleFire.targetPosition,weaponId:vehicleFire.weaponId,sourceVehicleId:vehicleFire.sourceVehicleId,seatId:vehicleFire.seatId}}:{})}:{}),...(downed?{downed:true,lifeState:'downed',dead:false,deathConfirmed:false,downedAt:m?._mercenaryDownAt||0,downedUntil:0}:{}),mercenary:{profession:r.profession,level:r.level,status:r.status},weapon:riding?(vehicleReady?m.weapon:'none'):!weaponDrawn(m)||['working','awaiting','retreat','countdown'].includes(m?._mercenaryAction?.phase)?'none':m.weapon||n.weapon||'pistol',_mercenaryAction:m?._mercenaryAction,mercenaryAction:m?._mercenaryAction});}else result.push(c?{...n,weapon:weaponDrawn(c.npc)?c.npc.weapon||'pistol':'none',mercenaryCandidate:true,mercenary:{profession:c.profession}}:n);}return Array.isArray(value)?result:{...value,npcs:result};}
 const api={get ready(){return ready;},greetMember,bindChatter,chatterEvent,getChatterSettings:()=>({volume:typeof _sfxVol==='number'?Math.max(0,Math.min(1,_sfxVol)):.5}),get dismissing(){return dismissing;},getRoster,cancelCommand,rally,follow,isDefending:id=>!!raw(id)?._mercenaryDefending,beginConversation,endConversation,demoSupported,qaSupported,qaInvite,qaLineup,qaPrepareProfessions,qaAssembleProfessions,qaPlacePatient,getCharges:()=>core?.snapshot().charges||[],getPendingTransactions:()=>core?.snapshot().pendingTransactions||[],resolvePending(requestId,receipt){if(!core||!local())return failure('Подтверждение недоступно.');const result=core.resolvePending(requestId,receipt);persist();return result;},recruit,equip,dismiss,upgrade,tick,resetMovementClock,awardCombatXp,reconcileInventory,canMoveMember,getMember,getTarget,blastVehicle,canUseLocalEffects:()=>local(),canCollectSafeLoot,syncSafeLootBalance,stats:id=>core?.stats(memberKey(id)),getAction:id=>core?.getAction(id),getQueue:id=>core?.getQueue(memberKey(id))||[],getFocusedTarget,getVehicleFireIntent,validateVehicleFireIntent,canIssueVehicleFireCommand,getVehicleDefenseFireState,setVehicleDefenseFire,toggleVehicleDefenseFire,qaVehicleDefenseAttack,noteVehicleAttack,getActions:t=>(core?.availableActions(t)||[]).map(a=>({...a,id:a.kind,label:a.kind==='unlock_door'&&t.kind==='vehicle'?'Взломать автомобиль':{revive:'Поднять союзника',intimidate:'Запугать',breach_door:'Выбить дверь',unlock_safe:'Вскрыть сейф',unlock_door:'Вскрыть замок',cut_fence:'Прорезать сетку',disable_power:'Отключить электричество',plant_bomb:'Подорвать'}[a.kind]||a.kind,enabled:a.available,disabledReason:a.available?undefined:'Специалист занят, ранен или восстанавливает навык'})).concat(focusActions(t)),command(actionId,target){const blocked=permitted();if(blocked)return blocked;if(actionId==='eliminate')return eliminate(target);const options=core.availableActions(target).filter(a=>a.kind===actionId&&a.available).sort((a,b)=>Number(a.willQueue)-Number(b.willQueue)||a.queuedCount-b.queuedCount);if(!options.length)return failure('Нет свободного специалиста для этого приказа.');const result=core.command(options[0].memberId,actionId,target.id);if(result.ok){if(!result.queued)clearFocus(raw(options[0].memberId));persist();chatterEvent(options[0].memberId,result.queued?'queued':'ack',{action:actionId});return {...result,...success(result.queued?'Задача добавлена в очередь · '+result.queuePosition:'Приказ принят.')};}return failure('Цель или боец недоступны.');},bindTargets:value=>{targets=value||{};if(!value){vehicleDefenseEnabled=false;vehicleDefenseId=null;vehicleAttackReceipts.clear();}},isMercenary:id=>!!record(id),ownsUpdate:m=>!!record(m?.id)&&(!!m._mercenaryVehicleSeat||m.hp<=0||m._mercenaryHospital||!!core.getAction(m.id)||!m._mercenaryDefending),decorateEntities,nearestCandidate(){adoptCandidates();return[...candidates].filter(([,c])=>npcs().includes(c.npc)&&recruitableResident(c.npc)).map(([id,c])=>({id,d:Math.hypot(c.npc.r-player.r,c.npc.c-player.c)*scale()})).filter(c=>c.d<=3).sort((a,b)=>a.d-b.d)[0]?.id||null;}};
 window.MafioziMercenaries=api;
 import(new URL('./mercenary_core.mjs',scriptUrl).href).then(module=>{bindCatchupModule(module);professions=module.MERCENARY_PROFESSIONS;routeFactory=module.createMercenaryRoutePlanner;longFollowFactory=module.createMercenaryLongFollow;core=module.createMercenarySquad({now,getMember,getTarget,moveMember,performEffect:effect,onAction:(id,action)=>{const m=raw(id);if(m){const previous=m._mercenaryAction;if(action.phase==='working'&&(previous?.phase!=='working'||previous?.targetId!==action.targetId))chatterEvent(id,'task',{action:action.kind});if(action.phase==='retreat'&&action.kind==='plant_bomb'&&previous?.phase==='working')chatterEvent(id,'armed',{action:action.kind});if(action.phase==='completed')chatterEvent(id,'done',{action:action.kind});if(action.phase==='cancelled'&&action.reason==='path_timeout')chatterEvent(id,'failed',{action:action.kind});if(['completed','cancelled'].includes(action.phase)){m._mercenaryLastAction={kind:action.kind,targetId:action.targetId,phase:action.phase,reason:action.reason,at:now()};m._mercenaryMoveReason='idle';queueSafeExit(m,action);if(action.reason==='damaged'){m._mercenaryOrder='rally';m._mercenaryRally=toWorld(m);}}if(action.phase==='working'){const target=action.workPoint?null:getTarget(action.targetId),p=action.workPoint||target?.center||target?.position;if(p)m.ang=Math.atan2(p.z-m.r*scale(),p.x-m.c*scale());}m._mercenaryAction=action;}},allowQaPatientReset:()=>qaSupported(),canStartQueued:id=>!raw(id)?._mercenarySafeExit,canAutoRevive:id=>raw(id)?._mercenaryOrder!=='rally'&&!raw(id)?._mercenaryFocus,scanReviveTargets:()=>['player',...core.getRoster().filter(r=>r.status!=='hospital').map(r=>r.id)].filter(id=>getTarget(id)?.hp<=0)});if(local())restore();ready=true;reconcileInventory(inventory());if(local())reconcileMembers();adoptCandidates();}).catch(error=>console.error('Mercenary initialization failed',error));
})();
