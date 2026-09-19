import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const source=fs.readFileSync('world.html','utf8').replace(/\r\n/g,'\n'),pick=sourceFunction(source,'pickNpcWaypoint');
const before=pick.replace('!wanderEdgePassable(fr,fc,r+.5,c+.5)','!_npcPathPassable(fr,fc,r+.5,c+.5,edgePass)');
assert.notEqual(before,pick);
const percentile=(a,p)=>[...a].sort((x,y)=>x-y)[Math.min(a.length-1,Math.floor(a.length*p))]||0;
const random=()=>{let s=77;const math=Object.create(Math);math.random=()=>((s=Math.imul(s,1664525)+1013904223>>>0)/4294967296);return math;};
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
 const blockedQuery=b._npcRouteWalkBlocked;let nativeChecks=0;b._npcRouteWalkBlocked=(...args)=>{nativeChecks++;return blockedQuery(...args)};
 const pass=b.npcWaypointOk;let checks=0;b.npcWaypointOk=(...args)=>{checks++;return pass(...args)};vm.runInContext(code,b);
 const completions=[],costs=[],failed=new Set();let frame=0;
 for(;frame<2400&&completions.length+failed.size<b.NPCS.length;frame++){
  f.nextFrame(1/60);const t=performance.now();for(const n of b.NPCS)if(!n._route?.length&&!failed.has(n)){
   if(b.pickNpcWaypoint(n))completions.push((frame+1)/60);
   else if(!n._npcWanderSearch&&n.idleUntil>f.now)failed.add(n);
  }costs.push(performance.now()-t);
 }
 let segmentCount=0,blockedSegments=0,validWholePaths=0;const occupied=new Set();
 for(const n of b.NPCS){if(!n._route?.length)continue;const goal=n._route.at(-1),key=goal.r+','+goal.c;assert(!occupied.has(key),'reserved native destination remains exclusive');occupied.add(key);let p=n,valid=true;for(const next of n._route){segmentCount++;if(!b._npcPathPassable(p.r,p.c,next.r,next.c,b.npcPassable)){blockedSegments++;valid=false;}p=next;}if(valid)validWholePaths++;}
 b.npcWaypointOk=pass;b._npcRouteWalkBlocked=blockedQuery;
 return{completed:completions.length,validWholePaths,pending:288-completions.length,frames:frame,predicateChecks:checks,nativePointChecks:nativeChecks,completionSeconds:{p50:percentile(completions,.5),p95:percentile(completions,.95),last:completions.at(-1)},updateCpuMs:{p50:percentile(costs,.5),p95:percentile(costs,.95),total:costs.reduce((sum,t)=>sum+t,0)},segmentCount,blockedSegments};
}

// Same actual geometry, identical edge endpoints and surface rules: compare
// boolean footprint acceptance independently of FIFO publication ordering.
const helper=pick.slice(pick.indexOf('  const wanderEdgePassable='),pick.indexOf('  let walkChoices='));
let checkedEdges=0;
for(const n of origins){
 b.edgePass=(r,c)=>b.npcWaypointOk(n,r,c);vm.runInContext('{'+helper+'globalThis.testWanderEdge=wanderEdgePassable;}',b);
 for(const [dr,dc] of [[1,0],[-1,0],[0,1],[0,-1]]){
  const r=Math.floor(n.r)+dr+.5,c=Math.floor(n.c)+dc+.5;
  assert.equal(b.testWanderEdge(n.r,n.c,r,c),b._npcPathPassable(n.r,n.c,r,c,b.edgePass),'all five exact footprint points agree');checkedEdges++;
 }
}
const baseline=actual(before),after=actual(pick);

assert.equal(baseline.blockedSegments,0);
assert.equal(after.blockedSegments,0);
assert(after.completed>=baseline.completed-8,'reservation ordering stays within three percent; geometry equivalence is checked separately');
assert(after.nativePointChecks<baseline.nativePointChecks*.8,'at least 20% fewer native point gates');
assert(after.completionSeconds.p50<baseline.completionSeconds.p50,'earlier median route publication');
assert(after.updateCpuMs.total<baseline.updateCpuMs.total,'less actual route CPU');
const report={scenario:'Actual city geometry, 288 simultaneous FIRST wander requests, one request per origin; same footprint without duplicate native point gates versus existing exact BFS early finish. Identical FIFO and 4ms actual CPU budget.',baseline,after,equivalentActualEdges:checkedEdges,limits:f.limits+' No full scene FPS or LIVE acceptance.'};
fs.writeFileSync('outputs/npc_wander_point_dedup18.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
