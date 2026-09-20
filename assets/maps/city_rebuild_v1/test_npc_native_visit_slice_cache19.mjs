import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';

const source=fs.readFileSync(new URL('./npc_native_directed_route_source.js',import.meta.url),'utf8');
// Reconstruct the pre-memo predicate calls while retaining the actual planner.
const baseline=source.replace(/ \/\/ BEGIN invocation body cache[\s\S]*? \/\/ END invocation body cache\r?\n/,'').replace(/\bslicePass\(/g,'passFn(');
assert.notEqual(baseline,source);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
assert(world.includes('<script src="assets/maps/city_rebuild_v1/npc_native_directed_route_source.js"></script>'));
assert(!world.includes('function _npcPlanNativeVisitRoute('),'helper is external, with no inline mirror');

function context(code){
 const box={MAP_COLS:200,_walkNpcNavigationResolver:()=>({swept:false}),_npcRouteWorkExpired:()=>false,
  _setNpcRoute:(n,path)=>{n._route=path;return true;}};
 vm.createContext(box);vm.runInContext(code,box);return box;
}
function movingObstacle(code){
 const box=context(code),npc={r:10.5,c:10.5};let yieldNow=false,resumed=false,startCalls=0,blockedReads=0;
 box._npcRouteWorkExpired=()=>yieldNow;
 const pass=(r,c)=>{
  if(r===10.5&&c===10.5){startCalls++;if(!resumed)yieldNow=true;else{blockedReads++;return false;}}
  return r>8&&r<13&&c>8&&c<13;
 };
 assert.equal(box._npcPlanNativeVisitRoute(npc,10.5,10.6,pass,.8,1200,'building_entry'),false);
 assert.equal(npc._routeSearchPending,true);assert(npc._npcDirectedSearch);
 const before=startCalls;resumed=true;yieldNow=false;npc._routeSearchPending=false;
 const ok=box._npcPlanNativeVisitRoute(npc,10.5,10.6,pass,.8,1200,'building_entry');
 assert(startCalls>before&&blockedReads>0,'resumed search reads changed vehicle/door admission at previously cached point');
 assert(!npc._routeSearchRestarts,'callback identity and frontier are retained');
 return JSON.parse(JSON.stringify({ok,path:npc._route,expanded:npc._routeSearchExpanded}));
}
assert.deepEqual(movingObstacle(source),movingObstacle(baseline));
for(const code of [baseline,source]){
 const box=context(code),error=new Error('physical predicate failed');let calls=0;
 assert.throws(()=>box._npcPlanNativeVisitRoute({r:10.5,c:10.5},10.5,10.6,()=>{calls++;throw error;},.8,1200,'building_entry'),e=>e===error);
 assert.equal(calls,1,'same thrown callback error escapes without swallowing or retries');
}

const f=await createCivilianNativeFixture(),box=f.box,door=box._residentBuildingDoors()[0],starts=[];
for(let radius=8;radius<=32&&starts.length<48;radius+=3)for(let i=0;i<16&&starts.length<48;i++){
 const angle=i*Math.PI/8,r=Math.floor(door.r+Math.sin(angle)*radius)+.5,c=Math.floor(door.c+Math.cos(angle)*radius)+.5;
 if(box._npcBodyPassable(r,c,box.npcPassableForSnitch))starts.push({r,c});
}
assert.equal(starts.length,48);
// Remove the clock deadline only in this CPU comparison to make each exact
// route/frontier deterministic. Production keeps its shared deadline unchanged.
vm.runInContext('_npcRouteWorkExpired=()=>false',box);
let expected;const reports=[];
for(let trial=0;trial<3;trial++)for(const label of trial%2?['memo','baseline']:['baseline','memo']){
 vm.runInContext(label==='memo'?source:baseline,box);
 let passCalls=0;const paths=[],times=[];
 const pass=(r,c)=>{passCalls++;return box._npcBodyPassable(r,c,box.npcPassableForSnitch);};
 for(const start of starts){
  f.nextFrame(.125);const npc={...start},at=performance.now();
  const ok=box._npcPlanNativeVisitRoute(npc,door.r,door.c,pass,.8,1200,'building_entry');
  times.push(performance.now()-at);assert(ok,'actual hospital destination remains reachable');
  paths.push(JSON.parse(JSON.stringify({path:npc._route,expanded:npc._routeSearchExpanded,visited:npc._routeSearchVisited})));
  if(!expected){let from=start;for(const to of npc._route){assert(box._npcPathPassable(from.r,from.c,to.r,to.c,box.npcPassableForSnitch));from=to;}}
 }
 if(expected)assert.deepEqual(paths,expected,'all 48 paths, expansions and visited counts exactly match');else expected=paths;
 times.sort((a,b)=>a-b);reports.push({trial,label,passCalls,totalMs:times.reduce((a,b)=>a+b,0),p50:times[24],p95:times[45]});
}
assert(reports.find(r=>r.label==='memo').passCalls<reports.find(r=>r.label==='baseline').passCalls*.9);
console.log(JSON.stringify({passed:true,checks:['48 actual paths and expansion parity','fresh dynamic obstacle on resume','callback error identity','external helper loading'],reports,limits:'CPU actual geometry; not LIVE FPS or source scheduling latency'}));
