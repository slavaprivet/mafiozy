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

// The planner must validate the whole boss body, not only a tile centre.
let bodyChecks = 0;
const waypointContext = vm.createContext({
  _empireBossPassable: () => true,
  _npcBodyPassable: (_r, _c, pass) => { bodyChecks++; return pass(_r, _c); },
});
vm.runInContext(
  between('function _empireBossWaypointPassable(', 'function _nearestEmpireWalkPoint('),
  waypointContext,
);
assert.equal(vm.runInContext('_empireBossWaypointPassable(47.5,80.5)', waypointContext), true);
assert.equal(bodyChecks, 1);

// Execute the real route-admission code and retain exact/partial outcome per actor.
const declarations = between('const _empireRoutePlanQueue=[];', 'function _empireCrewOrigin(');
const planner = between('function _planEmpireRouteTo(', 'function _empireBossReachedActivityTarget(');
let outcome = 'exact';
const plannerContext = vm.createContext({
  console,
  document: {documentElement: {dataset: {}}},
  performance: {now: () => 1000},
  _empireBossWaypointPassable: () => true,
  _clearNpcRoute: npc => { npc._route = null; npc._routeGoalR = null; npc._routeGoalC = null; },
  _planNpcRouteTo: (npc, goalR, goalC) => {
    npc._route = [{r: goalR, c: goalC}];
    npc._routeGoalR = outcome === 'partial' ? goalR + 7 : goalR;
    npc._routeGoalC = goalC;
    return true;
  },
});
vm.runInContext(declarations + planner, plannerContext);
vm.runInContext(`
  globalThis.exactBoss={r:1,c:1};
  _planEmpireRouteTo(exactBoss,10,10,.8,42000,'empire_action');
  _processEmpireRoutePlanQueue(1000);
`, plannerContext);
assert.equal(plannerContext.exactBoss._empireRouteExact, true);
outcome = 'partial';
vm.runInContext(`
  globalThis.partialBoss={r:1,c:1};
  _planEmpireRouteTo(partialBoss,20,20,.8,42000,'empire_action');
  _processEmpireRoutePlanQueue(1100);
`, plannerContext);
assert.equal(plannerContext.partialBoss._empireRouteExact, false);
vm.runInContext(`
  globalThis.staleBoss={r:1,c:1,_empireRouteGeneration:4};
  _planEmpireRouteTo(staleBoss,30,30,.8,42000,'empire_action');
  staleBoss._empireRouteGeneration=5;
  _processEmpireRoutePlanQueue(1200);
  if(staleBoss._route)throw new Error('stale action route survived generation change');
  if(document.documentElement.dataset.empireRouteStale!=='1')throw new Error('stale route was not attributed');
`, plannerContext);

// Execute the real arrival predicate and watchdog with deterministic time.
const recoveryContext = vm.createContext({
  console,
  document: {documentElement: {dataset: {}}},
  performance: {now: () => 0},
  EMPIRE_ROUTE_REQUEST_REASON: {BLOCKED_RETRY: 12},
  _empireBossPassable: () => true,
  _clearNpcRoute: npc => { npc._route = null; npc._routeIndex = 0; },
  _npcPathPassable: () => false,
});
vm.runInContext(
  between('function _empireBossReachedActivityTarget(', 'function _empireActivityTarget('),
  recoveryContext,
);
assert.equal(vm.runInContext('_empireBossReachedActivityTarget({r:4,c:4},{r:4.7,c:4.2})', recoveryContext), true);
assert.equal(vm.runInContext('_empireBossReachedActivityTarget({r:4,c:4},{r:11,c:4})', recoveryContext), false);
assert.equal(vm.runInContext("_empireRecoverySide({_specialistId:'A'})", recoveryContext), 1);
assert.equal(vm.runInContext("_empireRecoverySide({_specialistId:'B'})", recoveryContext), -1);

const stalled = {
  id: 'boss-A', r: 10, c: 10, _route: [{r: 11, c: 10}],
  _empireProgressAt: 1000, _empireProgressR: 10, _empireProgressC: 10,
  _empireRouteRetryAt: 0,
};
recoveryContext.stalled = stalled;
assert.equal(vm.runInContext("_empireMovementWatch(stalled,{r:30,c:10},2000,'blocked')", recoveryContext), false);
assert.equal(vm.runInContext("_empireMovementWatch(stalled,{r:30,c:10},4401,'blocked')", recoveryContext), true);
assert.equal(stalled._route, null);
assert.equal(stalled._empireStallRecoveries || 0, 0);
assert.equal(stalled._empireNextRouteReason, 12);
assert.equal(stalled.r, 10, 'recovery must not cross an invalid surface');

const falseOnly = {id:'boss-false',r:5,c:5,_empireProgressAt:1000,_empireProgressR:5,_empireProgressC:5};
recoveryContext.falseOnly = falseOnly;
assert.equal(vm.runInContext("_empireMovementWatch(falseOnly,{r:25,c:5},5000,false)", recoveryContext), false);
assert.equal(falseOnly._empireRecoveryAttempts || 0, 0);

const moving = {
  id: 'boss-B', r: 10.2, c: 10, _route: [{r: 20, c: 10}],
  _empireProgressAt: 1000, _empireProgressR: 10, _empireProgressC: 10,
};
recoveryContext.moving = moving;
assert.equal(vm.runInContext("_empireMovementWatch(moving,{r:30,c:10},4401,true)", recoveryContext), false);
assert.equal(moving._empireStallRecoveries || 0, 0);

// A partial endpoint can never resolve gameplay arrival or raid breach.
assert(!world.includes("if(moved==='arrived'||Math.hypot(n.r-target.r,n.c-target.c)<1.05)"));
assert(world.includes("else if(moved==='arrived'){"));
assert(world.includes("n._empireActionArrived=false"));
assert(world.includes("_empirePartialRecoveries"));
assert(world.includes("if(!recovered&&_empireBossReachedActivityTarget(n,target))"));
assert(world.includes("_empireRouteGeneration=(+npc._empireRouteGeneration||0)+1"));
assert(world.includes("request.generation!=="));
assert(world.includes("_empireRecoveryAttempts||0)>=3"));
assert(!world.includes("_empireMovementWatch(n,target,now,moved);continue;"));

// Preserve the bounded one-BFS-per-frame queue and protected city/bridge surfaces.
const admissionSource = between('function _processEmpireRoutePlanQueue(', 'function _empireBossReachedActivityTarget(');
assert(admissionSource.includes('return true;'));
assert(admissionSource.includes('return false;'));
assert(world.includes('tile===14||tile===15||tile===17||tile===18||tile===19'));
assert(world.includes('_processEmpireRoutePlanQueue(now);'));
assert(world.includes('previewBossBridge()'));
assert(world.includes("dataset.previewBossBridge="));
assert(world.includes("dataset.empireBossMotionAll="));
assert(world.includes("_UP.has('previewbossbridge')"));
assert(world.includes('&melee=smart-heavy-forward-kick-v16'));
console.log('empire boss stall recovery: 12/12 deterministic gates OK');
