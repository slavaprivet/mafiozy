import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replace(/\r\n/g,'\n');
const fixed=source.slice(source.indexOf('function _planNpcRouteTo('),source.indexOf('function _planNpcEscapeRoute('));
const legacy=fixed.replace(/      if\(native&&kind==='building_entry'\)\{[\s\S]*?\n      \}\n/,'');assert.notEqual(legacy,fixed);
// Already inflated car corner: the real departure point and first cell centre
// are clear, but their connecting edge cuts through the parked car.
const pass=(r,c)=>r>0&&r<10&&c>0&&c<10&&!(r>=2.7&&r<=3.2&&c>=4.2&&c<=4.8);
function setup(code){
 const box={MAP_COLS:20,performance,_walkNpcNavigationResolver:()=>{},_npcReserveRouteWork:()=>true,_npcRouteWorkExpired:()=>false,_setNpcRoute:(n,path)=>{n._route=path;return !!path.length},npcPassable:pass};vm.createContext(box);vm.runInContext(code,box);return box;
}
const edgeClear=(a,b)=>{const count=Math.ceil(Math.hypot(a.r-b.r,a.c-b.c)/.025);for(let i=0;i<=count;i++)if(!pass(a.r+(b.r-a.r)*i/count,a.c+(b.c-a.c)*i/count))return false;return true;};
const old=setup(legacy),current=setup(fixed),initial={r:2.5,c:4.1};
for(const [box,expected]of [[old,false],[current,true]]){
 const n={...initial};assert(box._planNpcRouteTo(n,6.5,4.5,pass,.1,1000,'building_entry'));let previous=initial,clear=true;
 for(const point of n._route){clear=clear&&edgeClear(previous,point);previous=point;}
 assert.equal(clear,expected,expected?'current actual route has a clear detour':'old route reproduces blocked first edge');
 assert.deepEqual([n.r,n.c],[initial.r,initial.c],'planning cannot move citizen');
}
// The existing per-frame budget still defers and resumes the same search.
let calls=0;current._npcRouteWorkExpired=()=>++calls>2;const resumed={...initial};current._planNpcRouteTo(resumed,6.5,4.5,pass,.1,1000,'building_entry');assert(resumed._routeSearchPending);const search=resumed._npcDirectedSearch;assert(search.qi>0);current._npcRouteWorkExpired=()=>false;assert(current._planNpcRouteTo(resumed,6.5,4.5,pass,.1,1000,'building_entry'));assert(!resumed._routeSearchRestarts);
const report={};for(const [label,box]of [['before',old],['after',current]]){const costs=[];for(let i=0;i<150;i++){const n={...initial},start=performance.now();box._planNpcRouteTo(n,6.5,4.5,pass,.1,1000,'building_entry');costs.push(performance.now()-start);}costs.sort((a,b)=>a-b);report[label]={p50:costs[75],p95:costs[142]};}
console.log(JSON.stringify({pass:true,case:'actual-origin and native visit edges; no body radius doubling, no movement, bounded continuation',cpuMs:report,limits:'small CPU route case, not scene FPS'}));
