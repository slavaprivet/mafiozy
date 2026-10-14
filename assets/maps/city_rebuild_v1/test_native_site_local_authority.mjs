import assert from 'node:assert/strict';
import test from 'node:test';
import {createNativeSiteCatalog,nativeSiteId} from './native_site_control.mjs';
import {createNativeSiteLocalAuthority} from './native_site_local_authority.mjs';
function fixture(maxReceipts=256){
 const siteId=nativeSiteId('local-explicit-house'),catalog=createNativeSiteCatalog({manifestRevision:'local-geometry-v1',entries:[{instance:{id:'local-explicit-house'},containsInterior:()=>true,floorHeight:()=>0,ceilingHeight:()=>3,approachPoint:()=>({x:0,y:0,z:0})}],policies:[{instanceId:'local-explicit-house',capturable:true,headquartersEligible:true}]});
 let local=true,claimant={actorId:'player-one',factionId:'leila',canManage:true};
 let facts={manifestRevision:catalog.manifestRevision,claimantFactionId:'leila',defenceRevision:0,defendersComplete:true,remainingHostileDefenderIds:['source-guard'],occupantsComplete:true,occupants:[{id:'player-one',factionId:'leila',disposition:'attacker',alive:true,combatReady:true,insideSiteId:siteId}]};
 const host=createNativeSiteLocalAuthority({catalog,siteId,initialOwnerFactionId:'marat',isLocalPreview:()=>local,readClaimant:()=>claimant,readFacts:()=>facts,maxReceipts});
 const request=(action,operationId)=>{const current=host.inspect();return {siteId,action,operationId,expectedRevision:current.revision,expectedDefenceRevision:current.defenceRevision,...(action==='headquarters'?{expectedHeadquartersRevision:current.headquarters.revision}:{})};};
 return {host,request,siteId,setLocal:value=>local=value,setFacts:patch=>facts={...facts,...patch},setClaimant:value=>claimant=value};
}
test('complete living source guard blocks; missing evidence never grants ownership',()=>{
 const f=fixture();assert.equal(f.host.execute(f.request('capture','guard-alive')).reason,'defenders-remain');
 f.setFacts({defendersComplete:false,remainingHostileDefenderIds:[]});assert.equal(f.host.execute(f.request('capture','guard-not-loaded')).reason,'defenders-unknown');
 f.setFacts({defendersComplete:true,occupantsComplete:false});assert.equal(f.host.execute(f.request('capture','occupants-not-loaded')).reason,'occupants-unknown');
 assert.equal(f.host.inspect().revision,0);assert.equal(f.host.inspect().ownerFactionId,'marat');
});
test('capture, HQ, competing capture and loss of HQ commit once with replay receipts',()=>{
 const f=fixture();f.setFacts({remainingHostileDefenderIds:[],defenceRevision:1});
 const request=f.request('capture','capture-1'),receipt=f.host.execute(request);
 assert.equal(receipt.ok,true);assert.equal(receipt.ownerFactionId,'leila');assert.equal(receipt.revision,1);assert.equal(receipt.persistent,false);
 assert.strictEqual(f.host.execute(request),receipt);assert.equal(f.host.execute({...request,action:'headquarters'}).reason,'operation-conflict');
 const hqRequest=f.request('headquarters','hq-1'),hqReceipt=f.host.execute(hqRequest);assert.equal(hqReceipt.headquarters.siteId,f.siteId);assert.equal(hqReceipt.headquarters.revision,1);
 assert.strictEqual(f.host.execute(hqRequest),hqReceipt);
 f.setClaimant({actorId:'player-two',factionId:'marat',canManage:true});
 f.setFacts({claimantFactionId:'marat',occupants:[{id:'player-two',factionId:'marat',disposition:'attacker',alive:true,combatReady:true,insideSiteId:f.siteId}]});
 assert.equal(f.host.execute(request).reason,'operation-conflict');
 const second=f.host.execute(f.request('capture','capture-2'));assert.equal(second.ownerFactionId,'marat');assert.equal(second.revision,2);
 assert.deepEqual(second.displacedHeadquarters,{factionId:'leila',siteId:null,revision:2});
 f.setClaimant({actorId:'player-one',factionId:'leila',canManage:true});
 assert.deepEqual(f.host.inspect().headquarters,{factionId:'leila',siteId:null,revision:2});
 assert.equal(receipt.ownerFactionId,'leila','old receipt immutable after newer capture');
});
test('stale defence/owner versions, forbidden actor, auth gate and disposed host fail closed',()=>{
 const f=fixture();f.setFacts({remainingHostileDefenderIds:[]});const stale=f.request('capture','stale');f.setFacts({defenceRevision:1});
 assert.equal(f.host.execute(stale).reason,'version-changed');
 const request=f.request('capture','valid');assert.equal(f.host.execute({...request,expectedRevision:9}).reason,'version-changed');
 f.setLocal(false);assert.equal(f.host.execute(request).reason,'local-authority-unavailable');f.setLocal(true);
 f.setClaimant({actorId:'player-one',factionId:'leila',canManage:false});assert.equal(f.host.execute(request).reason,'claimant-unavailable');
 f.setClaimant({actorId:'player-one',factionId:'leila',canManage:true});assert.equal(f.host.execute(request).ok,true);
 f.host.dispose();assert.equal(f.host.execute(request).reason,'disposed');
});
test('bounded receipt storage never evicts idempotency evidence to allow a second mutation',()=>{
 const f=fixture(1);f.setFacts({remainingHostileDefenderIds:[]});const request=f.request('capture','one'),receipt=f.host.execute(request);
 assert.equal(f.host.execute(f.request('headquarters','two')).reason,'receipt-capacity');assert.strictEqual(f.host.execute(request),receipt);
 assert.equal(f.host.inspect().headquarters.siteId,null);
});
