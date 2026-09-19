import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0);return source.slice(start,source.indexOf('\n}',start)+2);};
const queue=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo('));
function fixture(legacy=false){
 let now=1000,cost=0,throwPass=false;
 const box={Math,Number,Map,Set,Array,performance:{now:()=>now},prevT:1,MAP_COLS:200,
  _walkNpcNavigationResolver:()=>({swept:true,blocked:false}),
  npcPassable:()=>{if(throwPass)throw Error('query failed');now+=.02;cost+=.02;return true;},
  _setNpcRoute:(n,path)=>{n.path=path;return path.length>0;}};
 vm.createContext(box);vm.runInContext(queue+fn('_planNpcRouteTo'),box);
 if(legacy)vm.runInContext(`
  _npcFinishRouteWork=function(){};
  const currentReserve=_npcReserveRouteWork;
  _npcReserveRouteWork=function(now,owner){
    if(prevT===_npcRouteWorkFrame&&_npcRouteWorkDeadline&&performance.now()>=_npcRouteWorkDeadline)return false;
    const previousDeadline=prevT===_npcRouteWorkFrame?_npcRouteWorkDeadline:0;
    const admitted=currentReserve(now,owner);
    if(admitted&&previousDeadline)_npcRouteWorkDeadline=previousDeadline;
    return admitted;
  };`,box);
 return{box,advance:ms=>now+=ms,frame:i=>{now=1000+i*200;box.prevT=i;},fail:()=>{throwPass=true;},get cost(){return cost;},read:code=>vm.runInContext(code,box)};
}
function separatedSearches(legacy){
 const f=fixture(legacy),a={id:'a',r:10.5,c:10.5},b={id:'b',r:20.5,c:20.5};
 assert(f.box._planNpcRouteTo(a,11.5,10.5,f.box.npcPassable,.1,100,'directed'));
 const firstCost=f.cost;f.advance(5);
 f.box._planNpcRouteTo(b,40.5,40.5,f.box.npcPassable,.1,1200,'directed');
 const result={firstCostMs:firstCost,totalRouteCostMs:f.cost,nonRouteGapMs:5,secondExpanded:b._npcDirectedSearch?.qi||0};
 if(!legacy){assert(result.secondExpanded>0);assert(f.cost<=4.15);assert.equal(f.read('_npcRouteWorkStartedAt'),null);}
 return result;
}
const before=separatedSearches(true),after=separatedSearches(false);
assert.equal(before.secondExpanded,0);

// Eight cheap jobs can share a frame, but never a ninth or a second turn for
// the same owner. The oldest batch may run in actual update order next frame.
const cheap=fixture(),owners=Array.from({length:10},(_,i)=>({id:'cheap-'+i}));
for(let i=0;i<8;i++){
 assert(cheap.box._npcReserveRouteWork(0,owners[i]),'cheap job '+i+' receives a slot');
 cheap.advance(.25);cheap.box._npcFinishRouteWork();
}
assert.equal(cheap.read('_npcRouteWorkCount'),8);
assert.equal(cheap.read('_npcRouteWorkUsedMs'),2,'slot limit reached with CPU still available');
assert.equal(cheap.box._npcReserveRouteWork(0,owners[8]),false,'ninth slot rejected');
assert.equal(cheap.box._npcReserveRouteWork(0,owners[9]),false);
cheap.frame(2);assert(cheap.box._npcReserveRouteWork(0,owners[9]),'oldest batch may run in reverse update order');cheap.advance(.25);cheap.box._npcFinishRouteWork();
assert(cheap.box._npcReserveRouteWork(0,owners[8]));cheap.advance(.25);cheap.box._npcFinishRouteWork();
assert.equal(cheap.box._npcReserveRouteWork(0,owners[9]),false,'one grant per owner per frame');

// Intermediate-cost jobs stop at four admissions, before the slot cap.
const medium=fixture();
for(let i=0;i<4;i++){assert(medium.box._npcReserveRouteWork(0,{id:'medium-'+i}));medium.advance(1);medium.box._npcFinishRouteWork();}
assert.equal(medium.read('_npcRouteWorkUsedMs'),4);
assert.equal(medium.read('_npcRouteWorkCount'),4);
assert.equal(medium.box._npcReserveRouteWork(0,{id:'medium-over-budget'}),false,'4 ms CPU gate wins over 8-slot allowance');

// Full slice exhaustion must still reject a second search, including overrun.
const full=fixture(),a={id:'full',r:10.5,c:10.5};
full.box._planNpcRouteTo(a,90.5,90.5,full.box.npcPassable,.1,1200,'directed');
const next={id:'next'};
assert(full.cost>=4);assert.equal(full.box._npcReserveRouteWork(0,next),false);
full.frame(2);assert(full.box._npcReserveRouteWork(0,next));full.box._npcFinishRouteWork();

// An exception must not leave the active clock charging unrelated updates.
const failure=fixture();failure.fail();
assert.throws(()=>failure.box._planNpcRouteTo({id:'fail',r:1,c:1},9,9),/query failed/);
assert.equal(failure.read('_npcRouteWorkStartedAt'),null);

// All production reservation owners close their slice even on early return.
for(const name of ['_planNpcRouteTo','_planNpcEscapeRoute','pickNpcWaypoint','_planPoliceFootRoute','_npcWaterSearchStep']){
 assert.match(fn(name),/finally\s*\{[^}]*_npcFinishRouteWork\(\)/,name);
}
console.log(JSON.stringify({before,after,checks:'shared 4 ms, max 8 slots, cheap-job cap, medium/heavy CPU exhaustion, oldest-cohort fairness, same-owner exclusion, frame reset, exception cleanup and all five production callers',limits:'Actual source with deterministic CPU query cost; not LIVE or a full-scene FPS comparison.'},null,2));
