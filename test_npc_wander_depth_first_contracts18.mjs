import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {depthFirstWanderCandidate18} from './npc_wander_depth_first_candidate18.mjs';
const source=fs.readFileSync('world.html','utf8'),realPick=sourceFunction(source,'pickNpcWaypoint');
const applied=realPick.includes('if(resolver)queue.splice(search.qi+1,0,node);else queue.push(node);');
const candidate=applied?realPick:depthFirstWanderCandidate18(realPick);
function fixture(cost=.001){
 let now=1000;const b={Math,Number,Map,Set,NPCS:[],MAP_COLS:200,prevT:0,performance:{now:()=>now},_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 b._walkNpcNavigationResolver=()=>({surface:'land'});b.npcWaypointOk=(n,r,c)=>{now+=cost;return r>10&&r<190&&c>10&&c<190;};b._npcPathPassable=(fr,fc,r,c,pass)=>pass(r,c);
 vm.createContext(b);vm.runInContext(source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo(')),b);for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(sourceFunction(source,name),b);vm.runInContext(candidate,b);
 return{b,frame(){now+=50;b.prevT++;},now:()=>now};
}
const f=fixture(),dirs={north:0,south:0,east:0,west:0},routes=new Map();
for(let pass=0;pass<2;pass++)for(let i=0;i<256;i++){
 const n={id:'resident_'+i,r:100.5,c:100.5,hp:60};f.b.NPCS.length=0;f.b.NPCS.push(n);let ready=false;
 for(let frame=0;frame<80&&!ready;frame++){f.frame();ready=f.b.pickNpcWaypoint(n);}assert(ready);assert(n._route.length>=8&&n._route.length<=18);assert.equal(new Set(n._route.map(p=>p.r+','+p.c)).size,n._route.length,'no published waypoint loops');
 const end=n._route.at(-1),dr=end.r-n.r,dc=end.c-n.c;assert(Math.hypot(dr,dc)>=6,'one target is still a full-length outing');
 const key=Math.abs(dr)>=Math.abs(dc)?dr<0?'north':'south':dc<0?'west':'east';
 if(pass===0){dirs[key]++;routes.set(n.id,JSON.stringify(n._route));}else assert.equal(JSON.stringify(n._route),routes.get(n.id),'actor and origin produce stable expansion/target');
}
assert(Object.values(dirs).every(v=>v>=32&&v<=96),'open-space first-target directions have no common cardinal bias');
const slow=fixture(2),n={id:'slow',r:100.5,c:100.5,hp:60};slow.b.NPCS.push(n);slow.frame();slow.b.pickNpcWaypoint(n);const state=n._npcWanderSearch;assert(state);const order=JSON.stringify(state.wanderDirs);slow.frame();slow.b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,state);assert.equal(JSON.stringify(state.wanderDirs),order,'order retained across slices');
n._allowBeach=true;slow.frame();slow.b.pickNpcWaypoint(n);assert.notEqual(n._npcWanderSearch,state);n.panicUntil=slow.now()+1000;slow.frame();slow.b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null);n.panicUntil=0;n.dead=true;slow.frame();slow.b.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null);
console.log(JSON.stringify({status:'PASS',identicalRepeatActors:256,directions:dirs,minDepth:8,minNetSourceDistance:6,retainedOrder:true,interrupts:true},null,2));

const occupied=fixture(),a={id:'reserved-a',r:100.5,c:100.5,hp:60},other={id:'reserved-b',r:100.5,c:100.5,hp:60};occupied.b.NPCS.push(a,other);
for(const n of [a,other]){for(let frame=0;frame<100&&!n._route?.length;frame++){occupied.frame();occupied.b.pickNpcWaypoint(n);}assert(n._route?.length);}
assert.notEqual(a._routeGoalR+','+a._routeGoalC,other._routeGoalR+','+other._routeGoalC,'occupied goal remains exclusive');
console.log('PASS retained depth-first candidate: parent paths have no loops, depth limit18 retained, goals exclusive');

