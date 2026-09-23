// Portable bounded regression against the current production source, real token
// store, canonical control/segment validators and physical admission. No GPU.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {createLaneRouteJobs} from './city_lane_route_jobs.mjs';
import {createNpcVehicleSurfaceAccess} from './npc_vehicle_surface_access.mjs';
import {createNpcVehicleNavigation} from './npc_vehicle_navigation.mjs';
const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8').replaceAll('\r','');
const block=s=>s.slice(s.indexOf('function _policeVehicleCancelLane(v){'),s.indexOf('\nfunction _groundPoliceCanDrive(v,now){'));
assert(block(source).startsWith('function _policeVehicleCancelLane(v){'),'current police lane helpers');
function actual(name){const start=source.indexOf('function '+name+'(');assert(start>=0);const end=source.indexOf('\n',start),line=source.slice(start,end);return line.trimEnd().endsWith('}')?line:source.slice(start,source.indexOf('\n}',start)+2);}
const edge={id:'cross:1',kind:'pedestrian_crossing',edgeId:'edge:1',crosswalkIds:['zebra:1'],distanceM:.05,stopPoint:{r:0,c:.2},rule:'pedestrian_priority'};
const points=[{r:0,c:0,angle:0},{r:0,c:1,angle:0},{r:0,c:.5,angle:0,gear:'reverse'}];
function fixture(){
 let now=0,worker;const calls=[];
 const jobs=createLaneRouteJobs({clock:()=>now,ttlMs:1000,timeoutMs:30000,setTimer:()=>0,clearTimer:()=>{},createWorker:()=>worker={messages:[],postMessage(m){this.messages.push(structuredClone(m));},terminate(){},emit(data){this.onmessage({data});}}});
 jobs.initialize({});worker.emit({type:'initialized',generation:worker.messages[0].generation});
 const surface=createNpcVehicleSurfaceAccess({worldScale:4.1,verifyLaneSegment:r=>jobs.evaluateSegment(r)});
 const physical=createNpcVehicleNavigation({isRoad:()=>false,poseAllowed:()=>true,vehicleAccess:surface.query,worldScale:4.1});
 const v={id:'convoy',kind:'police',_policePrisonTransport:true,state:'returning',x:0,y:0,ang:0,speed:.1,hp:100,payload:{},_driverCopId:'driver'};
 const driver={id:'driver',alive:true,hp:100,_transportBoarded:true,_transportVehicleId:v.id};
 const box={performance:{now:()=>now},document:{documentElement:{dataset:{}}},player:{r:0,c:.2},NPCS:[],CARS:[],serviceVehicles:[v],cityCops:[driver],_LOCAL_PREVIEW:true,POLICE_RESPONSE_SPEED:.1,
  _murderPoliceArrest:{phase:'transport',vehicleId:v.id,playerAttachedVehicleId:v.id,playerBoarded:true,destination:{instanceId:'detention:fixture',stop:{r:0,c:.5,angle:0}}},
  _walkRendererActive:()=>true,_vehicleStep:()=>{throw Error('unexpected legacy movement');},_syncPoliceConvoyCop:()=>{},_policeConvoyDestination:()=>true,_ambientTrafficServiceKind:()=>false,
  _walkTrafficNavigationResolver:r=>{
   calls.push(structuredClone(r));
   if(r.mode==='lane-route')return jobs.query(r);
   if(r.mode==='lane-route-cancel')return jobs.cancel(r.requestId);
   if(r.mode==='lane-route-touch')return jobs.touch(r.requestId);
   if(r.mode==='road-rules')return {control:jobs.evaluateControl(r.control,r)};
   if(r.mode==='road-targets')return {status:'blocked',points:[]};
   return physical.query(r);
  }};
 vm.createContext(box);vm.runInContext(block(source)+'\n'+['_groundPoliceCanDrive','_policeConvoyCanDrive','updateServiceVehicles'].map(actual).join('\n'),box);
 const step=()=>{now+=100;physical.beginFrame();return box._policeVehicleStep(v,.1);};
 const finish=()=>{const m=worker.messages.at(-1);assert.equal(m.type,'route');worker.emit({type:'result',generation:m.generation,token:m.token,result:{status:'ready',points,controls:[edge],accessRouteIds:[],accessLotIds:[]},roadControls:[edge]});};
 return {jobs,worker,calls,v,driver,box,step,finish,advance:ms=>now+=ms};
}
const findings=[],passed=[];
// Pending request is revoked when its driver disappears.
{
 const f=fixture();f.step();const requestId=f.v._nativePoliceJob.id;f.driver.alive=false;f.step();
 assert.equal(f.v._nativePoliceJob,null);assert.equal(f.v.x,0);
 assert.notEqual(f.jobs.touch(requestId).status,'pending');assert.equal(f.jobs.diagnostics().pending,0);
 passed.push('pending request cancelled on driver loss');f.jobs.dispose();
}
// Changing the exact detention target also revokes the pending request.
{
 const f=fixture();f.step();const requestId=f.v._nativePoliceJob.id;
 f.box._murderPoliceArrest.destination={instanceId:'detention:other',stop:{r:0,c:.75,angle:0}};f.step();
 assert.notEqual(f.v._nativePoliceJob?.id,requestId);assert.notEqual(f.jobs.touch(requestId).status,'pending');assert.equal(f.jobs.diagnostics().pending,1);
 passed.push('pending request cancelled on target change');f.jobs.dispose();
}
// Exact world caller revokes ready authority before its convoy early-continue.
{
 const f=fixture();f.step();f.finish();f.step();const requestId=f.v._nativePoliceLaneRequestId,token=f.v._nativePoliceAuthority.laneRouteToken;
 assert(requestId&&token);f.driver.alive=false;const before=f.v.x;f.box.updateServiceVehicles(.1);
 assert.equal(f.v.x,before,'world does stop the physical convoy');
 assert.notEqual(f.jobs.touch(requestId).status,'ready');assert.equal(f.v._nativePoliceAuthority,null);assert.equal(f.v._nativePoliceRoute,null);
 passed.push('actual world convoy early-continue cancels ready token');f.jobs.dispose();
}
// The following ground-driver early-continue has the same cancellation seam.
{
 const f=fixture();f.step();f.finish();f.step();const requestId=f.v._nativePoliceLaneRequestId;
 f.driver._transportBoarded=false;const before=f.v.x;f.box.updateServiceVehicles(.1);
 assert.equal(f.v.x,before);assert.notEqual(f.jobs.touch(requestId).status,'ready');assert.equal(f.v._nativePoliceAuthority,null);assert.equal(f.v._nativePoliceRoute,null);
 passed.push('actual world ground-driver early-continue cancels ready token');f.jobs.dispose();
}
// Real canonical controls prove self-only exclusion, unlike an empty crosswalkIds.
{
 const f=fixture();f.step();f.finish();f.step();assert(f.v.x>0,'attached prisoner does not self-block');
 const before=f.v.x;f.box.NPCS.push({id:'stranger',r:0,c:.2,dead:false});f.step();assert.equal(f.v.x,before);assert.equal(f.v._nativePoliceReason,'pedestrian_crossing');
 f.box.NPCS.length=0;f.box._murderPoliceArrest.playerAttachedVehicleId='different-van';f.step();assert.equal(f.v.x,before,'player in other van is not globally excluded');
 f.box._murderPoliceArrest.playerAttachedVehicleId=f.v.id;f.box._murderPoliceArrest.playerBoarded=false;f.step();assert.equal(f.v.x,before,'unboarded player remains a crossing occupant');
 passed.push('canonical crossing: attached self excluded; unrelated NPC / other van / unboarded player block');f.jobs.dispose();
}
// Actual token verifier and native movement semantics: owner/direction/revocation.
{
 const f=fixture();f.step();f.finish();f.step();const token=f.v._nativePoliceAuthority.laneRouteToken,requestId=f.v._nativePoliceLaneRequestId;
 const proof={routeJob:token,carId:'service_convoy',from:{r:0,c:.1},to:{r:0,c:.2}};
 assert.equal(f.jobs.evaluateSegment(proof).allowed,true);
 assert.equal(f.jobs.evaluateSegment({...proof,carId:'other-car'}).reason,'route_owner_mismatch');
 assert.equal(f.jobs.evaluateSegment({...proof,from:proof.to,to:proof.from}).allowed,false);
 assert.equal(f.jobs.evaluateSegment({...proof,from:{r:0,c:.9},to:{r:0,c:.8}}).allowed,true,'authored reverse follows ordered canonical edge');
 f.jobs.cancel(requestId);assert.equal(f.jobs.evaluateSegment(proof).reason,'route_expired');
 const before=f.v.x;f.step();assert.equal(f.v.x,before,'revoked token fails physical admission');
 passed.push('real canonical token: correct owner/ordered reverse only, foreign/reversed/cancelled rejected');f.jobs.dispose();
}
// Lease expiry is caught before movement when the renewal boundary is reached.
{
 const f=fixture();f.step();f.finish();f.step();const before=f.v.x;f.advance(5100);f.step();
 assert.equal(f.v.x,before);assert.equal(f.v._nativePoliceReason,'route-expired');assert.equal(f.v._nativePoliceRoute,null);
 passed.push('real expired lease clears route before movement');f.jobs.dispose();
}
assert.equal(findings.length,0);
console.log(JSON.stringify({status:'PASS',findings,passed,limits:'Bounded CPU current source/canonical protocol regression; static hull fixture belongs to primary suite. No runtime changes or GPU.'},null,2));
