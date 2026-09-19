import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
const world=fs.readFileSync('world.html','utf8');
const code=world.slice(world.indexOf('function _maybePlanResidentBuildingVisit('),world.indexOf('function _pickResidentRespawnDoor('));
const doors=Array.from({length:96},(_,i)=>({id:'entry-'+i,r:10+i%12,c:10+Math.floor(i/12),native:true,authored:true,residentEligible:true}));
let probes=0,choices=0,target=null,now=1000;
const box=vm.createContext({performance:{now:()=>now},getGameHour:()=>12,_npcRoutineFor:()=> 'errands',_civilianPlanEligible:()=>true,_civilianPlanInterrupted:()=>false,_residentCanVisitBuilding:()=>true,_walkNpcNavigationResolver:()=>({}),_residentBuildingDoors:()=>doors,npcPassableForSnitch:()=>true,_npcBodyPassable:()=>{probes++;return true},_residentChoosePurposeDoors:(n,c)=>{choices++;return c},_clearNpcRoute:n=>{n._route=null},_cancelNpcDirectedSearch:n=>{n._routeSearchPending=false},_civilianRouteTo:(n,r,c)=>{target={r,c};n._routeSearchPending=true;n._routeSearchKind='building_entry';return false},_civilianPlanUnit:()=>0});
vm.runInContext(code,box);
const actor=()=>({id:'resident',r:12,c:12,_routeSearchKind:'building_entry',_routeSearchPending:true,_civilianPlan:{phase:'seek_shop',doorId:'entry-17',cycle:0}});
const n=actor();box._maybePlanResidentBuildingVisit(n);
assert.equal(probes,0,'resuming an existing destination must not query unrelated geometry');assert.equal(choices,0);assert.equal(n._civilianPlan.doorId,'entry-17');assert.deepEqual(target,{r:doors[17].r,c:doors[17].c});
// A disappeared/ineligible/failed destination must return to real selection.
for(const invalidate of [d=>d.residentEligible=false,d=>doors.splice(17,1),d=>n._civilianPlan._failedDoors={[d.id]:2000}]){
 const saved=doors.slice(),d=doors[17];n._civilianPlan.doorId=d.id;probes=0;invalidate(d);box._maybePlanResidentBuildingVisit(n);assert(probes>0);assert.notEqual(n._civilianPlan.doorId,d.id);doors.splice(0,doors.length,...saved);d.residentEligible=true;n._civilianPlan._failedDoors=null;
}
// Fresh selection still checks actual entrance clearance.
const fresh=actor();fresh._routeSearchPending=false;probes=0;box._maybePlanResidentBuildingVisit(fresh);assert(probes>0);
const costs=[];probes=0;for(let frame=0;frame<120;frame++){const start=performance.now();for(let i=0;i<288;i++)box._maybePlanResidentBuildingVisit(actor());costs.push(performance.now()-start)}costs.sort((a,b)=>a-b);
assert.equal(probes,0);console.log(JSON.stringify({pass:true,residents:288,doors:96,repeatedGeometryQueries:probes,cpuMs:{p50:costs[60],p95:costs[114]},limits:'pending destination selection only; no route search/render/FPS'}));
