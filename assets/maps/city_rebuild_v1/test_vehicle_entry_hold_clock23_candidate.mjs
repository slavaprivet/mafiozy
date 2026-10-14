import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {createVehicleEntryHoldClock} from './vehicle_entry_hold_clock23_candidate.mjs';
import {advanceEntryHold,HOLD_SECONDS,EXIT_HOLD_SECONDS,TRANSITION_SECONDS} from './car_entry.mjs';
import {canControlVehicle,vehicleSeat} from './vehicle_seats.mjs';
import {EXIT} from './car_exit.mjs';

const walk=readFileSync(new URL('./walk_preview.mjs',import.meta.url),'utf8');
const actual=walk.slice(walk.indexOf('function updateCarInteraction('),walk.indexOf('function setWalkPromptHidden('));
function replaceOne(text,from,to){assert.equal(text.split(from).length,2,from);return text.replace(from,to);}
let candidate=replaceOne(actual,"advanceEntryHold(entryHeld,pressed&&entryArmed,sourceVehicleState.phase==='driving',dt,EXIT_HOLD_SECONDS)",
 "entryHoldClock.advance(pressed&&entryArmed,sourceVehicleState.phase==='driving',performance.now()/1000,EXIT_HOLD_SECONDS)");
candidate=replaceOne(candidate,"advanceEntryHold(entryHeld,pressed&&entryArmed,entryAvailable&&(occupiedSeat||pointerHeld||nearestInteraction({fresh:true})?.kind==='car'),dt,holdDuration)",
 "entryHoldClock.advance(pressed&&entryArmed,entryAvailable&&(occupiedSeat||pointerHeld||nearestInteraction({fresh:true})?.kind==='car'),performance.now()/1000,holdDuration)");

function fixture(kind,code=candidate){
 let now=0,admissions=0,eligible=true;
 const listeners={},docListeners={},clock=createVehicleEntryHoldClock();
 const ctx={entryHoldClock:clock,sourceVehicleActive:()=>kind==='source-exit',sourceVehicleAccess:{poll(){}},sourceVehicleState:{phase:'driving'},
  performance:{now:()=>now*1000},carDriveDiagnosticsAt:Infinity,car:{profile:{label:'Fixture'}},hero:{},transition:null,
  occupiedSeat:kind==='local-exit'?'front_left':null,keys:new Set(),buildingKeyConsumed:false,pointerHeld:false,entryArmed:true,entryHeld:0,
  entrySpot:()=>eligible?{label:'Fixture door',sourceOwned:kind==='source-entry'}:null,nearestInteraction:()=>({kind:'car'}),setCarInteractionText(){},
  carState:{speed:0},carDamage:null,exitNoticeUntil:0,currentWeapon:{id:'none'},EXIT,canControlVehicle,vehicleSeat,
  advanceEntryHold,HOLD_SECONDS,EXIT_HOLD_SECONDS,TRANSITION_SECONDS,
  beginCarTransition(){admissions++;ctx.entryArmed=false;ctx.entryHeld=0;ctx.keys.clear();ctx.pointerHeld=false;},
  requestSourceVehicle(action){assert.equal(action,'exit');admissions++;ctx.entryArmed=false;ctx.entryHeld=0;ctx.keys.clear();},
  window:{},artistInput:{cancel(){}},jump:null,animationQaMoveUntil:0,animationQaMoveDirection:null,animationQaJumpPending:false,buildingQaMove:null,releaseWeapon(){},npcPopulation:{markPoseInterrupted(){}},
  document:{hidden:false,addEventListener:(name,fn)=>docListeners[name]=fn},addEventListener:(name,fn)=>listeners[name]=fn};
 vm.createContext(ctx);vm.runInContext(code+';globalThis.step=updateCarInteraction;',ctx);
 const releaseLine=walk.split('\n').find(line=>line.startsWith('const releaseControls='));
 assert(releaseLine);
 const candidateRelease=replaceOne(releaseLine,'const releaseControls=()=>{','const releaseControls=()=>{entryHoldClock.reset();');
 vm.runInContext(candidateRelease,ctx);
 return {ctx,clock,listeners,docListeners,get admissions(){return admissions;},set eligible(value){eligible=value;},step(at,dt=.04){now=at;ctx.step(dt);},press(){ctx.keys.add('KeyE');},release(){ctx.keys.delete('KeyE');clock.reset();}};
}

const rows=[];
for(const kind of ['local-entry','source-entry','local-exit','source-exit'])for(const hz of [7,15,30,60]){
 const f=fixture(kind);f.press();let firedAt=null;
 for(let frame=0;frame<hz*2;frame++){const t=frame/hz;f.step(t,Math.min(1/hz,.04));if(t<.3-1e-8)assert.equal(f.admissions,0,'never grant time from before press');if(f.admissions){firedAt=t;break;}}
 assert.ok(firedAt>=.3-1e-8&&firedAt<.3+1/hz+1e-8);
 rows.push({kind,hz,firedAt});
}

