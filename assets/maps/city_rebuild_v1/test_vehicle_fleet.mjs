import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {readFileSync} from 'node:fs';
const shared=fileURLToPath(new URL('.',import.meta.url));
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const {createVehicleFleet}=await import(pathToFileURL(shared+'vehicle_fleet.mjs'));
const {createDemoCar,CAR,carCorners,createCarWorld,carFits}=await import(pathToFileURL(shared+'car_drive.mjs'));
const {polygonVehicleContact}=await import(pathToFileURL(shared+'vehicle_contact.mjs'));
const {ARTIST_VEHICLE_PROFILES}=await import('./vehicle_fleet_models.mjs');
class RoundedBox extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const approx=(a,b,tol=1e-8)=>assert.ok(Math.abs(a-b)<=tol,`${a} != ${b}`);
function stub(id,x=0,z=0,profile={}){
 const p={...CAR,massKg:1500,id,...profile},object=new T.Group();object.userData.massKg=p.massKg;
 const car={object,profile:p,wheels:[],shell:[],doors:new Map(),seats:[],update(){}};
 const calls={damage:[],updates:0,resets:0,disposed:0};
 const damage={state:{hp:240},contactImpact(c){calls.damage.push(c);this.state.hp-=5;return true},update(){calls.updates++},reset(){calls.resets++;this.state.hp=240},dispose(){calls.disposed++},stats(){return{hp:this.state.hp}}};
 const roll={impact(){},update(){},reset(){},stats(){return{angle:0}}};
 const tyres={state:[],effects:{speedFactor:1},update(){},reset(){},dispose(){}};
 const trunk={state:{open:false},update(){},reset(){this.state.open=false},dispose(){},stats(){return this.state}};
 return{id,car,state:{x,z,yaw:0,speed:0,steer:0,travelYaw:0,yawRate:0,vehicleProfile:p},damage,roll,tyres,trunk,calls};
}
const make=options=>createVehicleFleet(T,{scene:new T.Scene(),RoundedBox,world:()=>()=>true,...options});

test('fleet batches cabin and moving door after adapters, syncs mutations, owns disposal',()=>{
 const supplied=stub('batch_integration'),interior=new T.Group(),door=new T.Group(),material=new T.MeshStandardMaterial();
 interior.name='Interior_Test';door.name='Door_front_left';door.userData.vehicleDoorId='front_left';supplied.car.object.add(interior,door);
 const cabin=Array.from({length:3},()=>new T.Mesh(new T.BoxGeometry(),material)),panels=Array.from({length:3},()=>new T.Mesh(new T.BoxGeometry(),material));interior.add(...cabin);door.add(...panels);
 supplied.car.update=()=>{door.rotation.y=.8;cabin[0].position.x=.25;};
 const fleet=make(),record=fleet.addCar(supplied);fleet.activate(fleet.addCar(stub('active_other',20)));assert.equal(record.renderBatches.stats.includeDoors,true);assert.equal(record.renderBatches.stats.members,6);assert.equal(record.renderBatches.stats.doorMembers,3);
 fleet.update(1/60);const batch=interior.children.find(n=>n.isBatchedMesh),doorBatch=door.children.find(n=>n.isBatchedMesh),matrix=new T.Matrix4();batch.getMatrixAt(0,matrix);approx(matrix.elements[12],.25);assert.equal(doorBatch.parent,door);approx(door.rotation.y,.8);
 supplied.damage.update=()=>{panels[0].userData.detached=true};fleet.update(1/60);assert.equal(record.renderBatches.stats.fallbackMembers,1);assert.equal(panels[0].material,material);
 let batchDisposals=0,sourceDisposals=0;batch.geometry.addEventListener('dispose',()=>batchDisposals++);cabin[0].geometry.addEventListener('dispose',()=>sourceDisposals++);
 fleet.dispose();assert.equal(batchDisposals,1);assert.equal(sourceDisposals,1);assert.equal(cabin[0].material,material);assert.equal(batch.parent,null);assert.equal(doorBatch.parent,null);
});

