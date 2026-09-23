import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {refreshEmpireCachedTargets23,cachedTargetRegistration23,buildCachedTargetCandidate23} from './npc_cached_target23_candidate.mjs';
import {sourceFunction} from './assets/maps/city_rebuild_v1/test_civilian_native_fixture.mjs';

// Lifecycle/ownership boundary tests. Physical geometry is independently covered
// by --refresh-candidate replay of the actual six invalid and thirteen valid goals.
const world=fs.readFileSync('world.html','utf8');
const deployed=world.includes('function refreshEmpireCachedTargets23()');
if(process.argv.includes('--require-fixed'))assert(deployed,'production helper is installed');
const registrationSource=deployed?world.split('\n').find(line=>line.trimStart().startsWith('registerWalkNpcNavigationResolver(resolver){')).trim().replace(/,$/,''):cachedTargetRegistration23(world);
const refreshSource=deployed?sourceFunction(world,'refreshEmpireCachedTargets23'):refreshEmpireCachedTargets23.toString();
let cases=0;
function fixture(change={}) {
  const target={r:10,c:10},n={id:'unique_boss',r:11,c:12,hp:100,_specialistId:'boss',_empireBoss:true,
    _empireAction:{kind:'patrol',target_id:'offline:boss',target_r:10,target_c:10},
    _empireActionKey:'patrol:offline:boss:offline',_empireRouteGeneration:7,
    _empireTarget:target,_empireActivityBaseTarget:target,_empireRouteQueued:true,
    _empirePendingRoute:{goalR:10,goalC:10,goalRadius:.8,maxVisited:42000,kind:'empire_action',failedBackoff:4000,generation:7,targetKey:'patrol:offline:boss:offline'},
    _route:[{r:10,c:10}],_routeKind:'empire_action',_routeSearchKind:'empire_action',_routeSearchPending:true,
    _npcDirectedSearch:{key:'old-frontier'},walking:true,...change};
  let queries=0,placements=0;
  const older={id:'older'},younger={id:'younger'};
  const box={Math,Number,String,Date,performance:{now:()=>1000},SPECIALIST_NPCS:[n],
    _walkNpcNavigationResolver:null,_walkRendererActive:()=>true,_npcInitialSafePlacement:()=>{placements++;},
    _npcRouteWorkQueue:new Map([[older,1],[n,1],[younger,1]]),_npcRouteWorkBatch:new Set([older,n]),
    _empireRoutePlanQueue:[older,n,younger],
    _empireTargetFootprintPassable23:(r,c)=>{queries++;return r!==10||c!==10;},
    _nearestEmpireWalkPoint:()=>({r:9.5,c:10.5})};
  vm.createContext(box);
  vm.runInContext(sourceFunction(world,'_clearNpcRoute')+'\n'+sourceFunction(world,'_pauseEmpireMovementWatch')+'\n'+refreshSource+'\nglobalThis.bridge={'+registrationSource+'};',box);
  return{box,n,query:()=>({surface:'land'}),queries:()=>queries,placements:()=>placements};
}
function check(name,fn){fn();cases++;console.log('PASS',name);}
check('ready registration preserves action/generation, positions and both queue orders',()=>{
  const {box,n,query,queries}=fixture(),action=n._empireAction,oldRequest=n._empirePendingRoute;
  const queue=[...box._npcRouteWorkQueue.keys()],batch=[...box._npcRouteWorkBatch],empire=[...box._empireRoutePlanQueue];
  assert(box.bridge.registerWalkNpcNavigationResolver(query));
  assert.equal(n._empireAction,action);assert.equal(n._empireRouteGeneration,7);
  assert.equal(n._empireActionKey,oldRequest.targetKey);assert.equal(n.r,11);assert.equal(n.c,12);
  assert.deepEqual({...n._empireTarget},{r:9.5,c:10.5});assert.equal(n._empireActivityBaseTarget,n._empireTarget);
  assert.deepEqual({...n._empirePendingRoute},{...oldRequest,goalR:9.5,goalC:10.5});
  assert.equal(n._empireRouteQueued,true);assert.equal(n._npcDirectedSearch,null);assert.equal(n._routeSearchPending,false);assert.equal(n._route,null);
  assert.deepEqual([...box._npcRouteWorkQueue.keys()],queue);assert.deepEqual([...box._npcRouteWorkBatch],batch);assert.deepEqual(box._empireRoutePlanQueue,empire);
  const before=queries();box.bridge.registerWalkNpcNavigationResolver(query);assert.equal(queries(),before);
});
const exclusions=[{_fighting:true},{_fightingMelee:true},{_hostile:true},{_empirePlayerWar:true},{_empireEnemyLeaderId:'rival'},
  {_empireCombatTarget:{}},{_empireFieldEncounterStatus:'active'},{_policeCuffed:true},
  {panicUntil:2000},{_knockedUntil:2000},{_meleeStunnedUntil:2000},{_empireDownUntil:2000},{_empireHospitalUntil:Date.now()+60000},
  {_civilianTrip:{}},{_civilianTripRiding:true},{_inVehicle:true},{_inCar:true},{vehicleId:'car'},{vehicle_id:'car'},
  {_responseVehicleId:'car'},{_civilianSeat:'driver'},{_transportBoarded:true},{_ambientTrafficPhase:'drive'},{_vehicleHijackControlled:true},
  {_residentNativeVisit:{}},{_residentIndoors:true},{_insideBuilding:true},{_interiorId:'shop'},
  {_empireStreetNegotiation:{}},{_playerConversationOpen:true},{_corpsePhoneCall:{}},
  {dead:true},{alive:false},{hp:0},{_hiddenByEmpire:true},{_medicalDowned:true},{_carriedByAmbulance:true},{_evacuated:true},
  {_routeKind:'building_entry'},{_routeSearchKind:'empire_recruit'},
  {_empireAction:{kind:'collect',target_id:'business'}},{_empireAction:{kind:'patrol',target_id:'server:district'}}];
