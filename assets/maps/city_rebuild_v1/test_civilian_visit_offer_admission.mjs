import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {sourceFunction} from './test_civilian_native_fixture.mjs';

const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
const box={Math};vm.createContext(box);
vm.runInContext(sourceFunction(source,'_civilianPlanUnit')+sourceFunction(source,'_civilianVisitOfferReady'),box);

const now=5000,plans=[];
let admitted=0;
for(let i=0;i<288;i++){
  const npc={id:`resident_${i}`},plan={phase:'seek_shop',cycle:0,retryAt:0};
  if(box._civilianVisitOfferReady(npc,plan,now,.26))admitted++;
  else{
    assert(plan.retryAt>=now+8000&&plan.retryAt<=now+20000,'declined visit receives a bounded staggered retry');
    plans.push({npc,plan});
  }
}
assert(admitted>=55&&admitted<=95,`expected a mixed startup population, got ${admitted}/288 building offers`);
assert(plans.length>=193,'most residents remain available for ordinary city walking');

const sample=plans[0],retry=sample.plan.retryAt;
assert.equal(box._civilianVisitOfferReady(sample.npc,sample.plan,now,.26),false,'same offer is deterministic');
assert.equal(sample.plan.retryAt,retry,'same frame cannot keep pushing the retry into the future');

const laterAccepted=plans.some(({npc,plan})=>{
  for(let t=15000;t<=300000;t+=15000){plan.retryAt=0;if(box._civilianVisitOfferReady(npc,plan,t,.26))return true;}
  return false;
});
assert(laterAccepted,'declined residents receive later visit opportunities');
console.log(`PASS civilian visit admission: ${admitted}/288 new building visits, ${288-admitted}/288 residents free to walk, recurring deterministic offers`);
