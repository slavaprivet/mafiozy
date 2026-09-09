import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const s=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
function fn(n){const a=s.indexOf(`function ${n}(`);return s.slice(a,s.indexOf('\n}',a)+2);}
let clock=1000,queries=0;
const env={performance:{now:()=>clock},prevT:1000,_walkNpcNavigationResolver:()=>{},MAP_COLS:200,
 npcPassable:()=>{queries++;clock+=.02;return true;},_setNpcRoute:(n,path)=>{n.path=path;return path.length>0;}};
vm.createContext(env);const start=s.indexOf('let _npcRouteWorkFrame='),end=s.indexOf('function _planNpcRouteTo(',start);
vm.runInContext(s.slice(start,end)+fn('_planNpcRouteTo'),env);
const actors=Array.from({length:200},(_,i)=>({id:'resident_'+i,r:10.5,c:10.5}));
for(const n of actors)env._planNpcRouteTo(n,180,180);
assert.ok(clock<=1004.1,`shared frame search window exceeded: ${clock-1000}ms`);
assert.ok(queries<220,'200 residents cannot each launch a full 18k-node search');
assert.ok(actors[0]._npcDirectedSearch?.qi>0,'unfinished search frontier is retained');
assert.equal(actors[0]._routeSearchPending,true);
assert.equal(actors[0].path,undefined,'unfinished route cannot masquerade as arrival');
const before=queries;clock+=500;env._planNpcRouteTo(actors[0],180,180);
assert.equal(queries,before,'expensive search cannot reset budget within same prevT frame');
env.prevT=clock;env._planNpcRouteTo(actors[1],180,180);assert.ok(queries>before,'next world frame serves oldest waiting actor');
env._walkNpcNavigationResolver=null;const n={r:10.5,c:10.5};assert.ok(env._planNpcRouteTo(n,12.5,10.5));
assert.deepEqual(Array.from(n.path,p=>p.r),[11.5,12.5],'legacy collision-only mode unchanged');
console.log(JSON.stringify({pass:true,fakeNativeCostMs:.02,requestsSameFrame:200,firstFrameQueryBound:220,timeWindowMs:4,retainedFrontier:true,stableFrame:true}));
