import fs from 'node:fs';
import vm from 'node:vm';
import {createCivilianNativeFixture,sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';
const scan=JSON.parse(fs.readFileSync('outputs/npc_grid_resolution_scan18.json','utf8'));
const source=fs.readFileSync('world.html','utf8'),results=[];
for(const row of scan.results.filter(r=>r.fine?.found)){
 const f=await createCivilianNativeFixture({assetId:row.assetId}),b=f.box;
 b._civilianPlanNext=()=>false;b._maybePlanResidentBuildingVisit=()=>false;
 vm.runInContext(sourceFunction(source,'pickNpcWaypoint'),b);
 const n={id:'audit-wander-'+row.assetId,...row.start,hp:60};b.NPCS.push(n);
 const pass=(r,c)=>b.npcWaypointOk(n,r,c);
 const edge=(from,to)=>{
  const sweep=b.nativePedestrianQuery({mode:'sweep',from,to,radius:.18});
  return{endpoint:pass(to.r,to.c),footprint:b._npcPathPassable(from.r,from.c,to.r,to.c,pass),sweptBlocked:!!sweep.blocked};
 };
 const sr=Math.floor(n.r),sc=Math.floor(n.c),neighbors=[[1,0],[-1,0],[0,1],[0,-1]].map(([dr,dc])=>{
  const to={r:sr+dr+.5,c:sc+dc+.5};return{to,...edge(n,to)};
 });
 let frames=0,ready=false;
 for(;frames<120;frames++){f.nextFrame();ready=b.pickNpcWaypoint(n);if(ready||!n._npcWanderSearch&&n.idleUntil>f.now)break;}
 let from=row.start,finePrefix=0,fineFirstBlocked=null;
 for(const to of row.fine.path){const checked=edge(from,to);if(!checked.endpoint||!checked.footprint||checked.sweptBlocked){fineFirstBlocked={from,to,...checked};break;}finePrefix++;from=to;}
 results.push({assetId:row.assetId,start:row.start,startWaypointAllowed:pass(row.start.r,row.start.c),neighbors,wander:{ready,frames:frames+1,path:n._route||[],retryDelay:n.idleUntil-f.now},knownFinePathUnderWanderRules:{clearPrefix:finePrefix,total:row.fine.path.length,firstBlocked:fineFirstBlocked}});
}
const report={results,limits:'Read-only production wander audit with actual CPU fixtures; known fine paths are only diagnostics, no new routing code installed.'};
fs.writeFileSync('outputs/npc_wander_grid_trap_audit18.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
