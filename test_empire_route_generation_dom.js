'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const world = fs.readFileSync('world.html', 'utf8');
const between = (start, end) => {
  const a = world.indexOf(start), b = world.indexOf(end, a);
  assert(a >= 0 && b > a, `missing production slice ${start}`);
  return world.slice(a, b);
};

const keyContext = vm.createContext({});
vm.runInContext(
  between('function _empireActivityGenerationKey(', 'function _empireActivityTarget('),
  keyContext,
);
const key = activity => vm.runInContext(
  `_empireActivityGenerationKey(${JSON.stringify(activity)},{hq_key:'1,2'})`, keyContext,
);
const base = {kind:'inspect', target_id:'coffee', created_at:75, target_r:10, target_c:20};
assert.equal(key(base), key({...base}));
assert.notEqual(key(base), key({...base, created_at:150}));
assert.notEqual(key(base), key({...base, kind:'patrol'}));
assert.notEqual(key(base), key({...base, target_id:'port'}));
assert.notEqual(key(base), key({...base, target_r:10.02}));
assert.equal(key(base), key({...base, target_r:10.004}));

const declarations = between('const _empireRoutePlanQueue=[];', 'function _empireCrewOrigin(');
const planner = between('function _planEmpireRouteTo(', 'function _empireBossReachedActivityTarget(');
let clears = 0;
const plannerContext = vm.createContext({
  console,
  document:{documentElement:{dataset:{}}},
  performance:{now:()=>1000},
  _empireBossWaypointPassable:()=>true,
  _clearNpcRoute:npc=>{clears++;npc._route=null;npc._routeGoalR=null;npc._routeGoalC=null;},
  _planNpcRouteTo:(npc,r,c)=>{npc._route=[{r,c}];npc._routeGoalR=r;npc._routeGoalC=c;return true;},
});
vm.runInContext(declarations + planner, plannerContext);

plannerContext.boss = {
  r:1,c:1,_empireRouteGeneration:2,_empireActionKey:'B',
  _route:[{r:8,c:8}],_routeGoalR:8,_routeGoalC:8,
  _empirePendingRoute:{goalR:4,goalC:4,goalRadius:.8,maxVisited:100,kind:'empire_action',failedBackoff:1000,generation:1,targetKey:'A'},
  _empireRouteQueued:true,
};
vm.runInContext('_empireRoutePlanQueue.push(boss);_processEmpireRoutePlanQueue(1000);', plannerContext);
assert.deepEqual(JSON.parse(JSON.stringify(plannerContext.boss._route)), [{r:8,c:8}]);
assert.equal(clears, 0);
assert.equal(plannerContext.document.documentElement.dataset.empireRouteStale, '1');

plannerContext.boss._empirePendingRoute={goalR:5,goalC:5,goalRadius:.8,maxVisited:100,kind:'empire_action',failedBackoff:1000,generation:2,targetKey:'A'};
plannerContext.boss._empireRouteQueued=true;
vm.runInContext('_empireRoutePlanQueue.push(boss);_processEmpireRoutePlanQueue(1100);', plannerContext);
assert.deepEqual(JSON.parse(JSON.stringify(plannerContext.boss._route)), [{r:8,c:8}]);
assert.equal(clears, 0);
assert.equal(plannerContext.document.documentElement.dataset.empireRouteStale, '2');

plannerContext.boss._empirePendingRoute={goalR:6,goalC:6,goalRadius:.8,maxVisited:100,kind:'empire_action',failedBackoff:1000,generation:2,targetKey:'B'};
plannerContext.boss._empireRouteQueued=true;
vm.runInContext('_empireRoutePlanQueue.push(boss);_processEmpireRoutePlanQueue(1200);', plannerContext);
assert.deepEqual(JSON.parse(JSON.stringify(plannerContext.boss._route)), [{r:6,c:6}]);
assert.equal(clears, 1);

plannerContext.boss._empirePendingRoute={goalR:7,goalC:7,goalRadius:.8,maxVisited:100,kind:'empire_escort',failedBackoff:1000,generation:2,targetKey:'leader-X'};
plannerContext.boss._empireRouteQueued=true;
vm.runInContext('_empireRoutePlanQueue.push(boss);_processEmpireRoutePlanQueue(1300);', plannerContext);
assert.deepEqual(JSON.parse(JSON.stringify(plannerContext.boss._route)), [{r:7,c:7}]);
assert.equal(clears, 2);

assert(world.includes("actionKey=action?_empireActivityGenerationKey(action,empire):''"));
assert(world.includes('npc._empireArrivedGeneration=-1'));
assert(world.includes('firstArrival=n._empireArrivedGeneration!==arrivalGeneration'));
assert(world.includes('if(firstArrival){n._empireArrivedGeneration=arrivalGeneration;'));
assert(!between('function _processEmpireRoutePlanQueue(', 'function _empireBossReachedActivityTarget(')
  .includes('_clearNpcRoute(npc);_empireRoutePlansBuilt++'));

console.log('empire route generation: 12/12 fingerprint, stale isolation and arrival idempotency OK');
