import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createStationaryServiceAdapter,advanceStationaryServiceActor} from './npc_stationary_service_adapter.mjs';
import {createResidentNeeds23,chooseResidentIntent23,applyResidentReceipt23,residentLedgerConserved23} from '../../../npc_resident_needs23_candidate.mjs';
const code=fs.readFileSync(new URL('npc_resident_commerce_source.js',import.meta.url),'utf8');
const setup=()=>{
 const box=vm.createContext({_civilianPlanInterrupted:n=>n.panicUntil>0||n.dead});vm.runInContext(code,box);
 const api=vm.runInContext('({arrive:_residentCommerceArrive,tick:_residentCommerceTick,register:_residentCommerceRegisterService})',box);
 const buildingId='REBUILD-VISUAL-print_shop-001',door={id:'native:'+buildingId,instanceId:buildingId,assetId:'print_shop',inside:{r:10,c:12}};
 let npc,state;
 for(let i=0;i<100;i++){
  npc={id:'adapter-buyer-'+i,r:10,c:12,hp:100,_civilianPlan:{cycle:0},_residentWallet:{balance:80,serial:7,inventory:{used_watch:{quantity:2}},receipts:[]}};
  state=createResidentNeeds23({npcId:npc.id,cash:80,bank:200,bankId:'B'});
  const goal=chooseResidentIntent23(state,{npcId:npc.id,now:1,health:{hp:100,max:100,version:1},places:[{id:door.id,kind:'shop',price:3,distanceM:0}]});
  if(goal.intent.kind==='shop')break;
 }
 assert.equal(state.goal.kind,'shop');
 const service={alive:true,generation:1,customerArrived:true},visit={door,phase:'browsing',until:4000,id:'visit-pilot-1'};
 const adapter=createStationaryServiceAdapter({buildingId,getServiceAccess:({npc,visit})=>({eligible:service.alive&&service.customerArrived,buildingId,siteRevision:'pilot-r1',stationId:'desk',employeeId:'seller',employeeGeneration:service.generation,customerId:npc.id,customerGeneration:1,visitId:visit.id}),getNeedsBinding:()=>({state,applyReceipt:applyResidentReceipt23})});
 return{api,npc,state,door,visit,adapter,service,buildingId};
};
let checks=0;
{
 const f=setup(),remove=f.api.register(f.buildingId,f.adapter),wallet=f.npc._residentWallet;
 assert(f.api.arrive(f.npc,f.visit,0));f.api.tick(f.npc,f.visit,1900);assert.equal(wallet.balance,80);
 f.api.tick(f.npc,f.visit,3100);assert.equal(wallet.balance,77);assert.equal(f.state.account.cash,77);assert(residentLedgerConserved23(f.state));assert.equal(f.visit.commerce.serviceResult.mirrored,true);assert.equal(wallet.inventory.newspaper.quantity,1);assert.equal(wallet.inventory.used_watch.quantity,2);checks++;
 f.api.tick(f.npc,f.visit,4000);assert.equal(wallet.balance,77);assert.equal(f.state.account.spent,3);checks++;
 assert(!Object.values(f.visit.commerce).includes(f.adapter),'persistent order does not retain provider closures');remove();
}
for(const scenario of ['dead-before','dead-during','generation-replaced','customer-away','provider-removed']){
 const f=setup(),remove=f.api.register(f.buildingId,f.adapter);
 if(scenario==='dead-before'){f.service.alive=false;assert.equal(f.api.arrive(f.npc,f.visit,0),false);}
 else{
  assert(f.api.arrive(f.npc,f.visit,0));
  if(scenario==='dead-during')f.service.alive=false;
  if(scenario==='generation-replaced')f.service.generation++;
  if(scenario==='customer-away')f.service.customerArrived=false;
  if(scenario==='provider-removed')remove();
  f.api.tick(f.npc,f.visit,3100);assert.equal(f.visit.commerce.phase,'cancelled');
 }
 assert.equal(f.npc._residentWallet.balance,80);assert.equal(f.state.account.cash,80);assert.equal(f.npc._residentWallet.receipts.length,0);checks++;
}
{
 const f=setup();f.api.register('other-building',f.adapter);assert(f.api.arrive(f.npc,f.visit,0));f.api.tick(f.npc,f.visit,3100);assert.equal(f.npc._residentWallet.balance,77);assert.equal(f.state.account.cash,80,'unregistered buildings retain prior checkout without new mirror');checks++;
}
{
 const f=setup();f.api.register(f.buildingId,f.adapter);assert(f.api.arrive(f.npc,f.visit,0));f.state.account.cash=79;
 f.api.tick(f.npc,f.visit,3100);assert.equal(f.npc._residentWallet.balance,77);assert.equal(f.visit.commerce.serviceResult.reason,'account-sync-required');f.api.tick(f.npc,f.visit,4000);assert.equal(f.npc._residentWallet.balance,77,'failed mirror never repeats source debit');checks++;
}
{
 const f=setup();assert.throws(()=>f.api.register(f.buildingId,{}));f.api.register(f.buildingId,f.adapter);assert.throws(()=>f.api.register(f.buildingId,f.adapter));assert.throws(()=>createStationaryServiceAdapter({buildingId:f.buildingId,mode:'authenticated',getServiceAccess:()=>true}));checks++;
}
for(const balance of [NaN,Infinity,-1,1.5,0x80000000]){
 const f=setup();f.npc._residentWallet.balance=balance;assert.equal(f.api.arrive(f.npc,f.visit,0),false);checks++;
}
const actor=()=>({id:'moving-staff',generation:3,r:0,c:0,hp:100});
const moveInput=n=>({actor:n,target:{x:1,y:0,z:0},actorId:n.id,generation:3,controlToken:'staff-lease',dt:.2});
const moveHost={identity:n=>({id:n.id,generation:n.generation}),hasControl:()=>true,canSweep:()=>true,isStationFloor:()=>true};
for(const change of [{dt:-1},{dt:NaN},{dt:Infinity},{dt:0},{dt:2},{speedMps:Infinity},{speedMps:4},{generation:2},{controlToken:''}]){
 const n=actor(),before=JSON.stringify(n);assert.equal(advanceStationaryServiceActor({...moveInput(n),...change},moveHost).status,'hold');assert.equal(JSON.stringify(n),before);checks++;
}
for(const key of ['hasControl','canSweep','isStationFloor']){
 const n=actor();const result=advanceStationaryServiceActor(moveInput(n),{...moveHost,[key]:()=>false});assert(['blocked','hold'].includes(result.status));assert.equal(n.r,0);assert.equal(n.c,0);checks++;
}
{
 const n=actor(),h={...moveHost,canSweep:()=>{n.hp=0;n.dead=true;return true;}};
 assert.equal(advanceStationaryServiceActor(moveInput(n),h).status,'hold');assert.equal(n.c,0,'death during collision query prevents stale write');assert.equal(n.hp,0);checks++;
}
{
 const n=actor();let owned=true,calls=0;const h={...moveHost,hasControl:()=>owned,canSweep:()=>{if(++calls===2)owned=false;return true;}};
 const result=advanceStationaryServiceActor(moveInput(n),h);assert.equal(result.status,'hold');assert(result.movedMetres>0&&result.movedMetres<=.0625);assert(Math.abs(n.c*4.1-result.movedMetres)<1e-10);checks++;
}
{
 const n=actor();let sweeps=0;const result=advanceStationaryServiceActor({...moveInput(n),dt:1/3},{...moveHost,canSweep:()=>{sweeps++;return true;}});
 assert.equal(sweeps,7);assert.equal(result.status,'moving');assert(Math.abs(result.movedMetres-1.25/3)<1e-10);checks++;
}
for(const key of ['isStationFloor','canSweep']){
 const n=actor();n.r=10;n.c=12;let calls=0;
 const result=advanceStationaryServiceActor({...moveInput(n),target:{x:49.2,y:3.2,z:41}},{...moveHost,[key]:()=>{calls++;return false;}});
 assert.equal(result.status,'blocked');assert.equal(calls,1);assert.equal(n.r,10);assert.equal(n.c,12);checks++;
}
{
 const n=actor();let owned=true;
 const result=advanceStationaryServiceActor({...moveInput(n),target:{x:0,y:0,z:0}},{...moveHost,hasControl:()=>owned,isStationFloor:()=>{owned=false;return true;}});
 assert.equal(result.status,'hold');assert.equal(n.walking,undefined,'arrival query cannot write after losing control');checks++;
}
console.log(JSON.stringify({pass:true,checks,limits:'Actual source checkout and opt-in adapter; source access/movement guard callbacks are controlled. No instantiated seller/room, world registration, online banking or LIVE/FPS claim.'},null,2));
