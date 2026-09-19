import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const helper=fs.readFileSync(new URL('./ambulance_transport.js',import.meta.url),'utf8');
const fn=name=>{const a=source.indexOf(`function ${name}(`);assert(a>=0,name);return source.slice(a,source.indexOf('\nfunction ',a+10));};
export function setup(){
  let time=1000,blocked=false,nativeCalls=0;
  const s={console,Math,Number,Infinity,performance:{now:()=>time},NPCS:[],MAP_COLS:100,
    document:{documentElement:{dataset:{}}},AMBULANCE_RESPONSE_SPEED:2,
    AMBULANCE_ROUTE_RETRY_MS:900,AMBULANCE_DEPLOY_PARKING_TOLERANCE:.8,
    AMBULANCE_DEPLOY_MAX_PATIENT_DISTANCE:7,_ambulanceWatchdogCount:0,
    _ambulanceDeliveryCount:0,_ambulanceHospitalRecoveryCount:0,
    _npcPacedSpeed:n=>n/2,_npcReserveRouteWork:()=>true,_npcRouteWorkExpired:()=>false,
    _vehicleRoadPassable:()=>true,_serviceVehicleFootprintClear:()=>true,
    _vehicleBlockedByCar:()=>null,_completePlayerAmbulanceRecovery:()=>assert.fail('not player'),
    _hospitalizeEmpireBoss:()=>assert.fail('not empire'),npcPassable:()=>!blocked,
    _walkNpcNavigationResolver:()=>({blocked,depth:0}),
    _walkTrafficNavigationResolver:q=>{nativeCalls++;assert.equal(q.carId,'service_amb_test');return q.mode==='route'?
      {status:blocked?'blocked':'ready',points:[{r:q.to.r,c:q.to.c}]}:{clear:!blocked,reason:blocked?'wall':''};},
    _setVehicleRoute:()=>assert.fail('native route must own ambulance'),
    _npcPathPassable:(r,c,rr,cc,pass=s.npcPassable)=>{
      const count=Math.max(1,Math.ceil(Math.hypot(rr-r,cc-c)/.2));
      for(let i=1;i<=count;i++)if(!pass(r+(rr-r)*i/count,c+(cc-c)*i/count))return false;return true;
    },
  };
  vm.createContext(s);vm.runInContext(helper,s);
  for(const name of ['_setNpcRoute','_planNpcRouteTo','_npcAdvanceRoute',
    '_ambulancePatientPosition','_ambulanceNeedsBodyCrew','_ambulanceReadyToDeploy',
    '_setAmbulanceCrewPose','_startAmbulanceBodyCrew','_updateAmbulanceBodyCrew',
    '_retryAmbulanceHospitalRoute','_completeAmbulanceHospitalDelivery','_ambulanceWatchdogAdvance'])vm.runInContext(fn(name),s);
  s._rerouteAmbulance=()=>false;
  const patient={id:'resident_wounded',hp:1,max_hp:60,_medicalDowned:true,r:10,c:14.2};
  const v={id:'amb_test',kind:'ambulance',y:10,x:10,ang:0,homeR:10,homeC:2,
    speed:2,state:'go_to_scene',sceneParkingR:10,sceneParkingC:10,payload:{npc:patient},path:[]};
  s._ensureAmbulanceCrew(v);
  return {s,v,patient,block:b=>blocked=b,calls:()=>nativeCalls,tick:(dt=.05)=>{time+=dt*1000;return s._updateAmbulanceBodyCrew(v,dt,time);},now:()=>time};
}
{
  const {s,v,patient,tick,now}=setup();
  assert.equal(s.NPCS.length,3);assert.equal(s.NPCS[0],v._ambulanceDriver);
  s._ensureAmbulanceCrew(v);assert.equal(s.NPCS.length,3,'stable crew identities');
  assert(s._startAmbulanceBodyCrew(v,now()));
  let loaded=false,phases=new Set();
  for(let i=0;i<1000&&!loaded;i++){loaded=tick();phases.add(v._medicalScene.phase);}
  assert(loaded,'physical round-trip reaches loading');
  for(const p of ['approaching','assessing','lifting','returning','loading','sealing','loaded'])assert(phases.has(p),p);
  assert.equal(patient.hp,1,'pickup does not heal');assert(patient._medicalDowned);
  assert(patient._ambulanceInTransit);assert(v._medicalCrew.every(n=>n._inVehicle));
  const pos=[v.x,v.y];assert.equal(s._completeAmbulanceHospitalDelivery(v,now(),'road-arrival'),false);
  assert.deepEqual([v.x,v.y],pos,'distant delivery never snaps');assert.equal(patient.hp,1);
  s._ambulanceWatchdogAdvance({...v,state:'returning'},now(),'stuck');assert.equal(patient.hp,1,'watchdog cannot heal');
  v.y=v.homeR;v.x=v.homeC;v._ambulanceReturnMoveObserved=true;
  assert.equal(s._completeAmbulanceHospitalDelivery(v,now(),'road-arrival'),true);
  assert.equal(patient.hp,35);assert.equal(patient._medicalDowned,false);
  assert.equal(v._medicalCrew.length,2,'delivery retains injured/dead-capable crew objects');
}
{
  const {s,v,patient,tick,block,now}=setup();s._startAmbulanceBodyCrew(v,now());
  for(let i=0;i<16;i++)tick();block(true);const start=[v._medicalScene.centerR,v._medicalScene.centerC];
  for(let i=0;i<1200;i++)tick();
  assert.deepEqual([v._medicalScene.centerR,v._medicalScene.centerC],start);
  assert.equal(v._medicalScene.phase,'approaching','time cannot override blocked path');
  assert.equal(patient._ambulanceInTransit,undefined);assert.equal(patient.hp,1);
}
{
  const {s,v,patient,tick,now}=setup();patient.dead=true;patient.hp=0;patient._medicalDowned=false;
  s._startAmbulanceBodyCrew(v,now());let loaded=false;
  for(let i=0;i<1000&&!loaded;i++)loaded=tick();assert(loaded);
  v.y=v.homeR;v.x=v.homeC;v._ambulanceReturnMoveObserved=true;
  s._completeAmbulanceHospitalDelivery(v,now());
  assert.equal(patient.hp,0);assert.equal(patient.dead,true,'hospital does not heal a corpse into a living NPC');
}
{
  const {s,v,patient,tick,now}=setup();s._startAmbulanceBodyCrew(v,now());
  while(v._medicalScene.phase!=='returning')tick();
  v._medicalCrew[0].dead=true;v._medicalCrew[0].hp=0;const deadPoint=[v._medicalCrew[0].r,v._medicalCrew[0].c];
  tick();assert.equal(v.state,'ambulance_disabled');assert.equal(patient.hp,1);
  assert.equal(patient._carriedByAmbulance,false);assert.deepEqual([v._medicalCrew[0].r,v._medicalCrew[0].c],deadPoint);
  assert.equal(patient._ambulanceInTransit,undefined,'a dead bearer cannot finish loading');
}
{
  const {s,v,block}=setup();v.path=[{r:10,c:20}];v.finalTarget={y:10,x:20};
  s._ambulanceVehicleStep(v,.05);assert(v.x>10);
  block(true);const stop=[v.x,v.y,v.ang];s._ambulanceVehicleStep(v,.05);assert.deepEqual([v.x,v.y,v.ang],stop,'native wall/car/water blocks');
  block(false);v._ambulanceDriver.dead=true;v._ambulanceDriver.hp=0;
  for(let i=0;i<100;i++)s._ambulanceVehicleStep(v,.05);
  assert.deepEqual([v.x,v.y,v.ang],stop,'dead driver cannot drive');
  v._ambulanceDriver.dead=false;v._ambulanceDriver.hp=1;v._ambulanceDriver._medicalDowned=true;
  assert.equal(s._ambulanceCanDrive(v),false,'HP1 downed driver is alive but cannot drive');
}
{
  const {s,v,tick}=setup();let queries=0,ready=false;
  s.HOSPITAL_R=80;s.HOSPITAL_C=80;s.AMBULANCE_FLEET_SIZE=6;
  s._walkTrafficNavigationResolver=q=>{
    if(q.mode==='hospital')return ready?{hospitalId:'native-hospital',door:{r:40,c:42},bay:{r:40,c:40,angle:0}}:null;
    queries++;return {clear:true};
  };
  assert.equal(s._ambulanceNativeBays().length,0,'unloaded hospital creates no legacy/door fallback');
  ready=true;
  s._ambulanceNativeBays();s._ambulanceNativeSceneParking(v,10,14);s._ambulanceNativeBays();
  assert(queries<=4,'shared parking budget caps repeated dispatch requests in one frame');
  for(let i=0;i<20;i++){tick();s._ambulanceNativeBays();}
  const bays=s._ambulanceNativeBays();assert.equal(bays.length,6);
  for(let i=0;i<bays.length;i++)for(let j=i+1;j<bays.length;j++)assert(Math.hypot(bays[i].r-bays[j].r,bays[i].c-bays[j].c)>=2.3);
  assert(bays.every(b=>b.hospitalId==='native-hospital'));
  assert(s._ambulanceNativeHospital(v));assert.equal(v.homeR,40);
  v.homeC=42.6;assert(s._ambulanceNativeHospital(v));assert.equal(v.homeC,42.6,'return keeps the assigned depot space');
}
// CPU update cost only: loaded scene FPS/draw calls must be measured by root.
{
  const {s,v}=setup();const rounds=[];
  for(let j=0;j<60;j++){const t=performance.now();for(let i=0;i<100;i++){
    v.x=10;v.y=10;v.speed=2;v.path=[{r:10,c:20}];v.pathIdx=0;s._ambulanceVehicleStep(v,.016);
  }if(j>=10)rounds.push((performance.now()-t)/100);}
  rounds.sort((a,b)=>a-b);console.log('ambulance helper CPU ms/update p50/p95',rounds[25].toFixed(4),rounds[47].toFixed(4));
}
console.log('PASS ambulance transport: actual source crew, blocked approach, arrival-only loading/delivery, crew casualty and native driving gates');

{
 const {s,v,block}=setup();v.path=[];v.finalTarget={y:v.y,x:v.x};v._ambulanceRouteGoal={r:v.y,c:v.x,angle:Math.PI/2};
 const before=v.ang;block(true);assert.equal(s._ambulanceVehicleStep(v,.05),false);assert.equal(v.ang,before,'blocked final turn cannot cut through a vehicle/wall');
 block(false);let arrived=false;for(let i=0;i<50&&!arrived;i++)arrived=s._ambulanceVehicleStep(v,.05);
 assert(arrived);assert(Math.abs(v.ang-Math.PI/2)<.035,'discharge requires the actual parking orientation');
}
