import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const helper=fs.readFileSync(new URL('./ambulance_transport.js',import.meta.url),'utf8');
const fn=name=>{const a=world.indexOf(`function ${name}(`);assert(a>=0,name);return world.slice(a,world.indexOf('\nfunction ',a+10));};

function setup(){
  let time=1000;
  const s={console,Math,Number,Infinity,performance:{now:()=>time},NPCS:[],MAP_COLS:100,
    document:{documentElement:{dataset:{}}},AMBULANCE_RESPONSE_SPEED:2,
    AMBULANCE_ROUTE_RETRY_MS:900,AMBULANCE_DEPLOY_PARKING_TOLERANCE:.8,
    AMBULANCE_DEPLOY_MAX_PATIENT_DISTANCE:7,_ambulanceWatchdogCount:0,
    _ambulanceDeliveryCount:0,_ambulanceHospitalRecoveryCount:0,
    _npcPacedSpeed:n=>n/2,_npcReserveRouteWork:()=>true,_npcRouteWorkExpired:()=>false,
    _vehicleRoadPassable:()=>true,_serviceVehicleFootprintClear:()=>true,
    _vehicleBlockedByCar:()=>null,_completePlayerAmbulanceRecovery:()=>assert.fail('not player'),
    _hospitalizeEmpireBoss:()=>assert.fail('not empire'),npcPassable:()=>true,
    _walkNpcNavigationResolver:()=>({blocked:false,depth:0}),
    _walkTrafficNavigationResolver:q=>q.mode==='route'?{status:'ready',points:[{r:q.to.r,c:q.to.c}]}:{clear:true},
    _setVehicleRoute:()=>assert.fail('native route must own ambulance'),
    _npcPathPassable:()=>true,
  };
  vm.createContext(s);vm.runInContext(helper,s);
  for(const name of ['_setNpcRoute','_planNpcRouteTo','_npcAdvanceRoute','_ambulancePatientPosition',
    '_ambulanceNeedsBodyCrew','_ambulanceReadyToDeploy','_setAmbulanceCrewPose'])vm.runInContext(fn(name),s);
  const patient={id:'resident_wounded_identity20',hp:1,max_hp:60,_medicalDowned:true,
    _forcedCrawl:true,r:10,c:14.2,tr:10,tc:14.2,walking:true,walkPhase:3};
  const v={id:'amb_identity20',kind:'ambulance',y:10,x:10,ang:0,homeR:10,homeC:2,
    speed:2,state:'go_to_scene',sceneParkingR:10,sceneParkingC:10,payload:{npc:patient},path:[]};
  s._ensureAmbulanceCrew(v);s._rerouteAmbulance=()=>false;
  return {s,v,patient,advance(ms){time+=ms;return s._ambulanceUpdateBodyCrew(v,ms/1000,time);},now:()=>time};
}

function oneVisibleBody(patient,scene){
  return Number(!patient._carriedByAmbulance)+Number(!!scene.bodyVisible);
}

{
  const {s,v,patient,advance,now}=setup();
  assert(s._ambulanceStartBodyCrew(v,now()));
  assert.equal(v.payload.npc,patient,'transport retains the exact source patient object');
  assert.equal(s._ambulancePatientMovementLocked(patient),true,'loading owns and freezes source movement');
  assert.equal(oneVisibleBody(patient,v._medicalScene),1,'deployment has only the source patient body');

  v._medicalScene.phase='lifting';v._medicalScene.phaseStartedAt=now();
  advance(v._medicalScene.liftMs*.2);
  assert.equal(v._medicalScene.liftProgress,.2);
  assert.equal(v._medicalScene.bodyVisible,false,'stretcher body is hidden before ownership transfer');
  assert.equal(patient._carriedByAmbulance,false,'source remains visible before transfer');
  assert.equal(oneVisibleBody(patient,v._medicalScene),1);

  advance(v._medicalScene.liftMs*.3);
  assert(v._medicalScene.liftProgress>.42);
  assert.equal(v._medicalScene.bodyVisible,true,'stretcher receives body at transfer threshold');
  assert.equal(patient._carriedByAmbulance,true,'source hides in the same update');
  assert.equal(oneVisibleBody(patient,v._medicalScene),1,'ownership handoff never duplicates the body');

  const sourcePosition=[patient.r,patient.c];
  v.x+=3;v.y+=2;advance(20);
  assert.deepEqual([patient.r,patient.c],sourcePosition,'vehicle motion cannot drag the hidden source object independently');
  assert.equal(v.payload.npc,patient);
  s._ambulanceMedicalAbort(v,'vehicle-moved-during-load');
  assert.equal(v.payload.npc,undefined);
  assert.equal(patient.hp,1);assert.equal(patient._medicalDowned,true);
  assert.equal(patient._ambulanceLoading,false);assert.equal(patient._carriedByAmbulance,false);
}