check('combat, vehicles, medical and other owners remain byte-for-byte unchanged',()=>{
  for(const exclusion of exclusions){const f=fixture(exclusion),before=JSON.stringify(f.n);f.box.bridge.registerWalkNpcNavigationResolver(f.query);assert.equal(JSON.stringify(f.n),before,JSON.stringify(exclusion));assert.equal(f.queries(),0);}
});
check('other pending owner and stale generation/key are protected',()=>{
  for(const changes of [{kind:'empire_escort'},{generation:6},{targetKey:'other-order'}]){
    const f=fixture();Object.assign(f.n._empirePendingRoute,changes);const before=JSON.stringify(f.n);
    f.box.bridge.registerWalkNpcNavigationResolver(f.query);assert.equal(JSON.stringify(f.n),before);assert.equal(f.queries(),0);
  }
});
check('no replacement does not discard current state or queued work',()=>{
  const f=fixture(),before=JSON.stringify(f.n);f.box._nearestEmpireWalkPoint=()=>null;
  f.box.bridge.registerWalkNpcNavigationResolver(f.query);assert.equal(JSON.stringify(f.n),before);
});
check('valid target and independent activity base remain unchanged',()=>{
  const f=fixture({_empireTarget:{r:8,c:8}}),before=JSON.stringify(f.n);
  f.box.bridge.registerWalkNpcNavigationResolver(f.query);assert.equal(JSON.stringify(f.n),before);
  const g=fixture({_empireActivityBaseTarget:{r:7,c:7}}),base=g.n._empireActivityBaseTarget;
  g.box.bridge.registerWalkNpcNavigationResolver(g.query);assert.equal(g.n._empireActivityBaseTarget,base);
});
check('invalid registration and inactive renderer do not run repair; null detaches',()=>{
  const f=fixture(),before=JSON.stringify(f.n);
  assert.equal(f.box.bridge.registerWalkNpcNavigationResolver(4),false);
  f.box._walkRendererActive=()=>false;assert.equal(f.box.bridge.registerWalkNpcNavigationResolver(f.query),false);
  assert.equal(f.box.bridge.registerWalkNpcNavigationResolver(null),true);
  assert.equal(f.queries(),0);assert.equal(f.placements(),0);assert.equal(JSON.stringify(f.n),before);
});
check('reviewable patch contains one helper, one registration call and full-footprint dependency',()=>{
  const built=deployed?world:buildCachedTargetCandidate23(world);
  assert.equal(built.split('function refreshEmpireCachedTargets23()').length-1,1);
  assert.equal(built.split('if(changed)refreshEmpireCachedTargets23();').length-1,1);
  assert.equal(built.split('function _empireTargetFootprintPassable23(').length-1,1);
  assert(built.includes('function _cancelEmpireEscortRoute('),'prior escort patch retained');
});
const report={candidateOnly:!deployed,actualDeployedSource:deployed,cases,excludedStates:exclusions.length,physicalRegression:'Separate actual six-target replay and thirteen unchanged target checks.'};
fs.writeFileSync('outputs/npc_cached_target23_candidate.json',JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));
