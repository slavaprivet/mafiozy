import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const source=fs.readFileSync('world.html','utf8');
const fn=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0,name);return source.slice(start,source.indexOf('\nfunction ',start+10));};
const helpers=source.slice(source.indexOf('let _walkShotContext=null;'),source.indexOf('function _threeBridgeFireAccepted('));
function setup(kind='civilian'){
 const npc={id:'target',r:.15,c:.30,x:.30,y:.15,hp:60,max_hp:60,alive:true,look:{}},events=[],packets=[];
 const local=kind==='civilian'||kind==='medic';
 if(kind==='medic')Object.assign(npc,{role:'medic',_medicalCrewVehicleId:'amb_source',_medicalCrewSeat:'front_right',_inVehicle:false});
 const c={Math:Object.create(Math),Number,String,Map,Set,Array,JSON,console,performance:{now:()=>5000},player:{r:0,c:0,ang:0},currentWeapon:'pistol',myMode:'pvp',myDead:false,_murderPoliceArrest:null,_myBagWeight:0,_bankRob:null,_policeEvidenceBag:null,lockedTarget:null,joyR:null,myDrivingCarId:null,myJetSkiId:null,_playerSwimmingDeep:false,_inBus:false,lastShotClientT:0,_naganLastShotAt:0,_naganChain:0,_naganShotCrit:false,_authoritativeShotId:'',_authoritativeRemoteSent:false,_shotCritical:false,_shotCritMul:1,WEAPON_CRIT_CHANCE:0,WEAPON_CRIT_MUL:1,RIGHT_STICK_DIRECT_FIRE:false,
 _threeForcedNpcShotUntil:0,_threeForcedVehicleShotUntil:0,_threeForcedGangShotUntil:0,_threeForcedNpcShotId:null,_threeForcedVehicleShotId:null,_threeForcedGangShotId:null,
 _buildingInt:null,_bankInt:null,NPCS:local?[npc]:[],cityCops:kind==='city_cop'?[npc]:[],worldCops:kind==='cop'?[npc]:[],worldEvent:null,aggroZones:{},michaelGuards:new Map(),beachgoers:new Map(),CARS:[],_busRiders:[],_busWaiters:[],_parkingNpcs:[],_threeNpcActionRefs:new Map(),QP:{uid:'7'},_LOCAL_PREVIEW:true,_UP:new Set(),_serverAuthoritativeAmmo:false,
 _lastPlayerCopAlertAt:5000,_lastPlayerShotPanicAt:5000,_lastPlayerWitnessAt:5000,_myGang:[],myWanted:0,pvpActive:false,_recoilUntil:0,_weaponCycle:null,_fireBtn:{classList:{add(){},remove(){}}},joyREl:{classList:{add(){},remove(){}}},document:{documentElement:{dataset:{}}},window:{dispatchEvent:e=>events.push(e.detail)},CustomEvent:class{constructor(type,{detail}){this.type=type;this.detail=detail;}},ws:{readyState:1,send:p=>packets.push(JSON.parse(p))},setTimeout(){},rounds:5,
 resolveWeapon:w=>w,weaponProfile:()=>({range:10,cd:.3,dmg:20,mode:'semi',pellets:7,spread:.04}),weaponCd:()=>.3,weaponFx:()=>({}),_spendWeaponRound:()=>--c.rounds>=0,_newCombatEventId:()=> 'actual-fire-1',_applyWeaponSpread:(dirX,dirY)=>({dirX,dirY}),muzzleWorldPoint:()=>({r:0,c:.5}),weaponDamageAt:()=>20,_currentShotDamage:x=>x,_reserveAuthoritativeTargetClaim:()=>true,
 _effectivePlayerStance:()=> 'stand',_peacefulInteriorGunLock:()=>false,_prisonWeaponLocked:()=>false,_inPrisonIslandRestrictedZone:()=>false,inArena:()=>true,inAggroZone:()=>false,_copInRadius:()=>false,_npcTrySurrenderAfterHit:()=>false,_npcPathPassable:()=>false,_threeNpcEntityId:n=>'npc_'+n.id,
 };
 c.Math.random=()=>.99;
 for(const name of ['showToast','_applyShotMoveSlow','spawnShot','spawnBullet','spawnImpact','addKick','fireScreenFlash','hapticFire','triggerHitStop','addShake','hapticHit','_gangAlertThreat','_markCombatBleeding','_npcRememberAggression','_npcSpreadRumor','_showCurrentShotCritical','_sendWorldWeaponFire','_alertNearbyCops','_sendPoliceWitnessOpenFire','_scheduleBallisticFx'])c[name]=()=>{};
 c.hitCityCop=(target,dy,dx,damage)=>{target.hp-=damage;c._walkConfirmDamage(target,damage);};
 vm.createContext(c);
 vm.runInContext(helpers+'\n'+['_raycastNpc','_raycastBeachgoer','_raycastDecorNpc','_raycastGangCar','_localBallisticTargets','_remoteBallisticTarget','_projectTargetOnRay','_fireShotgunPellets','_firePenetratingRound','_sendRemoteWeaponHit','hitNpc','fire'].map(fn).join('\n')+'\nthis.setContext=x=>_walkShotContext=x;',c);
 // These blockers model old feet-level 2D geometry. A physical resolver has
 // already tested the actual 3D ray; it must not receive this shortened range.
 c._weaponWallDistance=(r,col,dy,dx,range)=>c._walkShotPhysicalContact()?range:.08;c._raycastGasPump=()=>null;c._raycastDamageableCar=()=>null;c._raycastCasinoProp=()=>null;
 const id=local?'npc_target':kind==='cop'?'npc_world_cop_target':'npc_city_cop_target';c._threeNpcActionRefs.set(id,{ref:npc,view:{r:npc.r,c:npc.c}});
 const hit={npcId:id,point:{x:.35*4.1,y:1.1,z:.15*4.1},normal:{x:-1,y:0,z:0},zone:'body'};
 const ctx={request:{muzzleR:.15,muzzleC:.15,resolveContact:q=>{assert.equal(q.range,10,'native ray keeps canonical weapon range');return hit;}},at:5000,ref:null,contact:null,aimCalls:0};
 ctx.request.resolveAim=q=>{ctx.aimCalls++;assert.equal(q.range,10);return {angle:0,pitch:0};};c.setContext(ctx);
 return {c,npc,events,packets,ctx};
}
for(const weapon of ['pistol','rifle','sniper','shotgun'])for(const kind of ['civilian','medic','city_cop','cop']){
 const {c,npc,events,packets,ctx}=setup(kind);c.currentWeapon=weapon;c.fire(0);assert.equal(c.rounds,4,'one real source round');assert.equal(ctx.ref,npc);assert.equal(ctx.aimCalls,1,'one lazy aim after source admission');
 if(kind==='cop'){assert.equal(npc.hp,60,'server HP never optimistic');assert(packets.some(p=>p.t==='cop_shoot'&&p.d.target==='target'));assert.equal(events.length,0);}
 else{assert(npc.hp>=40&&npc.hp<=41,weapon+' '+kind+' admitted skin hit reaches existing damage route');assert.equal(events.length,1);assert.equal(events[0].targetId,ctx.npcId);}
}
for(const lock of ['pve','dead','empty','cooldown','reload','prison']){
 const {c,npc,events,ctx}=setup();if(lock==='pve')c.myMode='pve';if(lock==='dead')c.myDead=true;if(lock==='empty')c.rounds=0;if(lock==='cooldown')c.lastShotClientT=5000;if(lock==='reload')c._spendWeaponRound=()=>false;if(lock==='prison')c._prisonWeaponLocked=()=>true;c.fire(0);assert.equal(npc.hp,60);assert.equal(events.length,0);assert.equal(ctx.aimCalls,0,lock+' does not raycast or skin the scene');
}
for(const invalid of ['throws','nan']){
 const {c,npc,ctx}=setup();ctx.request.resolveAim=()=>{if(invalid==='throws')throw Error('invalid aim');return {angle:NaN,pitch:0};};c.fire(0);assert.equal(npc.hp,40,'invalid callback falls back to admitted original direction');if(invalid==='throws')assert.match(ctx.aimError,/invalid aim/);
}
for(const missing of ['miss','unknown']){
 const {c,npc,events,ctx}=setup();ctx.request.resolveContact=()=>missing==='miss'?null:{npcId:'npc_missing',point:{x:1,y:1,z:.6},normal:{x:-1,y:0,z:0}};
 c.fire(0);assert.equal(npc.hp,60);assert.equal(events.length,0);assert.equal(c.rounds,4,'physical miss spends a round without legacy radius fallback');
}
console.log('PASS actual fire admission: pistol/rifle/sniper/shotgun physical muzzle/range, close resident damage, off-centre city cop, remote cop packet without optimistic HP, PvE/death/empty/miss/unknown guards');
