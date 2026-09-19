import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createHash} from 'node:crypto';
import {Worker} from 'node:worker_threads';
import {createCityRoadNavigation} from './city_road_navigation.mjs';
import {createCarWorld,carFits,CAR} from './car_drive.mjs';
import {isExistingTrafficBridge} from './city_road_traffic_plan.mjs';
import {evaluateRoadEdgeControl} from './city_road_edge_controls.mjs';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';

// Execute the browser entry in a real worker thread, using the actual final
// authored scene. No synthetic route graph, busy loop or GPU is involved.
const read=path=>JSON.parse(fs.readFileSync(new URL(path,import.meta.url),'utf8'));
const scene=read('../../../outputs/roads_logical_20260912/integration_candidate_snapshot.json');
const topology=read('./topology_for_placement.json'),instances=[...scene.buildings,...scene.authoredDecor],M=4.1;
const bodies=instances.flatMap(i=>i.collision?.worldBodies||[]).concat(scene.decorPlan.colliders,scene.roadPlan.colliders,scene.parkingPlan.colliders);
// Match walk_preview.laneRoutingSnapshot: the traffic plan shares its object
// identity with preparedLaneGraph.plan, avoiding a second clone of that graph.
const snapshot={metresPerCell:M,topology,bodies,roadPlan:{trafficPlan:scene.roadPlan.preparedLaneGraph.plan,preparedLaneGraph:scene.roadPlan.preparedLaneGraph,serviceAccess:scene.roadPlan.serviceAccess},parkingPlan:scene.parkingPlan,instances:instances.map(i=>({id:i.id,role:i.role,entry:i.entry,footprint:i.footprint,stopFootprint:i.stopFootprint,transform:i.role==='district_detention'?{yawDegrees:i.transform?.yawDegrees}:undefined}))};
const world=createCarWorld(topology,bodies,M),navigation=createCityRoadNavigation({getRoadPlan:()=>scene.roadPlan,getParkingPlan:()=>scene.parkingPlan,getInstances:()=>instances,isRoad:(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)]||isExistingTrafficBridge(topology,x,z,M),poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape||CAR),metresPerCell:M});
navigation.prepare();
const slots=navigation.query({mode:'parking-anchors'}).slots;
const slot=id=>{const found=slots.find(s=>s.lotId==='parking:'+id);assert(found,'actual parking origin '+id);return {r:found.r,c:found.c,angle:found.angle}};
const goal=id=>{const found=scene.buildings.find(b=>b.id===id);assert(found?.entry?.anchorRC,'actual building entry '+id);return {...found.entry.anchorRC,buildingId:found.id}};
const hospital='REBUILD-VISUAL-hospital-001',north='REBUILD-VISUAL-pine_ridge_cottage_v1-002',gold='REBUILD-VISUAL-coastal_orchard_house_v1-001';
const requests=[
 {label:'hospital parking to hospital',from:slot(hospital),to:goal(hospital)},
 {label:'north hills to eastside hospital',from:slot(north),to:goal(hospital)},
 {label:'north hills to gold coast',from:slot(north),to:goal(gold)},
].map(r=>({...r,mode:'lane-route',maxSnapDistance:12}));
for(const request of requests)request.vehicleProfile={halfLength:2.4542,halfWidth:1.152};
const workerURL=new URL('./city_lane_route_worker.mjs',import.meta.url);
const bootstrap=`import {parentPort} from 'node:worker_threads';globalThis.self={postMessage:data=>parentPort.postMessage(data)};await import(${JSON.stringify(String(workerURL))});parentPort.on('message',data=>self.onmessage({data}));`;
const worker=new Worker(new URL('data:text/javascript,'+encodeURIComponent(bootstrap)),{type:'module'});
const messages=[],waiters=[];worker.on('message',message=>{messages.push(message);for(const waiter of [...waiters])if(waiter.match(message)){waiters.splice(waiters.indexOf(waiter),1);clearTimeout(waiter.timer);waiter.resolve(message)}});
const wait=match=>new Promise((resolve,reject)=>{const waiter={match,resolve,timer:setTimeout(()=>reject(Error('Worker response timeout')),120000)};waiters.push(waiter)});
const digest=value=>createHash('sha256').update(JSON.stringify(value,(key,v)=>/Ms$/.test(key)?undefined:v)).digest('hex');
const rows=[],expectedResults=[];let tickCount=0,lastTick=performance.now(),maxTickGap=0;
const heartbeat=setInterval(()=>{const now=performance.now();maxTickGap=Math.max(maxTickGap,now-lastTick);lastTick=now;tickCount++},2);
let clonePostMs,initElapsedMs,canonicalCount=0,occupiedDenied=0;
try{
 const initialized=wait(m=>m.type==='initialized'),initStart=performance.now();
 const postStart=performance.now();worker.postMessage({type:'init',generation:7,snapshot});clonePostMs=performance.now()-postStart;
 const init=await initialized;initElapsedMs=performance.now()-initStart;assert.equal(init.generation,7);
 for(let i=0;i<requests.length;i++){
  const request=requests[i],mainStart=performance.now(),expected=navigation.query(request),mainMs=performance.now()-mainStart;
  assert.equal(expected.status,'ready',request.label+': '+expected.reason);
  expectedResults.push(expected);
  const pending=wait(m=>m.token===i),startTicks=tickCount;lastTick=performance.now();maxTickGap=0;
  const start=performance.now();worker.postMessage({type:'route',generation:7,token:i,request});const postMs=performance.now()-start;
  const response=await pending;assert.equal(response.type,'result',response.error?.message);
  assert.equal(digest(response.result),digest(expected),'exact result parity: '+request.label);
  assert.equal(digest(response.roadControls),digest(navigation.roadControlRecords(expected.controls)),'canonical controls parity');
  const index={byId:new Map(response.roadControls.map(c=>[c.id,c]))};
  for(const control of response.result.controls){
   if(!['pedestrian_crossing','railway_crossing','road_end_turnaround','one_way_narrow_passage'].includes(control.kind))continue;
   canonicalCount++;assert(index.byId.has(control.id),'worker must include canonical control '+control.id);
   const c=index.byId.get(control.id),occupied={occupiedCrosswalkIds:c.crosswalkIds||[],occupiedRailCrossingIds:c.railCrossingIds||[],occupiedEdgeIds:c.conflictingEdgeIds||[]};
   if(Object.values(occupied).some(ids=>ids.length)){assert.equal(evaluateRoadEdgeControl(index,control,occupied).allowed,false);occupiedDenied++;}
   assert.equal(evaluateRoadEdgeControl(index,{...control,id:'forged:'+control.id}).allowed,false,'unknown control fails closed');
  }
  rows.push({label:request.label,from:request.from,to:request.to,points:expected.points.length,distanceM:expected.distanceM,controls:expected.controls.length,mainMs,postMs,workerMs:response.workerMs,elapsedMs:performance.now()-start,mainHeartbeatTicks:tickCount-startTicks,maxMainHeartbeatGapMs:maxTickGap,resultSHA:digest(expected)});
 }
 assert(canonicalCount>0&&occupiedDenied>0,'real routes exercise canonical occupied road controls');
 // A valid message behind the stale one is a queue barrier: no arbitrary sleep.
 worker.postMessage({type:'route',generation:6,token:'stale',request:requests[0]});
 const barrier=wait(m=>m.token==='barrier');worker.postMessage({type:'route',generation:7,token:'barrier',request:requests[0]});await barrier;
 assert(!messages.some(m=>m.token==='stale'),'stale generation ignored');
 assert(rows.some(row=>row.mainHeartbeatTicks>0),'main event loop progresses while actual worker routes calculate');
 await worker.terminate();
 const responseHandlerMs=[],clientQueryMs=[],clientRows=[];
 let clientWorker;
 const jobs=createLaneRouteJobs({createWorker:()=>{
  const raw=new Worker(new URL('data:text/javascript,'+encodeURIComponent(bootstrap)),{type:'module'});
  const adapter={postMessage:data=>raw.postMessage(data),terminate:()=>raw.terminate()};clientWorker=raw;
  raw.on('message',data=>{const start=performance.now();adapter.onmessage?.({data});responseHandlerMs.push(performance.now()-start)});
  raw.on('error',error=>adapter.onerror?.({error,message:error.message}));return adapter;
 }});
 try{
  const startInit=performance.now();jobs.initialize(snapshot);const clientInitializePostMs=performance.now()-startInit;
  const routed=createCityRoadNavigation({getRoadPlan:()=>scene.roadPlan,getParkingPlan:()=>scene.parkingPlan,getInstances:()=>instances,isRoad:(x,z)=>!!topology.roadMask[Math.floor(z/M)]?.[Math.floor(x/M)]||isExistingTrafficBridge(topology,x,z,M),poseAllowed:(x,z,yaw,shape)=>carFits(x,z,yaw,world,shape||CAR),metresPerCell:M,routeJobs:jobs});
  routed.prepare();
  for(let i=0;i<requests.length;i++){
   const request={...requests[i],requestId:'actual-'+i},started=performance.now(),ticks=tickCount;
   let result,polls=0;do{
    const begin=performance.now();result=routed.query(request);clientQueryMs.push(performance.now()-begin);polls++;
    if(result.status==='pending')await new Promise(resolve=>setTimeout(resolve,4));
    assert(performance.now()-started<120000,'client actual route timeout');
   }while(result.status==='pending');
   assert.equal(result.status,'ready',result.reason);
   const untagged={...result,controls:result.controls.map(({routeJob,...control})=>control)};
   assert.equal(digest(untagged),digest(expectedResults[i]),'actual client result parity: '+request.label);
   const begin=performance.now();assert.equal(routed.query(request),result,'completed poll reuses immutable result');clientQueryMs.push(performance.now()-begin);
   for(const control of result.controls){
    const canonical=control.kind==='pedestrian_crossing'&&navigation.roadControlRecords(expectedResults[i].controls).find(c=>c.id===control.id);
    if(canonical){const denied=routed.query({mode:'road-rules',control,occupiedCrosswalkIds:canonical.crosswalkIds});assert.equal(denied.control.allowed,false,'actual client checks worker canonical occupancy');}
   }
   clientRows.push({label:request.label,polls,elapsedMs:performance.now()-started,mainHeartbeatTicks:tickCount-ticks});
  }
  const worldUpdates=[];
  const startPose=requests[0].from,blocker={id:'worker-proof-temporary-solid-at-real-bay',minYM:0,maxYM:3,polygonCR:[[startPose.c-.8,startPose.r-.8],[startPose.c+.8,startPose.r-.8],[startPose.c+.8,startPose.r+.8],[startPose.c-.8,startPose.r+.8]]};
  for(const [label,nextBodies,wanted]of [['actual bay newly obstructed',[...bodies,blocker],'blocked'],['same bay obstacle removed',bodies,'ready']]){
   const before=jobs.diagnostics().generation,start=performance.now();jobs.updateWorld(nextBodies);const updatePostMs=performance.now()-start;
   assert(jobs.diagnostics().generation>before,'world replacement advances generation');
   let result;do{result=routed.query({...requests[0],requestId:'world-change'});if(result.status==='pending')await new Promise(resolve=>setTimeout(resolve,4));assert(performance.now()-start<120000,'world refresh timeout')}while(result.status==='pending');
   assert.equal(result.status,wanted,label+': '+result.reason);
   if(wanted==='ready'){
    assert.equal(digest(result.points),digest(expectedResults[0].points),'rebuild must restore the same real route geometry');
    assert.equal(result.distanceM,expectedResults[0].distanceM);
   }
   worldUpdates.push({label,status:result.status,reason:result.reason,updatePostMs,elapsedMs:performance.now()-start,generation:jobs.diagnostics().generation});
  }
  const sorted=clientQueryMs.toSorted((a,b)=>a-b),client={initializePostMs:clientInitializePostMs,queryCount:sorted.length,queryP50Ms:sorted[Math.floor(sorted.length*.5)],queryP95Ms:sorted[Math.floor(sorted.length*.95)],queryMaxMs:sorted.at(-1),responseHandlerMaxMs:Math.max(...responseHandlerMs),rows:clientRows};
  const report={createdAt:new Date().toISOString(),status:'PASS',scope:'Actual browser entry and production client in Node worker; host-minimized shared-reference snapshot; complete static colliders; exact synchronous-wrapper parity; CPU only, not browser FPS',snapshotCreatedAt:scene.createdAt,buildings:scene.buildings.length,bodies:bodies.length,clonePostMs,initElapsedMs,canonicalCount,occupiedDenied,rows,client,worldUpdates};
 fs.writeFileSync(new URL('../../../outputs/city_lane_route_worker_20260919.json',import.meta.url),JSON.stringify(report,null,2));
 console.log(JSON.stringify(report,null,2));
 }finally{jobs.dispose();await clientWorker?.terminate();}
}finally{clearInterval(heartbeat);for(const w of waiters)clearTimeout(w.timer);await worker.terminate();}
