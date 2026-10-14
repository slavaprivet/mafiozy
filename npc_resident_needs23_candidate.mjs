// Isolated resident needs/ledger candidate. No world, bank, HP or route authority.
const integer=n=>Number.isSafeInteger(n)&&n>=0&&n<=0x7fffffff;
const name=s=>typeof s==='string'&&s.length>0&&s.length<=240;
const unit=(key)=>{let h=2166136261;for(const ch of key){h^=ch.charCodeAt(0);h=Math.imul(h,16777619);}return(h>>>0)/4294967296;};
const copy=x=>JSON.parse(JSON.stringify(x));
const priority={hospital:3,police:2,bank:1,work:0,shop:0,walk:0,rest:0,leisure:0};
const balanceLimit=0x7fffffff;
export function createResidentNeeds23({npcId,mode='session',cash,bank,bankId=null,seed='resident-needs-v1',sequence=0}={}){
 if(!name(npcId)||!name(seed)||!['session','authenticated'].includes(mode)||!integer(cash)||!integer(bank)||!integer(sequence)||(bankId!==null&&!name(bankId)))throw Error('Invalid resident account');
 const rand=s=>unit(npcId+':'+seed+':'+s);
 return{version:1,npcId,mode,seed,account:{cash,bank,bankId,sequence,initialTotal:cash+bank,spent:0,robbed:0,income:0},traits:{cashLow:12+Math.floor(rand('low')*24),cashTarget:60+Math.floor(rand('buffer')*71),hospitalRatio:.48+rand('health')*.2,carDistanceM:45+rand('car')*55,shop:1+rand('shop')*3,work:.6+rand('work')*2,leisure:.7+rand('leisure')*2,rest:.5+rand('rest'),walk:.8+rand('walk')*2},decision:0,goal:null,resume:null,needsBank:false,bankRecovery:0,cases:[],receipts:[],lastKind:null,lastTime:0,failed:[],retryAt:0,health:null};
}
function receiptFailure(reason){return{accepted:false,reason};}
function verify(state,receipt,context){
 if(receipt?.accepted!==true||receipt.npcId!==state.npcId||!name(receipt.id)||!integer(receipt.sequence))return'wrong-or-unaccepted-receipt';
 const known=state.receipts.find(r=>r.id===receipt.id);if(known)return known.sequence===receipt.sequence?'duplicate':'receipt-id-conflict';
 if(receipt.sequence<=state.account.sequence)return'stale-receipt';if(receipt.sequence!==state.account.sequence+1)return'account-sync-required';
 if(receipt.authority!==(state.mode==='authenticated'?'server':'session'))return'wrong-authority';
 try{if(typeof context.verifyReceipt!=='function'||context.verifyReceipt(receipt)!==true)return'unverified-receipt';}catch{return'unverified-receipt';}
 return null;
}
function matchingArrival(state,r,ctx,kind){
 let g=state.goal?.id===r.goalId?state.goal:null;
 if(!g){
  const closed=state.closedGoals?.find(x=>x.goal.id===r.goalId);if(!closed)return null;
  // An expired instruction is not executable. A late receipt may only mirror
  // an operation already completed before cancellation, proven by the host.
  if(!Number.isFinite(r.completedAt)||r.completedAt<closed.goal.started||r.completedAt>closed.closedAt)return null;
  try{if(ctx.wasCompletedBeforeCancellation?.(r,copy(closed))!==true)return null;}catch{return null;}
  g=closed.goal;
 }
 if(g.kind!==kind||g.placeId!==r.placeId||!name(r.visitId))return null;
 try{return ctx.hasPhysicalArrival?.({npcId:state.npcId,goalId:g.id,placeId:g.placeId,visitId:r.visitId,kind})===true?g:null;}catch{return null;}
}
function closeGoal(state,now,reason){
 if(!state.goal)return;
 (state.closedGoals??=[]).push({goal:copy(state.goal),closedAt:now,reason});
 if(state.closedGoals.length>16)state.closedGoals.shift();
 state.goal=null;
}
function retainHealthEvidence(state){
 if(!state.health)return;
 (state.healthEvidence??=[]).push({...state.health});
 if(state.healthEvidence.length>8)state.healthEvidence.shift();
}
const arrivalFailure=(state,r,reason)=>receiptFailure(state.closedGoals?.some(x=>x.goal.id===r.goalId)?'account-sync-required':reason);
export function applyResidentReceipt23(state,receipt,context={}){
 const invalid=verify(state,receipt,context);if(invalid)return receiptFailure(invalid);
 const r=receipt,a=state.account,amount=r.amount,monetary=['purchase','withdraw','deposit','robbery','income'].includes(r.kind);let cash=a.cash,bank=a.bank,clearGoal=false,effect=null,completedGoal=null;
 if(monetary&&(!integer(amount)||amount===0))return receiptFailure('invalid-amount');
 if(r.kind==='purchase'){
  completedGoal=matchingArrival(state,r,context,'shop');if(!completedGoal||completedGoal.amount!==amount)return arrivalFailure(state,r,'checkout-arrival-required');if(amount>cash)return receiptFailure('insufficient-cash');cash-=amount;clearGoal=true;
 }else if(r.kind==='withdraw'||r.kind==='deposit'){
  completedGoal=matchingArrival(state,r,context,'bank');if(!completedGoal||completedGoal.operation!==r.kind||completedGoal.amount!==amount)return arrivalFailure(state,r,'bank-arrival-required');
  if(state.cases.some(c=>!c.reported))return receiptFailure('police-ack-required');
  if(state.mode==='authenticated'&&context.bankEndpointAvailable!==true)return receiptFailure('bank-endpoint-unsupported');
  if(r.bankId!==a.bankId)return receiptFailure('wrong-personal-bank');
  if(r.kind==='withdraw'){if(amount>bank)return receiptFailure('insufficient-bank');bank-=amount;cash+=amount;}else{if(amount>cash)return receiptFailure('insufficient-cash');cash-=amount;bank+=amount;}clearGoal=true;
 }else if(r.kind==='robbery'){
  if(r.victimId!==state.npcId||!name(r.caseId))return receiptFailure('wrong-victim');if(amount>cash)return receiptFailure('account-sync-required');if(state.cases.some(c=>c.id===r.caseId))return receiptFailure('duplicate-case');
  if(state.cases.filter(c=>!c.reported).length>=16)return receiptFailure('case-capacity');cash-=amount;
 }else if(r.kind==='income'){
  completedGoal=matchingArrival(state,r,context,'work');if(!completedGoal||r.workCompleted!==true)return receiptFailure('completed-work-required');bank+=amount;clearGoal=true;
 }else if(r.kind==='police_report'){
  if(!state.cases.some(c=>c.id===r.caseId&&!c.reported)||r.reportAcknowledged!==true)return receiptFailure('police-ack-required');clearGoal=state.goal?.kind==='police'&&state.goal.caseId===r.caseId;
 }else if(r.kind==='treatment'){
  completedGoal=matchingArrival(state,r,context,'hospital');
  const h=state.health,before=[...(state.healthEvidence||[]),...(h?[h]:[])].find(x=>!x.dead&&x.hp===r.hpBefore&&x.version>=completedGoal?.healthVersion&&x.version<r.healthVersion);
  if(!completedGoal||r.healingConfirmed!==true||!h||h.dead&&r.healthVersion>=h.version||!before||!Number.isFinite(r.hpBefore)||r.hpBefore<0||!Number.isFinite(r.hpAfter)||r.hpAfter<=r.hpBefore||r.hpAfter>before.max||!integer(r.healthVersion)||r.healthVersion<=completedGoal.healthVersion||r.healthVersion===h.version&&(r.hpAfter!==h.hp||before.max!==h.max))return receiptFailure('authoritative-healing-required');
  clearGoal=true;
  if(r.healthVersion>h.version)effect={type:'health-receipt',hp:r.hpAfter,max:before.max,version:r.healthVersion};
 }else if(r.kind==='activity_complete'){
  if(!state.goal||state.goal.id!==r.goalId||!['walk','rest','leisure'].includes(state.goal.kind)||r.activityCompleted!==true)return receiptFailure('activity-completion-required');clearGoal=true;
 }else return receiptFailure('unknown-receipt');
 if(!integer(cash)||!integer(bank))return receiptFailure('balance-overflow');
 // Server mode needs an accepted CURRENT account snapshot; a UI payout or the
 // legacy robbery amount alone is not proof of the resident's bank/cash state.
 if(state.mode==='authenticated'&&monetary&&(r.cashBefore!==a.cash||r.bankBefore!==a.bank||r.cashAfter!==cash||r.bankAfter!==bank))return receiptFailure('authoritative-balances-required');
 a.cash=cash;a.bank=bank;a.sequence=r.sequence;
 if(r.kind==='purchase')a.spent+=amount;if(r.kind==='income')a.income+=amount;
 if(r.kind==='robbery'){a.robbed+=amount;state.cases.push({id:r.caseId,receiptId:r.id,reported:false});state.needsBank=true;state.bankRecovery+=amount;}
 if(r.kind==='police_report'){state.cases.find(c=>c.id===r.caseId).reported=true;state.needsBank=true;}
 if(r.kind==='withdraw'){state.bankRecovery=Math.max(0,state.bankRecovery-amount);state.needsBank=state.bankRecovery>0;}
 if(r.kind==='treatment'&&effect){retainHealthEvidence(state);state.health={...state.health,hp:effect.hp,max:effect.max,version:effect.version};}
 state.receipts.push({id:r.id,sequence:r.sequence,kind:r.kind});if(state.receipts.length>64)state.receipts.shift();
 // Reported case details are bounded; old ledger sequence remains the replay
 // barrier even after short receipt/history lists are compacted.
 while(state.cases.length>16){const at=state.cases.findIndex(c=>c.reported);if(at<0)break;state.cases.splice(at,1);}
 if(clearGoal){
  const finished=completedGoal||state.goal;
  if(state.goal?.id===finished?.id){state.lastKind=state.goal.kind;state.goal=null;state.retryAt=0;}
  if(completedGoal&&state.closedGoals)state.closedGoals=state.closedGoals.filter(x=>x.goal.id!==completedGoal.id);
 }
 return{accepted:true,kind:r.kind,account:{cash,bank,sequence:a.sequence},...(effect?{effect}: {})};
}
function choosePlace(state,snapshot,kind){
 const list=snapshot.places.filter(p=>p.kind===kind&&!state.failed.some(f=>f.placeId===p.id&&f.until>snapshot.now));
 if(kind==='bank'){
  const own=list.filter(p=>!state.account.bankId||p.bankId===state.account.bankId);return own.sort((a,b)=>a.distanceM-b.distanceM||a.id.localeCompare(b.id))[0]||null;
 }
 let best=null,score=Infinity;for(const p of list){if(kind==='shop'&&(!integer(p.price)||p.price<1||p.price>state.account.cash))continue;const rank=p.distanceM+(unit(state.npcId+':'+state.seed+':'+state.decision+':'+p.id)*35);if(rank<score){score=rank;best=p;}}return best;
}
function bankAction(state){return state.needsBank||state.account.cash<state.traits.cashLow?{operation:'withdraw',amount:Math.min(state.account.bank,balanceLimit-state.account.cash,Math.max(state.bankRecovery,state.traits.cashTarget-state.account.cash))}:{operation:'deposit',amount:Math.min(balanceLimit-state.account.bank,Math.max(0,state.account.cash-state.traits.cashTarget))};}
function issue(state,snapshot,kind,extra={}){
 const place=['walk','rest'].includes(kind)?null:choosePlace(state,snapshot,kind);
 if(!place&& !['walk','rest'].includes(kind))return{status:'pending',reason:'no-reachable-'+kind,kind};
 if(kind==='bank'&&state.mode==='authenticated'&&snapshot.bankEndpointAvailable!==true)return{status:'unsupported',reason:'bank-endpoint-unsupported',kind};
 if(kind==='bank'&&(!integer(extra.amount)||extra.amount===0))return{status:'pending',reason:'bank-capacity-unavailable',kind};
 if(kind==='bank'&&!state.account.bankId){if(!name(place.bankId))return{status:'unsupported',reason:'bank-identity-required',kind};state.account.bankId=place.bankId;}
 const goal={id:`need:${state.npcId}:${++state.decision}`,kind,placeId:place?.id||null,started:snapshot.now,travel:place&&place.distanceM>state.traits.carDistanceM&&snapshot.carAvailable===true?'car':'walk',...extra};
 if(kind==='shop')goal.amount=place.price;
 if(kind==='hospital')goal.healthVersion=state.health.version;
 state.goal=goal;return{status:'intent',intent:copy(goal)};
}
export function chooseResidentIntent23(state,snapshot){
 if(snapshot?.npcId!==state.npcId||!Number.isFinite(snapshot.now)||snapshot.now<state.lastTime||!Array.isArray(snapshot.places)||snapshot.places.length>64||snapshot.places.some(p=>!name(p.id)||!name(p.kind)||!Number.isFinite(p.distanceM)||p.distanceM<0))return{status:'blocked',reason:'invalid-snapshot'};
 if(snapshot.eligible===false)return{status:'hold',reason:'protected-role'};
 const health=snapshot.health;
 if(!health||!Number.isFinite(health.hp)||!Number.isFinite(health.max)||health.max<=0||health.hp<0||health.hp>health.max||!integer(health.version))return{status:'blocked',reason:'invalid-health'};
 state.lastTime=snapshot.now;
 if(state.health&&health.version===state.health.version&&(health.hp!==state.health.hp||health.max!==state.health.max))return{status:'blocked',reason:'health-version-conflict'};
 if(!state.health||health.version>state.health.version){const retainDeath=state.health?.dead&&health.explicitAlive!==true;retainHealthEvidence(state);state.health={hp:retainDeath?0:health.hp,max:health.max,version:health.version,dead:retainDeath||health.dead===true||health.hp<=0};}
 const h=state.health;
 if(h.dead||snapshot.custody||snapshot.combat||snapshot.panic||snapshot.transportTransition||snapshot.medicalOwned)return{status:'hold',reason:h.dead?'dead':'existing-owner',retainedGoal:state.goal?.id||null};
 if(h.hp/h.max<.3)return{status:'medical',reason:'urgent-health',executor:'existing-emergency-care',retainedGoal:state.goal?.id||null};
 const needsTreatment=h.hp/h.max<state.traits.hospitalRatio;
 const report=state.cases.find(c=>!c.reported);
 const desired=needsTreatment?'hospital':report?'police':state.needsBank||state.account.cash<state.traits.cashLow?state.account.bank>0?'bank':'work':state.account.cash>state.traits.cashTarget*2&&state.account.bank<balanceLimit?'bank':null;
 if(state.goal){
  if(desired&&(priority[desired]||0)>(priority[state.goal.kind]||0)){
   const cancelled=state.goal.id;if(!state.resume&&['shop','work','walk','rest','leisure'].includes(state.goal.kind))state.resume={kind:state.goal.kind};closeGoal(state,snapshot.now,'preempted');const result=issue(state,snapshot,desired,desired==='police'?{caseId:report.id}:desired==='bank'?bankAction(state):{});return{...result,cancelGoal:cancelled};
  }
  return{status:'intent',intent:copy(state.goal)};
 }
 // A failed errand must not delay a newly urgent need; the failed place's own
 // cooldown remains active. Same/lower priority failures still back off.
 if(snapshot.now<state.retryAt&&(!desired||(priority[desired]||0)<=(priority[state.retryKind]||0)))return{status:'waiting',until:state.retryAt};
 state.failed=state.failed.filter(f=>f.until>snapshot.now);
 if(desired)return issue(state,snapshot,desired,desired==='police'?{caseId:report.id}:desired==='bank'?bankAction(state):{});
 if(state.resume){const kind=state.resume.kind;state.resume=null;const next=issue(state,snapshot,kind);if(next.status==='intent')return next;}
 const kinds=['shop','work','leisure','rest','walk'],available=kinds.filter(k=>(k!=='work'||state.account.bank<balanceLimit)&&(['rest','walk'].includes(k)||choosePlace(state,snapshot,k))),weights=available.map(k=>state.traits[k]*(k===state.lastKind ? .2 : 1));
 let pick=unit(state.npcId+':'+state.seed+':decision:'+state.decision)*weights.reduce((a,b)=>a+b,0),kind=available.at(-1);
 for(let i=0;i<available.length;i++){pick-=weights[i];if(pick<=0){kind=available[i];break;}}
 return issue(state,snapshot,kind);
}
export function failResidentIntent23(state,{goalId,now,reason='unavailable'}={}){
 if(state.goal?.id!==goalId||!Number.isFinite(now)||now<state.lastTime)return false;
 const goal=state.goal;closeGoal(state,now,reason);state.lastKind=goal.kind;state.retryKind=goal.kind;state.lastTime=now;state.retryAt=now+2000+Math.floor(unit(state.npcId+':retry:'+state.decision)*3000);
 if(goal.placeId){state.failed.push({placeId:goal.placeId,until:now+30000,reason});if(state.failed.length>16)state.failed.shift();}return true;
}
export const residentLedgerConserved23=state=>state.account.cash+state.account.bank===state.account.initialTotal+state.account.income-state.account.spent-state.account.robbed;
