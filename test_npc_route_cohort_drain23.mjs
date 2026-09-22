import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const world=fs.readFileSync('world.html','utf8');
const source=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));
const refill='  if(!_npcRouteWorkBatch.size)_npcRouteWorkBatchCount=0; // Reopen a drained cohort in this frame.';
const candidate=source.includes(refill)?source:source.replace('  let head=_npcRouteWorkQueue.keys().next().value;',refill+'\n  let head=_npcRouteWorkQueue.keys().next().value;');
const baseline=candidate.replace(refill,'');

function fixture(code){
 let now=0;
 const box={performance:{now:()=>now},prevT:0,_walkNpcNavigationResolver:()=>{}};
 vm.createContext(box);vm.runInContext(code,box);
 return {box,read:s=>vm.runInContext(s,box),frame(n){now=n*1000/7;box.prevT=n;},work(ms){now+=ms;box._npcFinishRouteWork();},reserve(n){return box._npcReserveRouteWork(now,n);}};
}
function drain(code){
 const f=fixture(code),actors=Array.from({length:12},(_,i)=>({id:'resident_'+i}));
 f.box.actors=actors;f.read('for(const n of actors)_npcRouteWorkQueue.set(n,0)');
 f.frame(1);
 for(let i=0;i<12;i++){const granted=f.reserve(actors[i]);assert.equal(granted,i<7);if(granted)f.work(.6);}
 assert.equal(f.read('_npcRouteWorkBatch.size'),1,'one older waiter carried into next frame');
 f.frame(2);
 assert.equal(f.reserve(actors[8]),false,'newer actor cannot overtake the remaining older waiter');
 assert(f.reserve(actors[7]));f.work(.25);
 const next=f.reserve(actors[9]);if(next)f.work(.25);
 return {next,usedMs:f.read('_npcRouteWorkUsedMs'),grants:f.read('_npcRouteWorkCount')};
}
const before=drain(baseline),after=drain(candidate);
assert.equal(before.next,false,'baseline strands a waiting resident despite free CPU and admission slots');
assert.equal(after.next,true,'draining the old cohort releases the next oldest cohort immediately');

function sustained(code){
 const f=fixture(code),actors=Array.from({length:288},(_,i)=>({id:'resident_'+i,index:i,grants:0,last:0,maxGap:0}));
 f.box.actors=actors;f.read('for(const n of actors)_npcRouteWorkQueue.set(n,0)');
 let total=0,maxCost=0;
 for(let frame=1;frame<=1260;frame++){
  f.frame(frame);let count=0;
  const offset=frame*17%actors.length;
  for(const n of [...actors.slice(offset),...actors.slice(0,offset)]){
   if(!f.reserve(n))continue;
   n.grants++;n.maxGap=Math.max(n.maxGap,frame-n.last);n.last=frame;count++;
   f.work(n.index%3===0?1:.25);
   assert.equal(f.reserve(n),false,'never serve the same owner twice per frame');
  }
  const used=f.read('_npcRouteWorkUsedMs');assert(count<=8);assert(used<5.001);total+=count;maxCost=Math.max(maxCost,used);
 }
 assert(actors.every(n=>n.grants>0),'all continuously requesting residents advance');
 const grants=actors.map(n=>n.grants);
 assert(Math.max(...grants)-Math.min(...grants)<=1,'oldest cohort fairness retained');
 return {meanAdmissions:total/1260,maxCostMs:maxCost,minGrants:Math.min(...grants),maxGrants:Math.max(...grants),resident205:actors[205],maxWaitSeconds:Math.max(...actors.map(n=>Math.max(n.maxGap,1260-n.last)))/7};
}
const sustainedBefore=sustained(baseline),sustainedAfter=sustained(candidate);
assert(sustainedAfter.meanAdmissions>sustainedBefore.meanAdmissions);
assert(sustainedAfter.resident205.grants>sustainedBefore.resident205.grants);
assert(sustainedAfter.maxWaitSeconds<sustainedBefore.maxWaitSeconds);
if(process.argv.includes('--require-fixed'))assert(source.includes(refill),'production includes the tested fix');
console.log(JSON.stringify({before,after,sustainedBefore,sustainedAfter,limits:'Actual production scheduler; deterministic query costs and request order, not a replay of LIVE search frontiers or GPU/FPS.'},null,2));