test('unsupported multi-draw gate preserves legacy batches but creates no new detail groups',()=>{
 const supplied=stub('no_multi_draw'),interior=new T.Group(),material=new T.MeshStandardMaterial(),pairMaterial=new T.MeshStandardMaterial();interior.name='Interior_Test';supplied.car.object.add(interior);
 interior.add(...Array.from({length:3},()=>new T.Mesh(new T.BoxGeometry(),material)),...Array.from({length:2},()=>new T.Mesh(new T.BoxGeometry(),pairMaterial)));
 const fleet=make({detailOptimization:false}),record=fleet.addCar(supplied);
 assert.equal(record.renderBatches.stats.members,3);assert.equal(record.renderBatches.stats.detailBatches,0);assert.equal(record.renderBatches.stats.detailOptimizationEnabled,false);fleet.dispose();
});

test('switching adopts existing adapters and preserves damage, doors and motion',()=>{
 const fleet=make(),a=stub('red'),b=stub('taxi',12);const first=fleet.addCar(a),second=fleet.addCar(b);
 assert.equal(first.damage,a.damage);assert.equal(second.trunk,b.trunk);assert.equal(fleet.activeId,'red');
 a.damage.state.hp=91;a.trunk.state.open=true;
 const moving={...first.state,speed:7,travelYaw:Math.PI/2};fleet.syncActive(moving);fleet.activate(second);
 assert.equal(first.state,moving);approx(first.state.vx,7);approx(first.state.vz,0);
 assert.equal(first.damage.state.hp,91);assert.equal(first.trunk.state.open,true);assert.equal(a.calls.resets,0);
 fleet.update(.1);assert.ok(first.state.x>.6);assert.equal(second.state.x,12,'active is stepped only by root');
 fleet.activate(first);assert.equal(first.damage.state.hp,91);assert.equal(fleet.active,first);
 assert.equal(fleet.records.length,2);fleet.dispose();assert.equal(a.calls.disposed,1);assert.equal(fleet.records.length,0);
});

test('a 1500kg car hitting 12000kg bus distributes impulse and damage delta-V by mass',()=>{
 const fleet=make(),a=fleet.addCar(stub('sedan')),b=fleet.addCar(stub('bus',0,4.48,{massKg:12000}));
 const before={...a.state,speed:16},after={...before,speed:0};
 const contact={point:{x:0,y:.8,z:2.24},normal:{x:0,y:0,z:1},otherVehicle:'bus'};
 const result=fleet.resolve(before,after,contact);
 assert.equal(result.resolved,true);approx(result.deltaVA/result.deltaVB,8);assert.equal(fleet.active.state,after);
 approx(1500*16,1500*after.vz+12000*b.state.vz);
 assert.equal(a.damage.state.hp,235);assert.equal(b.damage.state.hp,235);
 assert.ok(a.damage.state.hp>0);assert.ok(result.deltaVA>result.deltaVB*7.9);
 const energy=.5*1500*after.vz**2+.5*12000*b.state.vz**2;assert.ok(energy<=.5*1500*16**2);
 const repeat=fleet.resolve(after,after,contact);assert.equal(repeat.resolved,false);assert.equal(fleet.stats().contacts,1);
 fleet.dispose();
});

test('parked inertia can collide with another parked car and the active car',()=>{
 const fleet=make(),active=fleet.addCar(stub('active',0,0)),middle=fleet.addCar(stub('middle',0,7)),rear=fleet.addCar(stub('rear',0,14));
 rear.state.vz=-10;rear.state.speed=-10;rear.state.travelYaw=0;
 for(let i=0;i<180;i++)fleet.update(1/120);
 assert.ok(fleet.stats().contacts>=1);assert.ok(middle.damage.state.hp<240);assert.ok(rear.damage.state.hp<240);
 assert.ok(middle.state.z<7);assert.ok([active,middle,rear].every(r=>[r.state.x,r.state.z,r.state.speed,r.state.vx,r.state.vz].every(Number.isFinite)));
 assert.equal(active.state.z,0,'fleet never translates active vehicle behind root');
 fleet.dispose();
});

