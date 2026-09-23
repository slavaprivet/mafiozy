// Actual World lifecycle owners + actual Walk getter/controller. No proposal overlay.
import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createWalkVehicleExplosionLocalAuthority} from './walk_vehicle_explosion_local_authority.mjs';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const section=(source,startMarker,endMarker)=>{
 const start=source.indexOf(startMarker),end=source.indexOf(endMarker,start);
 assert(start>=0&&end>start,`Missing actual source anchors: ${startMarker}`);
 return source.slice(start,end);
};
const heroGetter=walk.split('\n').find(line=>line.includes('getHeroState(record){'));
const bridgeGetter=world.split('\n').find(line=>line.trim().startsWith('getWalkLocalVehicleOccupantLifeGeneration(){'));
assert(heroGetter&&bridgeGetter);

function fixture({direct=false,local=true,boot=false}={}){
 let now=1000;
 const record={id:'life-review',car:{}},patient={_playerPatient:true};
 // Presentation, network and city spawning are host boundaries. HP/death,
 // recovery, custody, receipt validation and epoch observation remain real code.
 const ctx={Math,Set,console,performance:{now:()=>now},
  document:{documentElement:{dataset:{}},getElementById:()=>null},
  _walkRendererActive:()=>true,_LOCAL_PREVIEW:local,_worldDirectCombatDemo:direct,
  _walkCoverDamage:d=>d,_meleeBlockHeld:false,_registerIncomingFire(){},_policeHasLevel:()=>false,
  player:{r:1,c:1,ang:0},PVP:{max_hp:100},myHp:100,myDead:false,_localDeath:false,
  myDeathBy:'',myDeathLeft:0,myJailIn:0,_murderPoliceArrest:null,
  _threePlayerImpactState:null,_meleeBruiseAt:0,_policeVestToastAt:0,_localHpHurtAt:0,
  _selfHpBarUntil:0,_bankShieldUntil:0,
  _combatState:{body:{current:100,max:100,dead:false},armor:{id:'vest',current:60,max:60},combat_version:-1},
  _worldDirectDemoArmorMax:60,_equippedArmor:'vest',_inventoryArmorUiState:null,
  _readInventoryArmorUiState:()=>({}),spawnFloatText(){},renderHudAvatar(){},updateArmorHud(){},
  _renderDirectDemoArmorHud(){},showEventBanner(){},showToast(){},_deathOv:null,
  _beginMurderPoliceArrest:()=>false,_playerEmergencyPatient:null,
  _setPlayerEmergencyTransport(){},spawnAmbulance:()=>({kind:'ambulance'}),
  _myGang:[],_saveGang(){},window:{MafioziMercenaries:{isMercenary:()=>true}},
  myDrivingCarId:null,myIsPassenger:false,myJetSkiId:null,_exitRequested:false,camShake:0,
  cam:{},TS:1,ISO_Y:.5,_hospitalDoor:()=>({r:4,c:5}),_hospitalDoorAt:()=>({r:6,c:7}),
  HOSPITAL_EAST_R:6,HOSPITAL_EAST_C:7,ws:null,
  _worldDirectDemoQaHits:0,_suppressedUntil:0,screenFlash:0,camKickX:0,camKickY:0,
  impacts:[],floatTexts:[],_walkVehicleOccupantLethalReceipts:new Set(),
  fleet:{active:record},occupiedSeat:'front_left',transition:null,worldHealthFrame:null,
  _myBagWeight:0,_murderIncidentSeq:0,_murderIncidents:[],_dispatchMurderPoliceCalls(){},
  serviceVehicles:[],cityCops:[],_murderPoliceRescueGraceUntil:0,
  _murderPoliceArrestInCustody:()=>false,_buildingInt:null,_bankInt:null};
 vm.createContext(ctx);
 const actualFunctions=[
  section(world,'function _localHostileCanResolveHit(){','\nlet _walkNpcVehicleIncomingResolver'),
  section(world,'function _hurtLocal(','\nlet myKills'),
  section(world,'function _completePlayerAmbulanceRecovery(','\nfunction _ambulanceWatchdogAdvance'),
  section(world,'function _dispatchPlayerAmbulance(){','\nfunction _fireTruckParkingPoint'),
  section(world,'function resetDirectWorldCombatDemo(){','\nfunction startDirectWorldCombatDemo'),
  section(world,'function _queueAnyPoliceDeathPickup(','\nfunction _nearestSurrenderPolice'),
  section(world,'function _cancelMurderPoliceArrest(','\nfunction _onMurderArrestCopKilled'),
  'this.actualTimerRespawn=function(dt){'+section(world,
   '  if (_localDeath && myDead && !_murderPoliceArrest && !_worldDirectCombatDemo) {',
   '\n  // ── ИНТЕРЬЕР ОБЫЧНОГО ЗДАНИЯ')+'};',
  // Same-script call before the lexical epoch initializer exercises its TDZ.
  boot?"_hurtLocal(10000,'boot');_completePlayerAmbulanceRecovery(_playerEmergencyPatient,{},1001);":'',
  section(world,'let _walkVehicleOccupantLifeGeneration=','\nlet _walkBlastExposureResolver')
 ].join('\n');
 vm.runInContext(actualFunctions+
  '\nthis.getGeneration=_walkLocalVehicleOccupantLifeGeneration;this.applyReceipt=_applyWalkLocalVehicleOccupantLethal;',ctx);
 vm.runInContext('window.Mafiozi3DBridge={'+bridgeGetter+'};',ctx);
 let reads=0;
 ctx.npcBridge={getPlayerState:()=>({hp:ctx.myHp,healthDead:ctx.myDead}),
  getWalkLocalVehicleOccupantLifeGeneration:()=>{reads++;return ctx.getGeneration();}};
 vm.runInContext('this.actualWalkHeroGetter=function '+heroGetter.trim().replace(/,$/,'')+';',ctx);
 return {ctx,record,state:()=>ctx.actualWalkHeroGetter(record),reads:()=>reads,
  recover:()=>{now+=3000;return direct?ctx.resetDirectWorldCombatDemo():
   ctx._completePlayerAmbulanceRecovery(ctx._playerEmergencyPatient||patient,{hospitalId:'main'},now);}};
}