{
  const {s,v,patient,now}=setup();
  const before={id:patient.id,r:patient.r,c:patient.c,hp:patient.hp,downed:patient._medicalDowned};
  assert(s._ambulanceStartBodyCrew(v,now()));
  s._ambulanceMedicalAbort(v,'cancel-before-transfer');
  assert.deepEqual({id:patient.id,r:patient.r,c:patient.c,hp:patient.hp,downed:patient._medicalDowned},before,
    'pre-transfer cancellation preserves identity, position and injury');
}

{
  const {s,v,patient,advance,now}=setup();
  assert(s._ambulanceStartBodyCrew(v,now()));
  v._medicalScene.phase='lifting';v._medicalScene.phaseStartedAt=now();advance(v._medicalScene.liftMs*.5);
  patient.dead=true;patient.hp=0;patient._medicalDowned=false;
  const drop=[v._medicalScene.centerR,v._medicalScene.centerC];
  s._ambulanceMedicalAbort(v,'death-during-loading');
  assert.equal(patient.dead,true);assert.equal(patient.hp,0,'transport cancellation cannot heal a fatal patient');
  assert.deepEqual([patient._deathR,patient._deathC],drop,'dead source identity is restored at the owned stretcher position');
}

assert(world.includes("if(n._medicalDowned){\n      if(typeof _ambulancePatientMovementLocked==='function'&&_ambulancePatientMovementLocked(n))"),
  'actual source crawl branch must stop while ambulance owns loading');
{
  // Execute the production loop branch, not only its textual guard. A patient
  // is frozen throughout transport ownership, then resumes their real crawl
  // when ownership is released, with no healing or identity replacement.
  const {s,patient}=setup(),start=world.indexOf('    if(n._medicalDowned){'),end=world.indexOf('    if(n._medicalCrewVehicleId)',start);
  assert(start>=0&&end>start,'actual medical crawl branch');
  s.player={r:8,c:12};patient._nextDownedBloodAt=Infinity;
  let pathQueries=0;s._npcPathPassable=()=>{pathQueries++;return true;};
  vm.runInContext(`globalThis.stepActualCrawl=function(patient,dt){const now=performance.now();for(const n of [patient]){${world.slice(start,end)}}};`,s);
  for(const flag of ['_ambulanceLoading','_carriedByAmbulance','_ambulanceInTransit']){
    patient[flag]=true;patient.walking=true;
    const before=[patient.r,patient.c,patient.walkPhase,patient.hp];
    s.stepActualCrawl(patient,.1);
    assert.deepEqual([patient.r,patient.c,patient.walkPhase,patient.hp],before,flag+' preserves location, gait and injury');
    assert.equal(patient.walking,false);assert.equal(patient.tr,patient.r);assert.equal(patient.tc,patient.c);
    assert.equal(pathQueries,0,'transport-owned patient never attempts a crawl route');
    patient[flag]=false;
  }
  const before=[patient.r,patient.c,patient.walkPhase];s.stepActualCrawl(patient,.1);
  assert.notDeepEqual([patient.r,patient.c],before.slice(0,2),'released living patient can crawl again');
  assert(patient.walkPhase>before[2]);assert.equal(patient.walking,true);assert.equal(pathQueries,1);
  assert.equal(patient.hp,1);assert.equal(patient._medicalDowned,true);
}
assert(world.includes('patient._ambulanceLoading||patient._carriedByAmbulance'),
  'actual helper branch must cancel against loading and carried patients');
assert(world.includes('x._evacuated||x._carriedByAmbulance||!prisonNpcAllowed(x)'),
  '3D admission hides the same source identity once the stretcher owns it');

console.log('PASS ambulance loading ownership: one body, frozen crawl, helper release, identity-preserving cancel/move/death');
