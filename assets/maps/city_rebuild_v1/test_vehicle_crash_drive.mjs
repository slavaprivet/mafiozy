import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createCrashMechanicsState,applyCrashMechanicsImpact,crashDriveEffects,stepCrashMechanics} from './vehicle_crash_mechanics.mjs';
const shared=fileURLToPath(new URL('.',import.meta.url));
const {CAR,stepCar,carFits,carOverlapsCircle,carCorners,createCarWorld}=await import(pathToFileURL(shared+'car_drive.mjs'));
const {vehicleSeat,vehicleSeatPoint,vehicleDoorPoint,findVehicleEntry,vehicleEntryPoint,planVehicleSeatExit}=await import(pathToFileURL(shared+'vehicle_seats.mjs'));
const {resolveVehiclePairImpulse}=await import(pathToFileURL(shared+'vehicle_pair_impulse.mjs'));
const open=()=>true;
const start=extra=>({x:0,z:0,yaw:0,speed:0,...extra});
const approx=(a,b,tol=1e-7)=>assert.ok(Math.abs(a-b)<=tol,`${a} != ${b}`);
function simulate(state,controls,seconds=3,dt=1/60){for(let i=0;i<Math.round(seconds/dt);i++)state=stepCar(state,controls,dt,open);return state;}
function damaged(speed,point={x:0,y:.8,z:2.15},normal={x:0,y:0,z:1}){const s=createCrashMechanicsState();applyCrashMechanicsImpact(s,{point,normal,impactSpeed:speed});return s;}
const bus={...CAR,halfWidth:1.45,halfLength:5.0,wheelBase:5.4,massKg:10200,maxSpeed:17,reverseSpeed:4,acceleration:2.6};

test('healthy crash effects preserve current acceleration, reverse and steering',()=>{
  const intact=crashDriveEffects(createCrashMechanicsState());
  const plain=simulate(start(),{forward:true,left:true}),withEffects=simulate(start({crashEffects:intact}),{forward:true,left:true});
  for(const key of ['x','z','yaw','speed','steer','yawRate'])approx(plain[key],withEffects[key]);
  assert.equal(simulate(start({crashEffects:intact}),{forward:true},6).speed,CAR.maxSpeed);
  assert.equal(simulate(start({crashEffects:intact}),{reverse:true},6).speed,-CAR.reverseSpeed);
});

test('front engine crush hurts acceleration more than same-energy rear crash',()=>{
  const front=damaged(15),rear=damaged(15,{x:0,y:.8,z:-2.15},{x:0,y:0,z:-1});
  const good=simulate(start(),{forward:true},3),a=simulate(start({crashEffects:crashDriveEffects(front)}),{forward:true},3),b=simulate(start({crashEffects:crashDriveEffects(rear)}),{forward:true},3);
  assert.ok(a.speed<b.speed*.7,`front ${a.speed}, rear ${b.speed}`);
  assert.ok(b.speed<good.speed);assert.ok(a.z<b.z);
  assert.equal(rear.engine,1);assert.ok(front.engine<.7);
});

test('wheel loss changes real steering, acceleration and coast drag',()=>{
  const crash=damaged(28,{x:.98,y:.55,z:1.93},{x:.22,y:0,z:1}),effects=crashDriveEffects(crash);
  assert.equal(effects.wheels.front_left.detached,true);
  const coast=simulate(start({speed:8,crashEffects:effects}),{},1),good=simulate(start({speed:8}),{},1);
  assert.ok(coast.speed<good.speed-2);assert.ok(coast.x>0,'damaged left wheel pulls car left during coast');
  const accel=simulate(start({crashEffects:effects}),{forward:true},3);
  assert.ok(accel.speed<simulate(start(),{forward:true},3).speed*.3);
});

test('an engine stall removes traction without deleting kinetic velocity or foot braking',()=>{
  const effects=crashDriveEffects(damaged(40));assert.equal(effects.engineDisabled,true);
  const moving=start({speed:12,crashEffects:effects});
  const coast=stepCar(moving,{},1/60,open),footBrake=stepCar(moving,{reverse:true},1/60,open);
  assert.ok(coast.speed>11.5,'engine stall must coast, never clamp to zero');
  assert.ok(coast.z>.19,'existing vehicle momentum survives motor failure');
  assert.ok(footBrake.speed<coast.speed,'S remains a foot brake with the engine dead');
  assert.equal(footBrake.braking,true);
  assert.equal(simulate(start({crashEffects:effects}),{forward:true},5).speed,0);
});

test('damage top-speed limits do not instantly chop moving-car kinetic energy',()=>{
  const effects={...crashDriveEffects(createCrashMechanicsState()),speedFactor:.2,powerFactor:.15,rollingDrag:2};
  const before=start({speed:20,crashEffects:effects}),next=stepCar(before,{},1/60,open);
  assert.ok(next.speed>19.5,'speed reduction is through force/drag, not a new low speed clamp');
  assert.ok(next.speed<before.speed);
  const underPower=stepCar(before,{forward:true},1/60,open);
  assert.ok(underPower.speed<=before.speed,'throttle cannot accelerate above damaged attainable top speed');
});

