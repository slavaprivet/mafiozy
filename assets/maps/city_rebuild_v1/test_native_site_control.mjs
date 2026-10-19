import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createNativeSiteCatalog,nativeSiteId,planNativeSiteCapture,planNativeHeadquarters} from './native_site_control.mjs';

const placement=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',import.meta.url)));
const house=placement.instances.find(instance=>instance.role==='residence');
const bank=placement.instances.find(instance=>instance.gameplayId==='bank:small');
assert(house&&bank);const before=JSON.stringify(placement);
// Simple entry boundary isolates authority tests. Real GLB geometry is exercised
// independently in test_native_site_control_geometry.mjs.
const entry=instance=>({instance,containsInterior:p=>p.x>0&&p.x<4&&p.z>0&&p.z<4,approachPoint:()=>({x:2,y:0,z:-1}),floorHeight:()=>0,ceilingHeight:()=>3});
const manifestRevision='test-current-placement';
const catalog=createNativeSiteCatalog({manifestRevision,entries:[entry(house),entry(bank)],policies:[{instanceId:house.id,capturable:true,headquartersEligible:true}]});
const siteId=nativeSiteId(house.id),request={siteId,factionId:'leila',operationId:'capture:1'};
const actor={id:'guard-real-17',factionId:'leila',disposition:'attacker',alive:true,combatReady:true,insideSiteId:siteId};
const state={manifestRevision,siteId,revision:4,defenceRevision:9,ownerFactionId:'rival',claimantFactionId:'leila',defendersComplete:true,remainingHostileDefenderIds:[],occupantsComplete:true,occupants:[actor]};
const original=structuredClone(state);
const capture=planNativeSiteCapture(catalog,state,request);assert(capture.ok);
assert.equal(capture.intent.expectedOwnerFactionId,'rival');assert.equal(capture.intent.expectedRevision,4);
assert.equal(capture.intent.expectedDefenceRevision,9);assert.deepEqual(capture.intent.enteredActorIds,[actor.id]);
assert.deepEqual(state,original,'planning never changes owner or combat facts');
assert.equal(JSON.stringify(placement),before,'geometry, placement and original gameplay IDs unchanged');
assert.equal(planNativeSiteCapture(catalog,{...state,remainingHostileDefenderIds:['offscreen-guard']},request).reason,'defenders-remain');
assert.equal(planNativeSiteCapture(catalog,{...state,defendersComplete:false},request).reason,'defenders-unknown');
assert.equal(planNativeSiteCapture(catalog,{...state,occupantsComplete:false},request).reason,'occupants-unknown');
for(const occupants of [[],[{...actor,insideSiteId:'native-site:other'}],[{...actor,alive:false}],[{...actor,combatReady:false}]])
 assert.equal(planNativeSiteCapture(catalog,{...state,occupants},request).reason,'physical-entry-required');
assert.equal(planNativeSiteCapture(catalog,{...state,occupants:[actor,{...actor,id:'rival',factionId:'rival',disposition:'hostile'}]},request).reason,'site-contested');
assert.equal(planNativeSiteCapture(catalog,{...state,occupants:[{...actor,alive:undefined}]},request).reason,'occupants-unknown');
assert.equal(planNativeSiteCapture(catalog,{...state,ownerFactionId:'leila'},request).reason,'already-owned');
assert.equal(planNativeSiteCapture(catalog,state,{...request,siteId:nativeSiteId(bank.id)}).reason,'site-not-capturable','bank is not claimed merely because it has an existing alias');
assert.equal(planNativeSiteCapture(catalog,{...state,siteId:'wrong'},request).reason,'authority-unavailable');
assert.equal(planNativeSiteCapture(catalog,{...state,revision:NaN},request).reason,'authority-unavailable');
assert.equal(planNativeSiteCapture(catalog,{...state,manifestRevision:'stale'},request).reason,'manifest-changed');
assert.equal(planNativeSiteCapture(catalog,{...state,claimantFactionId:'rival'},request).reason,'claimant-mismatch');
assert.equal(planNativeSiteCapture(catalog,{...state,claimantFactionId:undefined},request).reason,'claimant-mismatch');
assert.equal(capture.intent.expectedManifestRevision,manifestRevision);

