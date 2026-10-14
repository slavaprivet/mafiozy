import assert from 'node:assert/strict';
import fs from 'node:fs';
import {performance} from 'node:perf_hooks';
import {createServiceEmployee23 as create,stepServiceEmployee23 as step,serviceEligibility23 as eligible} from './npc_service_employee23_candidate.mjs';
// Synthetic certified-host fixture for state/authority tests. Actual building
// inventory is separately audited; these coordinates are never sent to world.
const p=(x,z)=>({x,y:0,z}),layout={buildingId:'actual-host-building',revision:'layout-r1',stationId:'counter-1',roomId:'stockroom-1',doorId:'service-door-1',spawn:p(0,0),doorInside:p(0,1),doorOutside:p(0,3),work:p(3,3),customer:p(3,5)};
const host={validateLayout:()=>true,isCurrentSite:()=>true,verifyDeath:a=>a.deathReceiptId==='death-7',canSpawnInClosedRoom:()=>true,verifySpawnReceipt:r=>r.authority==='session-test',doorSweepClear:()=>true,ownsServiceSlot:()=>true};
const make=()=>create({layout,employeeId:'seller-1',employeeGeneration:7},host);
const actor=(position=layout.work,extra={})=>({id:'seller-1',generation:7,hp:100,position:{...position},...extra});
const snapshot=(now,employee,extra={})=>({now,actor:employee,siteRevision:layout.revision,door:{id:layout.doorId,fraction:0},...extra});
let checks=0;
{
 assert.throws(()=>create({layout,employeeId:'seller-1',employeeGeneration:7},{}));
 assert.throws(()=>create({layout:{...layout,spawn:p(NaN,0)},employeeId:'seller-1',employeeGeneration:7},host));checks++;
}
{
 const s=make(),a=actor(),before=JSON.stringify(a);
 assert.equal(step(s,snapshot(1,a),host).status,'working');assert.equal(JSON.stringify(a),before,'controller does not move or mutate source actor');checks++;
 for(const flag of ['panic','combat','custody','medicalOwned','reportingCrime']){
  assert.equal(step(s,snapshot(++s.lastNow,actor(layout.work,{[flag]:true})),host).reason,'existing-crime-or-medical-owner');assert.equal(s.available,false);checks++;
 }
 assert.equal(step(s,snapshot(s.lastNow+1,actor(layout.spawn)),host).intent.kind,'walk');assert.equal(s.available,false);checks++;
}
const s=make(),dead=actor(layout.work,{hp:0,dead:true,deadAt:1000,deathReceiptId:'death-7'});
assert.equal(step(s,snapshot(1000,dead),host).until,61000);assert.equal(s.phase,'dead');checks++;
assert.equal(step(s,snapshot(60000,null),host).until,61000,'renderer absence does not reset source death timer');checks++;
const restored=JSON.parse(JSON.stringify(s));assert.equal(restored.death.dueAt,61000);assert.equal(step(restored,snapshot(60001,actor()),host).reason,'employee-dead','same generation positive HP cannot resurrect the seller');checks++;
assert.equal(step(s,snapshot(61000,dead),{...host,canSpawnInClosedRoom:()=>false}).reason,'backroom-not-ready');assert.equal(s.respawn,null);checks++;
assert.equal(step(s,snapshot(61001,dead,{door:{id:layout.doorId,fraction:1}}),host).reason,'backroom-not-ready');checks++;
const spawn=step(s,snapshot(61002,dead),host).intent;assert.equal(spawn.kind,'respawn-in-backroom');assert.deepEqual(spawn.position,layout.spawn);assert.equal(spawn.generation,8);assert.equal(spawn.buildingId,layout.buildingId);checks++;
const repeated=step(s,snapshot(61003,dead),host);assert.equal(repeated.status,'pending');assert.equal(repeated.requestId,spawn.requestId);assert.equal(s.generation,7,'clock alone cannot resurrect');checks++;
const receipt={accepted:true,requestId:spawn.requestId,buildingId:layout.buildingId,siteRevision:layout.revision,employeeId:s.employeeId,generation:8,spawnedAt:61004,position:{...layout.spawn},authority:'session-test'};
for(const change of [{buildingId:'other'},{generation:9},{spawnedAt:60999},{position:{...layout.work}},{accepted:false}]){
 const trial=structuredClone(s);assert.equal(step(trial,snapshot(61004,actor(layout.spawn,{generation:8}),{spawnReceipt:{...receipt,...change}}),host).reason,'unverified-respawn');assert.equal(trial.generation,7);checks++;
}
let result=step(s,snapshot(61004,actor(layout.spawn,{generation:8}),{spawnReceipt:receipt}),host);
assert.equal(s.generation,8);assert.equal(result.intent.kind,'walk');assert.deepEqual(result.intent.target,layout.doorInside);assert.equal(s.available,false);checks++;
result=step(s,snapshot(61005,actor(layout.doorInside,{generation:8}),{spawnReceipt:receipt}),host);
assert.equal(result.intent.kind,'set-service-door');assert.equal(result.intent.open,true,'repeated spawn receipt cannot restart respawn');checks++;
result=step(s,snapshot(61006,actor(layout.doorInside,{generation:8}),{door:{id:layout.doorId,fraction:.5}}),host);
assert.equal(result.intent.open,true);assert.equal(s.phase,'opening');checks++;
result=step(s,snapshot(61007,actor(layout.doorInside,{generation:8}),{door:{id:layout.doorId,fraction:1}}),host);
assert.deepEqual(result.intent.target,layout.doorOutside);assert.equal(result.intent.requireSweptMovement,true);checks++;
result=step(s,snapshot(61008,actor(layout.doorInside,{generation:8}),{door:{id:layout.doorId,fraction:1}}),host);
assert.deepEqual(result.intent.target,layout.doorOutside);assert.equal(s.phase,'exiting','blocked movement never counts as arrival');checks++;
result=step(s,snapshot(61009,actor(layout.doorOutside,{generation:8}),{door:{id:layout.doorId,fraction:1}}),{...host,doorSweepClear:()=>false});
assert.equal(result.reason,'door-sweep-occupied');checks++;
result=step(s,snapshot(61010,actor(layout.doorOutside,{generation:8}),{door:{id:layout.doorId,fraction:1}}),host);
assert.equal(result.intent.open,false);checks++;
result=step(s,snapshot(61011,actor(layout.doorOutside,{generation:8})),host);
assert.deepEqual(result.intent.target,layout.work);assert.equal(s.available,false);checks++;
const working=actor(layout.work,{generation:8});assert.equal(step(s,snapshot(61012,working),host).status,'working');checks++;
const customer={id:'buyer-1',generation:1,hp:100,position:{...layout.customer}},request={now:61012,actor:working,customer,siteRevision:layout.revision,visitId:'visit-1'};
assert(eligible(s,request,host).eligible);checks++;
for(const extra of [{actor:{...working,hp:0,dead:true}},{actor:{...working,generation:7}},{actor:{...working,panic:true}},{customer:{...customer,position:layout.spawn}},{siteRevision:'replaced'},{now:61013}]){
 assert.equal(eligible(s,{...request,...extra},host).eligible,false);checks++;
}
assert.equal(eligible(s,request,{...host,ownsServiceSlot:()=>false}).eligible,false);checks++;
assert.equal(step(s,snapshot(61013,dead),host).reason,'generation-mismatch');assert.equal(s.death,null,'old generation corpse cannot kill replacement');checks++;
assert.equal(step(s,snapshot(61014,working,{siteRevision:'demolished'}),host).reason,'stale-site-or-clock');checks++;
{
 const reordered=Object.fromEntries(Object.entries(receipt).reverse());
 const copy=structuredClone(s);copy.phase='backroom';
 const result=step(copy,snapshot(62000,actor(layout.doorInside,{generation:8}),{spawnReceipt:reordered}),host);
 assert.equal(result.intent.kind,'set-service-door');assert.equal(result.intent.open,true);checks++;
 assert.equal(step(copy,snapshot(62001,actor(layout.doorInside,{generation:8}),{spawnReceipt:reordered}),{...host,verifySpawnReceipt:()=>false}).reason,'unverified-respawn');checks++;
}
for(const trustedDeath of [false,true]){
 const trial=make();step(trial,snapshot(1000,dead),host);const req=step(trial,snapshot(61000,dead),host).intent;
 const birth={...receipt,requestId:req.requestId,spawnedAt:61001};
 const killed=actor(layout.work,{generation:8,hp:0,dead:true,deadAt:61002,deathReceiptId:'death-8'});
 const h={...host,verifyDeath:a=>a.deathReceiptId==='death-7'||trustedDeath&&a.deathReceiptId==='death-8'};
 const result=step(trial,snapshot(61003,killed,{spawnReceipt:birth}),h);
 assert.equal(trial.generation,trustedDeath?8:7);
 if(trustedDeath){assert.equal(result.until,121002);assert.equal(step(trial,snapshot(61004,killed),h).until,121002);}else assert.equal(result.reason,'unverified-respawn');checks++;
}
const pool=Array.from({length:75},make),stable=actor(),baseline=[],workingCosts=[];let sink=0;
for(let round=0;round<450;round++){
 let start=performance.now();for(const employee of pool)sink+=employee.generation+stable.hp;if(round>=50)baseline.push(performance.now()-start);
 start=performance.now();for(const employee of pool)step(employee,snapshot(round+1,stable),host);if(round>=50)workingCosts.push(performance.now()-start);
}
const percentiles=values=>{values.sort((a,b)=>a-b);return{p50:values[Math.floor(values.length*.5)],p95:values[Math.floor(values.length*.95)]}};
const report={pass:true,checks,cpu75WorkingEmployeesMs:{baseline:percentiles(baseline),candidate:percentiles(workingCosts)},sink,limits:'Isolated lifecycle/service eligibility candidate. Synthetic certified-host coordinates; no actor spawn, door/movement execution, commerce wiring, real backroom occlusion, online authority or LIVE/FPS acceptance.'};
fs.writeFileSync('outputs/npc_service_employee23_candidate.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
