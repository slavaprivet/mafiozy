import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';

const world=fs.readFileSync('world.html','utf8');
const source=fs.readFileSync('assets/maps/city_rebuild_v1/npc_civilian_activity_source.js','utf8');
const fn=name=>{const start=world.indexOf('function '+name+'(');assert(start>=0);return world.slice(start,world.indexOf('\n}',start)+2);};
function fixture(legacy=false){
 const box={NPCS:[],performance:{now:()=>1000},_npcStableUnit:()=>.5,
  _walkNpcNavigationResolver:()=>({blocked:false,depth:0,surface:'land'}),
  _npcPathPassable:()=>true,npcPassableForSnitch:()=>true,npcCarriedGun:()=>false,
  _npcConversationFor:(a,b)=>({speaker:a,listener:b}),
  _cancelNpcDirectedSearch:()=>assert.fail('optional activity cancelled a pending owner'),
  _civilianPlanCancel:()=>assert.fail('optional activity cancelled a reservation')};
 vm.createContext(box);
 for(const name of ['_npcLifeEligible','_residentCanSocialize','_clearNpcRoute','_setNpcRoute'])vm.runInContext(fn(name),box);
 const code=legacy?source.replace(/ if\(n\?\._route\?\.length&&\['building_entry','civilian_bench','civilian_road_exit'\].*?return false;\n/,''):source;
 vm.runInContext(code,box);
 function actor(kind='walk',col=5){
  const n={id:'resident_'+box.NPCS.length,r:5,c:col,hp:100,max_hp:100,_arcKey:'worker',walking:true,
   _npcAgenda:{current:kind==='building_entry'?'shop':kind==='civilian_bench'?'bench':'walk',started:true},
   _civilianPlan:{phase:kind==='building_entry'?'walk_to_shop':kind==='civilian_bench'?'walk_to_bench':'wander',doorId:kind==='building_entry'?'real-shop':null,benchId:kind==='civilian_bench'?'real-bench':null}};
  box._setNpcRoute(n,[{r:5,c:col+.5},{r:5,c:col+1},{r:5,c:col+1.5},{r:5,c:col+2}],kind);box.NPCS.push(n);return n;
 }
 return{box,actor};
}

// Before the guard, the actual module discarded both published destinations.
const old=fixture(true),oldBench=old.actor('civilian_bench'),oldShop=old.actor('building_entry',6);
assert(old.box._npcStartCivilianConversation(oldBench,oldShop,1000));
assert.equal(oldBench._route,null);assert.equal(oldShop._route,null);
assert.equal(oldBench._civilianActivity.resumeRoute,null);assert.equal(oldShop._civilianActivity.resumeRoute,null);
assert.equal(oldBench._civilianPlan.benchId,'real-bench');assert.equal(oldShop._civilianPlan.doorId,'real-shop');

for(const kind of ['building_entry','civilian_bench','civilian_road_exit']){
 const f=fixture(),n=f.actor(kind),partner=f.actor('walk',6),route=n._route,plan=n._civilianPlan,agenda=n._npcAgenda;
 const before=JSON.stringify({route,plan,agenda});
 assert(!f.box._npcCivilianActivityEligible(n,1000));
 assert(!f.box._npcStartCivilianConversation(n,partner,1000));
 assert(!f.box._npcStartStandingSmoke(n,1000));
 for(const activity of ['jog','stretch','squat','lookaround'])assert(!f.box._npcStartOutdoorRoutine(n,activity,1000));
 assert.equal(n._route,route);assert.equal(n._civilianPlan,plan);assert.equal(n._npcAgenda,agenda);
 assert.equal(JSON.stringify({route:n._route,plan:n._civilianPlan,agenda:n._npcAgenda}),before,'route and reserved target remain unchanged');assert.equal(n._civilianActivity,undefined);
}

const walking=fixture(),a=walking.actor(),b=walking.actor('walk',6);
assert(walking.box._npcStartCivilianConversation(a,b,1000),'ordinary walkers may still talk');
for(const activity of ['smoke','jog','stretch','squat','lookaround']){
 const f=fixture(),n=f.actor();assert(activity==='smoke'?f.box._npcStartStandingSmoke(n,1000):f.box._npcStartOutdoorRoutine(n,activity,1000),'ordinary walk retains '+activity);
}
for(const arc of ['pensioner','oldman','oldwoman']){
 const f=fixture(),n=f.actor();n._arcKey=arc;
 for(const kind of ['jog','stretch','squat'])assert(!f.box._npcStartOutdoorRoutine(n,kind,1000),arc+' excludes '+kind);
 assert(f.box._npcStartOutdoorRoutine(n,'lookaround',1000),arc+' can look around');
}
assert.match(world,/pensioner:\s*\{\s*speedRange:/,'pensioner is an actual source archetype');
for(const field of ['_residentNativeVisit','_residentIndoors','_civilianSeat']){
 const f=fixture(),n=f.actor();n[field]={};assert(!f.box._npcCivilianActivityEligible(n,1000),'existing visit/seat owner preserved');
}
console.log('PASS actual activity helper: reproduces old conversation route loss; protects shop/bench/road-exit journeys; ordinary walk leisure remains; actual pensioner policy; visit and seat ownership. CPU/source only, no LIVE claim.');
