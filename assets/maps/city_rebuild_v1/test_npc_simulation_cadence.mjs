import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('npc_simulation_cadence_source.js',import.meta.url),'utf8');
const box={player:{r:0,c:0},native:true,_walkRendererActive:()=>box.native};vm.createContext(box);vm.runInContext(source,box);
const step=box._npcSimulationDelta,make=i=>({id:'resident_'+i,r:70+i%20,c:60+i%17,hp:60});
const n=make(1);let elapsed=0,moved=0,ticks=0;
for(let frame=1;frame<=600;frame++){const dt=1/60;elapsed+=dt;const delta=step(n,dt,frame*1000/60);if(delta){ticks++;moved+=delta*4.6;}}
assert(ticks<45&&ticks>30);assert(Math.abs(moved+(n._npcSimCarry||0)*4.6-elapsed*4.6)<1e-8,'Deferred movement time is preserved');
n.r=n.c=0;const carry=n._npcSimCarry||0;assert.equal(step(n,.016,10016),carry+.016,'Approaching player catches up and resumes full updates');assert.equal(n._npcSimCarry,0);
for(const [key,value] of Object.entries({dead:true,hp:0,_said:true,_empireBoss:true,_medicalDowned:true,_civilianTrip:true,_ambientTrafficDriver:true,_corpsePhoneCall:{},_hijackReaction:{},snitching:true,_hostile:true,_routeSearchPending:true,_npcWanderSearch:{},_playerConversationOpen:true,panicUntil:10000})){
 const actor=make(2);actor[key]=value;actor._npcSimCarry=.05;actor._npcSimDue=10000;assert.equal(step(actor,.02,500),.02,key+' cannot apply peaceful deferred time to a new urgent action');
}
box.native=false;assert.equal(step(make(3),.02,500),.02,'Legacy behavior preserved');box.native=true;
for(const state of [{_residentNativeVisit:{}},{_civilianActivity:{phase:'approach'}},{_waterEscaping:true},{_inVehicle:true},{_ambulanceInTransit:true}]){const actor=Object.assign(make(4),state);actor._npcSimDue=10000;assert.equal(step(actor,.02,500),.02,'Physical visit, meeting approach and transport use full cadence');}
const actors=Array.from({length:384},(_,i)=>make(i)),updates=[];let full=0,deferred=0;
for(let frame=1;frame<=120;frame++){let count=0;for(const actor of actors)if(step(actor,1/60,frame*1000/60)){count++;full++;}else deferred++;updates.push(count);}
assert(Math.max(...updates)<80,'Far residents stagger rather than all updating together');assert(full<384*120*.1);
const durations=[];for(let i=0;i<100;i++){const at=performance.now();for(const actor of actors)step(actor,1/60,2500+i*1000/60);durations.push(performance.now()-at);}durations.sort((a,b)=>a-b);
console.log(JSON.stringify({pass:true,residents:384,full,deferred,maxUpdatesPerFrame:Math.max(...updates),cadenceLoopMs:{p50:durations[50],p95:durations[95]},limits:'CPU scheduling only, not loaded-scene FPS or full AI cost'}));
