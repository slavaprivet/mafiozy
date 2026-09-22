import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const world=fs.readFileSync('world.html','utf8');
const fn=name=>{const at=world.indexOf('function '+name+'(');assert(at>=0,name);const line=world.slice(at,world.indexOf('\n',at));return line.trimEnd().endsWith('}')?line:world.slice(at,world.indexOf('\n}',at)+2);};
const start=world.indexOf('    if(n._empireCrew&&!n._hostile&&!n._fighting&&!n._fightingMelee&&!(n.panicUntil>now)){'),end=world.indexOf('    if(n._empireBoss&&n._empireAction',start);
assert(start>0&&end>start);
const helper=`function _cancelEmpireEscortRoute(n){
 const request=n._empirePendingRoute;
 if(request&&request.kind!=='empire_escort')return false;
 const owned=request?.kind==='empire_escort'||n._routeSearchKind==='empire_escort';
 if(!owned)return false;
 n._empirePendingRoute=null;n._empireRouteQueued=false;
 if(n._routeSearchKind==='empire_escort')_cancelNpcDirectedSearch(n);
 for(let i=_empireRoutePlanQueue.length-1;i>=0;i--)if(_empireRoutePlanQueue[i]===n)_empireRoutePlanQueue.splice(i,1);
 return true;
}`;
const original=world.slice(start,end).replaceAll('_cancelEmpireEscortRoute(n);','');
const candidate=original.replace('_clearNpcRoute(n);const step=', '_cancelEmpireEscortRoute(n);_clearNpcRoute(n);const step=').replace("if(moved==='arrived'||distance<.8){_clearNpcRoute(n);", "if(moved==='arrived'||distance<.8){_cancelEmpireEscortRoute(n);_clearNpcRoute(n);");
assert.notEqual(original,candidate);
function fixture(fixed){
 let now=1000,queries=0;
 const leader={r:10.5,c:12.25,_specialistId:'leila',ang:0,speed:1},box={console,Math,Number,Map,Set,Array,Uint32Array,MAP_COLS:200,performance:{now:()=>now},prevT:1,SPECIALIST_NPCS:[leader],document:{documentElement:{dataset:{}}},_walkNpcNavigationResolver:()=>({surface:'land'}),_empireSpeak:()=>{},_npcPacedSpeed:s=>s,_empireMovementWatch:()=>{},_empireSeparationVector:()=>({r:0,c:0})};
 box.npcPassable=()=>{queries++;now+=.1;return true;};box._empireBossPassable=box.npcPassable;box._empireBossWaypointPassable=box.npcPassable;
 vm.createContext(box);
 vm.runInContext(world.slice(world.indexOf('let _npcRouteWorkFrame='),world.indexOf('function _planNpcRouteTo(')),box);
 vm.runInContext(world.slice(world.indexOf('const _empireRoutePlanQueue=[];'),world.indexOf('function _empireCrewOrigin(')),box);
 for(const name of ['_clearNpcRoute','_setNpcRoute','_planNpcRouteTo','_npcAdvanceRoute','_npcBodyPassable','_npcPathPassable','_nearestEmpireWalkPoint','_empireFormationOffset','_planEmpireRouteTo','_processEmpireRoutePlanQueue'])vm.runInContext(fn(name),box);
 vm.runInContext(helper+'\nglobalThis.crewTick=(actor,dt,now)=>{for(const n of [actor]){'+(fixed?candidate:original)+'}};',box);
 const n={id:'escort',r:10.5,c:9.5,hp:60,_empireCrew:true,_empireLeaderId:'leila',_empireCrewSlot:0,walkPhase:0,speed:1};
 box.n=n;
 return{box,n,leader,frame(){now+=150;box.prevT++;},get now(){return now},get queries(){return queries},read:s=>vm.runInContext(s,box)};
}
function run(fixed,mode){
 const f=fixture(fixed),{box:b,n}=f;
 b._planEmpireRouteTo(n,30.5,30.5,.75,6000,'empire_escort',1200,6,'leila');
 if(mode==='frontier'){b._processEmpireRoutePlanQueue(f.now);assert(n._npcDirectedSearch);f.frame();}
 if(mode==='arrived'){n.r=10.5;n.c=10.5;}
 const beforeQueries=f.queries,start={r:n.r,c:n.c};
 b.crewTick(n,.05,f.now);const moved=Math.hypot(n.r-start.r,n.c-start.c);
 const pendingAfterFollow=!!n._empirePendingRoute,queuedAfterFollow=f.read('_empireRoutePlanQueue.length');
 assert.equal(moved>0,mode!=='arrived','the actual crew branch selects physical direct following/arrival');
 const afterFollow=f.queries;
 f.frame();b._processEmpireRoutePlanQueue(f.now);
 const result={fixed,mode,moved,pendingAfterFollow,queuedAfterFollow,orphanQueryCalls:f.queries-afterFollow,followQueryCalls:afterFollow-beforeQueries};
 if(fixed){assert.equal(pendingAfterFollow,false);assert.equal(queuedAfterFollow,0);assert.equal(result.orphanQueryCalls,0);assert(!n._npcDirectedSearch);assert(!n._routeSearchPending);}
 else{assert(pendingAfterFollow);assert(queuedAfterFollow>0);assert(result.orphanQueryCalls>0);}
 return result;
}
const reports=[];for(const mode of ['queued','frontier','arrived'])reports.push({before:run(false,mode),after:run(true,mode)});
const f=fixture(true),n=f.n,b=f.box;
for(const kind of ['empire_action','empire_recruit','empire_retreat']){
 b._planEmpireRouteTo(n,30,30,.8,6000,kind,1200,0,'owner');const request=n._empirePendingRoute;n._routeSearchKind=kind;n._npcDirectedSearch={owner:kind};const search=n._npcDirectedSearch;
 assert.equal(b._cancelEmpireEscortRoute(n),false);assert.equal(n._empirePendingRoute,request);assert.equal(n._npcDirectedSearch,search);
}
if(process.argv.includes('--require-fixed')){assert(world.includes(helper));assert(world.slice(start,end).includes('_cancelEmpireEscortRoute(n);'));}
fs.writeFileSync('outputs/empire_escort_cancel23.json',JSON.stringify({reports,limits:'Actual crew branch, queue pump and source planner. Controlled open predicates/leader fixture; not actual city geometry or LIVE/FPS.'},null,2));
console.log(JSON.stringify(reports,null,2));
