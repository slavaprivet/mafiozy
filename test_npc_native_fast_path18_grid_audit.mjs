// Read-only audit: compare the production 1-cell route lattice with a .25-cell
// search using identical full-body production edge checks. No runtime changes.
import {createCivilianNativeFixture} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
import {performance} from 'node:perf_hooks';
import fs from 'node:fs';
import assert from 'node:assert/strict';
function fineRoute(b,start,door){
 const step=.25,heap=[],nodes=new Map(),key=(i,j)=>i+':'+j;
 const push=n=>{heap.push(n);let i=heap.length-1;while(i){const p=(i-1)>>1;if(heap[p].f<=n.f)break;heap[i]=heap[p];i=p;}heap[i]=n;};
 const pop=()=>{const n=heap[0],last=heap.pop();if(heap.length){let i=0;while(i*2+1<heap.length){let c=i*2+1;if(c+1<heap.length&&heap[c+1].f<heap[c].f)c++;if(last.f<=heap[c].f)break;heap[i]=heap[c];i=c;}heap[i]=last;}return n;};
 const first={i:0,j:0,r:start.r,c:start.c,g:0,f:Math.hypot(start.r-door.r,start.c-door.c)};nodes.set('0:0',first);push(first);let expanded=0;
 while(heap.length&&nodes.size<8000){
  const n=pop();if(n.closed)continue;n.closed=true;expanded++;
  if(Math.hypot(n.r-door.r,n.c-door.c)<.6&&b._npcPathPassable(n.r,n.c,door.r,door.c,b.npcPassableForSnitch)){
   const path=[{r:door.r,c:door.c}];let p=n;while(p.parent){path.push({r:p.r,c:p.c});p=p.parent;}path.reverse();return {found:true,expanded,visited:nodes.size,path};
  }
  for(const [di,dj]of [[1,0],[-1,0],[0,1],[0,-1]]){
   const i=n.i+di,j=n.j+dj,k=key(i,j),old=nodes.get(k),g=n.g+step;if(old?.closed||old&&old.g<=g)continue;
   const r=start.r+i*step,c=start.c+j*step;if(Math.hypot(r-door.r,c-door.c)>12||!b._npcPathPassable(n.r,n.c,r,c,b.npcPassableForSnitch))continue;
   const child={i,j,r,c,g,f:g+Math.hypot(r-door.r,c-door.c),parent:n};nodes.set(k,child);push(child);
  }
 }
 return {found:false,expanded,visited:nodes.size};
}
const results=[];
for(const assetId of ['print_shop','hospital']){
 const f=await createCivilianNativeFixture({assetId}),b=f.box,door=b._residentBuildingDoors()[0];
 b._npcRouteWorkExpired=()=>false;
 if(process.argv.includes('--scan')){
  let examined=0,traps=0;
  outer:for(let dr=-8;dr<=8;dr+=.5)for(let dc=-8;dc<=8;dc+=.5){
   const start={r:door.r+dr+.113,c:door.c+dc+.137};
   if(!b._npcBodyPassable(start.r,start.c,b.npcPassableForSnitch)||f.entry.containsInterior?.(new f.THREE.Vector3(start.c*f.M,f.floor(start.c*f.M,start.r*f.M),start.r*f.M)))continue;
   examined++;const r=Math.floor(start.r),c=Math.floor(start.c);
   if([[1,0],[-1,0],[0,1],[0,-1]].some(([i,j])=>b._npcPathPassable(start.r,start.c,r+i+.5,c+j+.5,b.npcPassableForSnitch)))continue;
   const n={...start},pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch),coarseOk=b._npcPlanNativeVisitRoute(n,door.r,door.c,pass,.8,1200,'building_entry');
   const fine=fineRoute(b,start,door);traps++;results.push({assetId,scan:true,start,door:{r:door.r,c:door.c},coarseOk,coarseExpanded:n._routeSearchExpanded,coarsePath:n._route||[],fine});
   if(fine.found){
    assert.equal(coarseOk,false,'production coarse/direct route must reproduce this false-negative');
    f.nextFrame();let from=start;for(const to of fine.path){assert(b._npcPathPassable(from.r,from.c,to.r,to.c,b.npcPassableForSnitch),'fine diagnostic route preserves actual full-body sweep');from=to;}
    break outer;
   }
   if(traps>=12)break outer;
  }
  console.log(JSON.stringify({assetId,examined,traps,escaped:results.filter(x=>x.assetId===assetId&&x.fine.found).length}));continue;
 }
 for(const radius of [1.5,3,5,7])for(let angle=0;angle<16;angle++){
  const a=angle*Math.PI/8,start={r:door.r+Math.sin(a)*radius,c:door.c+Math.cos(a)*radius};
  if(!b._npcBodyPassable(start.r,start.c,b.npcPassableForSnitch))continue;
  f.nextFrame();const n={...start},pass=(r,c)=>b._npcBodyPassable(r,c,b.npcPassableForSnitch);
  const ok=b._npcPlanNativeVisitRoute(n,door.r,door.c,pass,.8,1200,'building_entry'),tail=ok?n._route.at(-1):start;
  if(Math.hypot(tail.r-door.r,tail.c-door.c)<=.9&&b._npcPathPassable(tail.r,tail.c,door.r,door.c,b.npcPassableForSnitch))continue;
  const now=performance.now(),fine=fineRoute(b,start,door),inside=!!f.entry.containsInterior?.(new f.THREE.Vector3(start.c*f.M,f.floor(start.c*f.M,start.r*f.M),start.r*f.M));results.push({assetId,radius,angle,start,inside,door:{r:door.r,c:door.c},coarseExpanded:n._routeSearchExpanded,coarseTailDistance:Math.hypot(tail.r-door.r,tail.c-door.c),fine,cpuMs:performance.now()-now});
 }
}
console.log(JSON.stringify(results,null,2));
if(process.argv.includes('--scan'))assert.equal(results.filter(x=>x.fine.found).length,2,'two actual outdoor coarse-grid false-negative repros');
fs.writeFileSync(process.argv.includes('--scan')?'outputs/npc_grid_resolution_scan18.json':'outputs/npc_grid_resolution_audit18.json',JSON.stringify({results,limit:'Read-only actual geometry CPU audit. Fine planner is diagnostic only, never installed in game.'},null,2));
