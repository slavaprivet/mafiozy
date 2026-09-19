import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const world=fs.readFileSync('world.html','utf8'),helper=fs.readFileSync('assets/maps/city_rebuild_v1/npc_city_population_source.js','utf8');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0,name);let p=world.indexOf('{',start),d=1;for(p++;d;p++){if(world[p]==='{')d++;if(world[p]==='}')d--;}return world.slice(start,p);};
const timingStart=world.indexOf('  let dt = (t - prevT) / 1000;'),timingEnd=world.indexOf('if (dt > 0.1) dt = 0.1;',timingStart)+'if (dt > 0.1) dt = 0.1;'.length,timing=world.slice(timingStart,timingEnd);assert(timing.includes('if (dt > 0.1) dt = 0.1;'));
function run(fps,distant=false,civilianElapsedCandidate=false){
 let clock=1000;const start=80,n={id:'resident_dt_regression',r:start,c:80,tr:500,tc:80,speed:10,hp:100,maxHp:100,walkPhase:0,_routineSpeedK:1,_npcSimDue:1000};
 const b={Math,Number,Object,Map,Set,NPCS:[n],player:{r:distant?0:start,c:distant?0:80},performance:{now:()=>clock},_walkRendererActive:()=>true,npcPassable:()=>true,_npcRouteWalkBlocked:()=>false,_walkNpcNavigationResolver:q=>q.mode==='sweep'?{swept:true,blocked:false}:{blocked:false,depth:0,surface:'land'}};b.npcPassableForSnitch=b.npcPassable;
 vm.createContext(b);vm.runInContext('let prevT=1000;const NPC_HERO_PACE=Object.freeze({walk:1.8/4.1,run:7.8/4.1});const _npcSimulationStats={full:0,distant:0,deferred:0};',b);
 for(const name of ['_npcPacedSpeed','_npcEffectiveSpeed','_npcBodyPassable','_npcPathPassable','_npcSimulationDelta'])vm.runInContext(fn(name),b);vm.runInContext(helper,b);vm.runInContext('globalThis.frameDelta=t=>{'+timing+'return dt;}',b);
 let updates=0;for(let i=1;i<=fps*20;i++){clock=1000+i*1000/fps;const clamped=b.frameDelta(clock),dt=b._npcSimulationDelta(n,civilianElapsedCandidate?1/fps:clamped,clock);if(dt){assert(b._npcRoutineStep(n,dt,b.npcPassable));updates++;}}
 const metres=(n.r-start)*4.1;return{fps,distant,metres,metresPerSecond:metres/20,sourceSteps:updates,unconsumedCadenceSeconds:n._npcSimCarry||0};
}
const current=[],candidate=[];for(const distant of [false,true])for(const fps of [5,10,20]){current.push(run(fps,distant));candidate.push(run(fps,distant,true));}
for(const r of current){const expected=1.8*Math.min(1,r.fps*.1);assert(Math.abs(r.metresPerSecond-expected)<.025,'actual source speed follows clamp loss');}
for(const r of candidate)assert(Math.abs(r.metresPerSecond-1.8)<.025,'same actual cadence/movement retains real speed when given elapsed');
const observedElapsed=.2049,predictedSpeed=1.8*.1/observedElapsed;assert(Math.abs(predictedSpeed-.878)<.002);
console.log(JSON.stringify({current,candidateElapsedOnly:candidate,hypotheticalFramePrediction:{snapshotIntervalNotFrameDt:observedElapsed,configuredMps:1.8,ifThisWereFrameDtMps:predictedSpeed,reportedMps:.878,provesLiveCause:false},scope:'Actual frame dt snippet + civilian cadence + effective speed + physical routine step, no renderer/snapshot involved. This diagnostic compares original capped input with a raw-input control; it does not measure LIVE frame timing.'},null,2));