const receipt=(id,lifeGeneration=0)=>({id,eventId:'event:'+id,vehicleId:'fleet:life-review',
 actorId:'player',seatId:'front_left',lifeGeneration,kind:'vehicle_explosion',lethal:true,confirmed:true});

for(const direct of [false,true])test(`unsampled real death → ${direct?'direct reset':'ambulance recovery'} rejects an old receipt`,()=>{
 const f=fixture({direct});let pending;
 // Walk normally delivers synchronously. Holding this genuine receipt is an
 // explicit admission-boundary negative, not a claim of a production delay queue.
 const owner=createWalkVehicleExplosionLocalAuthority({sessionId:'life-audit',
  canUseLocalEffects:()=>true,getHeroState:()=>f.state(),getCrewState:()=>[],
  applyCrewReceipt:()=>({accepted:false}),applyHeroReceipt:r=>{pending=r;return{accepted:false,reason:'held-for-boundary-review'};}});
 assert.equal(owner.handle({record:f.record,vehicle:f.record.car,state:{explosions:1}}).targets,1);
 assert.equal(pending.lifeGeneration,0);assert.equal(f.reads(),1);
 f.ctx._hurtLocal(10000,'unrelated death',false,{kind:'bullet',weapon:'pistol'});
 assert(f.ctx.myDead&&f.ctx.myHp===0);assert.equal(f.reads(),1);
 assert(f.recover());assert(!f.ctx.myDead&&f.ctx.myHp>0);
 assert.equal(f.reads(),1,'no Walk snapshot between actual death and recovery');
 // Admission itself must reject stale life before a new snapshot can help it.
 const hp=f.ctx.myHp,result=f.ctx.applyReceipt(pending);
 assert.equal(result.accepted,false);assert.equal(result.reason,'stale-life');
 assert.equal(f.ctx.myHp,hp);assert.equal(hp,direct?100:40);assert.equal(f.ctx.myDead,false);
 assert.equal(f.state().lifeGeneration,1);assert.equal(f.ctx._combatState.combat_version,-1);
});

