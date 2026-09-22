import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createVehicleEntryHoldClock} from './vehicle_entry_hold_clock.mjs';
import {HOLD_SECONDS,EXIT_HOLD_SECONDS,TRANSITION_SECONDS} from './car_entry.mjs';
import {canControlVehicle,vehicleSeat} from './vehicle_seats.mjs';
import {EXIT} from './car_exit.mjs';

// Execute current production bodies, without substituting the hold implementation.
// External admission side effects are counted; source server success is separate.
const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const lines=walk.split(/\r?\n/),lineWith=part=>{
 const found=lines.filter(line=>line.includes(part));assert.equal(found.length,1,part);return found[0];
};
const start=walk.indexOf('function updateCarInteraction('),end=walk.indexOf('function setWalkPromptHidden(');
assert(start>=0&&end>start);
const actual=walk.slice(start,end);
assert.equal((actual.match(/entryHoldClock\.advance\(/g)||[]).length,2);
assert(!actual.includes('advanceEntryHold('));
assert.match(walk,/import \{createVehicleEntryHoldClock\} from '\.\/vehicle_entry_hold_clock\.mjs';/);
const init=lineWith('const entryHoldClock=createVehicleEntryHoldClock(');
const keysLine=lineWith('const keys=new Set();');
const releaseLine=lineWith('const releaseControls=()=>{');
const buttonLine=lineWith("button.id='car'");
const qaLine=lineWith('onEntryHold(pressed)');

function fixture(kind,{qa=false}={}){
 let now=0,admissions=0,eligible=true,button=null;
 const listeners={},docListeners={};
 const add=(registry,name,fn)=>(registry[name]??=[]).push(fn);
 const ctx={createVehicleEntryHoldClock,sourceVehicleActive:()=>kind==='source-exit',sourceVehicleAccess:{poll(){}},sourceVehicleState:{phase:'driving'},
  performance:{now:()=>now*1000},carDriveDiagnosticsAt:Infinity,carQa:qa?{stats:()=>null}:null,car:{profile:{label:'Fixture'},setDoorById(){}},hero:{},transition:null,
  occupiedSeat:kind==='local-exit'?'front_left':null,buildingKeyConsumed:false,pointerHeld:false,entryArmed:true,entryHeld:0,
  entrySpot:()=>eligible?{label:'Fixture door',sourceOwned:kind==='source-entry'}:null,nearestInteraction:()=>({kind:'car'}),setCarInteractionText(){},
  carState:{speed:0,x:0,z:0,yaw:0},carDamage:null,exitNoticeUntil:0,currentWeapon:{id:'none'},EXIT,canControlVehicle,vehicleSeat,HOLD_SECONDS,EXIT_HOLD_SECONDS,TRANSITION_SECONDS,
  beginCarTransition(){admissions++;ctx.entryArmed=false;ctx.entryHeld=0;ctx.keys.clear();ctx.pointerHeld=false;},
  requestSourceVehicle(action){assert.equal(action,'exit');admissions++;ctx.entryArmed=false;ctx.entryHeld=0;ctx.keys.clear();},
  window:{},artistInput:{cancel(){}},jump:null,animationQaMoveUntil:0,animationQaMoveDirection:null,animationQaJumpPending:false,buildingQaMove:null,releaseWeapon(){},npcPopulation:{markPoseInterrupted(){}},
  document:{hidden:false,addEventListener:(name,fn)=>add(docListeners,name,fn),createElement:()=>button={setPointerCapture(){}}},
  $:()=>({append(){}}),addEventListener:(name,fn)=>add(listeners,name,fn)};
 vm.createContext(ctx);
 vm.runInContext(init+'\n'+keysLine+'\n'+releaseLine+'\n'+buttonLine+'\n'+actual+
  '\n;globalThis.keys=keys;globalThis.clock=entryHoldClock;globalThis.step=updateCarInteraction;globalThis.releaseControls=releaseControls;globalThis.qa={'+qaLine+'};',ctx);
 return {ctx,listeners,docListeners,get button(){return button;},get admissions(){return admissions;},set eligible(value){eligible=value;},
  emit(name,event={}){for(const fn of listeners[name]||[])fn(event);},
  at(at){now=at;},
  step(at,dt=.04){now=at;ctx.step(dt);},
  press(input='keyboard'){if(input==='keyboard')ctx.keys.add('KeyE');else if(input==='qa')ctx.qa.onEntryHold(true);else button.onpointerdown({button:0,pointerId:1,preventDefault(){}});},
  release(input='keyboard'){if(input==='keyboard')this.emit('keyup',{code:'KeyE'});else if(input==='qa')ctx.qa.onEntryHold(false);else button.onpointerup();}
 };
}

let cases=0;const rows=[];
const kinds=['local-entry','source-entry','local-exit','source-exit'];
for(const kind of kinds)for(const hz of [7,15,30,60]){
 const f=fixture(kind);f.press();let firedAt=null;
 for(let frame=0;frame<hz*2;frame++){
  const t=frame/hz;f.step(t,Math.min(1/hz,.04));
  if(t<.3-1e-8)assert.equal(f.admissions,0,'no credit before the observed press');
  if(f.admissions){firedAt=t;break;}
 }
 assert.ok(firedAt>=.3-1e-8&&firedAt<.3+1/hz+1e-8);
 rows.push({kind,hz,firedAt});cases++;
}

for(const kind of kinds){
 // Admission disarms E. A real release must rearm synchronously, even when
 // release+repress happens between frames and no frame observes !pressed.
 for(const input of kind==='source-exit'?['keyboard']:['keyboard','pointer','qa']){
  const f=fixture(kind);f.press(input);f.step(0);f.step(.31);assert.equal(f.admissions,1);assert.equal(f.ctx.entryArmed,false);
  f.release(input);assert.equal(f.ctx.entryArmed,true,'release immediately rearms '+kind+'/'+input);
  f.press(input);f.step(.4);f.step(.6);assert.equal(f.admissions,1);f.step(.71);assert.equal(f.admissions,2);cases++;
 }
 // A new press after an idle/focus gap must start at zero, not latch as stale.
 for(const afterFocus of [false,true]){
  const f=fixture(kind,{qa:true});
  if(afterFocus){f.press();f.step(0);f.step(.2);f.emit('blur');}
  f.step(1);f.press();f.step(2);assert.equal(f.admissions,0);assert.equal(f.ctx.entryHeld,0);
  assert.equal(f.ctx.clock.getTrace().at(-1).interrupted,false);
  f.step(2.2);assert.equal(f.admissions,0);f.step(2.31);assert.equal(f.admissions,1);cases++;
 }
 for(const input of kind==='source-exit'?['keyboard']:['keyboard','pointer','qa']){
  const f=fixture(kind);f.press(input);f.step(0);f.step(.2);assert.equal(f.admissions,0);
  // Actual release callbacks must catch release+repress between render frames.
  f.release(input);f.press(input);f.step(.21);f.step(.4);assert.equal(f.admissions,0);
  f.step(.52);assert.equal(f.admissions,1);cases++;
 }
 if(kind.endsWith('entry')){
  const f=fixture(kind);f.press();f.step(0);f.step(.2);f.eligible=false;f.step(.25);
  f.eligible=true;f.step(.3);f.step(.5);assert.equal(f.admissions,0);f.step(.61);assert.equal(f.admissions,1);cases++;
 }
 for(const interruption of ['blur','hidden','releaseControls']){
  const f=fixture(kind);f.press();f.step(0);f.step(.2);
  if(interruption==='blur')f.emit('blur');
  else if(interruption==='hidden'){f.ctx.document.hidden=true;for(const fn of f.docListeners.visibilitychange)fn();f.ctx.document.hidden=false;}
  else f.ctx.releaseControls();
  assert.equal(f.ctx.keys.size,0);assert.equal(f.ctx.pointerHeld,false);assert.equal(f.ctx.entryHeld,0);
  f.step(20);assert.equal(f.admissions,0);f.press();f.step(20.1);f.step(20.3);assert.equal(f.admissions,0);f.step(20.41);assert.equal(f.admissions,1);cases++;
 }
 // A long render gap must fail closed even if the browser missed focus events.
 const f=fixture(kind);f.press();f.step(0);f.step(.2);f.step(20);
 for(let i=1;i<=20;i++)f.step(20+i*.05);assert.equal(f.admissions,0);
 f.release();f.press();f.step(21.1);f.step(21.3);assert.equal(f.admissions,0);f.step(21.41);assert.equal(f.admissions,1);cases++;
}
for(const release of ['pointercancel','qa-release','releaseControls','blur','hidden']){
 const f=fixture('local-entry');f.press('qa');f.step(0);f.step(.31);assert.equal(f.ctx.entryArmed,false);
 if(release==='pointercancel')f.button.onpointercancel();
 else if(release==='qa-release')f.ctx.qa.onRelease();
 else if(release==='releaseControls')f.ctx.releaseControls();
 else if(release==='blur')f.emit('blur');
 else{f.ctx.document.hidden=true;for(const fn of f.docListeners.visibilitychange)fn();f.ctx.document.hidden=false;}
 assert.equal(f.ctx.entryArmed,true,release+' immediately rearms');
 f.press('qa');f.step(.4);f.step(.71);assert.equal(f.admissions,2);cases++;
}
for(const kind of kinds){
 // 4 FPS timing is measured from first eligible observation, not event time.
 // A .7s QA gesture can miss .3s at phase .24/.49/.74; do not fabricate credit.
 const input=kind==='source-exit'?'keyboard':'qa';
 const short=fixture(kind);short.press(input);short.at(.2);short.release(input);short.step(.24);short.step(.49);assert.equal(short.admissions,0);cases++;
 const offset=fixture(kind);offset.press(input);offset.step(.24,.04);offset.step(.49,.04);assert.equal(offset.admissions,0);
 offset.at(.7);offset.release(input);offset.step(.74,.04);assert.equal(offset.admissions,0);cases++;
 const held=fixture(kind);held.press(input);held.step(.24,.04);held.step(.49,.04);assert.equal(held.admissions,0);held.step(.74,.04);assert.equal(held.admissions,1);cases++;
 const aligned=fixture(kind);aligned.press(input);aligned.step(0,.04);aligned.step(.25,.04);assert.equal(aligned.admissions,0);aligned.step(.5,.04);assert.equal(aligned.admissions,1);cases++;
}
// The current .5s safety threshold is deliberately unchanged pending LIVE trace.
// This captures the known false-suspension risk of a .58s foreground render gap.
for(const kind of kinds){
 const f=fixture(kind,{qa:true});f.press();f.step(0);f.step(.2);f.step(.78);
 const sample=f.ctx.clock.getTrace().at(-1);assert.equal(sample.channel,kind);
 assert.equal(sample.interrupted,true);assert.equal(sample.latched,true);assert.ok(Math.abs(sample.gap-.58)<1e-9);
 f.step(.9);f.step(1.2);assert.equal(f.admissions,0);f.release();f.press();f.step(1.21);f.step(1.52);assert.equal(f.admissions,1);cases++;
}
for(const release of ['pointerup','pointercancel','qa-release']){
 const f=fixture('local-entry');f.press('pointer');f.step(0);f.step(.2);
 if(release==='qa-release')f.ctx.qa.onRelease();else f.button['on'+release]();
 assert.equal(f.ctx.pointerHeld,false);f.press('pointer');f.step(.21);f.step(.4);assert.equal(f.admissions,0);f.step(.52);assert.equal(f.admissions,1);cases++;
}
{
 const f=fixture('source-exit');f.ctx.sourceVehicleState.phase='exit';f.press();f.step(0);f.step(.2);f.step(.4);
 assert.equal(f.admissions,0);f.ctx.sourceVehicleState.phase='driving';f.step(.41);f.step(.61);assert.equal(f.admissions,0);f.step(.72);assert.equal(f.admissions,1);cases++;
}

// Transition motion keeps bounded animation dt despite a much larger wall clock.
assert.ok(walk.includes('const dt=Math.min(rawDt,.04)'));
{
 const f=fixture('local-entry');let observedDt=null;f.ctx.transition={exiting:true};
 f.ctx.updateMovingExit=dt=>{observedDt=dt;f.ctx.transition=null;};f.step(50,.04);assert.equal(observedDt,.04);cases++;
}
{
 const f=fixture('local-entry');const position={x:0,y:0,z:0};
 const t={elapsed:0,seatId:'front_left',doorId:'front_left',from:{clone:()=>({lerp:()=>position})},outside:position};
 f.ctx.transition=t;f.ctx.hero.object={position:{set(){}},rotation:{y:0}};
 f.ctx.vehicleEntryPoint=()=>({x:0,y:0,z:0,yaw:0,pose:{done:false,door:.2}});f.ctx.groundHeight=()=>0;f.ctx.poseVehicleOccupant=()=>{};
 f.step(50,.04);assert.equal(t.elapsed,.04);cases++;
}
for(const time of [NaN,Infinity,-1]){
 const clock=createVehicleEntryHoldClock();clock.advance(true,true,0);clock.advance(true,true,.2);
 assert.equal(clock.advance(true,true,time).interrupted,true);assert.equal(clock.advance(true,true,.5).ready,false);
 clock.advance(false,true,.51);assert.equal(clock.advance(true,true,.52).elapsed,0);cases++;
}
{
 const clock=createVehicleEntryHoldClock(),first=clock.advance(true,true,0);
 assert.equal(clock.advance(true,true,.3),first,'reuse one result object');assert.equal(first.ready,true);
 assert.equal(clock.advance(true,true,.4).ready,false,'successful hold cannot repeat without release');cases++;
}
{
 const clock=createVehicleEntryHoldClock();clock.advance(true,true,0);clock.advance(true,true,.3);clock.reset();
 assert.equal(clock.getTrace().length,0,'normal gameplay allocates no trace rows');cases++;
}
{
 const clock=createVehicleEntryHoldClock({traceEnabled:()=>true});
 for(let i=0;i<=35;i++)clock.advance(true,true,i/10,10,'local-entry');
 assert.equal(clock.getTrace().length,4,'stable held QA samples are limited to 1Hz');
 clock.reset('blur',3.6);assert.equal(clock.getTrace().at(-1).reason,'blur');assert.equal(clock.getTrace().at(-1).pressed,false);
 for(let i=0;i<20;i++){clock.advance(true,true,4+i,10,'local-entry');clock.reset('keyup',4+i+.1);}
 assert.equal(clock.getTrace().length,16,'QA ring cannot grow beyond 16 observations');
 assert.ok(clock.getTrace().every(row=>typeof row.pressed==='boolean'&&typeof row.eligible==='boolean'));cases++;
}
{
 const f=fixture('local-entry',{qa:true});f.ctx.document.body={dataset:{}};f.ctx.fleet={activeId:'fixture'};f.ctx.lastDoorSide=1;
 f.ctx.car.wheels=[{wheel:{rotation:{x:0}}}];f.ctx.car.object={position:{y:0}};f.ctx.carDriveDiagnosticsAt=-Infinity;
 f.press();f.step(1);const first=JSON.parse(f.ctx.document.body.dataset.carDrive);
 assert.equal(first.entryHoldTrace.length,1);assert.equal(first.entryHoldTrace[0].channel,'local-entry');
 f.release();f.step(1.2);const released=JSON.parse(f.ctx.document.body.dataset.carDrive);
 assert.equal(released.entryHoldTrace.at(-1).reason,'keyup');assert.equal(released.entryHoldTrace.at(-1).pressed,false);
 f.ctx.carQa=null;f.step(1.4);assert.equal('entryHoldTrace' in JSON.parse(f.ctx.document.body.dataset.carDrive),false);cases++;
}
console.log(JSON.stringify({status:'PASS',cases,actualProductionBodies:true,rows,animationStep:.04,liveRequired:true}));