test('shape-aware blocking ignores active only, reports exact otherVehicle ID and can switch',()=>{
 const base=(x,z)=>Math.abs(x)<50&&Math.abs(z)<50,fleet=make({world:()=>base});
 const a=fleet.addCar(stub('red')),b=fleet.addCar(stub('bus',0,12,{halfLength:5,halfWidth:1.5}));
 const blocking=fleet.blockingWorld(base);
 assert.equal(blocking.poseAllowed(0,0,0,CAR),true);assert.equal(blocking.poseAllowed(0,6,0,CAR),false);
 assert.equal(blocking.contactAt(0,6,0,CAR).otherVehicle,'bus');
 assert.equal(fleet.overlaps(0,0,.36,'red'),false);assert.equal(fleet.overlaps(0,0,.36),true);
 assert.equal(fleet.nearby({x:0,z:0},2)[0],a);
 fleet.activate(b);assert.equal(fleet.blockingWorld(base),blocking,'wrapper follows active identity');
 assert.equal(blocking.poseAllowed(0,12,0,b.state.vehicleProfile),true);assert.equal(blocking.contactAt(0,6,0,b.state.vehicleProfile).otherVehicle,'red');
 fleet.dispose();
});

test('external renderer contacts route to the owning car, not whichever car is active',()=>{
 const fleet=make(),red=stub('red'),taxi=stub('taxi',10);taxi.car.object.userData.mapColor='#ffe070';
 const a=fleet.addCar(red),b=fleet.addCar(taxi);fleet.activate(a);
 assert.equal(b.car.object.userData.receiveCollision({point:{x:10,y:.8,z:2},normal:{x:0,y:0,z:1},impactSpeed:7}),true);
 assert.equal(red.calls.damage.length,0);assert.equal(taxi.calls.damage.length,1);
 assert.equal(fleet.stats().vehicles.find(v=>v.id==='taxi').mapColor,'#ffe070');
 assert.ok(Object.hasOwn(fleet.stats().vehicles[0],'hood'));
 fleet.dispose();assert.equal(b.car.object.userData.receiveCollision,undefined);
});

test('spawn search fits all 12 real profiles with no fleet/hero overlap',()=>{
 const hero={x:0,z:0},fleet=make({getHero:()=>hero});fleet.addCar(stub('red',0,0));
 for(const profile of ARTIST_VEHICLE_PROFILES){
  const spawn=fleet.findSpawn(profile,{x:0,z:0,yaw:0},{maxRadius:130});assert.ok(spawn,'missing spawn '+profile.id);
  fleet.addCar(stub(profile.id,spawn.x,spawn.z,profile),spawn).state.yaw=spawn.yaw;
 }
 assert.equal(fleet.records.length,13);
 for(let i=0;i<fleet.records.length;i++)for(let j=i+1;j<fleet.records.length;j++){
  const a=fleet.records[i].state,b=fleet.records[j].state;
  assert.equal(polygonVehicleContact(carCorners(a.x,a.z,a.yaw,a.vehicleProfile),carCorners(b.x,b.z,b.yaw,b.vehicleProfile)),null);
 }
 assert.equal(fleet.stats().vehicles.length,13);fleet.dispose();
});

test('new real red car creates owned damage/tyres/trunk, reset and dispose are complete',()=>{
 const scene=new T.Scene(),fleet=make({scene}),car=createDemoCar(T,RoundedBox),record=fleet.addCar(car,{x:4,z:8,yaw:.3});
 assert.equal(record.car,car);assert.equal(record.state.x,4);assert.ok(record.trunk.enabled);assert.equal(record.damage.state.hp,240);
 assert.equal(record.car.trunk,record.trunk);car.object.updateMatrixWorld(true);const hero=car.object.localToWorld(new T.Vector3(0,0,-3));
 assert.equal(record.trunk.setOpen(true,{hero,vehicleState:record.state,damageState:record.damage.state}).accepted,true);record.damage.state.hp=120;
 const next=createDemoCar(T,RoundedBox);next.profile={...CAR,id:'second',massKg:2100};const parked=fleet.addCar(next,{x:14,z:8,yaw:0});
 fleet.activate(parked);fleet.update(.1);assert.equal(record.trunk.state.open,true);assert.equal(record.damage.state.hp,120);
 fleet.reset();assert.equal(record.damage.state.hp,240);assert.equal(record.trunk.state.open,false);assert.equal(record.state.x,4);
 fleet.dispose();assert.equal(scene.children.length,0);
});

