// Independent synchronous callback/lifetime regression tests. No world or DB.
import assert from 'node:assert/strict';
import test from 'node:test';
import {createNativeSiteCatalog,nativeSiteId} from './native_site_control.mjs';
import {createNativeSiteLocalAuthority} from './native_site_local_authority.mjs';
function fixture(onRead){
 const siteId=nativeSiteId('callback-audit20');
 const catalog=createNativeSiteCatalog({manifestRevision:'audit20-v1',entries:[{instance:{id:'callback-audit20'},containsInterior:()=>true,floorHeight:()=>0,ceilingHeight:()=>3,approachPoint:()=>({x:0,y:0,z:0})}],policies:[{instanceId:'callback-audit20',capturable:true,headquartersEligible:true}]});
 let local=true,called=false,host;const claimant={actorId:'player',factionId:'ours',canManage:true};
 const facts={manifestRevision:catalog.manifestRevision,claimantFactionId:'ours',defenceRevision:0,defendersComplete:true,remainingHostileDefenderIds:[],occupantsComplete:true,occupants:[{id:'player',factionId:'ours',disposition:'attacker',alive:true,combatReady:true,insideSiteId:siteId}]};
 const request={siteId,action:'capture',operationId:'audit20-op',expectedRevision:0,expectedDefenceRevision:0};
 host=createNativeSiteLocalAuthority({catalog,siteId,initialOwnerFactionId:'theirs',isLocalPreview:()=>local,readClaimant:()=>claimant,readFacts:()=>{
  if(!called){called=true;onRead({host,request,claimant,setLocal:value=>local=value});}return facts;
 }});
 return {host,request,setLocal:value=>local=value};
}
test('disposing authority during source callback invalidates outer execute',()=>{
 const f=fixture(({host})=>host.dispose());
 assert.equal(f.host.execute(f.request).ok,false,'disposed session cannot commit an in-flight capture');
 assert.equal(f.host.inspect().reason,'disposed');
});
test('disabling local authority during source callback invalidates outer execute',()=>{
 const f=fixture(({setLocal})=>setLocal(false));
 assert.equal(f.host.execute(f.request).ok,false,'changed authority gate cannot commit');
 f.setLocal(true);assert.equal(f.host.inspect().ownerFactionId,'theirs');assert.equal(f.host.inspect().revision,0);
});
test('inspect cannot allow a reentrant source callback to execute ownership writes',()=>{
 let nested;const f=fixture(({host,request})=>nested=host.execute(request));
 f.host.inspect();assert.equal(nested.ok,false,'nested execute must be denied while reading snapshot');
 assert.equal(f.host.inspect().ownerFactionId,'theirs');assert.equal(f.host.inspect().revision,0);
});
test('source permission revoked while facts are read cannot authorize capture',()=>{
 let claimant;const f=fixture(context=>{claimant=context.claimant;claimant.canManage=false;});
 assert.equal(f.host.execute(f.request).ok,false,'permission must still hold after source callbacks');
 claimant.canManage=true;assert.equal(f.host.inspect().ownerFactionId,'theirs');assert.equal(f.host.inspect().revision,0);
});
