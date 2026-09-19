import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {performance} from 'node:perf_hooks';
const code=fs.readFileSync(new URL('./npc_resident_commerce_source.js',import.meta.url),'utf8');
const context=vm.createContext({_civilianPlanInterrupted:(n,now)=>n.panicUntil>now||n._fighting||n.dead});vm.runInContext(code,context);
const api=vm.runInContext('({account:_residentCommerceAccount,arrive:_residentCommerceArrive,tick:_residentCommerceTick,activity:_residentCommerceActivity,choose:_residentChoosePurposeDoors,purpose:_residentDoorPurpose,stats:_residentCommerceStats})',context);
const shop={id:'native:printing',assetId:'print_shop',inside:{r:10,c:12}},home={id:'native:home',assetId:'townhouse',buildingRole:'residence',inside:{r:10,c:12}},bank={id:'native:bank',sourceKind:'bank',inside:{r:10,c:12}};
const resident=id=>({id,r:10,c:12,hp:60,_civilianPlan:{cycle:0}});
const visit=(door=shop)=>({door,phase:'browsing',since:0,until:4000});
let n=resident('alice'),v=visit();n._residentNativeVisit=v;let balance=api.account(n).balance;
assert(api.arrive(n,v,0));assert(!api.arrive(n,v,1),'arrival repeated cannot replace receipt');assert(api.tick(n,v,1799));assert.equal(api.activity(n).phase,'browse');
assert(api.tick(n,v,1900));assert.equal(api.activity(n).phase,'pay');assert.equal(n._residentWallet.balance,balance,'gesture does not spend before checkout');
assert(!api.tick(n,v,3100));assert.equal(n._residentWallet.balance,balance-3);assert.equal(n._residentWallet.inventory.newspaper.quantity,1);assert.equal(n._residentWallet.receipts.length,1);
api.tick(n,v,4000);assert.equal(n._residentWallet.balance,balance-3,'one debit per visit');assert.equal(api.activity(n),null);
assert.equal(api.arrive(n,visit(),5000),false,'does not buy the same need at each door loop');
for(const door of [home,bank,{id:'unknown',inside:shop.inside}]){const other=resident(door.id);assert.equal(api.arrive(other,visit(door),0),false,'no fictitious sale in '+door.id);assert(!other._residentWallet);}
for(const [label,change]of [['dead',x=>x.dead=true],['panic',x=>x.panicUntil=10000],['left interior',x=>x.c=13]]){
 const other=resident(label),order=visit();api.arrive(other,order,0);const before=other._residentWallet.balance;change(other);api.tick(other,order,4000);assert.equal(other._residentWallet.balance,before,label);assert.equal(order.commerce.phase,'cancelled');
}
n=resident('poor');api.account(n).balance=0;assert(!api.arrive(n,visit(),0));assert.equal(api.choose(n,[home,shop],'home',0)[0],home);
n=resident('errands');assert.equal(api.choose(n,[home,bank,shop],'errands',0)[0],shop);n._civilianPlan.doorId=bank.id;assert.equal(api.choose(n,[home,bank,shop],'errands',0).length,3,'retained trip destination remains authoritative');
n=resident('far');n.r=9;assert(!api.arrive(n,visit(),0),'proximity to outside is not physical interior arrival');
n=resident('journal');api.account(n).balance=1000;for(let i=0;i<20;i++){v=visit();api.arrive(n,v,i*400000);api.tick(n,v,i*400000+4000);}assert.equal(n._residentWallet.receipts.length,8);assert.equal(n._residentWallet.inventory.newspaper.quantity,20);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
assert(world.includes('npc_resident_commerce_source.js'));assert(world.includes('_residentCommerceArrive(n,visit,now)'));assert(world.includes('_residentCommerceTick(n,visit,now)'));
Object.assign(context,{_walkTrafficNavigationResolver:()=>({ready:true}),_walkNpcNavigationResolver:()=>({swept:true,blocked:false}),_civilianPlanUnit:()=>.5,_npcEffectiveSpeed:()=>1,_npcPathPassable:()=>false,_residentNativePassable:()=>true,_clearNpcRoute:()=>{},pickNpcWaypoint:()=>{}});
vm.runInContext(world.slice(world.indexOf('function _residentNativeVisitTick('),world.indexOf('function _residentEnterBuilding(')),context);
const physical=resident('physical');physical.r=9.9;physical.walkPhase=0;physical._residentNativeVisit={phase:'entering',door:{...shop,r:9.9,c:12},since:0};
context._residentNativeVisitTick(physical,.05,0);assert(!physical._residentWallet,'blocked actual source entry cannot buy');
context._npcPathPassable=()=>true;for(let i=1;i<=4;i++)context._residentNativeVisitTick(physical,.05,i*50);
assert(physical._residentNativeVisit.commerce,'actual physical inside arrival starts checkout');const physicalBalance=physical._residentWallet.balance;
context._residentNativeVisitTick(physical,.05,3400);assert.equal(physical._residentWallet.balance,physicalBalance-3,'actual source browsing completes exactly one purchase');
// Compare equal populations: no commerce vs an unsettled interior browse. The
// per-resident function performs no scan of residents/buildings or route query.
const samples=[],baseline=[],pool=Array.from({length:384},(_,i)=>resident('bench'+i));for(const item of pool){item._residentNativeVisit=visit();api.arrive(item,item._residentNativeVisit,0);}
let sink=0;for(let batch=0;batch<600;batch++){let t=performance.now();for(const item of pool)sink+=item.r+item.c;baseline.push(performance.now()-t);t=performance.now();for(const item of pool)api.tick(item,item._residentNativeVisit,500);samples.push(performance.now()-t);}
const pct=(s,p)=>s.sort((a,b)=>a-b)[Math.floor(s.length*p)];console.log(JSON.stringify({pass:true,cases:'physical checkout, one debit, need cooldown, cancelled crime/death/exit, actual shop classification, existing destination, capped receipts',cpu384:{baselineP50:pct(baseline,.5),baselineP95:pct(baseline,.95),commerceP50:pct(samples,.5),commerceP95:pct(samples,.95)},limit:'CPU only; session NPC wallet, no server revenue/persistence or GPU acceptance',sink}));
