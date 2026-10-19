import assert from 'node:assert/strict';
import fs from 'node:fs';
import {gunzipSync} from 'node:zlib';
import {createCivilianNativeFixture} from './test_civilian_native_fixture.mjs';
import {createPrintShopServiceStation} from './native_print_shop_service_station.mjs';
import {advanceStationaryServiceActor} from './npc_stationary_service_adapter.mjs';
import {createServiceEmployee23,stepServiceEmployee23,serviceEligibility23} from '../../../npc_service_employee23_candidate.mjs';

// Actual building/collisions/door/executor with fixture source records. Camera
// visibility and accepted lifecycle authority are controlled inputs, not LIVE proof.
const snapshot=JSON.parse(gunzipSync(fs.readFileSync(new URL('test_fixtures/native_static_collision19.json.gz',import.meta.url))));
const f=await createCivilianNativeFixture({assetId:'print_shop',snapshot});
const rc=p=>({r:p.z/f.M,c:p.x/f.M});
const clear=p=>!f.pedestrian.query({mode:'sweep',from:rc(p),to:rc(p),radius:.18}).blocked;
const station=createPrintShopServiceStation({THREE:f.THREE,entry:f.entry,siteRevision:'physical-lifecycle23',validateLayout:({layout})=>['spawn','doorInside','doorOutside','work','customer'].every(k=>clear(layout[k]))});
const layout=station.layout,originalBodies=f.entry.getCollisionBodies.bind(f.entry);
f.entry.getCollisionBodies=()=>originalBodies().concat(station.getCollisionBodies());
const refresh=()=>{f.refreshBodies();f.pedestrian.beginFrame();};refresh();
const cycles=[];
for(const hz of [60,15,7,5,3]){
 let now=1000,hidden=false,blocked=false,blockObserved=false,birth=null,births=0;
 let actor={id:'staff-'+hz,generation:1,hp:100,...rc(layout.work)};
 const actorView=()=>({...actor,position:{x:actor.c*f.M,y:layout.work.y,z:actor.r*f.M}});
 const occupants=()=>[{position:actorView().position,radius:.18*f.M,height:1.9}];
 const host={validateLayout:l=>l===layout,isCurrentSite:l=>l.revision===layout.revision,
  verifyDeath:a=>a.deathReceiptId==='fixture-death-'+hz,
  canSpawnInClosedRoom:()=>hidden&&clear(layout.spawn),
  verifySpawnReceipt:r=>r===birth,
  doorSweepClear:()=>station.sweptClear(station.doorState.fraction,0,occupants()),ownsServiceSlot:()=>true};
 const state=createServiceEmployee23({layout,employeeId:actor.id,employeeGeneration:1},host);
 const tick=()=>stepServiceEmployee23(state,{now,actor:actorView(),door:station.doorState,siteRevision:layout.revision,...(birth?{spawnReceipt:birth}:{})},host);
 assert.equal(tick().status,'working');
 actor.hp=0;actor.dead=true;actor.deadAt=now;actor.deathReceiptId='fixture-death-'+hz;
 assert.equal(tick().until,61000);now=60999;assert.equal(tick().status,'unavailable');
 now=61000;assert.equal(tick().reason,'backroom-not-ready');assert.equal(state.respawn,null);
 hidden=true;const intent=tick().intent;assert.equal(intent.kind,'respawn-in-backroom');
 assert.deepEqual(intent.position,layout.spawn);assert.equal(tick().status,'pending');
 // Stand-in for the existing authoritative spawn executor; never called by runtime.
 births++;actor={id:actor.id,generation:2,hp:100,...rc(intent.position)};
 birth={accepted:true,requestId:intent.requestId,buildingId:layout.buildingId,siteRevision:layout.revision,employeeId:actor.id,generation:2,spawnedAt:now,position:{...intent.position},authority:'fixture'};
 const movementHost={identity:n=>({id:n.id,generation:n.generation}),hasControl:()=>true,
  canSweep:(a,b)=>!blocked&&f.box._residentNativeSegmentPassable(a.r,a.c,b.r,b.c),
  isStationFloor:(p,y)=>Math.abs(f.floor(p.c*f.M,p.r*f.M)-y)<.05};
 let frames=0,walks=0,opens=0,closes=0,result;
 do{
  now+=1000/hz;refresh();result=tick();
  assert.notEqual(result.status,'hold',result.reason);
  if(result.intent?.kind==='walk'){
   if(!blockObserved){
    blocked=true;const before={r:actor.r,c:actor.c};
    const stopped=advanceStationaryServiceActor({actor,target:result.intent.target,actorId:actor.id,generation:2,controlToken:'fixture-lease',dt:1/hz},movementHost);
    assert.equal(stopped.status,'blocked');assert.deepEqual({r:actor.r,c:actor.c},before);assert.equal(state.available,false);
    blocked=false;blockObserved=true;
   }
   const move=advanceStationaryServiceActor({actor,target:result.intent.target,actorId:actor.id,generation:2,controlToken:'fixture-lease',dt:1/hz},movementHost);
   assert(['moving','arrived'].includes(move.status),JSON.stringify({hz,phase:state.phase,move}));walks++;
  }else if(result.intent?.kind==='set-service-door'){
   const request=station.requestDoor(result.intent.open,{actorPosition:actorView().position,occupants:occupants()});
   assert(request.accepted,JSON.stringify({hz,phase:state.phase,request}));
   if(result.intent.open)opens++;else closes++;
  }
  station.update(1/hz,occupants());
  assert(++frames<2000,'physical lifecycle completes');
 }while(result.status!=='working');
 assert.equal(births,1);assert(blockObserved&&walks>0&&opens>0&&closes>0);
 assert(station.doorState.fraction<=.01);assert.equal(state.generation,2);
 const customer={id:'buyer',generation:1,hp:100,position:{...layout.customer}};
 const query={now,actor:actorView(),customer,siteRevision:layout.revision,visitId:'fixture-visit'};
 assert(serviceEligibility23(state,query,host).eligible);
 assert.equal(serviceEligibility23(state,{...query,actor:{...query.actor,hp:0,dead:true}},host).eligible,false);
 cycles.push({hz,frames,walks,opens,closes,births,returnSeconds:(now-61000)/1000});
}
station.dispose();f.entry.getCollisionBodies=originalBodies;f.entry.dispose();
const report={pass:true,cycles,limits:'Actual printshop geometry, door and swept executor; lifecycle source records, authority, customer slot and camera visibility are fixture inputs. No real source spawn, visual animation, registered checkout or LIVE/FPS claim.'};
fs.writeFileSync(new URL('../../../outputs/npc_service_physical_lifecycle23.json',import.meta.url),JSON.stringify(report,null,2));
console.log(JSON.stringify(report,null,2));
