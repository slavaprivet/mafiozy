import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
const T=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
import {createDemoCar} from './car_drive.mjs';
import {createVehicleHood,findHoodInteraction} from './vehicle_hood.mjs';
import {createVehicleDamage} from './vehicle_damage.mjs';
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
const vehicle={x:0,y:0,z:0,yaw:0,speed:0},hero={x:0,y:0,z:3};
function fixture(){const scene=new T.Scene(),car=createDemoCar(T,Box);scene.add(car.object);const hood=createVehicleHood(T,Box,car,{scene});car.hood=hood;const damage=createVehicleDamage(T,car,{scene,getState:()=>vehicle});return{scene,car,hood,damage,context:{hero,vehicleState:vehicle,damage},dispose(){damage.dispose();hood.dispose()}}}
test('front and rear-service access own only their stationary approach sectors',()=>{
  assert(findHoodInteraction(vehicle,hero));for(const h of [{x:0,y:0,z:-3},{x:1.9,y:0,z:0},{x:0,y:0,z:5},{x:0,y:4,z:3}])assert.equal(findHoodInteraction(vehicle,h),null);
  for(const c of [{occupied:true},{transition:true},{blocked:true},{damageState:{destroying:true}},{damageState:{wrecked:true}}])assert.equal(findHoodInteraction(vehicle,hero,c),null);
  assert.equal(findHoodInteraction({...vehicle,speed:.51},hero),null);
  assert(findHoodInteraction(vehicle,{x:0,y:0,z:-3},{profile:{front:false,accessZ:-2.2}}));
  assert(findHoodInteraction({...vehicle,yaw:Math.PI/2},{x:3,y:0,z:0}));
});
test('real hood lifts clear of windscreen and exposes detailed separate engine bay',()=>{
  const f=fixture();try{
    const {hood,car}=f,lid=hood.lid,closed=new T.Box3().setFromObject(lid),doors=[...car.doors.values()].map(n=>n.quaternion.clone());assert(hood.enabled);assert.equal(car.object.getObjectByName('Engine_core').visible,false);
    for(const name of ['Engine_block','Radiator_core','Upper_radiator_hose','Engine_battery','Air_filter_housing','Oil_filler_cap','Coolant_expansion_tank'])assert(hood.bay.getObjectByName(name));
    assert(hood.stats().engineParts>=40);assert.equal(hood.stats().visibleEngineParts,0,'closed hood does not draw hidden engine details');assert(!lid.getObjectByName('Engine_block'));
    const engineBounds=new T.Box3().setFromObject(hood.bay.getObjectByName('Engine_block'));assert(engineBounds.max.y<closed.min.y,'engine remains below closed hood');
    assert(hood.toggle(f.context).accepted);for(let i=0;i<45;i++)hood.update(1/60,{vehicleState:vehicle,crashState:f.damage.crash.state});
    const opened=new T.Box3().setFromObject(lid);assert(opened.max.y>closed.max.y+.8);assert(opened.min.z>closed.min.z-.02,'hinge clears windshield');assert(hood.interaction(hero,vehicle).repairAvailable);assert(hood.bay.getObjectByName('Engine_block').visible);assert(hood.stats().visibleEngineParts>=40);
    [...car.doors.values()].forEach((door,i)=>assert(door.quaternion.equals(doors[i])));assert.equal(car.interior.parts.seats.length,4);
    assert(hood.toggle(f.context).accepted);for(let i=0;i<45;i++)hood.update(1/60,{vehicleState:vehicle});assert.equal(hood.state.amount,0);assert.equal(hood.stats().visibleEngineParts,0);
    f.damage.crash.state.engine=.2;hood.update(.1,{vehicleState:vehicle,crashState:f.damage.crash.state});assert(hood.stats().smokeParticles>0,'closed hood does not suppress visible engine smoke');assert.equal(hood.stats().visibleEngineParts,0);
  }finally{f.dispose()}
});
test('R repairs engine and cooling only with open access, preserving body and wheels',()=>{
  const f=fixture();try{
    assert.equal(f.hood.repair(f.context).reason,'hood-closed');assert(f.hood.toggle(f.context).accepted);for(let i=0;i<45;i++)f.hood.update(1/60,{vehicleState:vehicle});
    const s=f.damage.crash.state;s.engine=.28;s.radiator=.19;s.temperature=.82;s.wheels.front_left.health=.4;s.wheels.front_left.sag=.12;s.steering=.7;s.brakes=.72;s.nodes[0].position.x+=.12;
    const before={hp:f.damage.state.hp,wheels:JSON.stringify(s.wheels),nodes:JSON.stringify(s.nodes),steering:s.steering,brakes:s.brakes};
    f.hood.update(.1,{vehicleState:vehicle,crashState:s,damageState:f.damage.state});assert(f.hood.stats().smokeParticles>0);
    assert.equal(f.hood.repair({...f.context,hero:{x:0,y:0,z:7}}).reason,'out-of-range');assert.equal(f.hood.repair({...f.context,vehicleState:{...vehicle,speed:.3}}).reason,'moving');
    const repaired=f.hood.repair(f.context);assert(repaired.accepted&&repaired.repaired);assert.equal(s.engine,1);assert.equal(s.radiator,1);assert.equal(s.temperature,0);assert.equal(f.damage.state.hp,before.hp);assert.equal(JSON.stringify(s.wheels),before.wheels);assert.equal(JSON.stringify(s.nodes),before.nodes);assert.equal(s.steering,before.steering);assert.equal(s.brakes,before.brakes);assert.equal(f.hood.stats().smokeParticles,0);
  }finally{f.dispose()}
});
test('crash detaches original hood once; exposed engine stays accessible for repair',()=>{
  const f=fixture();try{
    assert(f.damage.crash.contactImpact({point:{x:0,y:.9,z:2.15},normal:{x:0,y:0,z:1},impactSpeed:25}));
    f.hood.update(1/60,{vehicleState:vehicle,crashState:f.damage.crash.state});assert(f.hood.state.detached);assert.equal(f.hood.toggle(f.context).reason,'detached');assert(f.hood.interaction(hero,vehicle).repairAvailable);
    assert.equal(f.damage.crash.root.children.filter(n=>n.name==='Hood_lid').length,1);assert(f.hood.bay.parent===f.car.object);assert(f.hood.repair(f.context).accepted);
    f.damage.reset();assert.equal(f.hood.state.detached,false);assert.equal(f.hood.state.amount,0);assert(f.hood.lid.visible);assert.equal(f.damage.crash.root.children.length,0);
  }finally{f.dispose()}
});
test('fire or destruction cannot be cancelled by roadside engine repair',()=>{
  const f=fixture();try{f.hood.toggle(f.context);for(let i=0;i<45;i++)f.hood.update(1/60,{vehicleState:vehicle});f.damage.impact({object:f.hood.lid,damage:190});assert(f.damage.state.burning);assert.equal(f.hood.repair(f.context).reason,'burning');f.damage.impact({object:f.hood.lid,damage:999});assert.equal(f.hood.repair(f.context).reason,'destroyed')}finally{f.dispose()}
});
