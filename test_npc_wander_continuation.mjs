import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
import {historicalEagerWander19} from './npc_wander_lazy_compare19.mjs';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n');
const fn=name=>{const start=source.indexOf('function '+name+'(');let p=source.indexOf('{',start),d=1;for(p++;d;p++){if(source[p]==='{')d++;if(source[p]==='}')d--;}return source.slice(start,p);};
const budget=source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo('));
function fixture({legacy=false,small=false}={}){
 let clock=1000,checks=0;const ctx={Math,Number,Map,Set,performance:{now:()=>clock},prevT:1,MAP_COLS:80,NPCS:[],_walkNpcNavigationResolver:()=>({surface:'land'}),_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 ctx.npcWaypointOk=(n,r,c)=>{checks++;clock+=2;return small?r===30.5&&c>=30.5&&c<=33.5:r>10&&r<60&&c>10&&c<60;};
 // Bounded queue-continuation fixture; actual footprint geometry is exercised
 // separately by test_npc_wander_early_finish and native cadence tests.
 ctx._npcPathPassable=(fr,fc,r,c,pass)=>pass(r,c);
 vm.createContext(ctx);vm.runInContext(budget,ctx);for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(fn(name),ctx);
 let pick=fn('pickNpcWaypoint');
 if(legacy&&pick.includes('search.lazyStack'))pick=historicalEagerWander19(pick);
 if(legacy){pick=pick.replace(/const wanderChoiceTarget=(?:1|8);/,'const wanderChoiceTarget=Infinity;').replace(/if\(cur\.depth>=1\)\{candidates\.push\(cur\);if\(resolver&&longWalk\(cur\)&&\+\+walkChoices>=wanderChoiceTarget\)\{walkReady=true;break;\}\}/,'if(cur.depth>=6)candidates.push(cur);').replace(/if\(resolver&&!walkReady&&[^\n]*return false;\}/,'');}
 if(legacy)pick=pick.replace('if(resolver)npc._npcWanderSearch=search;','');
 vm.runInContext(pick,ctx);
 return {ctx,actor(id){const n={id,r:30.5,c:30.5,tr:45.5,tc:30.5,hp:100,idleUntil:0};ctx.NPCS.push(n);return n;},frame(){clock+=16.667;ctx.prevT++;},clock:()=>clock,checks:()=>checks};
}
const old=fixture({legacy:true}),oldN=old.actor('old');for(let i=0;i<50;i++){old.frame();old.ctx.pickNpcWaypoint(oldN);}assert(!oldN._route?.length,'previous per-frame frontier discard never reaches its six-cell minimum');
const f=fixture(),a=f.actor('a'),b=f.actor('b');b.r=35.5;b.c=35.5;
let firstSearch=null,firstProgress=0,finishedFrame=0;
for(let i=0;i<500;i++){
 f.frame();for(const n of [a,b])if(!n._route?.length)f.ctx.pickNpcWaypoint(n);
 assert(vm.runInContext('_npcRouteWorkCount<=8',f.ctx),'existing eight-admission ceiling per frame');
 if(a._npcWanderSearch){assert.equal(a.r,30.5);assert.equal(a.tr,a.r);assert.equal(a.idleUntil,0);if(!firstSearch){firstSearch=a._npcWanderSearch;firstProgress=firstSearch.qi;}else assert.equal(a._npcWanderSearch,firstSearch,'one frontier survives slices');}
 if(a._route?.length&&b._route?.length){finishedFrame=i+1;break;}
}
assert(finishedFrame,'both actual source FIFO owners eventually receive routes');assert(firstSearch.qi>firstProgress);assert(a._route.length>=6);assert(b._route.length>=6);
const tight=fixture({small:true}),t=tight.actor('courtyard');for(let i=0;i<20&&!t._route?.length;i++){tight.frame();tight.ctx.pickNpcWaypoint(t);}assert(t._route?.length>0&&t._route.length<6,'a genuinely small reachable courtyard still has a walk');
const invalid=fixture(),n=invalid.actor('interrupt');invalid.frame();invalid.ctx.pickNpcWaypoint(n);let saved=n._npcWanderSearch;assert(saved);
invalid.ctx._walkNpcNavigationResolver=()=>({surface:'land'});invalid.frame();invalid.ctx.pickNpcWaypoint(n);assert.notEqual(n._npcWanderSearch,saved,'native callback replacement invalidates the old frontier');
saved=n._npcWanderSearch;n._allowBeach=true;invalid.frame();invalid.ctx.pickNpcWaypoint(n);assert.notEqual(n._npcWanderSearch,saved,'changed permitted surface invalidates the frontier');
invalid.ctx._clearNpcRoute(n);assert.equal(n._npcWanderSearch,null,'external route cancellation cancels wander');invalid.frame();invalid.ctx.pickNpcWaypoint(n);n.panicUntil=invalid.clock()+5000;invalid.frame();invalid.ctx.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null,'panic owns motion immediately');n.panicUntil=0;invalid.frame();invalid.ctx.pickNpcWaypoint(n);n.dead=true;invalid.frame();invalid.ctx.pickNpcWaypoint(n);assert.equal(n._npcWanderSearch,null,'dead actors cannot retain or publish a wander');
console.log(`PASS source wander: old 50-slice stall reproduced; two FIFO owners complete in ${finishedFrame} frames, same 8-admission/4-ms budget; short courtyard, callback/surface invalidation, panic/death/cancel verified (${f.checks()} predicate checks total)`);

