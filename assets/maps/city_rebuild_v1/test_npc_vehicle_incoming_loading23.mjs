import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createNpcNativePerception} from './npc_native_perception.mjs';

// Actual deployed World admission/perception and the early Walk occupancy
// callback. No source transform, proposal, vendor checkout, browser or GPU.
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const walk=fs.readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8').replace(/\r\n/g,'\n');
function section(source,start,end){
 const a=source.indexOf(start),b=source.indexOf(end,a+start.length);
 assert(a>=0&&b>a,`Missing production source section: ${start}`);return source.slice(a,b);
}
function sourceFunction(name){
 const start=world.indexOf('function '+name+'(');assert(start>=0,name);
 const tail=world.slice(start),end=tail.search(/\n(?:function |let |const |var )/);
 assert(end>0,`Missing function boundary: ${name}`);return tail.slice(0,end);
}
const incomingSource=section(world,'let _walkNpcVehicleIncomingResolver=null;','let _walkCoverResolver=null;');
const registerSource=section(world,'registerWalkVehicleOccupancyResolver(resolver)','\n');
const earlyRegistration=section(walk,'npcBridge?.registerWalkVehicleOccupancyResolver?.(','let npcSupportCache=');
const sourceVehicleActive=section(walk,'const sourceVehicleActive=','\n');
const perceptionSource=['_getWalkVehicleState','_policePerceptionActor','_policeCanSeePoint','_npcPerceptionHeight','_npcPerceptionTargetHeight','_npcCanSeePoint','_localHostileCanResolveHit'].map(sourceFunction).join('\n');

function fixture({online=false,resolver='missing',installOccupancy=true}={}){
 const native=createNpcNativePerception({bodiesAt:()=>[],getVehicles:()=>[]});
 const cop={id:'registered_patrol',x:0,y:0,ang:0,hp:100,alive:true};
 const events=new Map(),ctx={
  cityCops:[cop],player:{r:0,c:2,ang:0},myDead:false,myDrivingCarId:null,myIsPassenger:false,
  questCars:new Map(),_threeVehicleEntrySequence:null,_walkVehicleSeatId:'front_left',_walkVehicleLastAction:null,
  _LOCAL_PREVIEW:!online,_serverAuthoritativeAmmo:online,_worldDirectCombatDemo:false,
  _walkRendererActive:()=>true,_walkNpcPerceptionResolver:native.query,
  _effectivePlayerStance:()=> 'stand',_policeWorldLineClear:()=>true,
  occupiedSeat:null,transition:null,sourceVehicleState:null,
  worldHealthFrame:{snapshot:{dead:false}},heroCustodyActive:false,
  // NPC loading is deliberately incomplete; the real top-level callback must
  // already work and must not depend on updateNpcPopulation's readiness guard.
  npcPopulation:null,addEventListener:(name,callback)=>events.set(name,callback),
 };
 vm.createContext(ctx);
 vm.runInContext(incomingSource+'\n'+perceptionSource+'\n'+sourceVehicleActive+
  '\nglobalThis.npcBridge={'+registerSource+'};',ctx);
 if(installOccupancy)vm.runInContext(earlyRegistration,ctx);
 if(resolver==='throws')vm.runInContext("_walkNpcVehicleIncomingResolver=()=>{throw Error('renderer loading');};",ctx);
 return {
  ctx,cop,native,events,
  setResolver(value){ctx.resolver=value;vm.runInContext('_walkNpcVehicleIncomingResolver=resolver;',ctx);},
  visible:()=>ctx._policeCanSeePoint(cop,ctx.player.r,ctx.player.c,8),
  admission:()=>ctx._walkPoliceVehicleIncoming({phase:'prepare',cop}),
  register:value=>ctx.npcBridge.registerWalkVehicleOccupancyResolver(value),
  sourceDrive(){ctx.questCars.set('42',{id:'42',x:2,y:0,ang:0});ctx.myDrivingCarId='42';},
 };
}
function expectFoot(f){
 const queries=f.native.diagnostics().queries;assert.equal(f.visible(),true);
 assert.equal(f.native.diagnostics().queries,queries+1,'foot visibility reaches ordinary native geometry');
 assert.equal(f.admission(),null,'foot shot uses its existing source admission');
}
function expectClosed(f,reason){
 const queries=f.native.diagnostics().queries;assert.equal(f.visible(),false);
 assert.equal(f.native.diagnostics().queries,queries,'occupied loading cannot fall back to the coarse car ray');
 const result=f.admission();assert.equal(result.handled,true);assert.equal(result.ready,false);
 assert.equal(result.visible,false);assert.equal(result.reason,reason);
}