for(const kind of ['local-entry','source-entry','local-exit','source-exit']){
 // Short tap, release/repress within one render interval, and lost eligibility.
 const tap=fixture(kind);tap.press();tap.step(0);tap.step(.2);assert.equal(tap.admissions,0);tap.release();tap.press();tap.step(.21);tap.step(.4);assert.equal(tap.admissions,0);tap.step(.52);assert.equal(tap.admissions,1);
 if(kind.endsWith('entry')){const f=fixture(kind);f.press();f.step(0);f.step(.2);f.eligible=false;f.step(.25);f.eligible=true;f.step(.3);f.step(.5);assert.equal(f.admissions,0);f.step(.61);assert.equal(f.admissions,1);}
 for(const interruptedBy of ['blur','hidden']){
  const f=fixture(kind);f.press();f.step(0);f.step(.2);
  if(interruptedBy==='blur')f.listeners.blur();else{f.ctx.document.hidden=true;f.docListeners.visibilitychange();f.ctx.document.hidden=false;}
  assert.equal(f.ctx.keys.size,0);assert.equal(f.ctx.pointerHeld,false);assert.equal(f.ctx.entryHeld,0);
  f.step(20);assert.equal(f.admissions,0);f.press();f.step(20.1);f.step(20.3);assert.equal(f.admissions,0);f.step(20.41);assert.equal(f.admissions,1);
 }
 // Missing focus events still cannot turn a pre-sleep held key into admission.
 const f=fixture(kind);f.press();f.step(0);f.step(.2);f.step(20);for(let i=1;i<=20;i++)f.step(20+i*.05);assert.equal(f.admissions,0);f.release();f.step(21.05);f.press();f.step(21.1);f.step(21.3);assert.equal(f.admissions,0);f.step(21.41);assert.equal(f.admissions,1);
}

// Exercise existing release callbacks with candidate clock reset added.
{
 const f=fixture('local-entry'),keyRegistry=walk.slice(walk.indexOf('const keys=new Set();'),walk.indexOf('\n',walk.indexOf('const keys=new Set();')));
 const candidateKeys=replaceOne(keyRegistry,"if(e.code==='KeyE'){buildingKeyConsumed=false;","if(e.code==='KeyE'){entryHoldClock.reset();buildingKeyConsumed=false;");
 const keyListeners={},ctx={entryHoldClock:f.clock,addEventListener:(name,fn)=>keyListeners[name]=fn,window:{},buildingKeyConsumed:true};
 vm.createContext(ctx);vm.runInContext(candidateKeys,ctx);
 f.clock.advance(true,true,0);f.clock.advance(true,true,.2);keyListeners.keyup({code:'KeyE'});
 assert.equal(f.clock.advance(true,true,.21).elapsed,0,'actual keyup resets timestamp even before next render');
 let button;const buttonLine=walk.split('\n').find(line=>line.includes("button.id='car'"));
 const candidateButton=replaceOne(buttonLine,'()=>{pointerHeld=false}','()=>{pointerHeld=false;entryHoldClock.reset();}');
 const pointerCtx={entryHoldClock:f.clock,pointerHeld:false,document:{createElement:()=>button={}},$:()=>({append(){}})};
 vm.runInNewContext(candidateButton,pointerCtx);
 f.clock.advance(true,true,.4);button.onpointercancel();assert.equal(f.clock.advance(true,true,.41).elapsed,0);
}

// The candidate must not alter bounded animation or moving-exit dt.
for(const line of actual.split('\n').filter(line=>line.includes('updateMovingExit(dt)')||line.includes('t.elapsed+=dt')))assert.ok(candidate.includes(line));
assert.ok(walk.includes('const dt=Math.min(rawDt,.04)'));
const moving=fixture('local-entry');let observedDt=null;moving.ctx.transition={exiting:true};moving.ctx.updateMovingExit=dt=>{observedDt=dt;moving.ctx.transition=null;};moving.step(50,.04);assert.equal(observedDt,.04);
for(const time of [NaN,Infinity,-1]){const clock=createVehicleEntryHoldClock();clock.advance(true,true,0);clock.advance(true,true,.2);assert.equal(clock.advance(true,true,time).interrupted,true);assert.equal(clock.advance(true,true,.5).ready,false);clock.advance(false,true,.51);assert.equal(clock.advance(true,true,.52).elapsed,0);}
const baseline=fixture('local-entry',actual);baseline.press();let before=null;for(let i=0;i<20;i++){baseline.step(i/7,.04);if(baseline.admissions){before=i/7;break;}}
console.log(JSON.stringify({status:'CANDIDATE PASS',cases:rows,baseline7HzSecondsAfterFirstObservation:before,candidate7HzSecondsAfterFirstObservation:rows[0].firedAt,productionChanged:false},null,2));
