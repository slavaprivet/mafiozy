import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createCivilianNativeFixture,sourceFunction} from './test_civilian_native_fixture.mjs';

const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const choose=sourceFunction(world,'_maybePlanResidentBuildingVisit');
const door={id:'native:test',instanceId:'test',native:true,r:10,c:11};
function fixture({doors=[door],available=true,body=true,failed=false,full=false,retry=false,pending=false}={}){
 let bodyCalls=0,availabilityCalls=0;
 const npc={id:'diagnostic',r:10,c:10,_npcRoutine:'errands',_npcAgenda:{current:'shop'},_civilianPlan:{phase:'seek_shop',cycle:0},_routeSearchPending:pending};
 if(failed)npc._civilianPlan._failedDoors={[door.id]:100};
 if(pending){npc._civilianPlan.doorId=door.id;npc._routeSearchKind='building_entry';npc._residentDestinationChoice={at:20,outcome:'selected',doorId:door.id};}
 const box={performance:{now:()=>50},_civilianPlanEligible:()=>true,_civilianPlanInterrupted:()=>false,_residentCanVisitBuilding:()=>true,
  _walkNpcNavigationResolver:()=>assert.fail('diagnostic must not add direct navigation queries'),_residentBuildingDoors:()=>doors,
  _npcActivityDoorAvailable:()=>{availabilityCalls++;return available;},_npcActivityDoorKey:d=>d.id,
  _npcActivityDoorRetry:new WeakMap(),_npcActivityBuildingSlots:new Map(),NPC_ACTIVITY_BUILDING_CAPACITY:15,
  _npcActivityClaimDoor:()=>true,_npcActivityCancelPending:()=>{},_cancelNpcDirectedSearch:()=>{},
  _npcBodyPassable:()=>{bodyCalls++;return body;},npcPassableForSnitch:()=>true,_civilianPlanUnit:()=>0,
  _clearNpcRoute:()=>{},_civilianRouteTo:(n,r,c)=>{n._routeGoalR=r;n._routeGoalC=c;return !pending;},_npcRememberEvent:()=>{}};
 if(full)box._npcActivityBuildingSlots.set(door.id,new Map(Array.from({length:15},(_,i)=>[i,{}])));
 if(retry)box._npcActivityDoorRetry.set(npc,new Map([[door.id,100]]));
 vm.createContext(box);vm.runInContext(choose,box);
 const result=box._maybePlanResidentBuildingVisit(npc);
 return {npc,result,bodyCalls,availabilityCalls};
}
for(const [options,reason] of [
 [{doors:[]},'registry-not-ready'],[{doors:[{...door,r:100}]},'no-local-door'],
 [{available:false,full:true},'full-capacity'],[{failed:true},'recent-route-failure'],
 [{available:false,retry:true},'recent-route-failure'],[{body:false},'door-body-blocked']]){
 const run=fixture(options);assert.equal(run.result,false);assert.equal(run.npc._residentVisitStatus,'no-reachable-entry');
 assert.equal(run.npc._residentDestinationChoice.rejections[reason],1);assert.equal(run.npc._residentDestinationChoice.at,50);
 assert.equal(run.bodyCalls,reason==='door-body-blocked'?1:0,'same existing short-circuit body admission count');
}
const selected=fixture();assert.equal(selected.result,true);assert.equal(selected.bodyCalls,1);assert.equal(selected.availabilityCalls,1);
assert.equal(selected.npc._residentDestinationChoice.outcome,'selected');
const resumed=fixture({pending:true});assert.equal(resumed.npc._residentDestinationChoice.at,20);assert.equal(resumed.bodyCalls,0);assert.equal(resumed.availabilityCalls,1);