test('all 12 authored footprints find separated legal spawns in checked-in city geometry',()=>{
 const read=name=>JSON.parse(readFileSync(shared+name,'utf8'));
 const topology=read('topology_for_placement.json'),items=[...read('buildings_placement.v1.json').instances,...read('decor_placement.v1.json').instances];
 const world=createCarWorld(topology,items.flatMap(item=>item.collision?.worldBodies||[]));
 const origin={x:626,z:59.45,yaw:Math.PI/2},hero={x:626,z:56.7},fleet=make({world:()=>world,getHero:()=>hero});
 const red=stub('red',origin.x,origin.z);red.state.yaw=origin.yaw;fleet.addCar(red);
 for(const profile of ARTIST_VEHICLE_PROFILES){
  const spawn=fleet.findSpawn(profile,origin,{topology,hero,maxRadius:240});assert.ok(spawn,'no city spawn '+profile.id);
  assert.ok(carFits(spawn.x,spawn.z,spawn.yaw,world,profile));
  const car=stub(profile.id,spawn.x,spawn.z,profile);car.state.yaw=spawn.yaw;fleet.addCar(car);
 }
 assert.equal(fleet.records.length,13);
 for(let i=0;i<fleet.records.length;i++)for(let j=i+1;j<fleet.records.length;j++){
  const a=fleet.records[i].state,b=fleet.records[j].state;
  assert.equal(polygonVehicleContact(carCorners(a.x,a.z,a.yaw,a.vehicleProfile),carCorners(b.x,b.z,b.yaw,b.vehicleProfile)),null);
 }
 fleet.dispose();
});

test('parked dry pose is reused while water physics remains frame-accurate',()=>{
 const posed=[],fleet=make({pose:(car,state)=>{
  posed.push(state.x);state.waterState={inWater:state.x===18};
 }});
 for(const x of [0,9,18])fleet.addCar(stub('pose_'+x,x,0));
 assert.deepEqual(posed.sort((a,b)=>a-b),[0,9,18],'addCar establishes the initial grounded pose');
 posed.length=0;fleet.update(1/60);
 assert.deepEqual(posed,[18],'only the wet car continues terrain/water sampling');
 posed.length=0;fleet.update(1/60);
 assert.deepEqual(posed,[18],'only the wet car continues terrain/water sampling');
 fleet.dispose();
});

test('a pristine parked car reuses drive effects but still refreshes on controls or damage',()=>{
 let effectReads=0,damageUpdates=0,tyreUpdates=0,trunkUpdates=0,hoodUpdates=0;
 const fleet=make(),active=fleet.addCar(stub('active')),
  parkedCar={object:new T.Group(),profile:{...CAR,id:'idle',massKg:1500},wheels:[],shell:[],doors:new Map(),seats:[],update(){}},
  damageState={maxHp:240,hp:240,smoking:false,burning:false,destroying:false,wrecked:false},tyreState=[];
 const parked=fleet.addCar({id:'idle',car:parkedCar,state:{x:12,z:0,yaw:0,speed:0,travelYaw:0,yawRate:0},
  damage:{state:damageState,get crashEffects(){effectReads++;return{speedFactor:1}},update(){damageUpdates++},crash:{applyWheels(){}}},
  tyres:{state:tyreState,get effects(){effectReads++;return{speedFactor:1}},update(){tyreUpdates++}},
  roll:{angle:0,unstable:false,update(){}},trunk:{state:{open:false},update(){trunkUpdates++}},hood:{state:{open:false},update(){hoodUpdates++}}});
 fleet.update(1/60);const firstEffects=parked.state.crashEffects,firstReads=effectReads;
 fleet.update(1/60);
 assert.equal(effectReads,firstReads,'stable drive effects are not rebuilt');assert.equal(parked.state.crashEffects,firstEffects);
 assert.equal(damageUpdates,2);assert.equal(tyreUpdates,2);assert.equal(trunkUpdates,2);assert.equal(hoodUpdates,2,'presentation remains live');
 parked.state.braking=true;fleet.update(1/60);assert.equal(parked.state.braking,false);assert.equal(effectReads,firstReads+2,'a parked former driver is normalized once');
 damageState.hp=230;fleet.update(1/60);assert.equal(effectReads,firstReads+4,'damage invalidates the pristine cache');
 assert.equal(active.state.x,0);fleet.dispose();
});
