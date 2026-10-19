// Independent fail-closed review cases; no renderer, persistence or world writes.
import assert from 'node:assert/strict';
import test from 'node:test';
import {createNativeSiteCatalog,nativeSiteId,planNativeSiteCapture,planNativeHeadquarters} from './native_site_control.mjs';

const siteId=nativeSiteId('audit20-fixed-house'),manifestRevision='audit20-m1';
const catalog=createNativeSiteCatalog({manifestRevision,entries:[{
 instance:{id:'audit20-fixed-house'},containsInterior:()=>true,approachPoint:()=>({x:0,y:0,z:0}),floorHeight:()=>0,ceilingHeight:()=>3
}],policies:[{instanceId:'audit20-fixed-house',capturable:true,headquartersEligible:true}]});
const actor={id:'physical-actor-1',factionId:'ours',disposition:'attacker',alive:true,combatReady:true,insideSiteId:siteId};
const request={siteId,factionId:'ours',operationId:'audit20-operation'};
const base={manifestRevision,siteId,revision:2,defenceRevision:3,ownerFactionId:'rival',claimantFactionId:'ours',
 defendersComplete:true,remainingHostileDefenderIds:[],occupantsComplete:true,occupants:[actor]};

function assertUnknown(occupants){
 const state={...base,occupants};
 assert.equal(planNativeSiteCapture(catalog,state,request).ok,false,'ambiguous presence cannot authorize a capture intent');
 assert.equal(planNativeHeadquarters(catalog,{...state,ownerFactionId:'ours'},
  {factionId:'ours',siteId:null,revision:0},request).ok,false,'ambiguous presence cannot authorize an HQ intent');
}

test('duplicate actor identity with conflicting alive state is unavailable evidence',()=>{
 assertUnknown([actor,{...actor,alive:false,combatReady:false}]);
});
test('duplicate actor identity with conflicting faction is unavailable evidence',()=>{
 assertUnknown([actor,{...actor,factionId:'rival',combatReady:false}]);
});
test('sparse complete occupant roster is unavailable evidence',()=>{
 const occupants=[actor];occupants.length=2;assertUnknown(occupants);
});
