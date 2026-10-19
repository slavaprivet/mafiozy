import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createResidentNeeds23 as create,chooseResidentIntent23 as choose,applyResidentReceipt23 as apply,failResidentIntent23 as fail,residentLedgerConserved23 as conserved} from './npc_resident_needs23_candidate.mjs';
const places=[{id:'bank:local',kind:'bank',bankId:'personal-bank',distanceM:120},{id:'hospital',kind:'hospital',distanceM:110},{id:'police',kind:'police',distanceM:25},{id:'paper',kind:'shop',price:3,distanceM:15},{id:'work',kind:'work',distanceM:80},{id:'cafe',kind:'leisure',distanceM:30}];
const state=(npcId='resident1',cash=20,bank=200,mode='session')=>create({npcId,cash,bank,mode,bankId:'personal-bank'});
const snap=(s,extra={})=>({npcId:s.npcId,now:s.lastTime+1,health:s.health?{...s.health}:{hp:100,max:100,version:1},places,carAvailable:true,...extra});
const trusted={verifyReceipt:()=>true,hasPhysicalArrival:()=>true,bankEndpointAvailable:true};
const receipt=(s,kind,extra={})=>({id:'receipt:'+s.npcId+':'+(s.account.sequence+1),npcId:s.npcId,accepted:true,sequence:s.account.sequence+1,authority:s.mode==='authenticated'?'server':'session',kind,...extra});
const goalReceipt=(s,kind,extra={})=>receipt(s,kind,{goalId:s.goal.id,placeId:s.goal.placeId,visitId:'physical-visit:'+s.goal.id,amount:s.goal.amount,bankId:s.account.bankId,...extra});
let cases=0;
{
 const s=state('cash-empty',0,80),plan=choose(s,snap(s));assert.equal(plan.intent.kind,'bank');assert.equal(plan.intent.operation,'withdraw');const before=structuredClone(s.account),r=goalReceipt(s,'withdraw');
 assert.equal(apply(s,r,{...trusted,hasPhysicalArrival:()=>false}).reason,'bank-arrival-required');assert.deepEqual(s.account,before);cases++;
 assert(apply(s,r,trusted).accepted);assert(conserved(s));assert.equal(s.account.cash,Math.min(80,s.traits.cashTarget));assert.equal(apply(s,r,trusted).reason,'duplicate');assert(conserved(s));cases++;
 const saved=JSON.parse(JSON.stringify(s));assert.equal(apply(saved,r,trusted).reason,'duplicate');assert.deepEqual(saved.account,s.account);cases++;
}
{
 const s=state('rich-cash',1000,30),p=choose(s,snap(s));assert.equal(p.intent.operation,'deposit');const total=s.account.cash+s.account.bank;assert(apply(s,goalReceipt(s,'deposit'),trusted).accepted);assert.equal(s.account.cash+s.account.bank,total);assert.equal(s.account.cash,s.traits.cashTarget);cases++;
}
{
 const s=state('empty-account',0,0),p=choose(s,snap(s));assert.equal(p.intent.kind,'work');const balance=structuredClone(s.account);assert.equal(apply(s,goalReceipt(s,'income',{amount:30,workCompleted:false}),trusted).reason,'completed-work-required');assert.deepEqual(s.account,balance);assert(apply(s,goalReceipt(s,'income',{amount:30,workCompleted:true}),trusted).accepted);assert.equal(s.account.bank,30);assert(conserved(s));cases++;
}
{
 const s=state('robbery-victim',80,150);choose(s,snap(s));const robbed=receipt(s,'robbery',{amount:10,victimId:s.npcId,caseId:'case-A'}),prior=s.account.cash;
 assert.equal(apply(s,{...robbed,npcId:'somebody-else'},trusted).accepted,false);assert.equal(apply(s,{...robbed,victimId:'somebody-else'},trusted).accepted,false);assert.equal(apply(s,{...robbed,accepted:false},trusted).accepted,false);assert.equal(s.account.cash,prior);cases++;
 assert(apply(s,robbed,trusted).accepted);assert.equal(s.account.cash,prior-10);assert.equal(apply(s,robbed,trusted).reason,'duplicate');assert(conserved(s));cases++;
 const police=choose(s,snap(s));assert.equal(police.intent.kind,'police');assert.equal(choose(s,snap(s)).intent.id,police.intent.id);const report=receipt(s,'police_report',{caseId:'case-A',reportAcknowledged:false});assert.equal(apply(s,report,trusted).reason,'police-ack-required');cases++;
 assert(apply(s,{...report,reportAcknowledged:true},trusted).accepted);const bank=choose(s,snap(s));assert.equal(bank.intent.kind,'bank');assert(bank.intent.amount>=10&&bank.intent.amount<=150);assert(apply(s,goalReceipt(s,'withdraw'),trusted).accepted);assert.equal(s.needsBank,false);assert.equal(s.bankRecovery,0);assert(conserved(s));cases++;
}
{
 // A robbery can happen when the person already carries more than their usual
 // cash target. Recovery still withdraws the lost amount, never a zero order.
 const s=state('well-funded-victim',150,100);assert(apply(s,receipt(s,'robbery',{amount:5,victimId:s.npcId,caseId:'case-B'}),trusted).accepted);assert(apply(s,receipt(s,'police_report',{caseId:'case-B',reportAcknowledged:true}),trusted).accepted);const p=choose(s,snap(s));assert.equal(p.intent.kind,'bank');assert.equal(p.intent.amount,5);cases++;
}
{
 const s=state('injured-victim',10,200);assert(apply(s,receipt(s,'robbery',{amount:5,victimId:s.npcId,caseId:'hurt-case'}),trusted).accepted);let p=choose(s,snap(s));assert.equal(p.intent.kind,'police');
 p=choose(s,snap(s,{health:{hp:35,max:100,version:2}}));assert.equal(p.intent.kind,'hospital');assert(p.cancelGoal);const healthBefore=structuredClone(s.health),r=goalReceipt(s,'treatment',{hpBefore:35,hpAfter:90,healthVersion:3,healingConfirmed:true});assert.equal(apply(s,r,{...trusted,hasPhysicalArrival:()=>false}).accepted,false);assert.deepEqual(s.health,healthBefore);cases++;
 assert(apply(s,r,trusted).accepted);assert.equal(s.health.hp,90);p=choose(s,snap(s,{health:{hp:35,max:100,version:2}}));assert.equal(p.intent.kind,'police','stale pre-treatment health must not restart treatment');assert.equal(s.health.hp,90);cases++;
 assert(apply(s,receipt(s,'police_report',{caseId:'hurt-case',reportAcknowledged:true}),trusted).accepted);assert.equal(choose(s,snap(s)).intent.kind,'bank');cases++;
}
{
 const s=state('emergency',10,200);const p=choose(s,snap(s,{health:{hp:15,max:100,version:1}}));assert.equal(p.status,'medical');assert.equal(p.executor,'existing-emergency-care');assert.equal(s.goal,null);assert.equal(s.health.hp,15);cases++;
 assert.equal(choose(s,snap(s,{health:{hp:0,max:100,version:2,dead:true}})).reason,'dead');assert.equal(choose(s,snap(s,{health:{hp:80,max:100,version:3}})).reason,'dead','sparse alive snapshot cannot revive');assert.equal(s.health.hp,0);cases++;
}
for(const flag of ['custody','combat','panic','transportTransition','medicalOwned']){
 const s=state(flag,0,100),g=choose(s,snap(s)).intent;assert.equal(choose(s,snap(s,{[flag]:true})).status,'hold');assert.equal(s.goal.id,g.id);cases++;
}
{
 const s=state('online',0,100,'authenticated');assert.equal(choose(s,snap(s)).status,'unsupported');assert.equal(s.goal,null);choose(s,snap(s,{bankEndpointAvailable:true}));const r=goalReceipt(s,'withdraw'),before=structuredClone(s.account);
 assert.equal(apply(s,r,trusted).reason,'authoritative-balances-required');assert.deepEqual(s.account,before);cases++;
 const accepted={...r,cashBefore:0,bankBefore:100,cashAfter:r.amount,bankAfter:100-r.amount};assert.equal(apply(s,{...accepted,authority:'session'},trusted).reason,'wrong-authority');assert.equal(apply(s,accepted,{...trusted,verifyReceipt:()=>false}).reason,'unverified-receipt');assert.equal(apply(s,accepted,{...trusted,bankEndpointAvailable:false}).reason,'bank-endpoint-unsupported');assert(apply(s,accepted,trusted).accepted);assert(conserved(s));cases++;
}
{
 const s=state('blocked-bank',0,100),g=choose(s,snap(s)).intent;assert.equal(g.travel,'car');assert(fail(s,{goalId:g.id,now:s.lastTime+1,reason:'door-blocked'}));assert.equal(s.goal,null);assert.equal(choose(s,snap(s)).status,'waiting');const old=s.account.cash;assert.equal(apply(s,{...receipt(s,'withdraw'),goalId:g.id,placeId:g.placeId,visitId:'old',amount:g.amount,bankId:'personal-bank'},trusted).accepted,false);assert.equal(s.account.cash,old);cases++;
 const p=choose(s,snap(s,{now:s.retryAt+1}));assert.equal(p.status,'pending');assert.equal(p.reason,'no-reachable-bank');cases++;
}
{
 const s=state('no-car',0,100);assert.equal(choose(s,snap(s,{carAvailable:false})).intent.travel,'walk');cases++;
}
{
 const s=state('wrong-seq');const r=receipt(s,'robbery',{sequence:2,amount:5,victimId:s.npcId,caseId:'seq'});assert.equal(apply(s,r,trusted).reason,'account-sync-required');assert.equal(s.account.sequence,0);cases++;
}