test('same-life zero, duplicate receipt, repeat alive recovery and next-life lethal receipt',()=>{
 const f=fixture(),first=receipt('first-life-fatal');
 assert.equal(f.ctx.applyReceipt(first).accepted,true);assert(f.recover());
 assert.equal(f.state().lifeGeneration,1);const hp=f.ctx.myHp;
 assert.equal(f.ctx.applyReceipt(first).duplicate,true);assert.equal(f.ctx.myHp,hp);
 assert.equal(f.ctx.myDead,false);assert(f.recover());
 assert.equal(f.state().lifeGeneration,1,'repeat recovery of an alive patient is not a new life');
 assert.equal(f.ctx.applyReceipt(receipt('next-life-fatal',1)).accepted,true);
});

test('authenticated HP/death ownership and preview combat_version -1 are unchanged',()=>{
 const f=fixture({local:false,direct:false});
 const state=()=>({hp:f.ctx.myHp,dead:f.ctx.myDead,version:f.ctx._combatState.combat_version});
 const before=state();f.ctx._hurtLocal(10000,'server-owned');
 assert.equal(f.ctx.applyReceipt(receipt('auth-denied')).reason,'authority');
 assert.deepEqual(state(),before);assert.equal(f.state().lifeGeneration,0);
});

test('early actual hurt/recovery before epoch declaration cannot enter its TDZ',()=>{
 assert(world.indexOf('let _walkVehicleOccupantLifeGeneration=')<world.indexOf('window.Mafiozi3DBridge = Object.freeze({'));
 const f=fixture({boot:true});assert.equal(f.ctx.myHp,40);assert.equal(f.ctx.myDead,false);
 assert.equal(f.state().lifeGeneration,0,'no receipt API existed before epoch initialization');
});

test('actual fallback timer respawn preserves the unsampled lethal life boundary',()=>{
 const f=fixture();f.ctx.spawnAmbulance=()=>null;assert.equal(f.state().lifeGeneration,0);
 f.ctx._hurtLocal(10000,'timer');assert.equal(f.ctx._playerEmergencyPatient,null);
 f.ctx.actualTimerRespawn(19);assert.equal(f.ctx.myHp,100);assert.equal(f.ctx.myDead,false);
 assert.equal(f.ctx.applyReceipt(receipt('before-timer-respawn')).reason,'stale-life');
 assert.equal(f.state().lifeGeneration,1);assert.equal(f.state().lifeGeneration,1);
});

test('actual lethal police pickup, custody rejection and rescue preserve one life boundary',()=>{
 const f=fixture();assert.equal(f.state().lifeGeneration,0);const cop={id:'cop-life-review'};
 f.ctx._hurtLocal(10000,'Полиция',false,{kind:'city_cop',cop});
 assert.equal(f.ctx._murderPoliceArrest.phase,'awaiting_pickup');assert.equal(f.ctx._playerEmergencyPatient,null);
 const ar=f.ctx._murderPoliceArrest;
 assert.equal(f.ctx._completePlayerAmbulanceRecovery({_playerPatient:true},{},1001),false);
 assert.equal(f.ctx.myDead,true);assert.equal(f.ctx.myHp,0);assert.equal(f.ctx._murderPoliceArrest,ar);
 f.ctx._hurtLocal(10000,'Полиция',false,{kind:'city_cop',cop});
 assert.equal(f.ctx.document.documentElement.dataset.policeCustodyDamageBlocked,'1');
 assert.equal(f.ctx._murderIncidents.length,1);
 assert(f.ctx._cancelMurderPoliceArrest({kind:'gang_companion'},1100));
 assert.equal(f.ctx.myHp,1);assert.equal(f.ctx.myDead,false);
 assert.equal(f.ctx.applyReceipt(receipt('before-custody-rescue')).reason,'stale-life');
 assert.equal(f.state().lifeGeneration,1);assert.equal(f.state().lifeGeneration,1);
});

