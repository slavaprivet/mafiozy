import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {performance} from 'node:perf_hooks';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
const reports=[];
for(const assetId of ['print_shop']){
 const f=await createCivilianNativeFixture({assetId}),b=f.box,door=b._residentBuildingDoors()[0];
 assert.equal(door.assetId,assetId,'catalog uses actual model metadata');
 assert(door.native&&door.inside);assert.equal(door.sourceKind,'native');assert.equal(door.sourceAliases.length,0,'no invented canonical shop ownership');
 const dr=door.r-door.inside.r,dc=door.c-door.inside.c,length=Math.hypot(dr,dc);
 const start={r:door.r+dr/length*.65,c:door.c+dc/length*.65};
 assert(b._npcPathPassable(start.r,start.c,door.r,door.c,b.npcPassableForSnitch),'real pavement reaches entrance');
 assert(!b._npcPathPassable(door.r,door.c,door.inside.r,door.inside.c,b._residentNativePassable),'actual closed leaf blocks entry');
 const n={id:'resident_actual_'+assetId,...start,tr:start.r,tc:start.c,hp:60,max_hp:60,speed:1,alive:true,walkPhase:0,_arcKey:'worker',_npcRoutine:'errands',_civilianPlan:{phase:'seek_shop',cycle:0,doorId:door.id}};f.npcs.push(n);
 const wallet=b._residentCommerceAccount(n),balance=wallet.balance,costs=[],phases=new Set();let distance=0,paidInside=false,done=false,maxStep=0,error=null,block=null;
 try{
  for(let i=0;i<900;i++){
   f.nextFrame(.05);const old={r:n.r,c:n.c},t=performance.now();
   if(!b._residentNativeVisitTick(n,.05,f.now)){
    if(!n._route?.length)b._maybePlanResidentBuildingVisit(n);
    if(!n._routeSearchPending)b.actualFootTick(n,.05,f.now);
   }
   costs.push(performance.now()-t);const v=n._residentNativeVisit;
   phases.add(v?.commerce?.phase||v?.phase||n._civilianPlan.phase);
   if(v?.phase)phases.add(v.phase);
   if(!block&&n._residentVisitStatus==='entry-path-blocked'){
    block={position:{r:n.r,c:n.c},target:door.inside,door:{r:door.r,c:door.c},point:b._residentNativePassable(door.inside.r,door.inside.c),radii:[.18,.14,.1,.08].map(radius=>({radiusM:radius*f.M,...f.pedestrian.query({mode:'sweep',from:{r:n.r,c:n.c},to:door.inside,radius})}))};
   }
   const step=Math.hypot(n.r-old.r,n.c-old.c);distance+=step*f.M;maxStep=Math.max(maxStep,step*f.M);
   assert(step<=.4*.05+1e-6,'no shop teleport');assert.equal(f.npcs[0],n);assert.equal(n.hp,60);assert(!n._residentIndoors);
   if(wallet.receipts.length){assert(v?.phase==='browsing'||v?.phase==='exiting'||n._residentVisitStatus==='visit-complete');if(!paidInside)assert(f.entry.containsInterior(new f.THREE.Vector3(n.c*f.M,f.floor(n.c*f.M,n.r*f.M),n.r*f.M)),'first payment is within the actual model interior');paidInside=true;assert.equal(wallet.receipts.length,1);}
   if(n._residentVisitStatus==='visit-complete'){done=true;break;}
  }
 }catch(e){error=e.message;}
 costs.sort((a,b)=>a-b);const receipt=wallet.receipts[0];
 const report={assetId,entryId:door.id,done,error,block,phases:[...phases],distanceM:distance,maxStepM:maxStep,initialBalance:balance,finalBalance:wallet.balance,receipt,paidInside,p50Ms:costs[Math.floor(costs.length*.5)],p95Ms:costs[Math.floor(costs.length*.95)],final:{r:n.r,c:n.c,status:n._residentVisitStatus},limit:'actual shop GLB/source/collision and session wallet CPU; no GPU appearance or server income'};
 reports.push(report);console.log(JSON.stringify(report,null,2));
 assert(!error,error);assert(done,'physical shop visit must finish');assert(paidInside,'real entry must reach checkout');assert.equal(balance-wallet.balance,receipt.price);assert.equal(wallet.inventory[receipt.item].quantity,1);
 for(const phase of ['entering','browse','pay','complete','exiting'])assert(phases.has(phase),assetId+' phase '+phase);
}
fs.writeFileSync(new URL('../../../outputs/npc_actual_shop_visits_20260919.json',import.meta.url),JSON.stringify(reports,null,2));