for(const factionId of ['ally',null]){
 const visitor={...actor,id:'nonblocking-visitor',factionId,disposition:'nonblocking'};
 assert(planNativeSiteCapture(catalog,{...state,occupants:[actor,visitor]},request).ok,'explicit host-classified ally/civilian does not contest');
 assert.equal(planNativeSiteCapture(catalog,{...state,occupants:[actor,{...visitor,disposition:undefined}]},request).reason,'occupants-unknown','unknown disposition never becomes implicit neutrality');
 assert.equal(planNativeSiteCapture(catalog,{...state,occupants:[{...visitor,disposition:'attacker'}]},request).reason,'occupants-unknown','claimant mismatch cannot prove entry');
 assert.equal(planNativeSiteCapture(catalog,{...state,occupants:[visitor]},request).reason,'physical-entry-required','nonblocking occupant cannot substitute for a claimant');
}
for(const remainingHostileDefenderIds of [new Array(1),['guard','guard'],['guard',undefined]])
 assert.equal(planNativeSiteCapture(catalog,{...state,remainingHostileDefenderIds},request).reason,'defenders-unknown');

const headquarters={factionId:'leila',siteId:'native-site:previous-hq',revision:7};
assert.equal(planNativeHeadquarters(catalog,state,headquarters,request).reason,'capture-required');
const owned={...state,ownerFactionId:'leila'},hq=planNativeHeadquarters(catalog,owned,headquarters,{...request,operationId:'hq:1'});
assert(hq.ok);assert.equal(hq.intent.expectedHeadquartersSiteId,headquarters.siteId);
assert.equal(hq.intent.expectedHeadquartersRevision,7);assert.equal(headquarters.siteId,'native-site:previous-hq','planning does not silently destroy old headquarters');
assert.equal(planNativeHeadquarters(catalog,owned,{...headquarters,siteId},request).reason,'already-headquarters');
assert.equal(planNativeHeadquarters(catalog,owned,{...headquarters,factionId:'rival'},request).reason,'headquarters-authority-unavailable');
assert.equal(planNativeHeadquarters(catalog,{...owned,remainingHostileDefenderIds:['reinforcement']},headquarters,request).reason,'defenders-remain');
assert(planNativeHeadquarters(catalog,{...owned,occupants:[actor,{...actor,id:'own-garrison',disposition:'nonblocking'}]},headquarters,request).ok,'own stationed guard does not block HQ when hostile defenders are absent');
assert.equal(planNativeHeadquarters(catalog,{...owned,claimantFactionId:'rival'},headquarters,request).reason,'claimant-mismatch');

const duplicate=createNativeSiteCatalog({manifestRevision,entries:[entry(house),entry(house)],policies:[{instanceId:house.id,capturable:true}]});
assert.equal(planNativeSiteCapture(duplicate,state,request).reason,'site-ambiguous');
const unloaded=createNativeSiteCatalog({manifestRevision});assert.equal(planNativeSiteCapture(unloaded,state,request).reason,'site-missing');
assert.throws(()=>createNativeSiteCatalog({manifestRevision,policies:[{instanceId:house.id},{instanceId:house.id}]}),/duplicate/);
assert.throws(()=>createNativeSiteCatalog(),/manifest revision/);
assert(!catalog.contains(siteId,{x:2,y:0,z:-.01}),'facade proximity does not prove entry');
assert(catalog.contains(siteId,{x:2,y:0,z:2}));assert(!catalog.contains(siteId,{x:2,y:4,z:2}));
assert(!catalog.contains(siteId,{x:NaN,y:0,z:2}));
for(const y of [-.151,.151,1,3,20])assert(!catalog.contains(siteId,{x:2,y,z:2}),'XZ inside is not supported feet at y='+y);
for(const y of [-.15,0,.15])assert(catalog.contains(siteId,{x:2,y,z:2}),'bounded floor sampling tolerance at y='+y);
for(const missing of ['floorHeight','ceilingHeight']){
 const incomplete={...entry(house),[missing]:undefined},c=createNativeSiteCatalog({manifestRevision,entries:[incomplete],policies:[{instanceId:house.id,capturable:true}]});
 assert(!c.get(siteId).capturable);assert(!c.contains(siteId,{x:2,y:0,z:2}),'missing geometry fails closed');
}
for(const bad of [null,undefined,NaN,Infinity])for(const method of ['floorHeight','ceilingHeight']){
 const broken={...entry(house),[method]:()=>bad},c=createNativeSiteCatalog({manifestRevision,entries:[broken]});
 assert(!c.contains(siteId,{x:2,y:0,z:2}),'unknown '+method+' fails closed');
}
const throws=createNativeSiteCatalog({manifestRevision,entries:[{...entry(house),floorHeight(){throw new Error('entry unavailable')}}]});
assert(!throws.contains(siteId,{x:2,y:0,z:2}),'unavailable geometry fails closed');
assert(Object.isFrozen(catalog.get(siteId))&&Object.isFrozen(capture.intent)&&Object.isFrozen(capture.intent.enteredActorIds));
console.log('PASS native site control: complete guards, physical entry, contested capture, immutable versioned intents, ownership-before-HQ, explicit eligibility and identity isolation. No persistence/commit or LIVE claimed.');
