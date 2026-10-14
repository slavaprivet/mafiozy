import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {advanceStationaryServiceActor,createStationaryServiceAdapter} from './npc_stationary_service_adapter.mjs';
import {createServiceEmployee23,stepServiceEmployee23,serviceEligibility23} from '../../../npc_service_employee23_candidate.mjs';
import {serviceArrivalSourceCandidate} from '../../../npc_service_arrival23_patch_candidate.mjs';
const actualSource=fs.readFileSync(new URL('npc_resident_commerce_source.js',import.meta.url),'utf8');
const proposal=actualSource.includes('function _residentCommerceArrivalTarget(')?actualSource:serviceArrivalSourceCandidate(actualSource);
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot}),rc=p=>({r:p.z/f.M,c:p.x/f.M});
const clear=p=>!f.pedestrian.query({mode:'sweep',from:rc(p),to:rc(p),radius:.18}).blocked;
const station=createPrintShopServiceStation({THREE:f.THREE,entry:f.entry,siteRevision:'arrival23',validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer','customerVia'].every(k=>clear(layout[k]))});
const layout=station.layout,originalBodies=f.entry.getCollisionBodies.bind(f.entry);
f.entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies());f.refreshBodies();f.pedestrian.beginFrame();
const actualDoor=f.box.nativeTrafficQuery({mode:'resident-access',action:'list'}).doors.find(d=>d.instanceId===layout.buildingId),doorBefore=JSON.stringify(actualDoor);
let checks=0;
for(const hz of [60,7,3]){
 const box=vm.createContext({_civilianPlanInterrupted:()=>false});vm.runInContext(proposal,box);
 const api=vm.runInContext('({arrive:_residentCommerceArrive,tick:_residentCommerceTick,register:_residentCommerceRegisterService,target:_residentCommerceArrivalTarget})',box);
 const npc={id:'buyer-'+hz,generation:1,hp:100,...actualDoor.inside,_civilianPlan:{cycle:0},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}},visit={id:'visit-'+hz,door:actualDoor,phase:'browsing',until:10000};
 let seller={id:'seller',generation:2,hp:100,position:{...layout.work}},now=0,targetStamp='site:arrival23:buyer:'+hz+':visit:'+hz;
 const host={validateLayout:()=>true,isCurrentSite:()=>true,ownsServiceSlot:()=>true},state=createServiceEmployee23({layout,employeeId:seller.id,employeeGeneration:2},host);
 const updateEmployee=()=>stepServiceEmployee23(state,{now,siteRevision:layout.revision,actor:seller,door:station.doorState},host);
 const adapter=createStationaryServiceAdapter({buildingId:layout.buildingId,getServiceAccess:()=>serviceEligibility23(state,{now,actor:seller,customer:{...npc,position:{x:npc.c*f.M,y:layout.customer.y,z:npc.r*f.M}},siteRevision:layout.revision,visitId:visit.id},host)});
 adapter.getServiceArrivalTarget=()=>({...rc(layout.customer),y:layout.customer.y,stamp:targetStamp});
 const unregister=api.register(layout.buildingId,adapter);updateEmployee();
 assert.equal(api.arrive(npc,visit,now),false,'real entrance is not counter arrival');checks++;
 const movementHost={identity:n=>({id:n.id,generation:n.generation}),hasControl:()=>true,canSweep:(a,b)=>f.box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),isStationFloor:(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05};
 for(const target of [layout.customerVia,layout.customer]){
  let move,count=0;
  do{
   now+=1000/hz;f.pedestrian.beginFrame();updateEmployee();
   move=advanceStationaryServiceActor({actor:npc,target,actorId:npc.id,generation:1,controlToken:'fixture-service',dt:1/hz},movementHost);
   assert(['moving','arrived'].includes(move.status));assert(++count<1000);assert.equal(npc._residentWallet.balance,80);
  }while(move.status!=='arrived');
 }
 updateEmployee();assert(api.arrive(npc,visit,now),'actual precise arrival is accepted');
 now+=3100;updateEmployee();api.tick(npc,visit,now);
 assert.equal(npc._residentWallet.balance,77);assert.equal(npc._residentWallet.inventory.newspaper.quantity,1);assert.equal(visit.commerce.serviceResult.accepted,true);checks++;
 api.tick(npc,visit,now+1);assert.equal(npc._residentWallet.balance,77);checks++;
 // Resolved service target never silently changes into an entrance checkout.
 targetStamp+=':changed';assert.equal(api.target(npc,visit,now),null);checks++;
 targetStamp=targetStamp.slice(0,-8);unregister();assert.equal(api.target(npc,visit,now),null);checks++;
 api.register(layout.buildingId,adapter);assert.equal(api.target(npc,visit,now),null);checks++;
 assert.equal(JSON.stringify(actualDoor),doorBefore,'shared entrance/exit data untouched');
}
{
 const box=vm.createContext({_civilianPlanInterrupted:()=>false});vm.runInContext(proposal,box);
 const api=vm.runInContext('({arrive:_residentCommerceArrive,tick:_residentCommerceTick,register:_residentCommerceRegisterService,target:_residentCommerceArrivalTarget})',box);
 const npc={id:'guards',generation:1,hp:100,...rc(layout.customer),_civilianPlan:{},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]}};
 let target={...rc(layout.customer),y:layout.customer.y,stamp:'stable'},live=true;
 const provider={getServiceArrivalTarget:()=>target,canServe:()=>({available:live,stamp:'seller2'}),onPurchase:()=>({accepted:true})};
 const remove=api.register(layout.buildingId,provider);
 const visit={door:actualDoor,phase:'browsing',until:10000};
 assert(api.arrive(npc,visit,0));live=false;api.tick(npc,visit,3100);assert.equal(visit.commerce.phase,'cancelled');assert.equal(npc._residentWallet.balance,80);checks++;
 for(const invalid of [null,{...target,r:NaN},{...target,c:Infinity},{...target,y:undefined},{...target,stamp:''}]){
  target=invalid;assert.equal(api.target(npc,{door:actualDoor},0),null);checks++;
 }
 const other={door:{...actualDoor,id:'other',instanceId:'other'}};assert.deepEqual(api.target(npc,other,0),actualDoor.inside);checks++;
 const waiting={door:actualDoor,phase:'browsing'};target=null;
 assert.equal(api.target(npc,waiting,0),null);remove();Object.assign(npc,actualDoor.inside);
 assert.equal(api.target(npc,waiting,1),null,'first invalid service target still binds the visit; removal cannot fall back to entrance checkout');
 assert.equal(api.arrive(npc,waiting,1),false);assert.equal(npc._residentWallet.balance,80);checks++;
}
station.dispose();f.entry.getCollisionBodies=originalBodies;f.entry.dispose();
const report={pass:true,checks,limits:'Exact proposed commerce source delta in VM plus actual geometry/capsule movement at60/7/3Hz. No fake arrival boolean. Actor records and service-slot authority are fixtures; source file frozen, no world movement hook/activation/LIVE.'};
fs.writeFileSync(new URL('../../../outputs/npc_service_arrival23_candidate.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