for(const mutate of [r=>r.amount=-1,r=>r.amount=NaN,r=>r.amount=1.5,r=>r.amount=0,r=>r.bankId='someone-elses-bank',r=>r.goalId='stale-goal',r=>r.visitId='',r=>r.placeId='outside-bank']){
 const s=state('negative-bank',0,100);choose(s,snap(s));const r=goalReceipt(s,'withdraw'),before=JSON.stringify(s);mutate(r);assert.equal(apply(s,r,trusted).accepted,false);assert.equal(JSON.stringify(s),before);cases++;
}
{
 const s=state('protected',0,100);assert.equal(choose(s,snap(s,{eligible:false})).reason,'protected-role');assert.equal(s.goal,null);assert.equal(s.health,null);cases++;
}
{
 const a=state('same-person',80,200),b=JSON.parse(JSON.stringify(a));assert.deepEqual(choose(a,snap(a)),choose(b,snap(b)),'serialized decisions preserve personality/sequence');cases++;
}
{
 const s=state('unconfirmed',80,100),r=receipt(s,'robbery',{amount:5,victimId:s.npcId,caseId:'unconfirmed'}),before=JSON.stringify(s);assert.equal(apply(s,r,{}).reason,'unverified-receipt');assert.equal(apply(s,r,{verifyReceipt:()=>{throw Error('offline')}}).reason,'unverified-receipt');assert.equal(JSON.stringify(s),before);cases++;
}
{
 const s=state('healing',80,100);choose(s,snap(s,{health:{hp:35,max:100,version:1}}));const r=goalReceipt(s,'treatment',{hpBefore:35,hpAfter:90,healthVersion:2,healingConfirmed:true}),before=JSON.stringify(s);for(const change of [{hpAfter:101},{hpBefore:34},{healthVersion:1},{healingConfirmed:false}]){assert.equal(apply(s,{...r,...change},trusted).accepted,false);assert.equal(JSON.stringify(s),before);}cases++;
}
{
 const s=state('ledger-overflow',0,0x7fffffff);choose(s,snap(s));const r=goalReceipt(s,'withdraw');assert(apply(s,r,trusted).accepted);assert(conserved(s));assert.throws(()=>state('invalid',-1,100));cases++;
}

