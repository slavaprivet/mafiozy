import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n'),pick=sourceFunction(source,'pickNpcWaypoint');
const before=pick.replace(/const wanderChoiceTarget=(?:1|8);/,'const wanderChoiceTarget=Infinity;');
assert.notEqual(pick,before,'baseline disables only early completion, preserving current FIFO first-slice fix');
const edgeStart=before.indexOf('      if(resolver){\n        const fr=cur.key===startKey?npc.r:cur.r+.5,fc=cur.key===startKey?npc.c:cur.c+.5;');
const edgeEnd=before.indexOf('\n      }',edgeStart)+'\n      }'.length;
assert(edgeStart>=0&&edgeEnd>edgeStart,'locate only native exact-edge block');
const exactEdge=before.slice(edgeStart,edgeEnd);
assert(exactEdge.includes("mode:'sweep'")&&exactEdge.includes('wanderEdgePassable')&&exactEdge.includes('_npcPathPassable'),'baseline removes both exact native and fallback path gates');
const endpointBefore=before.slice(0,edgeStart)+before.slice(edgeEnd);
assert.notEqual(endpointBefore,before,'historical endpoint-only baseline removes exact edge gate');
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))]||0;
const random=()=>{let s=77;const math=Object.create(Math);math.random=()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296);return math;};
function synthetic(code){
 let now=1000,checks=0;const NPCS=[],b={Math:random(),Number,Map,Set,NPCS,MAP_COLS:120,performance:{now:()=>now},prevT:0,_walkNpcNavigationResolver:()=>({surface:'land'}),_civilianPlanNext:()=>false,_maybePlanResidentBuildingVisit:()=>false};
 b.npcWaypointOk=(n,r,c)=>{checks++;now+=.02;return r>1&&r<119&&c>1&&c<119&&!(Math.floor(c)===75&&r<80);};
 b._npcPathPassable=(fr,fc,r,c,pass)=>pass(r,c);
 vm.createContext(b);vm.runInContext(source.slice(source.indexOf('let _npcRouteWorkFrame='),source.indexOf('function _planNpcRouteTo(')),b);
 for(const name of ['_clearNpcRoute','_setNpcRoute'])vm.runInContext(sourceFunction(source,name),b);vm.runInContext(code,b);
 for(let i=0;i<288;i++){const r=15.5+Math.floor(i/18)*4,c=10.5+i%18*4;NPCS.push({id:'walker-'+i,r,c,tr:r,tc:c,hp:60,_routeStartR:r-8,_routeStartC:c});}
 const completions=[],costs=[];let frame=0;
 for(;frame<6000&&completions.length<NPCS.length;frame++){
  now+=1000/60;b.prevT=frame;const t=performance.now();
  for(const n of NPCS)if(!n._route?.length&&b.pickNpcWaypoint(n))completions.push((frame+1)/60);
  costs.push(performance.now()-t);assert(vm.runInContext('_npcRouteWorkCount<=2',b));
 }
 assert.equal(completions.length,288,'all 288 walkers get a route');
 const goals=new Set();for(const n of NPCS){assert(n._route.length>=8);const end=n._route.at(-1);assert(Math.hypot(end.r-n.r,end.c-n.c)>=6);assert(Math.hypot(end.r-n._previousRouteStartR,end.c-n._previousRouteStartC)>5.5);assert(!goals.has(end.r+','+end.c));goals.add(end.r+','+end.c);for(const p of n._route)assert(!(Math.floor(p.c)===75&&p.r<80),'no synthetic wall crossing');}
 return{completed:completions.length,frames:frame,completionSeconds:{p50:percentile(completions,.5),p95:percentile(completions,.95),last:completions.at(-1)},predicateChecks:checks,updateCpuMs:{p50:percentile(costs,.5),p95:percentile(costs,.95)},minimumRouteCells:Math.min(...NPCS.map(n=>n._route.length))};
}
const syntheticBefore=synthetic(before),syntheticAfter=synthetic(pick);assert(syntheticAfter.predicateChecks<syntheticBefore.predicateChecks*.6,'substantial query reduction without raising work budget');
const f=await createCivilianNativeFixture(),b=f.box,origins=[];
b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
for(let r=3;r<b.MAP_ROWS-4&&origins.length<288;r+=2)for(let c=3;c<b.MAP_COLS-4&&origins.length<288;c+=2){
 const n={r:r+.5,c:c+.5};if(origins.length%10===0)n.c+=.11;
 if(b.npcWaypointOk(n,n.r,n.c)&&b._npcBodyPassable(n.r,n.c,b.npcPassable))origins.push(n);
}
assert.equal(origins.length,288);
function actual(code){
 b.Math=random();b.NPCS.length=0;for(let i=0;i<origins.length;i++)b.NPCS.push({id:'native-walker-'+i,...origins[i],tr:origins[i].r,tc:origins[i].c,hp:60});
 vm.runInContext('_npcRouteWorkFrame=null;_npcRouteWorkCount=0;_npcRouteWorkDeadline=0;_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();',b);
 const pass=b.npcWaypointOk;let checks=0;b.npcWaypointOk=(...args)=>{checks++;return pass(...args)};vm.runInContext(code,b);
 const completions=[],costs=[];let frame=0;
 for(;frame<2400&&completions.length<b.NPCS.length;frame++){
  f.nextFrame(1/60);const t=performance.now();for(const n of b.NPCS)if(!n._route?.length&&!(n.idleUntil>f.now)&&b.pickNpcWaypoint(n))completions.push((frame+1)/60);costs.push(performance.now()-t);
 }
 let segmentCount=0,blockedSegments=0,validWholePaths=0;const occupied=new Set();
 for(const n of b.NPCS){if(!n._route?.length)continue;const goal=n._route.at(-1),key=goal.r+','+goal.c;assert(!occupied.has(key),'reserved native destination remains exclusive');occupied.add(key);let p=n,valid=true;for(const next of n._route){segmentCount++;if(!b._npcPathPassable(p.r,p.c,next.r,next.c,b.npcPassable)){blockedSegments++;valid=false;}p=next;}if(valid)validWholePaths++;}
 b.npcWaypointOk=pass;
 return{completed:completions.length,validWholePaths,pending:288-completions.length,frames:frame,predicateChecks:checks,completionSeconds:{p50:percentile(completions,.5),p95:percentile(completions,.95),last:completions.at(-1)},updateCpuMs:{p50:percentile(costs,.5),p95:percentile(costs,.95),total:costs.reduce((sum,t)=>sum+t,0)},segmentCount,blockedSegments};
}
const actualEndpointBefore=actual(endpointBefore),actualBefore=actual(before),actualAfter=actual(pick);
assert(actualAfter.completed>=actualBefore.completed,'no loss of reachable walkers');assert(actualAfter.predicateChecks<actualBefore.predicateChecks,'actual-geometry predicate queries decrease');
assert(actualEndpointBefore.blockedSegments>0,'reproduce endpoint-only historical defect');assert.equal(actualBefore.blockedSegments,0);assert.equal(actualAfter.blockedSegments,0,'every published whole native route passes execution footprint from actual actor position');
const report={scenario:'288 simultaneous ordinary wander requests; 2 jobs/4 ms unchanged; current FIFO marker retained on all sides. Early-finish A/B uses exact edges; additional actualEndpointBefore is historical endpoint-only planner. Synthetic host query costs 0.02 ms with simple edge predicate; actual fixture uses real body/swept gates and CPU time.',syntheticBefore,syntheticAfter,actualEndpointBefore,actualBefore,actualAfter,limits:f.limits+' This is route planning, not complete AI update, GPU or FPS. Existing runtime swept movement gate remains authoritative.'};
fs.writeFileSync('outputs/npc_wander_early_finish_20260919.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
