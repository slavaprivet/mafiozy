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
 let core,professions,routeFactory,targets={},lastCandidates=-Infinity,lastSave=-Infinity,dismissing=false,ready=false,followAngle=null;
 let restoreBlocked=false,restoredOnce=false,safeLootBalance=0,qaRecruiting=false;const persistenceDiagnostics={restore:null,save:null,removals:[]};
 let routeWorkDeadline=0,routeFrameOffset=0;
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
 const squadPassengerSeats=['front_right','rear_left','rear_right'],squadBoardDistance=6,squadTeleportDistance=36,squadTeleportDelay=2.5;
 function playerSquadVehicle(){
  if(typeof myDrivingCarId==='undefined'||!myDrivingCarId||typeof questCars==='undefined'||!questCars?.get)return null;
  const car=questCars.get(myDrivingCarId)||questCars.get(String(myDrivingCarId));if(!car||![car.x,car.y].every(Number.isFinite)||car._hidden||car._towed||car._wrecked||car.wrecked)return null;
  const id=`quest_${car.id}`,reserved=new Set();
  if(typeof myIsPassenger!=='undefined'&&myIsPassenger)reserved.add(typeof _walkVehicleSeatId!=='undefined'&&squadPassengerSeats.includes(_walkVehicleSeatId)?_walkVehicleSeatId:'front_right');
  for(const uid of car.passenger_uids||[])if(String(uid)!==String(typeof QP!=='undefined'?QP.uid:''))reserved.add('front_right');
  return {id,car,r:+car.y,c:+car.x,ang:+car.ang||0,seats:squadPassengerSeats.filter(seat=>!reserved.has(seat))};
 }
 function squadVehicleDrop(m,index,vehicle){
  const angle=vehicle?.ang||0,origin=vehicle?{r:vehicle.r,c:vehicle.c}:{r:+player.r||0,c:+player.c||0};
  for(const radius of [3.8,4.8,6])for(const turn of [Math.PI+index*.8,Math.PI/2+index*.8,-Math.PI/2+index*.8,index*.8]){
   const a=angle+turn,r=origin.r+Math.sin(a)*radius/scale(),c=origin.c+Math.cos(a)*radius/scale(),p=toWorld({r,c});
   if(typeof _npcBodyPassable==='function'&&!_npcBodyPassable(r,c))continue;if(targets.canMove&&targets.canMove(p,p,m.id)!==true)continue;return {r,c};
  }
  return {r:origin.r,c:origin.c};
 }
 function clearSquadVehicle(m,index,vehicle){
  if(!m?._mercenaryVehicleSeat)return false;const drop=squadVehicleDrop(m,index,vehicle);m.r=m.tr=drop.r;m.c=m.tc=drop.c;m.ang=vehicle?.ang||m.ang||0;delete m._mercenaryVehicleSeat;delete m._mercenaryVehicleId;delete m._mercenaryVehicleChaseAt;m._mercenaryVehicleChase=false;m._mercenaryPath=null;m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;return true;
 }
 function squadVehicleTick(roster){
  const vehicle=playerSquadVehicle(),members=roster.map(row=>({row,m:raw(row.id)})).filter(item=>item.m),assigned=new Set();let teleported=0;
  for(const {row,m}of members){const eligible=row.status==='active'&&m.hp>0&&!m.dead&&!m._mercenaryHospital&&!core.getAction(row.id)&&(m._mercenaryOrder||'follow')==='follow'&&!m._mercenaryDefending;
   if(!vehicle||!eligible||m._mercenaryVehicleId&&m._mercenaryVehicleId!==vehicle.id){clearSquadVehicle(m,members.findIndex(item=>item.m===m),vehicle);m._mercenaryVehicleChase=false;delete m._mercenaryVehicleChaseAt;continue;}
   if(m._mercenaryVehicleSeat&&!vehicle.seats.includes(m._mercenaryVehicleSeat)){clearSquadVehicle(m,members.findIndex(item=>item.m===m),vehicle);continue;}
   if(m._mercenaryVehicleSeat)assigned.add(m._mercenaryVehicleSeat);
  }
  if(!vehicle)return null;
  for(let index=0;index<members.length;index++){const {row,m}=members[index],eligible=row.status==='active'&&m.hp>0&&!m.dead&&!m._mercenaryHospital&&!core.getAction(row.id)&&(m._mercenaryOrder||'follow')==='follow'&&!m._mercenaryDefending;if(!eligible)continue;
   if(m._mercenaryVehicleSeat){m.r=m.tr=vehicle.r;m.c=m.tc=vehicle.c;m.ang=vehicle.ang;m._mercenaryMove=null;m._mercenaryPath=null;m._followSpeed=0;m.walkPhase=0;m._mercenaryMoveReason='vehicle_passenger';continue;}
   const distance=Math.hypot(m.r-vehicle.r,m.c-vehicle.c)*scale(),seat=vehicle.seats.find(id=>!assigned.has(id));m._mercenaryVehicleChase=true;m._mercenaryVehicleChaseAt??=now();
   const catchup=distance>=squadTeleportDistance&&now()-m._mercenaryVehicleChaseAt>=squadTeleportDelay;
   if(catchup){const drop=squadVehicleDrop(m,index,vehicle);m.r=m.tr=drop.r;m.c=m.tc=drop.c;m._mercenaryPath=null;m._mercenaryMove=null;m._mercenaryVehicleChaseAt=now();teleported++;}
   if(seat&&(distance<=squadBoardDistance||catchup)){assigned.add(seat);m._mercenaryVehicleSeat=seat;m._mercenaryVehicleId=vehicle.id;m.r=m.tr=vehicle.r;m.c=m.tc=vehicle.c;m.ang=vehicle.ang;m._mercenaryVehicleChase=false;delete m._mercenaryVehicleChaseAt;m._mercenaryMove=null;m._mercenaryPath=null;m._followSpeed=0;m.walkPhase=0;m._mercenaryMoveReason='vehicle_passenger';}
  }
  if(document.documentElement?.dataset)document.documentElement.dataset.mercenaryVehicle=JSON.stringify({vehicleId:vehicle.id,seated:members.filter(({m})=>m._mercenaryVehicleSeat).map(({m})=>({id:m.id,seatId:m._mercenaryVehicleSeat})),chasing:members.filter(({m})=>m._mercenaryVehicleChase).map(({m})=>m.id),teleported});
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
   clearFocus(m);positions.push(chosen);m._mercenaryOrder='rally';m._mercenaryRally=chosen;m._mercenaryReturnMove=false;count++;
  }
  if(count){persist();chatterEvent('player','rally');}return {ok:count>0,count,cancelled,deferred,blocked,positions,message:count?(deferred?'Отряд идёт к месту сбора. Занятые бойцы присоединятся после безопасного отхода или подтверждения действия.':'Отряд идёт к месту сбора.'):'Рядом нет свободных мест.'};
 }
 function follow(){if(!ready||!local())return failure('Приказ недоступен.');let completing=0;for(const r of core.getRoster()){const m=raw(r.id);if(m){clearFocus(m);core.clearQueue(r.id);const action=core.getAction(r.id);if(action){if(action.armed||action.phase==='awaiting')completing++;else core.cancel(r.id);}m._mercenaryOrder='follow';m._mercenaryRally=null;m._mercenaryFollowAt=0;}}persist();if(core.getRoster().length)chatterEvent('player','follow');return success(completing?'Отряд следует за вами. Занятые бойцы завершат безопасный отход или подтверждение действия.':'Отряд следует за вами.');}
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
  if(m.hp<=0||m.dead||m._mercenaryHospital){m._mercenaryMove=null;m._mercenaryReturnMove=false;m._followSpeed=0;m._mercenaryMoveReason=m._mercenaryHospital?'hospital':'downed';return;}
  let goal=m._mercenaryMove;if(!goal)return;const from=toWorld(m);if(routeFactory){goal=approachWaypoint(m,from,goal);if(!goal){m._followSpeed=0;m.walkPhase=0;return;}}
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
  m._followSpeed=0;m.walkPhase=0;if(goal.routed){const route=m._mercenaryPath;route.blockedAt=route.blockedAt||now();if(now()-route.blockedAt>.5)m._mercenaryPath=null;}
 }
 function approachWaypoint(m,from,goal){
  let route=m._mercenaryPath;const purpose=(goal.phase||m._mercenaryOrder||'follow')+':'+(goal.targetId||''),following=!goal.phase&&m._mercenaryOrder!=='rally',tracking=following||goal.tracksMovingTarget===true,threshold=goal.phase?.35:.8,drift=route?Math.hypot(route.goal.x-goal.position.x,route.goal.z-goal.position.z):0;
  // Moving leaders and bomb targets must not reset an unfinished search on
  // every update. Use its safe prefix, then reconnect to the current contact.
  const replace=route&&(route.purpose!==purpose||drift>threshold&&(!tracking||route.direct||drift>12||route.search&&now()-route.createdAt>6||route.path&&Math.hypot(from.x-route.goal.x,from.z-route.goal.z)<=goal.stopDistance+.1));
  if(replace)route=m._mercenaryPath=null;
  const clear=(a,b)=>{
   if(!canMoveMember(m.id,{r:a.z/scale(),c:a.x/scale()},{r:b.z/scale(),c:b.x/scale()}))return false;
   const dx=b.x-a.x,dz=b.z-a.z,length2=dx*dx+dz*dz;
   for(const other of gang()){if(other===m||other.hp<=0||other._mercenaryHospital)continue;const x=other.c*scale()-a.x,z=other.r*scale()-a.z,start=Math.hypot(x,z),projection=length2?(x*dx+z*dz)/length2:0;if(start<1.1&&projection<=0)continue;const t=Math.max(0,Math.min(1,projection));if(Math.hypot(x-dx*t,z-dz*t)<1.1)return false;}
   return true;
  };
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
 function effect(e){if(!local())return false;const armed=core.getAction(e.memberId);if(e.kind==='plant_bomb'&&armed?.armed&&armed.id===e.actionId)return targets.performEffect?.(e)||false;const m=raw(e.memberId);if(!m||!record(e.memberId))return false;if(e.kind==='hospitalize'){m.hp=0;m._mercenaryHospital=true;m._mercenaryMove=null;return true;}if(e.kind==='discharge'){const door=typeof _hospitalDoor==='function'?_hospitalDoor():null;if(!door||!_npcBodyPassable(door.r,door.c))return false;m.r=door.r;m.c=door.c;m.hp=m.max_hp;m._mercenaryDownAt=0;m.dead=false;m._mercenaryHospital=false;m._mercenaryAction=null;return true;}if(e.kind==='revive'){if(e.targetId==='player'){return revivePlayer(e);}const ally=raw(e.targetId);if(!ally||!record(ally.id)||record(ally.id).status==='hospital'||ally.hp>0)return false;ally.hp=Math.max(1,Math.round(ally.max_hp*(e.stats?.reviveFraction||.35)));ally.dead=false;delete ally._mercenaryQaRescueUntil;ally._mercenaryDownAt=0;ally._mercenaryHospital=false;return true;}if(e.kind==='intimidate'){const n=findNpc(e.targetId);if(!n||n.dead||n.hp<=0||n._empireBoss||n._guard||n._invulnerable)return false;const t=performance.now();if(typeof _npcApplyIntimidation==='function'){if(!_npcApplyIntimidation(n,m.r,m.c,t))return false;}else{n._intimidatedUntil=t+60000;n.snitching=false;n.snitchUntil=0;n._witnessCallUntil=0;n.panicUntil=t+8000;n.panicSrcR=m.r;n.panicSrcC=m.c;n._hostile=false;n._fighting=false;n._fightingMelee=false;n._panicStyle='flee';}n.cryText='Не трогай меня!';n.cryUntil=t+3000;return true;}return targets.performEffect?.(e)||false;}
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
 function tick(dt){
  if(!ready||!local()){resetMovementClock();return;}if(!restoredOnce){restore();reconcileInventory(inventory());}reconcileMembers();adoptCandidates();const elapsed=movementElapsed(dt);
  const wantedAngle=Number(player.ang)||0,maxTurn=1.45*Math.min(.05,elapsed);
  if(followAngle===null)followAngle=wantedAngle;
  else{const turn=Math.atan2(Math.sin(wantedAngle-followAngle),Math.cos(wantedAngle-followAngle));followAngle+=Math.max(-maxTurn,Math.min(maxTurn,turn));}
  for(const r of core.getRoster()){const m=raw(r.id);if(m){if(m.hp<=0&&!m._mercenaryDownAt)m._mercenaryDownAt=performance.now();else if(m.hp>0)m._mercenaryDownAt=0;}}
  core.update();let lifecycleChanged=false;
  const moveRoster=core.getRoster();squadVehicleTick(moveRoster);routeWorkDeadline=performance.now()+1.5;routeFrameOffset=(routeFrameOffset+1)%Math.max(1,moveRoster.length);
  for(let offset=0;offset<moveRoster.length;offset++){const index=(offset+routeFrameOffset)%moveRoster.length,r=moveRoster[index];
   if(records.get(r.id)?.status!==r.status){records.set(r.id,r);lifecycleChanged=true;}
   const m=raw(r.id);if(!m)continue;m.level=r.level;m.fighterXp=r.xp;const action=core.getAction(r.id);if(m._mercenaryVehicleSeat){m._mercenaryMove=null;m._followSpeed=0;m.walkPhase=0;continue;}
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
  if(lifecycleChanged||now()-lastSave>=2)persist();
 }

 function decorateEntities(value){if(!ready||!value)return value;const list=Array.isArray(value)?value:value.npcs;if(!Array.isArray(list))return value;const result=[];for(const n of list){const id=String(n.id||'').replace(/^npc_/,'');const memberId=id.startsWith('crew_')?id.slice(5):null;const r=memberId?record(memberId):null;if(r?.status==='hospital')continue;const c=candidates.get(id);if(r){const m=raw(memberId),riding=!!m?._mercenaryVehicleSeat,downed=r.status==='downed'&&n.deathConfirmed!==true&&m?.dead!==true;result.unshift({...n,crouching:!riding&&squadPosture(m)==='crouch',prone:!riding&&squadPosture(m)==='prone',...(riding?{civilianTripRiding:true,civilianTripCarId:m._mercenaryVehicleId,civilianTripPhase:'drive',civilianTripProgress:1,vehicleSeatId:m._mercenaryVehicleSeat}:{}),...(downed?{downed:true,lifeState:'downed',dead:false,deathConfirmed:false,downedAt:m?._mercenaryDownAt||0,downedUntil:0}:{}),mercenary:{profession:r.profession,level:r.level,status:r.status},weapon:riding||!weaponDrawn(m)||['working','awaiting','retreat','countdown'].includes(m?._mercenaryAction?.phase)?'none':m.weapon||n.weapon||'pistol',_mercenaryAction:m?._mercenaryAction,mercenaryAction:m?._mercenaryAction});}else result.push(c?{...n,weapon:weaponDrawn(c.npc)?c.npc.weapon||'pistol':'none',mercenaryCandidate:true,mercenary:{profession:c.profession}}:n);}return Array.isArray(value)?result:{...value,npcs:result};}
 const api={get ready(){return ready;},greetMember,bindChatter,chatterEvent,getChatterSettings:()=>({volume:typeof _sfxVol==='number'?Math.max(0,Math.min(1,_sfxVol)):.5}),get dismissing(){return dismissing;},getRoster,cancelCommand,rally,follow,isDefending:id=>!!raw(id)?._mercenaryDefending,beginConversation,endConversation,demoSupported,qaSupported,qaInvite,qaLineup,qaPrepareProfessions,qaAssembleProfessions,qaPlacePatient,getCharges:()=>core?.snapshot().charges||[],getPendingTransactions:()=>core?.snapshot().pendingTransactions||[],resolvePending(requestId,receipt){if(!core||!local())return failure('Подтверждение недоступно.');const result=core.resolvePending(requestId,receipt);persist();return result;},recruit,equip,dismiss,upgrade,tick,resetMovementClock,awardCombatXp,reconcileInventory,canMoveMember,getMember,getTarget,blastVehicle,canUseLocalEffects:()=>local(),canCollectSafeLoot,syncSafeLootBalance,stats:id=>core?.stats(memberKey(id)),getAction:id=>core?.getAction(id),getQueue:id=>core?.getQueue(memberKey(id))||[],getFocusedTarget,getActions:t=>(core?.availableActions(t)||[]).map(a=>({...a,id:a.kind,label:a.kind==='unlock_door'&&t.kind==='vehicle'?'Взломать автомобиль':{revive:'Поднять союзника',intimidate:'Запугать',breach_door:'Выбить дверь',unlock_safe:'Вскрыть сейф',unlock_door:'Вскрыть замок',cut_fence:'Прорезать сетку',disable_power:'Отключить электричество',plant_bomb:'Подорвать'}[a.kind]||a.kind,enabled:a.available,disabledReason:a.available?undefined:'Специалист занят, ранен или восстанавливает навык'})).concat(focusActions(t)),command(actionId,target){const blocked=permitted();if(blocked)return blocked;if(actionId==='eliminate')return eliminate(target);const options=core.availableActions(target).filter(a=>a.kind===actionId&&a.available).sort((a,b)=>Number(a.willQueue)-Number(b.willQueue)||a.queuedCount-b.queuedCount);if(!options.length)return failure('Нет свободного специалиста для этого приказа.');const result=core.command(options[0].memberId,actionId,target.id);if(result.ok){if(!result.queued)clearFocus(raw(options[0].memberId));persist();chatterEvent(options[0].memberId,result.queued?'queued':'ack',{action:actionId});return {...result,...success(result.queued?'Задача добавлена в очередь · '+result.queuePosition:'Приказ принят.')};}return failure('Цель или боец недоступны.');},bindTargets:value=>{targets=value||{};},isMercenary:id=>!!record(id),ownsUpdate:m=>!!record(m?.id)&&(m.hp<=0||m._mercenaryHospital||!!core.getAction(m.id)||!m._mercenaryDefending),decorateEntities,nearestCandidate(){adoptCandidates();return[...candidates].filter(([,c])=>npcs().includes(c.npc)&&recruitableResident(c.npc)).map(([id,c])=>({id,d:Math.hypot(c.npc.r-player.r,c.npc.c-player.c)*scale()})).filter(c=>c.d<=3).sort((a,b)=>a.d-b.d)[0]?.id||null;}};
 window.MafioziMercenaries=api;
 import(new URL('./mercenary_core.mjs',scriptUrl).href).then(module=>{professions=module.MERCENARY_PROFESSIONS;routeFactory=module.createMercenaryRoutePlanner;core=module.createMercenarySquad({now,getMember,getTarget,moveMember,performEffect:effect,onAction:(id,action)=>{const m=raw(id);if(m){const previous=m._mercenaryAction;if(action.phase==='working'&&(previous?.phase!=='working'||previous?.targetId!==action.targetId))chatterEvent(id,'task',{action:action.kind});if(action.phase==='retreat'&&action.kind==='plant_bomb'&&previous?.phase==='working')chatterEvent(id,'armed',{action:action.kind});if(action.phase==='completed')chatterEvent(id,'done',{action:action.kind});if(action.phase==='cancelled'&&action.reason==='path_timeout')chatterEvent(id,'failed',{action:action.kind});if(['completed','cancelled'].includes(action.phase)){m._mercenaryLastAction={kind:action.kind,targetId:action.targetId,phase:action.phase,reason:action.reason,at:now()};m._mercenaryMoveReason='idle';queueSafeExit(m,action);if(action.reason==='damaged'){m._mercenaryOrder='rally';m._mercenaryRally=toWorld(m);}}if(action.phase==='working'){const target=action.workPoint?null:getTarget(action.targetId),p=action.workPoint||target?.center||target?.position;if(p)m.ang=Math.atan2(p.z-m.r*scale(),p.x-m.c*scale());}m._mercenaryAction=action;}},allowQaPatientReset:()=>qaSupported(),canStartQueued:id=>!raw(id)?._mercenarySafeExit,canAutoRevive:id=>raw(id)?._mercenaryOrder!=='rally'&&!raw(id)?._mercenaryFocus,scanReviveTargets:()=>['player',...core.getRoster().filter(r=>r.status!=='hospital').map(r=>r.id)].filter(id=>getTarget(id)?.hp<=0)});if(local())restore();ready=true;reconcileInventory(inventory());if(local())reconcileMembers();adoptCandidates();}).catch(error=>console.error('Mercenary initialization failed',error));
})();