for(const online of [false,true])for(const resolver of ['missing','throws']){
 const label=`${online?'authenticated':'local'} / ${resolver}`;
 const reason=resolver==='missing'?'renderer-unavailable':'renderer-error';
 test(`on-foot perception survives missing or failed car geometry: ${label}`,()=>{
  const f=fixture({online,resolver});expectFoot(f);
  assert.equal(f.ctx._localHostileCanResolveHit(),!online,'online does not gain local HP authority');
  assert.equal(f.ctx._policeCanSeePoint(f.cop,0,3,8),true,'unrelated event point remains visible');
 });
 test(`actual local occupied/entry/exit closure remains closed during NPC loading: ${label}`,()=>{
  const f=fixture({online,resolver});assert.equal(f.ctx.npcPopulation,null);
  f.ctx.occupiedSeat='front_left';expectClosed(f,reason);
  f.ctx.occupiedSeat=null;
  for(const phase of ['enter','exit']){f.ctx.transition={phase};expectClosed(f,reason);}
  f.ctx.transition=null;expectFoot(f);
  f.ctx.sourceVehicleState={active:true};expectClosed(f,reason);
  f.ctx.sourceVehicleState=null;expectFoot(f);
 });
 test(`actual source drive and transitions override an explicit foot callback: ${label}`,()=>{
  const f=fixture({online,resolver});f.register(()=>false);f.sourceDrive();expectClosed(f,reason);
  f.ctx.myDrivingCarId=null;
  for(const phase of ['enter','exit']){f.ctx._threeVehicleEntrySequence={phase,seatId:'front_left'};expectClosed(f,reason);}
  f.ctx._threeVehicleEntrySequence=null;expectFoot(f);
 });
}

test('before Walk callback installation, foot falls back but actual source vehicle remains closed',()=>{
 const f=fixture({installOccupancy:false});expectFoot(f);f.sourceDrive();expectClosed(f,'renderer-unavailable');
 f.ctx.myDrivingCarId=null;f.ctx._threeVehicleEntrySequence={phase:'enter'};expectClosed(f,'renderer-unavailable');
});

test('only explicit false permits foot fallback; invalid values, throws and failed source state stay closed',()=>{
 const f=fixture();
 for(const value of [true,undefined,null,0,1,'',{},[]]){f.register(()=>value);expectClosed(f,'renderer-unavailable');}
 f.register(()=>{throw Error('occupancy unavailable');});expectClosed(f,'renderer-unavailable');
 f.register(()=>false);expectFoot(f);
 f.ctx.questCars={get(){throw Error('source state unavailable');}};f.ctx.myDrivingCarId='42';expectClosed(f,'renderer-unavailable');
});

test('invalid registration cannot clear occupied ownership; actual pagehide callback unregisters it',()=>{
 const f=fixture();f.ctx.occupiedSeat='front_right';assert.equal(f.register(false),false);expectClosed(f,'renderer-unavailable');
 assert.equal(typeof f.events.get('pagehide'),'function');f.events.get('pagehide')();expectFoot(f);
 f.sourceDrive();expectClosed(f,'renderer-unavailable');
});

test('a working geometry resolver keeps its own authority and exact source identity',()=>{
 const f=fixture();let received;
 f.register(()=>{throw Error('must not be queried while precise resolver works');});
 f.setResolver(request=>{received=request;return null;});expectFoot(f);
 assert.equal(received.sourceRef,f.cop);assert.equal(received.sourceId,'city_cop:'+f.cop.id);
 assert.equal(received.localAllowed,true);
 f.ctx._LOCAL_PREVIEW=false;f.ctx._serverAuthoritativeAmmo=true;expectFoot(f);assert.equal(received.localAllowed,false);
 f.setResolver(()=>({handled:true,ready:false,visible:false,reason:'physical-cover'}));expectClosed(f,'physical-cover');
});

test('unregistered and dead sources remain rejected independently of the foot loading fallback',()=>{
 const f=fixture();assert.equal(f.ctx._walkPoliceVehicleIncoming({phase:'prepare',cop:{...f.cop}}).reason,'unregistered-source');
 f.cop.hp=0;assert.equal(f.admission().reason,'actor-life');
});

test('production occupancy registration precedes asynchronous NPC startup and has lifecycle cleanup',()=>{
 const registrationAt=walk.indexOf('npcBridge?.registerWalkVehicleOccupancyResolver?.(');
 assert(registrationAt>walk.indexOf('npcBridge=window.Mafiozi3DBridge||null'));
 assert(registrationAt<walk.indexOf('async function initNpcPopulation(){'));
 assert(earlyRegistration.includes("addEventListener('pagehide'"));
 const f=fixture();assert.equal(f.ctx.npcPopulation,null);f.ctx.transition={phase:'enter'};expectClosed(f,'renderer-unavailable');
});
