import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {performance} from 'node:perf_hooks';
import {patchCivilian,patchNavigation,patchExport,patchInspection,patchWorld} from './transport_lane_qa23_candidate.mjs';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';

const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const originals={civilian:read('civilian_parking_trip_source.js'),navigation:read('city_road_navigation.mjs'),exporter:read('npc_inspection_export.mjs'),inspection:read('npc_runtime_inspection.mjs'),world:read('../../../world.html')};
const asModule=(code,overrides={})=>'data:text/javascript,'+encodeURIComponent(code.replace(/from '(\.\/[^']+)'/g,(_,path)=>'from '+JSON.stringify(overrides[path]||new URL(path,import.meta.url).href)));
const {createCityRoadNavigation:Navigation}=await import(asModule(patchNavigation(originals.navigation)));
const {createCityRoadNavigation:BaselineNavigation}=await import('./city_road_navigation.mjs');
const exportUrl=asModule(patchExport(originals.exporter));
const {createNpcRuntimeInspection:Inspection}=await import(asModule(patchInspection(originals.inspection),{'./npc_inspection_export.mjs':exportUrl}));
let checks=0;
function fixture(search='?npcqa=1',{baseline=false,parentSearch='',jobClient=null,profile={halfLength:2.7,halfWidth:1.13,collisionPadding:.08,collisionHull:[[-1,-2],[1,-2],[1,2],[-1,2]]}}={}){
 let now=1000,reply={status:'pending',points:[]},profileReads=0,writes=0;
 const requests=[],geometryCalls=[],data={};
 const dataset=new Proxy(data,{set(o,k,v){writes++;o[k]=v;return true;}});
 const car={id:'live-car17',r:35.34146341463414,c:42.109756097560975,ang:-Math.PI/2,model:{L:1.8,W:.88}},npc={id:'resident_2',r:32.85541513915751,c:38.5,hp:60};
 const nav=new (baseline?BaselineNavigation:Navigation)({getRoadPlan(){geometryCalls.push('road');throw Error('Unexpected geometry');},poseAllowed(){geometryCalls.push('hull');throw Error('Unexpected geometry');},getVehicleProfile(){profileReads++;return profile;},routeJobs:jobClient||{query(q){requests.push(structuredClone(q));return reply;},cancel(){return {status:'blocked',reason:'route_cancelled'};}}});
 const ctx={CARS:[car],NPCS:[npc],prevT:now,performance:{now:()=>now},location:{search},window:{__npcTripDiagnostics:true,parent:{location:{search:parentSearch}}},document:{documentElement:{dataset}},_walkRendererActive:()=>true,_threeVehicleEntityId:c=>c.id,_threeNpcEntityId:n=>n.id,
  _walkTrafficNavigationResolver(q){if(['lane-route','lane-route-cancel'].includes(q.mode))return nav.query(q);if(q.mode==='parking-destination')return {ready:true,status:'ready',lotIds:['lot-one']};if(q.mode==='parking-anchors')return {ready:true,slots:[{id:'bay-one',lotId:'lot-one',r:80,c:80,angle:0,widthM:5,lengthM:10}]};if(q.mode==='road-targets')return {status:'ready',points:[{r:18,c:50,angle:0}]};if(q.mode==='route')return {status:'pending',expanded:7};throw Error('Unexpected query '+q.mode);}};
 vm.createContext(ctx);vm.runInContext(baseline?originals.civilian:patchCivilian(originals.civilian),ctx);
 ctx.car=car;ctx.npc=npc;vm.runInContext('_civilianTripRegister({car,npc,carId:car.id,phase:"planning"});',ctx);
 function reset(){car._civilianNativePlan={status:'pending',doors:[{id:'native:pine-ridge001',r:18,c:50}],doorIndex:0,attempt:0,nextAt:0,laneRejected:false,createdAt:now};}
 reset();
 return {ctx,car,npc,requests,geometryCalls,profile,reset,setReply:v=>{reply=v;},tick(){now+=600;ctx.prevT=now;ctx._civilianTripNativePlan(car);},history:()=>data.civilianLaneRejections?JSON.parse(data.civilianLaneRejections):null,get reads(){return profileReads;},get writes(){return writes;},get now(){return now;}};
}

