import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

// Exercise the actual shared production scheduler. A reversed queue arises
// when activity/police passes submit requests before the ordinary NPC loop.
const world=fs.readFileSync('world.html','utf8');
const source=world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo('));
function run({strict=false,frames=120,mixed=false,permuted=false}={}){
  let now=0;
  const box={performance:{now:()=>now},prevT:0,_walkNpcNavigationResolver:()=>{}};
  vm.createContext(box);
  vm.runInContext(strict?source.replace('!_npcRouteWorkBatch.has(owner)','head!==owner'):source,box);
  const actors=Array.from({length:180},(_,i)=>({id:'resident_'+i,index:i,grants:0,last:0,maxGap:0}));
  box.actors=actors;
  vm.runInContext('for(const actor of [...actors].reverse())_npcRouteWorkQueue.set(actor,0);',box);
  let admitted=0,totalCost=0,maxFrameCost=0;
  for(let frame=1;frame<=frames;frame++){
    now=frame*33;box.prevT=frame;const start=now;let count=0;
    const offset=permuted?(frame*17)%actors.length:0;
    const order=permuted?[...actors.slice(offset),...actors.slice(0,offset)]:actors;
    for(const actor of order){
      if(!box._npcReserveRouteWork(now,actor))continue;
      count++;admitted++;actor.grants++;actor.maxGap=Math.max(actor.maxGap,frame-actor.last);actor.last=frame;
      now+=mixed?(actor.index%3===0?1:.25):.2;
      box._npcFinishRouteWork();
      assert.equal(box._npcReserveRouteWork(now,actor),false,'one grant per owner in a frame');
    }
    const cost=now-start;totalCost+=cost;maxFrameCost=Math.max(maxFrameCost,cost);
    assert(count<=8,'eight admission cap');
    assert(cost<5.001,'4 ms work budget plus at most one indivisible 1 ms job');
    if(!strict&&!mixed)assert.equal(count,8,'reverse/permuted update order does not waste cheap-job slots');
  }
  const grants=actors.map(a=>a.grants),maxGap=Math.max(...actors.map(a=>Math.max(a.maxGap,frames-a.last)));
  if(!strict){assert(Math.min(...grants)>0,'every continuously waiting owner is served');assert(maxGap<=90,'oldest actor cannot be repeatedly bypassed');}
  return{admitted,meanAdmissions:admitted/frames,meanCostMs:totalCost/frames,maxFrameCostMs:maxFrameCost,minGrants:Math.min(...grants),maxGrants:Math.max(...grants),maxWaitFrames:maxGap};
}
const strict=run({strict:true}),batched=run(),permuted=run({permuted:true}),mixed=run({mixed:true,permuted:true,frames:600});
assert.equal(strict.meanAdmissions,1);
assert.equal(batched.meanAdmissions,8);
assert(batched.maxGrants-batched.minGrants<=1,'persistent oldest cohort preserves long-term fairness');
assert(mixed.maxGrants-mixed.minGrants<=1,'CPU-heavy jobs cannot replenish the cohort ahead of older waiters');
console.log(JSON.stringify({strict,batched,permuted,mixed,limits:'Actual-source scheduler with deterministic work costs; not LIVE movement or full-scene FPS.'},null,2));
