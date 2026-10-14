import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const fixtureURL=new URL('./test_npc_service_applied23.mjs',import.meta.url);
let prefix=fs.readFileSync(fixtureURL,'utf8');prefix=prefix.slice(0,prefix.indexOf('const n=box.spawnNpc(777777'));
prefix=prefix.replace(/from\s+(['"])(\.[^'"]+)\1/g,(_,q,s)=>'from '+JSON.stringify(new URL(s,fixtureURL).href));
prefix=prefix.replace(/import\((['"])(\.[^'"]+)\1\)/g,(_,q,s)=>'import('+JSON.stringify(new URL(s,fixtureURL).href)+')');
prefix=prefix.replace(/new URL\((['"])([^'"]+)\1,import\.meta\.url\)/g,(_,q,s)=>'new URL('+JSON.stringify(new URL(s,fixtureURL).href)+')');
prefix+='\nexport {f,box,pilot,frame,door,world,population,sourceFunction};';
const {f,box,pilot,frame,door,world,population,sourceFunction}=await import('data:text/javascript;base64,'+Buffer.from(prefix).toString('base64'));
vm.runInContext(sourceFunction(world,'_planNpcEscapeRoute'),box);
const panicStart=world.indexOf('    if (n.panicUntil && now < n.panicUntil) {',world.indexOf('function updateNpcs(')),panicEnd=world.indexOf('    } else if (n.panicUntil)',panicStart);assert(panicStart>0&&panicEnd>panicStart);
vm.runInContext('function servicePanicDispatch23(n,dt,now){for(const once of [0]){if(_npcRunActivityElapsed(n,null,dt,now,_residentNativeVisitTick))return true;\n'+world.slice(panicStart,panicEnd)+'\n}}return false;}',box);
const results=[];let serial=880000;
for(const scenario of ['panic-await','panic-approach','panic-counter','combat-counter','report-counter','conversation-counter']){
 const n=box.spawnNpc(++serial,{cityOnly:true});Object.assign(n,{r:door.r,c:door.c,tr:door.r,tc:door.c,_civilianPlan:{phase:'walk_to_shop',cycle:1},_residentWallet:{balance:80,serial:0,inventory:{},receipts:[]},_arc:{...n._arc,panicMult:2.5}});f.npcs.push(n);assert(box._residentEnterBuilding(n,f.now,door));
 const reached=()=>scenario.endsWith('await')?n._residentNativeVisit?._serviceRoute23?.stage==='await':scenario.endsWith('approach')?n._residentNativeVisit?._serviceRoute23?.stage==='approach':n._residentNativeVisit?.phase==='browsing';
 let guard=0;while(!reached()){frame(.05);pilot.controller.tick(f.now,0);box._residentNativeVisitTick(n,.05,f.now);assert(++guard<700,'reach '+scenario);}
 const visit=n._residentNativeVisit,certificate=visit._serviceRoute23.certificate,before={r:n.r,c:n.c};
 if(scenario.startsWith('panic')){n.panicUntil=f.now+10000;n._panicStyle='flee';n.panicSrcR=n.r-.1;n.panicSrcC=n.c;}
 else if(scenario.startsWith('combat'))n._fighting=true;
 else if(scenario.startsWith('report'))n.snitching=true;
 else n._playerConversationOpen=true;
 n.walking=true;const ownerRoute=[{r:n.r+.01,c:n.c}];n._route=ownerRoute;n._routeKind='higher-priority-owner';
 for(let i=0;i<20;i++){
  frame(.1);pilot.controller.tick(f.now,0);
  assert.equal(box._npcRunActivityElapsed(n,null,.1,f.now,box._residentNativeVisitTick),false,'visit yields existing source owner immediately');
  assert.equal(n.walking,true,'visit does not overwrite owner walking');assert.equal(n._route,ownerRoute,'visit does not clear foreign route');assert.deepEqual({r:n.r,c:n.c},before,'visit does not move foreign owner');
 }
 assert.equal(n._residentNativeVisit,visit);assert.equal(visit._serviceRoute23.certificate,certificate,'exit capability retained');assert.equal(n._residentWallet.balance,80);assert.equal(n._residentWallet.receipts.length,0);if(visit.commerce)assert.equal(visit.commerce.phase,'cancelled');
 let panicMovementM=0;
 if(scenario==='panic-counter'){
  const via=visit._serviceRoute23.points[1];assert(pilot.canSweep({r:n.r,c:n.c},via,n),'physical source panic leg must be clear');
  box._setNpcRoute(n,[{r:via.r,c:via.c}],'panic');
  assert.equal(box.servicePanicDispatch23(n,.1,f.now),false,'actual later panic branch gets control');
  panicMovementM=Math.hypot(n.r-before.r,n.c-before.c)*f.M;assert(panicMovementM>.01,'actual existing panic route executor moves shopper');
 }
 // End the injected incident. Source resumes from the actual displaced point.
 n.panicUntil=0;n._fighting=false;n.snitching=false;n._playerConversationOpen=false;
 let exitFrames=0;while(n._residentNativeVisit){frame(.1);pilot.controller.tick(f.now,0);box._residentNativeVisitTick(n,.1,f.now);assert(++exitFrames<600,'physical interrupted exit '+scenario);}
 assert.equal(n._residentWallet.balance,80);assert.equal(n._residentWallet.receipts.length,0);
 assert(Math.hypot(n.r-visit.returnPoint.r,n.c-visit.returnPoint.c)<=.03,'physical return point reached without teleport');
 results.push({scenario,yieldTicks:20,exitFrames,panicMovementM,balance:80});f.npcs.splice(f.npcs.indexOf(n),1);
}
pilot.dispose();population.dispose();f.entry.dispose();
const report={pass:true,results,limits:'Actual composed source visit/commerce/elapsed arbitration, native geometry, production GLB population. Incidents injected at ownership boundary; one real original panic movement branch/route executed. No full world perception/combat/GPU/FPS claim.'};
console.log(JSON.stringify({...report,actualAppliedRuntime:true},null,2));
