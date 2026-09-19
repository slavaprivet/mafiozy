import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';
const source=fs.readFileSync(new URL('npc_activity_agenda_source.js',import.meta.url),'utf8');
function setup(){const b={Math,Number,Object,_walkNpcNavigationResolver:()=>({}),_walkRendererActive:()=>true,_isRespawnableResident:()=>true,_civilianPlanEligible:()=>true};vm.createContext(b);vm.runInContext(source,b);return b;}
const make=(id='resident_queue18')=>({id,hp:100,r:10,c:10,_arcKey:'worker'});
function select(b,n,kind){const a=b._npcAgendaEnsure(n);a.index=a.queue.indexOf(kind);a.current=a.queue[a.index];a.started=false;return a;}
{
 const b=setup(),a=make(),c=make();assert.deepEqual([...b._npcAgendaEnsure(a).queue],[...b._npcAgendaEnsure(c).queue]);
 const rotations=new Set;for(let i=0;i<96;i++){const q=b._npcAgendaEnsure(make('resident_'+i)).queue;assert.equal(q.length,6);assert.equal(q.filter(x=>x==='walk').length,3);assert.equal(q.filter(x=>x==='shop').length,1);assert.equal(q.filter(x=>x==='bench').length,1);assert.equal(q.filter(x=>x==='drive').length,1);rotations.add(q.join(','));}assert(rotations.size>1);
}
{
 const b=setup(),n=make();select(b,n,'shop');let calls=0;b._maybePlanResidentBuildingVisit=()=>{calls++;return false;};
 assert.equal(b._npcAgendaPick(n,0),'walk');assert.equal(calls,1);assert.equal(n._npcAgenda.current,'walk');assert.equal(n._npcAgenda.lastResult.reason,'unavailable');
 const plan=n._civilianPlan;assert.equal(b._npcAgendaPick(n,1),'walk');assert.equal(n._civilianPlan,plan);assert.equal(calls,1);
 assert(!b._npcAgendaComplete(n,'shop','stale'));assert.equal(n._npcAgenda.current,'walk');assert(b._npcAgendaComplete(n,'walk','arrived'));assert.equal(n._npcAgenda.current,'bench');
 b._civilianPlanNext=()=>false;assert.equal(b._npcAgendaPick(n,2),'walk');assert.equal(n._npcAgenda.current,'walk');assert(b._npcAgendaComplete(n,'walk','arrived'));assert.equal(n._npcAgenda.current,'drive');
 assert(b._npcAgendaWantsDrive(n,3));assert.equal(b._npcAgendaPick(n,3),'walk','missing adapter immediately advances');
}
for(const kind of ['shop','bench']){
 const b=setup(),n=make();select(b,n,kind);let calls=0,plan;
 const executor=actor=>{calls++;if(calls===1){plan=actor._civilianPlan;plan.doorId='native:retained-shop';plan.benchId='retained-bench';actor._routeSearchPending=true;actor._routeSearchKind=kind==='shop'?'building_entry':'civilian_bench';return false;}assert.equal(actor._civilianPlan,plan);assert.equal(plan.doorId,'native:retained-shop');actor._routeSearchPending=false;actor._route=[{r:12,c:10}];return true;};
 if(kind==='shop')b._maybePlanResidentBuildingVisit=executor;else b._civilianPlanNext=executor;
 assert.equal(b._npcAgendaPick(n,0),'pending');assert.equal(b._npcAgendaPick(n,100),'ready');assert.equal(calls,2);assert.equal(n._npcAgenda.current,kind);assert.equal(n._civilianPlan,plan);
}
{
 const b=setup(),n=make();select(b,n,'walk');const search={key:'retained-wander'};n._npcWanderSearch=search;n._civilianPlan={phase:'walk_to_bench',doorId:'old-shop'};const p=n._civilianPlan;
 b._civilianPlanNext=()=>assert.fail('stale automatic phase must not override explicit agenda');assert.equal(b._npcAgendaPick(n,100),'walk');assert.equal(n._npcWanderSearch,search);assert.equal(n._civilianPlan,p);
}
{
 const b=setup(),n=make();select(b,n,'drive');b._isRespawnableResident=actor=>!actor._civilianTrip;let claims=0;b._npcAgendaTryDrive=actor=>{assert(b._npcAgendaWantsDrive(actor,0));claims++;actor._civilianTrip=true;return true;};assert.equal(b._npcAgendaPick(n,0),'ready');assert.equal(b._npcAgendaPick(n,1),'ready');assert.equal(claims,1);assert(!b._npcAgendaWantsDrive(n,1));assert.equal(n._npcAgenda.current,'drive');
}
{
 const b=setup(),n=make();select(b,n,'walk');n._civilianPlan={phase:'walk_to_shop',doorId:'native:trip-a',tripDestination:true};n._routeSearchPending=true;n._routeSearchKind='building_entry';const p=n._civilianPlan;let calls=0;
 b._maybePlanResidentBuildingVisit=actor=>{calls++;assert.equal(actor._civilianPlan,p);assert.equal(p.doorId,'native:trip-a');if(calls<3)return false;actor._routeSearchPending=false;actor._routeKind='building_entry';actor._route=[{r:12,c:10}];return true;};
 assert.equal(b._npcAgendaPick(n,0),'pending');assert.equal(b._npcAgendaPick(n,1),'pending');assert.equal(b._npcAgendaPick(n,2),'ready');assert.equal(b._npcAgendaPick(n,3),'ready');assert.equal(calls,3);assert.equal(n._npcAgenda.current,'shop');assert.equal(n._civilianPlan,p);
}
for(const field of ['_civilianSeat','_residentNativeVisit','_civilianTrip','_civilianActivity','_residentIndoors']){
 const b=setup(),n=make();select(b,n,'shop');n[field]={};const a=n._npcAgenda;b._civilianPlanEligible=()=>false;b._maybePlanResidentBuildingVisit=()=>assert.fail('owner overwritten');assert.equal(b._npcAgendaPick(n,0),'ready');assert.equal(n._npcAgenda,a);assert.equal(a.current,field==='_civilianSeat'?'bench':field==='_civilianTrip'?'drive':'shop');
}
{
 const b=setup(),n=make();select(b,n,'drive');n._civilianPlan={phase:'walk_to_shop',tripDestination:true,doorId:'native:missing'};n._residentVisitTargetId='native:missing';n._residentDoor={id:'native:missing'};let released=0;
 b._maybePlanResidentBuildingVisit=()=>false;b._npcActivityCancelPending=(owner,reason)=>{assert.equal(owner,n);assert.equal(reason,'activity-unavailable');released++;};
 assert.equal(b._npcAgendaPick(n,0),'walk');assert.equal(n._npcAgenda.current,'walk');assert.equal(n._civilianPlan.tripDestination,false);assert.equal(n._civilianPlan.doorId,null);assert.equal(n._residentVisitTargetId,null);assert.equal(n._residentDoor,null);assert.equal(released,1);
}
for(const [routeKind,agendaKind] of [['walk','walk'],['building_entry','shop'],['civilian_bench','bench']]){
 const b=setup(),n=make();n._routeKind=routeKind;n._route=[{r:11,c:10}];select(b,n,agendaKind==='shop'?'drive':'shop');const path=n._route;
 assert.equal(b._npcAgendaPick(n,0),agendaKind==='walk'?'walk':'ready');assert.equal(n._npcAgenda.current,agendaKind);assert.equal(n._route,path);assert(b._npcAgendaComplete(n,agendaKind,'arrived'));assert.notEqual(n._npcAgenda.current,agendaKind);
}
for(const state of [{dead:true},{hp:0},{_empireBoss:true},{police:true},{_gang:true},{_medicalDowned:true},{_playerConversationOpen:true},{panicUntil:1000}]){
 const b=setup(),n=Object.assign(make(),state);b._maybePlanResidentBuildingVisit=()=>assert.fail('ineligible executor');assert.equal(b._npcAgendaPick(n,10),null);assert.equal(n._npcAgenda,undefined);
}
{
 const b=setup(),n=make();b._walkRendererActive=()=>false;assert.equal(b._npcAgendaPick(n,0),null);assert.equal(n._npcAgenda,undefined);
}
console.log(JSON.stringify({pass:true,checks:['stable finite rotation','full/unavailable immediate fallback','no random gate in helper','pending target and frontier preserved and resumed','one atomic drive claim','trip destination consistency','active ownership','stale completion no-op','native and threat guards'],limits:'Unit state transitions only; world hooks/slots/physical navigation are integration responsibilities.'}));