test('nonlethal damage, invalid recovery and peaceful custody do not invent a new life',()=>{
 const f=fixture();assert.equal(f.state().lifeGeneration,0);
 f.ctx._hurtLocal(1,'nonlethal');assert.equal(f.state().lifeGeneration,0);assert.equal(f.ctx.myHp,99);
 assert.equal(f.ctx._completePlayerAmbulanceRecovery({},{}),false);assert.equal(f.state().lifeGeneration,0);
 f.ctx._queueAnyPoliceDeathPickup(null,{peaceful:true},1100);assert.equal(f.ctx.myHp,99);
 assert(f.ctx._cancelMurderPoliceArrest({},1200));assert.equal(f.state().lifeGeneration,0);
});

test('actual controller/owners tolerate synchronous recovery and reentrant duplicate delivery',()=>{
 const f=fixture();let firstDelivery=null,currentReceipt=null,callbackCount=0;
 const owner=createWalkVehicleExplosionLocalAuthority({sessionId:'reentry-review',
  canUseLocalEffects:()=>true,getHeroState:()=>f.state(),getCrewState:()=>[],
  applyCrewReceipt:()=>({accepted:false}),applyHeroReceipt:r=>{
   currentReceipt=r;const result=f.ctx.applyReceipt(r);firstDelivery??=result;return result;
  }});
 const ordinaryAmbulance=f.ctx.spawnAmbulance;
 f.ctx.spawnAmbulance=()=>{
  if(++callbackCount!==1)return ordinaryAmbulance();
  // Explicit callback-boundary injection: no claim that ambulances arrive instantly.
  assert.equal(f.ctx.applyReceipt(currentReceipt).duplicate,true);
  assert.equal(f.ctx.myHp,0);assert.equal(f.ctx.myDead,true);
  assert(f.ctx._completePlayerAmbulanceRecovery(f.ctx._playerEmergencyPatient,{hospitalId:'main'}));
  assert.equal(f.ctx.myHp,40);assert.equal(f.ctx.myDead,false);return null;
 };
 const first=owner.handle({record:f.record,vehicle:f.record.car,state:{explosions:1}});
 assert.equal(first.targets,1);assert.equal(first.delivered,0);
 assert.equal(firstDelivery.accepted,false,'recovery means the player is currently alive');
 assert.equal(f.state().lifeGeneration,1);assert.equal(f.ctx.myHp,40);assert.equal(callbackCount,1);
 assert.equal(f.ctx._combatState.combat_version,-1);
 const oldReceipt=currentReceipt;
 assert.equal(f.ctx.applyReceipt(oldReceipt).duplicate,true);assert.equal(f.ctx.myHp,40);
 assert.equal(f.ctx.applyReceipt(receipt('unseen-prior-life')).reason,'stale-life');assert.equal(f.ctx.myHp,40);
 assert.equal(owner.handle({record:f.record,vehicle:f.record.car,state:{explosions:1}}).duplicate,true);
 assert.equal(callbackCount,1);assert.equal(owner.noteReset(f.record),true);
 const next=owner.handle({record:f.record,vehicle:f.record.car,state:{explosions:1}});
 assert.equal(next.delivered,1);assert.equal(currentReceipt.lifeGeneration,1);
 assert.notEqual(currentReceipt.id,oldReceipt.id);assert.equal(f.ctx.myHp,0);assert.equal(f.ctx.myDead,true);
 assert.equal(callbackCount,2);assert(f.recover());assert.equal(f.state().lifeGeneration,2);
 assert.equal(f.ctx.myHp,40);assert.equal(f.ctx.applyReceipt(currentReceipt).duplicate,true);
 assert.equal(f.ctx.myHp,40);
});
