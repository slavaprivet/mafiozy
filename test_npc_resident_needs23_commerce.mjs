// Integration contract test only. Executes existing source checkout; the adapter
// below is a test host, not production wiring or an authenticated receipt issuer.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createResidentNeeds23 as create,chooseResidentIntent23 as choose,applyResidentReceipt23 as apply,residentLedgerConserved23 as conserved} from './npc_resident_needs23_candidate.mjs';
const source=fs.readFileSync('assets/maps/city_rebuild_v1/npc_resident_commerce_source.js','utf8');
const box=vm.createContext({_civilianPlanInterrupted:n=>n.panicUntil>0||n.dead});
vm.runInContext(source,box);
const commerce=vm.runInContext('({arrive:_residentCommerceArrive,tick:_residentCommerceTick})',box);
const door={id:'native:printing',assetId:'print_shop',inside:{r:10,c:12}};
const make=()=>{
 // Find a naturally chosen shop intent without overriding personality/goal.
 for(let i=0;i<100;i++){
  const npc={id:'checkout-contract-'+i,r:10,c:12,hp:100,_civilianPlan:{cycle:0},_residentWallet:{balance:80,serial:7,inventory:{used_watch:{quantity:2,nextNeedAt:0}},receipts:[{id:'prior-purchase',price:24}]}};
  const before=JSON.stringify(npc),wallet=npc._residentWallet;
  const state=create({npcId:npc.id,cash:wallet.balance,bank:150,bankId:'personal-bank'});
  assert.equal(JSON.stringify(npc),before,'reading the existing wallet must not reset inventory/history');
  const plan=choose(state,{npcId:npc.id,now:1,health:{hp:100,max:100,version:1},places:[{id:door.id,kind:'shop',price:3,distanceM:0}]});
  if(plan.intent.kind==='shop')return{npc,state,wallet};
 }
 throw Error('No natural shop intent');
};
function testHost(state,npc,visit){
 const order=visit.commerce,physical=npc._residentWallet.receipts.find(r=>r.id===order?.id);
 if(!physical||!order.settled||order.phase!=='complete')return null;
 const receipt={id:'commerce:'+physical.id,npcId:npc.id,accepted:true,sequence:state.account.sequence+1,authority:'session',kind:'purchase',goalId:state.goal?.id,placeId:physical.doorId,visitId:order.id,amount:physical.price};
 const context={
  verifyReceipt:r=>r===receipt&&physical===npc._residentWallet.receipts.find(x=>x.id===order.id)&&state.account.cash-r.amount===npc._residentWallet.balance,
  hasPhysicalArrival:p=>p.npcId===npc.id&&p.goalId===receipt.goalId&&p.visitId===order.id&&p.placeId===visit.door.id&&visit.phase==='browsing'&&Math.hypot(npc.r-visit.door.inside.r,npc.c-visit.door.inside.c)<=.08
 };
 return{receipt,context};
}
let checks=0;
{
 const {npc,state,wallet}=make(),visit={door,phase:'browsing',until:4000};
 assert(commerce.arrive(npc,visit,0));assert.equal(visit.commerce.id,npc.id+':8','source serial survives migration');
 commerce.tick(npc,visit,1900);assert.equal(testHost(state,npc,visit),null,'payment gesture is not a receipt');assert.equal(state.account.cash,80);checks++;
 commerce.tick(npc,visit,3100);assert.equal(wallet.balance,77);
 const host=testHost(state,npc,visit);assert(host);assert(apply(state,host.receipt,host.context).accepted);
 assert.equal(state.account.cash,77);assert.equal(wallet.balance,77,'mirror must not debit actual wallet twice');assert(conserved(state));
 assert.equal(wallet.inventory.used_watch.quantity,2);assert.equal(wallet.inventory.newspaper.quantity,1);assert.equal(wallet.receipts[0].id,'prior-purchase');checks++;
 const saved=JSON.parse(JSON.stringify(state)),before=JSON.stringify(wallet);
 commerce.tick(npc,visit,4000);assert.equal(apply(saved,host.receipt,host.context).reason,'duplicate');assert.equal(JSON.stringify(wallet),before);checks++;
}
for(const [label,interrupt] of [['left-interior',n=>n.r=11],['dead',n=>n.dead=true],['panic',n=>n.panicUntil=10000],['cash-spent-elsewhere',n=>n._residentWallet.balance=1]]){
 const {npc,state}=make(),visit={door,phase:'browsing',until:4000};assert(commerce.arrive(npc,visit,0));interrupt(npc);const balance=npc._residentWallet.balance;
 commerce.tick(npc,visit,3200);assert.equal(testHost(state,npc,visit),null,label);assert.equal(npc._residentWallet.balance,balance);assert.equal(state.account.spent,0);checks++;
}
{
 const {npc,state}=make(),visit={door,phase:'browsing',until:4000};assert(commerce.arrive(npc,visit,0));commerce.tick(npc,visit,3100);
 const host=testHost(state,npc,visit),before=JSON.stringify(state);
 assert.equal(apply(state,{...host.receipt,id:'forged'},host.context).reason,'unverified-receipt');assert.equal(JSON.stringify(state),before);checks++;
 // An intervening accepted source debit requires reconciliation, never a blind
 // mirror overwrite of the existing wallet or an invented compensating credit.
 npc._residentWallet.balance-=5;
 assert.equal(apply(state,host.receipt,host.context).reason,'unverified-receipt');assert.equal(JSON.stringify(state),before);checks++;
}
{
 // Exercise the existing entry state machine too. Passability is a controlled
 // host stub; this is not an actual city geometry/collision acceptance test.
 const world=fs.readFileSync('world.html','utf8');
 Object.assign(box,{_walkTrafficNavigationResolver:()=>({ready:true}),_walkNpcNavigationResolver:()=>({swept:true,blocked:false}),_civilianPlanUnit:()=>.5,_npcEffectiveSpeed:()=>1,_npcPathPassable:()=>false,_residentNativePassable:()=>true,_clearNpcRoute:()=>{},pickNpcWaypoint:()=>{}});
 vm.runInContext(world.slice(world.indexOf('function _residentNativeVisitTick('),world.indexOf('function _residentEnterBuilding(')),box);
 const {npc,state}=make();npc.r=9.9;npc.walkPhase=0;
 const visit=npc._residentNativeVisit={phase:'entering',door:{...door,r:9.9,c:12},since:0};
 box._residentNativeVisitTick(npc,.05,0);
 assert(!visit.commerce);assert.equal(state.account.cash,80);assert.equal(npc._residentWallet.balance,80);checks++;
 box._npcPathPassable=()=>true;
 for(let i=1;i<=4;i++)box._residentNativeVisitTick(npc,.05,i*50);
 assert(visit.commerce);assert(Math.hypot(npc.r-door.inside.r,npc.c-door.inside.c)<=.04);
 box._residentNativeVisitTick(npc,.05,3400);
 const host=testHost(state,npc,visit);assert(host);assert(apply(state,host.receipt,host.context).accepted);
 assert.equal(state.account.cash,77);assert.equal(npc._residentWallet.balance,77);assert(conserved(state));checks++;
}
const report={pass:true,checks,source:'actual npc_resident_commerce_source.js and world resident visit tick',limits:'Isolated test-host receipt bridge; controlled passability stubs, no production adapter, city geometry acceptance, online authority, bank/hospital execution or GPU/FPS claim.'};
fs.writeFileSync('outputs/npc_resident_needs23_commerce.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
