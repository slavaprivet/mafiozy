import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createCityRoadDressingPlan} from './city_road_dressing_plan.mjs';
import {createLandscapePlan} from './landscape_plan.mjs';
import {createExplorationRailwayPlan} from './exploration_railway_plan.mjs';

const read=name=>JSON.parse(readFileSync(new URL(name,import.meta.url))),topology=read('topology_for_placement.json'),landscape=createLandscapePlan(),railPlan=createExplorationRailwayPlan({topology,landscape});
const plan=createCityRoadDressingPlan({topology,landscape,railPlan,instances:[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances]}),approaches=new Map(plan.junctionRules.flatMap(j=>j.approaches).map(a=>[a.id,a]));
// These are actual neighbouring intersections from the user's East-Side view.
// The local crossing stays equal, while the next entry into A-NORTH still yields.
const local=approaches.get('street-junction-297:L-EA-V-032:0:-1'),mainEntry=approaches.get('street-junction-24:L-EA-V-032:0:-1');
assert.equal(local.rule,'priority_right');assert.equal(local.signId,null);
assert.equal(mainEntry.rule,'yield');assert.equal(mainEntry.internalJunctionLink,false);assert.ok(mainEntry.signId||mainEntry.yieldIndication==='painted_triangle');
const eastLocal=approaches.get('street-junction-23:L-EA-V-031:0:-1');assert.equal(eastLocal.rule,'yield','a parallel local street does not inherit A-EAST-RING priority over A-NORTH');
const driveway=approaches.get('street-junction-300:AL-015:0:1');assert.equal(driveway.rule,'yield');assert.equal(driveway.yieldIndication,'driveway_rule');assert.equal(driveway.signId,null);
for(const a of approaches.values())if(a.yieldIndication==='driveway_rule')assert.ok(!plan.markings.some(m=>m.approachId===a.id&&m.kind.startsWith('yield')),'ordinary courtyard exits retain implicit yielding without redundant street equipment');
let mouthChecks=0,sharedApproaches=0;
for(const sign of plan.signs.filter(s=>s.kind==='yield')){
  const a=approaches.get(sign.approachId),dx=sign.x-a.controlCenter.x,dz=sign.z-a.controlCenter.z,along=dx*a.outward.x+dz*a.outward.z,right=dx*a.outward.z-dz*a.outward.x;
  assert.ok(along>=-1e-7&&along<=6+1e-7,'yield pole stays beside its approach instead of a neighbouring junction');
  assert.ok(right>0&&right<=a.width/2+2.5+1e-7,'yield pole stays on its own right verge');
  mouthChecks++;
  for(const id of sign.approachIds){const member=approaches.get(id);assert.equal(member.signId,sign.id);assert.equal(member.roadId,sign.roadId);assert.equal(member.rule,'yield');if(id!==sign.approachId)sharedApproaches++;}
}
assert.ok(sharedApproaches>0,'duplicate authored approaches share one pole');
assert.equal(plan.placementUnresolved.length,0);
const nearby=r=>plan.signs.filter(s=>s.kind==='yield'&&Math.hypot(s.x-611,s.z-83)<r).length;
assert.ok(nearby(40)<3,'the three old foreground poles are not recreated');
console.log(JSON.stringify({status:'PASS',mouthChecks,sharedApproaches,yieldSigns:mouthChecks,nearby40:nearby(40),nearby60:nearby(60),allSigns:plan.signs.length}));