for(const search of ['', '?perfqa=1','?npccombatqa=1','?npcqa=0','?npctransportqa=10','?x=npcqa=1']){
 const f=fixture(search);f.setReply({status:'blocked',reason:'source_has_no_safe_directed_lane',points:[]});f.tick();assert.equal(f.history(),null);assert(!('qaLaneShape'in f.requests[0]));assert.equal(f.geometryCalls.length,0);checks++;
}
for(const [search,parentSearch]of [['?npcqa=1',''],['?npctransportqa=1',''],['','?npcqa=1']]){
 const f=fixture(search,{parentSearch});f.tick();assert.equal(f.history(),null);const firstRequest=f.requests[0];
 f.setReply(Object.freeze({status:'blocked',reason:'source_has_no_safe_directed_lane',points:Object.freeze([])}));f.tick();
 const h=f.history();assert.equal(h.records.length,1);assert.equal(h.records[0].requestId,firstRequest.requestId);assert.equal(h.records[0].sourceClockMs,f.now);assert.equal(h.records[0].carId,f.car.id);assert.equal(h.records[0].npcId,f.npc.id);assert.deepEqual(h.records[0].from,firstRequest.from);assert.deepEqual(h.records[0].allowedLotIds,firstRequest.to.lotIds);assert.equal(h.records[0].to.angle,null);assert.equal(h.records[0].shape.halfLength,2.7);assert.equal(h.records[0].shape.halfWidth,1.13);assert.deepEqual(h.records[0].shape.collisionHull,f.profile.collisionHull);
 assert.equal(f.car._civilianNativePlan.trace.stage,'route');assert.equal(f.car._civilianNativePlan.trace.status,'pending');assert.equal(h.records[0].reason,'source_has_no_safe_directed_lane','first lane refusal survives trace overwrite');
 const saved=JSON.stringify(h);f.profile.collisionHull[0][0]=100;f.profile.halfLength=3;firstRequest.to.lotIds.push('later');f.tick();assert.equal(JSON.stringify(f.history()),saved);assert.equal(f.geometryCalls.length,0);checks++;
}
{
 const f=fixture();f.setReply({status:'blocked',reason:'route_queue_full',points:[]});f.tick();
 f.setReply({status:'blocked',reason:'route_worker_uninitialized',points:[]});for(let i=0;i<20;i++)f.tick();assert.equal(f.history(),null,'temporary worker admission replies do not hide the later causal lane rejection');
 f.setReply({status:'blocked',reason:'source_has_no_safe_directed_lane',points:[]});f.tick();const first=f.history();for(let i=0;i<20;i++)f.tick();assert.deepEqual(f.history(),first);assert.equal(f.writes,1);assert.equal(first.records[0].reason,'source_has_no_safe_directed_lane');checks++;
}
{
 const f=fixture();f.setReply({status:'blocked',reason:'route_queue_full',points:[]});for(let i=0;i<60&&f.car._civilianNativePlan.status!=='blocked';i++)f.tick();assert.equal(f.car._civilianNativePlan.status,'blocked');assert.equal(f.history().records.length,1);assert.equal(f.history().records[0].reason,'route_queue_full');assert(f.history().records[0].sourceClockMs>=31000,'admission timeout is retained once producer finally rejects the lane');checks++;
}
const full=fixture();full.setReply({status:'blocked',reason:'source_has_no_safe_directed_lane',points:[]});const timestamps=[];
for(let i=0;i<23;i++){full.reset();full.tick();timestamps.push(full.now);}assert.equal(full.history().records.length,16);assert.deepEqual(full.history().records.map(r=>r.sourceClockMs),timestamps.slice(-16));assert.equal(new Set(full.history().records.map(r=>r.requestId)).size,16);checks++;
{
 const base=fixture('?npcqa=1',{baseline:true}),qa=fixture('?npcqa=1');
 for(const f of [base,qa]){f.tick();f.setReply({status:'blocked',reason:'controlled-refusal',points:[]});f.tick();f.tick();}
 assert.deepEqual(qa.requests,base.requests,'diagnostic flag does not enter actual worker request or cache signature');assert.equal(qa.reads,base.reads);assert.deepEqual(JSON.parse(JSON.stringify(qa.car)),JSON.parse(JSON.stringify(base.car)),'job/gameplay/source car fields remain unchanged');assert.deepEqual(qa.npc,base.npc);assert.equal(qa.geometryCalls.length,0);checks++;
}
{
 const f=fixture('?npcqa=1',{profile:{halfLength:NaN,halfWidth:1}});f.tick();assert.equal(f.requests.length,0);assert.equal(f.history().records[0].shape,null);assert.equal(f.history().records[0].reason,'invalid_vehicle_profile');checks++;
}
{
 const f=fixture();f.setReply({status:'ready',points:[{r:20,c:20,angle:0}]});f.tick();assert.equal(f.history(),null,'successful lane result never becomes a lane rejection, even if parking attachment fails');checks++;
}
{
 const worker={messages:[],postMessage(m){this.messages.push(structuredClone(m));},terminate(){}};
 const client=createLaneRouteJobs({createWorker:()=>worker,clock:()=>1000,setTimer:()=>1,clearTimer:()=>{}});client.initialize({fixture:true});worker.onmessage({data:{type:'initialized',generation:worker.messages[0].generation}});
 const f=fixture('?npcqa=1',{jobClient:client});f.tick();f.tick();f.tick();assert.equal(worker.messages.length,2,'actual job cache keeps one request while QA producer polls');const sent=worker.messages[1];assert(!('qaLaneShape'in sent.request));
 worker.onmessage({data:{type:'result',generation:sent.generation,token:sent.token,result:{status:'blocked',reason:'route_static_clearance_changed',points:[]},roadControls:[]}});
 f.tick();const captured=f.history().records[0];assert.equal(captured.reason,'route_static_clearance_changed');assert.equal(captured.requestId,sent.request.requestId);assert.deepEqual(captured.shape,{halfLength:sent.request.vehicleProfile.halfLength,halfWidth:sent.request.vehicleProfile.halfWidth,collisionPadding:sent.request.vehicleProfile.collisionPadding,collisionHull:sent.request.vehicleProfile.collisionHull});assert.equal(worker.messages.length,2);client.dispose();checks++;
}
class Element{constructor(){this.children=[];this.style={};this.handlers={};this.value='';this.hidden=false;this.dataset={};}append(...nodes){for(const n of nodes){n.parent=this;this.children.push(n);}}replaceChildren(){this.children=[];}setAttribute(k,v){this[k]=v;}addEventListener(k,v){this.handlers[k]=v;}click(){this.handlers.click?.();}remove(){this.parent.children=this.parent.children.filter(n=>n!==this);}}
const blobTexts=[];const doc={body:new Element(),documentElement:{dataset:{civilianLaneRejections:JSON.stringify(full.history())}},createElement:()=>new Element(),defaultView:{URL:{createObjectURL:b=>{blobTexts.push(b.text);return 'blob:qa';},revokeObjectURL(){}},Blob:class {constructor(parts){this.text=parts.join('');}}}};
const ui=Inspection({document:doc,search:'?npctransportqa=1'});assert(ui.enabled);const button=ui.panel.children[1].children.find(e=>e.textContent==='Скачать снимок NPC (JSON)');assert(button);button.click();const roundtrip=JSON.parse(blobTexts[0]);assert.deepEqual(roundtrip.civilianLaneRejections,full.history());assert.equal(roundtrip.civilianLaneRejections.records.length,16);ui.dispose();checks++;
const candidateWorld=patchWorld(originals.world),block=candidateWorld.slice(candidateWorld.indexOf('// CIVILIAN_PARKING_TRIP_START'),candidateWorld.indexOf('// CIVILIAN_PARKING_TRIP_END')+'// CIVILIAN_PARKING_TRIP_END'.length);assert.equal(block.trim(),patchCivilian(originals.civilian).trim());checks++;
const cpu={};for(const baseline of [true,false]){const f=fixture('?npcqa=1',{baseline});f.setReply({status:'blocked',reason:'controlled-refusal',points:[]});const samples=[];for(let b=0;b<20;b++){const start=performance.now();for(let i=0;i<100;i++){f.reset();f.tick();}samples.push((performance.now()-start)/100);}samples.sort((a,b)=>a-b);cpu[baseline?'before':'qaEnabled']={p50Ms:samples[10],p95Ms:samples[18]};}
const report={pass:true,checks,maxHistory:16,exportRoundtripRecords:roundtrip.civilianLaneRejections.records.length,geometryCalls:0,workerRequestsAndGameplayParity:true,actualJobCacheRoundtrip:true,cpu,limits:'Candidate text applied only in VM/data modules; actual producer/navigation wrapper/job cache/download serializer, controlled worker replies. No runtime file edits, browser or full-scene performance claim.'};
fs.writeFileSync(new URL('../../../outputs/transport_lane_qa23_candidate_results.json',import.meta.url),JSON.stringify(report,null,2));console.log(report);