{
 const s=state('injury-during-backoff',0,100),bank=choose(s,snap(s)).intent;
 assert(fail(s,{goalId:bank.id,now:s.lastTime+1}));
 const hospital=choose(s,snap(s,{health:{hp:35,max:100,version:2}}));
 assert.equal(hospital.intent.kind,'hospital','new injury bypasses failed bank retry');
 assert(s.lastTime<s.retryAt);assert(s.failed.some(f=>f.placeId===bank.placeId));cases++;
 assert(fail(s,{goalId:hospital.intent.id,now:s.lastTime+1}));
 assert.equal(choose(s,snap(s)).status,'waiting','same failed urgent goal retains backoff');cases++;
}
{
 const s=state('robbed-during-backoff',80,100);let g=choose(s,snap(s)).intent;
 assert(fail(s,{goalId:g.id,now:s.lastTime+1}));
 assert(apply(s,receipt(s,'robbery',{amount:5,victimId:s.npcId,caseId:'new-incident'}),trusted).accepted);
 assert.equal(choose(s,snap(s)).intent.kind,'police','new robbery bypasses ordinary retry');cases++;
}
for(const hpAfterSnapshot of [90,40,0]){
 const s=state('late-heal-'+hpAfterSnapshot,80,100);choose(s,snap(s,{health:{hp:35,max:100,version:1}}));
 const r=goalReceipt(s,'treatment',{hpBefore:35,hpAfter:90,healthVersion:2,healingConfirmed:true});
 choose(s,snap(s,{health:{hp:90,max:100,version:2}}));
 if(hpAfterSnapshot!==90)choose(s,snap(s,{health:{hp:hpAfterSnapshot,max:100,version:3,dead:hpAfterSnapshot===0}}));
 const accepted=apply(s,r,trusted);assert(accepted.accepted);assert.equal(accepted.effect,undefined,'late receipt cannot send an old HP effect back to world');
 assert.equal(s.health.hp,hpAfterSnapshot);assert.equal(s.health.dead,hpAfterSnapshot===0);assert.equal(s.goal,null);assert.equal(apply(s,r,trusted).reason,'duplicate');cases++;
}
{
 const s=state('damage-on-way',80,100);choose(s,snap(s,{health:{hp:40,max:100,version:1}}));
 choose(s,snap(s,{health:{hp:35,max:100,version:2}}));
 const r=goalReceipt(s,'treatment',{hpBefore:35,hpAfter:90,healthVersion:3,healingConfirmed:true});
 choose(s,snap(s,{health:{hp:90,max:100,version:3}}));assert(apply(s,r,trusted).accepted);assert.equal(s.health.hp,90);cases++;
}
{
 const s=state('no-progress',80,100);choose(s,snap(s,{health:{hp:35,max:100,version:1}}));const before=JSON.stringify(s);
 assert.equal(apply(s,goalReceipt(s,'treatment',{hpBefore:35,hpAfter:35,healthVersion:2,healingConfirmed:true}),trusted).accepted,false);assert.equal(JSON.stringify(s),before);cases++;
}
{
 const s=state('late-bank',0,200,'authenticated'),bank=choose(s,snap(s,{bankEndpointAvailable:true})).intent;
 const r=goalReceipt(s,'withdraw',{cashBefore:0,bankBefore:200,cashAfter:bank.amount,bankAfter:200-bank.amount,completedAt:s.lastTime});
 const urgent=choose(s,snap(s,{health:{hp:35,max:100,version:2}})).intent,before=JSON.stringify(s);
 assert.equal(apply(s,r,trusted).reason,'account-sync-required');assert.equal(JSON.stringify(s),before);cases++;
 const proof={...trusted,wasCompletedBeforeCancellation:(receipt,closed)=>receipt===r&&closed.goal.id===bank.id&&closed.reason==='preempted'};
 assert(apply(s,r,proof).accepted);assert.equal(s.goal.id,urgent.id);assert.equal(s.account.cash,bank.amount);assert(conserved(s));
 assert(apply(s,goalReceipt(s,'treatment',{hpBefore:35,hpAfter:90,healthVersion:3,healingConfirmed:true}),trusted).accepted);assert.equal(s.account.sequence,2);cases++;
}
{
 const s=state('late-forged-bank',0,200),g=choose(s,snap(s)).intent,r=goalReceipt(s,'withdraw');
 choose(s,snap(s,{health:{hp:35,max:100,version:2}}));const before=JSON.stringify(s);
 assert.equal(apply(s,{...r,completedAt:s.lastTime+1},{...trusted,wasCompletedBeforeCancellation:()=>true}).accepted,false);assert.equal(JSON.stringify(s),before);cases++;
}
{
 const s=state('near-bank-limit',1000,0x7fffffff-2),g=choose(s,snap(s)).intent;assert.equal(g.operation,'deposit');assert.equal(g.amount,2);
 assert(apply(s,goalReceipt(s,'deposit'),trusted).accepted);assert(conserved(s));assert.equal(s.account.bank,0x7fffffff);
 const next=choose(s,snap(s));assert.notEqual(next.intent.kind,'bank');assert.notEqual(next.intent.kind,'work');cases++;
}
{
 const s=state('robbed-at-bank',10,200);choose(s,snap(s));const oldBank=s.goal;
 assert(apply(s,receipt(s,'robbery',{amount:5,victimId:s.npcId,caseId:'bank-incident'}),trusted).accepted);
 assert.equal(apply(s,goalReceipt(s,'withdraw'),trusted).reason,'police-ack-required');assert.equal(s.account.cash,5);
 assert.equal(choose(s,snap(s)).intent.kind,'police');assert(s.closedGoals.some(x=>x.goal.id===oldBank.id));cases++;
}
// Many completed voluntary decisions should vary, while pending decisions stay
// stable. Capture different people and future choices, not per-frame rerolls.
const population=[];
for(let i=0;i<80;i++){
 const s=state('person-'+i,80,300),sequence=[];
 for(let j=0;j<24;j++){
  const p=choose(s,snap(s));assert.equal(p.status,'intent');const g=p.intent;assert.equal(choose(s,snap(s)).intent.id,g.id);sequence.push(g.kind);
  if(g.kind==='shop')assert(apply(s,goalReceipt(s,'purchase'),trusted).accepted);
  else if(g.kind==='bank')assert(apply(s,goalReceipt(s,g.operation),trusted).accepted);
  else if(g.kind==='work')assert(apply(s,goalReceipt(s,'income',{amount:10,workCompleted:true}),trusted).accepted);
  else assert(apply(s,receipt(s,'activity_complete',{goalId:g.id,activityCompleted:true}),trusted).accepted);
  assert(conserved(s));
 }
 population.push({id:s.npcId,sequence,traits:s.traits});
}
assert(new Set(population.map(p=>p.sequence.join(','))).size>60);assert(population.some(p=>new Set(p.sequence).size>=4));cases++;
{
 const s=state('ledger-history',80,1000);let first=null;
 for(let i=0;i<70;i++){
  choose(s,snap(s));const g=s.goal;let r=g.kind==='shop'?goalReceipt(s,'purchase'):g.kind==='bank'?goalReceipt(s,g.operation):g.kind==='work'?goalReceipt(s,'income',{amount:10,workCompleted:true}):receipt(s,'activity_complete',{goalId:g.id,activityCompleted:true});first??=r;assert(apply(s,r,trusted).accepted);assert(conserved(s));
 }
 assert.equal(s.receipts.length,64);const before=JSON.stringify(s.account);assert.equal(apply(s,first,trusted).reason,'stale-receipt');assert.equal(JSON.stringify(s.account),before);cases++;
}
const pool=Array.from({length:384},(_,i)=>state('perf'+i,80,200));for(const s of pool)choose(s,snap(s));const times=[];
for(let round=0;round<300;round++){const at=performance.now();for(const s of pool)choose(s,snap(s));if(round>49)times.push(performance.now()-at);}times.sort((a,b)=>a-b);
const report={cases,population:population.map(p=>({id:p.id,sequence:p.sequence})),uniqueSequences:new Set(population.map(p=>p.sequence.join(','))).size,cpu384StableIntents:{p50:times[125],p95:times[237]},limits:'Isolated source-state candidate. Injected test receipts/arrival proofs; no online bank endpoint, actual hospital treatment, route wiring, LIVE city or FPS acceptance.'};fs.writeFileSync('outputs/npc_resident_needs23_candidate.json',JSON.stringify(report,null,2));console.log(JSON.stringify({...report,population:undefined},null,2));
