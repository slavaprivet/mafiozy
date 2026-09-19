import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box,door=b._residentBuildingDoors()[0];
const code=fs.readFileSync('assets/maps/city_rebuild_v1/npc_native_directed_route_source.js','utf8');
const baseline=code.replace(/  const directLength=[\s\S]*?search\.direct=[^\n]*\n/,'').replace(/ \/\/ BEGIN short direct approach[\s\S]*? \/\/ END short direct approach\r?\n/,'');
const starts=[],pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch);
for(const radius of [1.5,3,5,7])for(let i=0;i<16;i++){
 const a=i*Math.PI/8,p={r:door.r+Math.sin(a)*radius,c:door.c+Math.cos(a)*radius};
 if(pass(p.r,p.c))starts.push(p);
}
assert(starts.length>=24);
const reports=[];
for(const [label,version] of [['before',baseline],['after',code]]){
 vm.runInContext(version,b);
 vm.runInContext('_npcRouteWorkQueue.clear();_npcRouteWorkServed.clear();_npcRouteWorkFrame=null;_npcRouteWorkStartedAt=null;_npcRouteWorkUsedMs=0;',b);
 const actors=starts.map((p,i)=>({...p,id:'resident_queue18_'+i}));f.npcs.splice(0,f.npcs.length,...actors);
 let frame=0,completed=0,cpuMs=0,maxAdmissions=0;const finished=[],frameCosts=[];
 for(;frame<2000&&completed<actors.length;frame++){
  f.nextFrame(.2);const at=performance.now();
  for(const n of actors){
   if(n.done)continue;
   const published=b._planNpcRouteTo(n,door.r,door.c,pass,.8,1200,'building_entry');
   if(!published&&n._routeSearchPending)continue;
   n.done=true;completed++;finished.push(frame+1);
  }
  const elapsed=performance.now()-at;cpuMs+=elapsed;frameCosts.push(elapsed);
  maxAdmissions=Math.max(maxAdmissions,vm.runInContext('_npcRouteWorkCount',b));
 }
 for(const n of actors){
   const path=n._route||[],tail=path.at(-1)||n;
   n.reached=Math.hypot(tail.r-door.r,tail.c-door.c)<=.9&&b._npcPathPassable(tail.r,tail.c,door.r,door.c,b.npcPassableForSnitch);
   let from=n;for(const to of path){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch));from=to;}
 }
 assert.equal(completed,actors.length);assert(maxAdmissions<=8);
 frameCosts.sort((a,c)=>a-c);
 reports.push({label,residents:actors.length,completed,reached:actors.filter(n=>n.reached).length,frames:frame,waitP50Frames:finished[Math.floor(finished.length*.5)],waitP95Frames:finished[Math.floor(finished.length*.95)],cpuMs,frameCpuP95:frameCosts[Math.floor(frameCosts.length*.95)],maxAdmissions});
}
assert.equal(reports[1].reached,reports[0].reached);
console.log(JSON.stringify({reports,limits:'Actual city geometry, production shared FIFO / 4 ms / max eight admissions, fixed residents and shop goal. Query costs are wall-clock and noisy on a shared machine. No rendering, collision between staged NPCs, actual world update or LIVE FPS.'},null,2));
