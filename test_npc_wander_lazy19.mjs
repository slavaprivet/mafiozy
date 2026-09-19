import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {historicalEagerWander19} from './npc_wander_lazy_compare19.mjs';
const world=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const start=world.indexOf('function '+name+'(');return world.slice(start,world.indexOf('\n}',start)+2)};
const actual=fn('pickNpcWaypoint'),eager=historicalEagerWander19(actual);
function fixture(code,{edgeQuota=Infinity,clear=()=>true,sweep=()=>true,native=true}={}){
 let checks=0,sweeps=0,sliceSweeps=0,backtracks=0,visited=new Set();
 const b={Math,Number,Map,Set,NPCS:[],MAP_COLS:200,performance:{now:()=>1000},_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false,_npcReserveRouteWork:()=>true,_npcFinishRouteWork:()=>{},_npcRouteWorkExpired:()=>sliceSweeps>=edgeQuota,npcWaypointOk:(n,r,c)=>{checks++;return clear(r,c)},_clearNpcRoute:n=>{n._route=null},_setNpcRoute:(n,path)=>{n._route=path;n._routeGoalR=path.at(-1).r;n._routeGoalC=path.at(-1).c;return true}};
 b._walkNpcNavigationResolver=native?q=>{if(q.mode==='sweep'){sweeps++;sliceSweeps++;return{swept:true,blocked:!sweep(q.from,q.to)}}return{surface:'land'}}:null;
 b._npcPathPassable=(fr,fc,r,c,pass)=>{for(let i=1;i<=Math.ceil(Math.hypot(r-fr,c-fc)/.14);i++){const t=i/Math.ceil(Math.hypot(r-fr,c-fc)/.14);if(!pass(fr+(r-fr)*t,fc+(c-fc)*t))return false;}return sweep({r:fr,c:fc},{r,c});};
 vm.createContext(b);vm.runInContext(code,b);
 return{b,get checks(){return checks},get sweeps(){return sweeps},get backtracks(){return backtracks},step(n){sliceSweeps=0;const ready=b.pickNpcWaypoint(n),s=n._npcWanderSearch;if(s){for(const x of s.nodes.values())if(x.nextDirection>1&&visited.has(x.key))backtracks++;visited=new Set(s.nodes.keys());assert.equal(new Set(s.candidates.map(p=>p.key)).size,s.candidates.length);}return ready;}};
}
function run(code,options={},id='resident_123'){
 const f=fixture(code,options),n={r:100.5,c:100.5,hp:60,id};f.b.NPCS.push(n);let frames=0;
 while(!n._route&&frames++<2000)f.step(n);
 assert(n._route?.length>=8);assert(n._route.length<=18);const end=n._route.at(-1);assert(Math.hypot(end.r-n.r,end.c-n.c)>=6);
 assert.equal(new Set(n._route.map(p=>p.r+','+p.c)).size,n._route.length);
 let previous=n;for(const point of n._route){assert((options.sweep||(()=>true))(previous,point));previous=point;}
 return{f,n,frames,path:JSON.stringify(n._route),checks:f.checks,sweeps:f.sweeps};
}
const before=run(eager),after=run(actual),sliced=run(actual,{edgeQuota:1});
assert(after.sweeps<=before.sweeps/2);assert(after.checks<=before.checks/2);assert.equal(after.path,sliced.path,'each-edge yield preserves eventual route');
// A cross corridor deliberately makes each arm dead-end before minDepth8.
// The planner must backtrack and turn around the room, without revisiting a node.
const clear=(r,c)=>r>90&&r<111&&c>90&&c<111&&!(r>101&&r<105&&c>99&&c<103);
const obstacle=run(actual,{clear,edgeQuota:1}),obstacleWhole=run(actual,{clear});
assert.equal(obstacle.path,obstacleWhole.path);assert(obstacle.f.backtracks>0,'retained parent is revisited with its remaining directions');
// Thin continuous blocker can be missed by finite point samples: sweep stays mandatory.
const sweep=(a,b)=>!((a.c<100.73&&b.c>=100.73||b.c<100.73&&a.c>=100.73)&&Math.max(a.r,b.r)>95&&Math.min(a.r,b.r)<106);
run(actual,{sweep,edgeQuota:1});
const directions={north:0,south:0,east:0,west:0};
for(let i=0;i<256;i++){const one=run(actual,{},'resident_'+i),repeat=run(actual,{edgeQuota:1},'resident_'+i);assert.equal(one.path,repeat.path);const end=one.n._route.at(-1),dr=end.r-one.n.r,dc=end.c-one.n.c;directions[Math.abs(dr)>=Math.abs(dc)?dr<0?'north':'south':dc<0?'west':'east']++;}
assert(Object.values(directions).every(v=>v>=32&&v<=96));
// Legacy 2D still uses its preceding BFS, including exact goal with stable RNG.
for(const code of [eager,actual]){const f=fixture(code,{native:false}),n={r:100.5,c:100.5,hp:60,id:'legacy'};const stable=Object.create(Math);stable.random=()=>.25;f.b.Math=stable;f.b.NPCS.push(n);f.step(n);if(code===eager)globalThis.legacyPath=JSON.stringify(n._route);else assert.equal(JSON.stringify(n._route),globalThis.legacyPath);}
const interrupted=fixture(actual,{edgeQuota:1}),n={r:100.5,c:100.5,hp:60,id:'panic'};interrupted.b.NPCS.push(n);interrupted.step(n);assert(n._npcWanderSearch);n.panicUntil=2000;interrupted.step(n);assert.equal(n._npcWanderSearch,null);
console.log(JSON.stringify({pass:true,open:{before:{sweeps:before.sweeps,pointCalls:before.checks},after:{sweeps:after.sweeps,pointCalls:after.checks}},slicedFrames:sliced.frames,backtracks:obstacle.f.backtracks,directions,limits:'Source algorithm contracts/query counts; not native geometry CPU or scene FPS.'},null,2));
