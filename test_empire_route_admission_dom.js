'use strict';

// Execute the production admission queue without a browser. The fixture pins
// observability only: one admitted BFS per call, latest-request coalescing and
// exact/partial/empty outcome classification.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const world = fs.readFileSync('world.html', 'utf8');
const declarationsStart = world.indexOf('const _empireRoutePlanQueue=[];');
const declarationsEnd = world.indexOf('function _empireCrewOrigin(', declarationsStart);
const plannerStart = world.indexOf('function _planEmpireRouteTo(');
const plannerEnd = world.indexOf('function _empireMovementWatch(', plannerStart);
assert(declarationsStart >= 0 && declarationsEnd > declarationsStart);
assert(plannerStart >= 0 && plannerEnd > plannerStart);

let outcome = 'exact';
const context = vm.createContext({
  console,
  document: {documentElement: {dataset: {}}},
  performance: {now: () => 1000},
  _empireBossPassable: () => true,
  _clearNpcRoute: npc => {
    npc._route = null; npc._routeGoalR = null; npc._routeGoalC = null;
  },
  _planNpcRouteTo: (npc, goalR, goalC) => {
    if (outcome === 'empty') return false;
    npc._route = [{r: goalR, c: goalC}];
    npc._routeGoalR = outcome === 'partial' ? goalR + 4 : goalR;
    npc._routeGoalC = goalC;
    return true;
  },
});
vm.runInContext(
  world.slice(declarationsStart, declarationsEnd) +
  world.slice(plannerStart, plannerEnd),
  context,
  {filename: 'world.html#empire-route-admission'},
);

vm.runInContext(`
  const first={r:1,c:1};
  _planEmpireRouteTo(first,10,10,.8,42000,'empire_action',4000,EMPIRE_ROUTE_REQUEST_REASON.ACTION_ROUTE_MISSING,'gang:7:100');
  _planEmpireRouteTo(first,10.24,10.24,.8,42000,'empire_action',4000,EMPIRE_ROUTE_REQUEST_REASON.ACTION_ROUTE_MISSING,'gang:7:100');
  if(_empireRoutePlanQueue.length!==1)throw new Error('coalescing duplicated queue entry');
  _processEmpireRoutePlanQueue(1000);
`, context);

outcome = 'partial';
vm.runInContext(`
  const second={r:2,c:2};
  _planEmpireRouteTo(second,20,20,.8,6000,'empire_escort',1200,EMPIRE_ROUTE_REQUEST_REASON.ESCORT_GOAL_DRIFT,'boss:2');
  _processEmpireRoutePlanQueue(1100);
`, context);

outcome = 'empty';
vm.runInContext(`
  const third={r:3,c:3};
  _planEmpireRouteTo(third,30,30,.8,9000,'empire_recruit',900,EMPIRE_ROUTE_REQUEST_REASON.RECRUIT,'boss:3');
  _processEmpireRoutePlanQueue(1200);
  if(third._empireRouteRetryAt!==2100)throw new Error('empty route lost its backoff');
`, context);

const result = vm.runInContext(`({
  queueLength:_empireRoutePlanQueue.length,
  built:_empireRoutePlansBuilt,
  deferred:_empireRoutePlansDeferred,
  counters:Array.from(_empireRoutePlanTotals),
  reasons:_empireRoutePlanReasonSummary(),
  kinds:_empireRoutePlanKindSummary(),
  firstPublish:_publishEmpireRoutePlanCounters(),
  duplicatePublish:_publishEmpireRoutePlanCounters(),
  admission:document.documentElement.dataset.empireRouteAdmission,
})`, context);
assert.deepEqual(JSON.parse(JSON.stringify(result)), {
  queueLength: 0,
  built: 3,
  deferred: 3,
  counters: [3, 1, 2, 1, 1, 1, 1],
  reasons: 'action-route-missing-2:escort-goal-drift-1:recruit-1',
  kinds: [
    'empire_action:q1,c1,a1,e1,p0,f0,i1',
    'empire_escort:q1,c0,a1,e0,p1,f0,i0',
    'empire_recruit:q1,c0,a0,e0,p0,f1,i0',
  ].join(';'),
  firstPublish: true,
  duplicatePublish: false,
  admission: 'one-per-frame:built-3:deferred-3:accepted-2:exact-1:partial-1:empty-1:coalesced-1:identical-1',
});
console.log('empire route admission observability: exact/partial/empty/coalesced OK');
