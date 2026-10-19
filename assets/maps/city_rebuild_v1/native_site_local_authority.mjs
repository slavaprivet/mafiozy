// Single-site LOCAL session authority. Source callbacks own actors and evidence.
// This module never substitutes for authenticated server ownership/persistence.
import {planNativeSiteCapture,planNativeHeadquarters} from './native_site_control.mjs';
const id=value=>typeof value==='string'&&value.trim().length>0;
const deny=reason=>({ok:false,reason,authority:'local-session'});
export function createNativeSiteLocalAuthority({catalog,siteId,initialOwnerFactionId,isLocalPreview,readClaimant,readFacts,maxReceipts=256}){
 if(!catalog?.get(siteId)?.capturable||!id(initialOwnerFactionId)||![isLocalPreview,readClaimant,readFacts].every(fn=>typeof fn==='function'))throw new Error('Explicit local site fixture and source callbacks required');
 if(!Number.isSafeInteger(maxReceipts)||maxReceipts<1)throw new Error('Invalid receipt limit');
 let ownerFactionId=initialOwnerFactionId,revision=0,disposed=false,inOperation=false;
 const headquarters=new Map(),receipts=new Map();
 const headquartersOf=factionId=>headquarters.get(factionId)||Object.freeze({factionId,siteId:null,revision:0});
 function source(){
  if(disposed)return deny('disposed');
  try{
   if(isLocalPreview()!==true)return deny('local-authority-unavailable');
   const initial=readClaimant();
   if(!id(initial?.actorId)||!id(initial?.factionId)||initial.canManage!==true)return deny('claimant-unavailable');
   const claimant={actorId:initial.actorId,factionId:initial.factionId,canManage:true};
   const facts=readFacts({siteId,claimantFactionId:claimant.factionId});
   if(!facts||typeof facts!=='object')return deny('authority-unavailable');
   // Source callbacks are synchronous but can still dispose this session or
   // switch authority. Revalidate after them; nested operations are barred.
   if(disposed)return deny('disposed');
   const latest=readClaimant();
   if(latest?.actorId!==claimant.actorId||latest?.factionId!==claimant.factionId||latest?.canManage!==true)return deny('claimant-unavailable');
   if(isLocalPreview()!==true)return deny('local-authority-unavailable');
   if(disposed)return deny('disposed');
   // Owner/revision are written here only, never accepted from a request/facts.
   return {ok:true,claimant,state:{...facts,siteId,ownerFactionId,revision},headquarters:headquartersOf(claimant.factionId)};
  }catch(_){return deny('authority-unavailable');}
 }
 function inspect(){
  const current=source();if(!current.ok)return current;
  const {claimant,state,headquarters:hq}=current,request={siteId,factionId:claimant.factionId,operationId:'inspect-only'};
  return {ok:true,authority:'local-session',siteId,ownerFactionId,revision,defenceRevision:state.defenceRevision,
   headquarters:{...hq},capture:planNativeSiteCapture(catalog,state,request),assignHeadquarters:planNativeHeadquarters(catalog,state,hq,request)};
 }
 function execute(request={}){
  const current=source();if(!current.ok)return current;
  if(request.siteId!==siteId||!id(request.operationId)||request.operationId.length>128||!['capture','headquarters'].includes(request.action))return deny('invalid-request');
  const {claimant,state,headquarters:hq}=current;
  const signature=JSON.stringify([claimant.actorId,claimant.factionId,request.siteId,request.action,request.expectedRevision,request.expectedDefenceRevision,request.expectedHeadquartersRevision]);
  const existing=receipts.get(request.operationId);
  if(existing)return existing.signature===signature?existing.receipt:deny('operation-conflict');
  if(receipts.size>=maxReceipts)return deny('receipt-capacity');
  if(!Number.isSafeInteger(request.expectedRevision)||request.expectedRevision!==revision||!Number.isSafeInteger(request.expectedDefenceRevision)||request.expectedDefenceRevision!==state.defenceRevision)return deny('version-changed');
  if(request.action==='headquarters'&&request.expectedHeadquartersRevision!==hq.revision)return deny('headquarters-version-changed');
  const intentRequest={siteId,factionId:claimant.factionId,operationId:request.operationId};
  const plan=request.action==='capture'?planNativeSiteCapture(catalog,state,intentRequest):planNativeHeadquarters(catalog,state,hq,intentRequest);
  if(!plan.ok)return {...plan,authority:'local-session'};
  // No await/event dispatch between evidence and this one synchronous commit.
  // Capturing an enemy HQ clears its role in the same source transition.
  let displacedHeadquarters=null;
  if(request.action==='capture'){
   const previous=headquartersOf(ownerFactionId);
   if(previous.siteId===siteId){displacedHeadquarters=Object.freeze({...previous,siteId:null,revision:previous.revision+1});headquarters.set(ownerFactionId,displacedHeadquarters);}
   ownerFactionId=claimant.factionId;revision++;
  }else headquarters.set(claimant.factionId,Object.freeze({...hq,siteId,revision:hq.revision+1}));
  const receipt=Object.freeze({ok:true,authority:'local-session',persistent:false,operationId:request.operationId,action:request.action,siteId,actorId:claimant.actorId,factionId:claimant.factionId,
   ownerFactionId,revision,defenceRevision:state.defenceRevision,headquarters:Object.freeze({...headquartersOf(claimant.factionId)}),displacedHeadquarters});
  receipts.set(request.operationId,{signature,receipt});return receipt;
 }
 function run(operation){
  if(inOperation)return deny('operation-in-progress');
  inOperation=true;try{return operation();}finally{inOperation=false;}
 }
 return Object.freeze({inspect:()=>run(inspect),execute:request=>run(()=>execute(request)),dispose(){disposed=true;headquarters.clear();receipts.clear();}});
}