// Real authored print shop and actual reservation adapter: the sixteenth actor
// has no shop slot, advances to walk, and must not be diagnosed as stuck.
const f=await createCivilianNativeFixture({assetId:'print_shop'}),b=f.box,actualDoor=b._residentBuildingDoors()[0];
vm.runInContext(f.source.slice(f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_START'),f.source.indexOf('// CIVILIAN_PURPOSEFUL_PLANS_END')),b);
const dr=actualDoor.r-actualDoor.inside.r,dc=actualDoor.c-actualDoor.inside.c,len=Math.hypot(dr,dc),start={r:actualDoor.r+dr/len*.65,c:actualDoor.c+dc/len*.65};
const make=i=>({id:'diagnostic_shop_'+i,...start,tr:start.r,tc:start.c,hp:60,alive:true,walkPhase:0,idleUntil:0,_arcKey:'worker',_npcRoutine:'errands',_civilianPlan:{phase:'seek_shop',cycle:0,doorId:actualDoor.id},_npcAgenda:{queue:['shop','walk'],index:0,current:'shop',started:true,completed:0}});
const visitors=Array.from({length:15},(_,i)=>make(i)),extra=make(15);f.npcs.push(...visitors,extra);f.nextFrame(.05);
for(const npc of visitors)assert(b._npcActivityClaimDoor(npc,actualDoor,f.now));
assert.equal(b._npcActivityBuildingCount(b._npcActivityDoorKey(actualDoor),{now:f.now}),15);
assert.equal(b._maybePlanResidentBuildingVisit(extra),false);
assert.equal(extra._residentDestinationChoice.rejections['full-capacity'],1);
assert.equal(b._npcAgendaPick(extra,f.now),'walk');assert.equal(extra._residentVisitStatus,'no-reachable-entry');
assert.equal(extra._npcAgenda.current,'walk');assert(!extra._routeSearchPending);

// Publish only the actor under inspection; no owner pruning is involved.
b.NPCS=[extra];b._UP=new Set(['npcqa']);
vm.runInContext('let _residentVisitDiagnosticAt=0;\n'+sourceFunction(world,'_residentVisitDiagnostics'),b);
const queryCount=f.pedestrian.diagnostics().queries;
b._residentVisitDiagnostics(f.now);
const report=JSON.parse(b.document.documentElement.dataset.npcResidentVisits);
assert.equal(report.currentActivities.walk,1);
assert.equal(report.destinationSelection.byCurrentActivity.walk['no-candidate'],1);
assert.equal(report.destinationSelection.rejections['full-capacity'],1);
assert.equal(report.destinationSelection.samples[0].currentActivity,'walk');
assert.equal(report.destinationSelection.samples[0].lastChoiceAt,extra._residentDestinationChoice.at);
assert.equal(f.pedestrian.diagnostics().queries,queryCount,'publishing adds no physical queries');
assert.equal(b._npcActivityBuildingCount(b._npcActivityDoorKey(actualDoor),{now:f.now}),15,'diagnostics do not release or reserve slots');
b.NPCS=Array.from({length:288},(_,i)=>({...extra,id:'report_'+i}));
const publicationCosts=[];
for(let i=1;i<=80;i++){const startAt=performance.now();b._residentVisitDiagnostics(f.now+i*1001);publicationCosts.push(performance.now()-startAt);}
const populationReport=JSON.parse(b.document.documentElement.dataset.npcResidentVisits);
assert.equal(populationReport.currentActivities.walk,288);assert.equal(populationReport.destinationSelection.samples.length,16,'sample output stays bounded');
assert.equal(f.pedestrian.diagnostics().queries,queryCount);
publicationCosts.splice(0,10);publicationCosts.sort((a,b)=>a-b);
console.log(JSON.stringify({pass:true,checks:['five rejection classes plus reservation retry','original admission probe counts','retained choice timestamp','actual print_shop15slot negative case','current walk vs last failed selection','no physical queries on publish','16 sample cap'],sample:report.destinationSelection.samples[0],publication288Ms:{p50:publicationCosts[35],p95:publicationCosts[66]},limits:'CPU source/actual capacity and synthetic288 report-only cost; no LIVE or FPS measurement'}));