test('bus profile changes acceleration, turning radius, footprint and pair inertia',()=>{
  const sedan=simulate(start(),{forward:true},3),coach=simulate(start({vehicleProfile:bus}),{forward:true},3);
  assert.ok(coach.speed<sedan.speed*.6);assert.equal(coach.vehicleProfile,bus);
  const shortTurn=simulate(start({speed:5}),{left:true},.8),longTurn=simulate(start({speed:5,vehicleProfile:bus}),{left:true},.8);
  assert.ok(Math.abs(longTurn.yaw)<Math.abs(shortTurn.yaw)*.65);
  assert.equal(carOverlapsCircle(start({vehicleProfile:bus}),0,4.5,.1),true);
  assert.equal(carOverlapsCircle(start(),0,4.5,.1),false);
  assert.equal(carFits(0,0,0,(x,z)=>Math.abs(z)<4,CAR),true);
  assert.equal(carFits(0,0,0,(x,z)=>Math.abs(z)<4,bus),false);
  assert.equal(Math.max(...carCorners(0,0,0,bus).map(p=>p[1])),5);
  const contact={point:{x:1,y:.8,z:0},normal:{x:0,y:0,z:1}};
  const obstacle={x:0,z:8,mass:100000,vx:0,vz:0,halfWidth:2,halfLength:2};
  const carHit=resolveVehiclePairImpulse({x:0,z:0,mass:1500,vx:0,vz:10,halfWidth:CAR.halfWidth,halfLength:CAR.halfLength},obstacle,contact);
  const busHit=resolveVehiclePairImpulse({x:0,z:0,mass:bus.massKg,vx:0,vz:10,halfWidth:bus.halfWidth,halfLength:bus.halfLength},obstacle,contact);
  assert.ok(Math.abs(busHit.a.yawRate)<Math.abs(carHit.a.yawRate)*.5);
});

test('dynamic two-seat cabin exposes authored seats and distinct entry/exit anchors',()=>{
  const seats=[
    {id:'front_left',doorId:'front_left',label:'Водитель грузовика',side:1,canDrive:true,anchor:{side:.70,front:3.2,y:.75},doorFront:3.0,doorDistance:2.1},
    {id:'front_right',doorId:'front_right',label:'Пассажир грузовика',side:-1,canDrive:false,anchor:{side:-.70,front:3.2,y:.75},doorFront:3.0,doorDistance:2.1},
  ];
  const car=start({x:15,z:22,yaw:Math.PI/2,vehicleProfile:bus,seats});
  assert.equal(vehicleSeat('front_left',car).label,'Водитель грузовика');
  assert.throws(()=>vehicleSeat('rear_left',car));
  const seat=vehicleSeatPoint(car,'front_left');approx(seat.x,18.2);approx(seat.z,21.3);approx(seat.y,.75);
  const door=vehicleDoorPoint(car,'front_left');approx(door.x,18);approx(door.z,19.9);
  const entry=findVehicleEntry(car,door,open);assert.equal(entry.seatId,'front_left');assert.equal(entry.canDrive,true);
  const complete=vehicleEntryPoint(car,'front_left',1);approx(complete.x,seat.x);approx(complete.y,seat.y);approx(complete.z,seat.z);
  const other=findVehicleEntry(car,vehicleDoorPoint(car,'front_right'),open);assert.equal(other.seatId,'front_right');assert.equal(other.canDrive,false);
  assert.equal(findVehicleEntry(car,door,open,{occupiedSeats:['front_left','front_right']}),null);
  const exit=planVehicleSeatExit(car,'front_left',open,open);assert.equal(exit.seatId,'front_left');assert.equal(exit.doorId,'front_left');
  assert.equal(exit.predictedCar.seats,seats);assert.equal(exit.predictedCar.vehicleProfile,bus);
});

test('profile reaches SAT world queries instead of reverting to sedan dimensions',()=>{
  const grid=Array.from({length:15},()=>Array(15).fill(0));
  const body={minYM:0,maxYM:4,polygonCR:[[5,6.8],[8,6.8],[8,6.9],[5,6.9]]};
  const world=createCarWorld({grid},[body],1);
  assert.equal(carFits(6.5,3.5,0,world,CAR),true);
  assert.equal(carFits(6.5,3.5,0,world,bus),false);
  assert.ok(world.contactAt(6.5,3.5,0,bus));
});

test('damaged driving remains frame-consistent and finite through long mixed controls',()=>{
  const crash=damaged(11,{x:.95,y:.7,z:1.6},{x:1,y:0,z:.3}),effects=crashDriveEffects(crash);
  const a=simulate(start({crashEffects:effects}),{forward:true,left:true},3,1/30),b=simulate(start({crashEffects:effects}),{forward:true,left:true},3,1/120);
  assert.ok(Math.hypot(a.x-b.x,a.z-b.z)<.005);
  let state=start({vehicleProfile:bus,crashEffects:effects});
  for(let i=0;i<12000;i++) {
    const input={forward:i%800<450,reverse:i%800>=650,left:i%400<120,right:i%400>280,handbrake:i%1100>1060};
    state=stepCar(state,input,1/120,open);stepCrashMechanics(crash,1/120,{speed:state.speed,throttle:input.forward?1:0});
    assert.ok(['x','z','yaw','speed','steer','travelYaw','yawRate','distance'].every(k=>Number.isFinite(state[k])));
    assert.ok(Math.abs(state.speed)<=bus.maxSpeed+1e-8);
  }
  assert.equal(state.vehicleProfile,bus);
});

