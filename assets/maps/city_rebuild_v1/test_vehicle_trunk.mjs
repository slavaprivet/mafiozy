import assert from 'node:assert/strict';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {VEHICLE_TRUNK_RULES,createTrunkState,stepTrunkState,findTrunkInteraction,createVehicleTrunk} from './vehicle_trunk.mjs';

const ROOT=fileURLToPath(new URL('../../../',import.meta.url));
const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const {createDemoCar}=await import(new URL('car_drive.mjs',import.meta.url));
class TestBox extends THREE.BoxGeometry{constructor(w,h,d){super(w,h,d)}}

const vehicle={x:0,z:0,y:0,yaw:0,speed:0},hero={x:0,y:0,z:-3};
assert.equal(findTrunkInteraction(vehicle,hero).action,'open');
for(const context of [{occupied:true},{transition:true},{blocked:true},{damageState:{destroying:true}},{damageState:{wrecked:true}},{state:{...createTrunkState(),detached:true}}])assert.equal(findTrunkInteraction(vehicle,hero,context),null);
assert.equal(findTrunkInteraction({...vehicle,speed:.51},hero),null);
assert.equal(findTrunkInteraction(vehicle,{x:1.9,y:0,z:-1.15}),null,'rear seat E remains a seat interaction');
assert.equal(findTrunkInteraction(vehicle,{x:0,y:0,z:3}),null);
assert.equal(findTrunkInteraction(vehicle,{x:0,y:0,z:-5}),null);
assert.equal(findTrunkInteraction(vehicle,{x:0,y:5,z:-3}),null);
assert(findTrunkInteraction({...vehicle,x:10,z:7,yaw:Math.PI/2},{x:7,y:0,z:7}),'rotated world coordinates resolve rear');
assert.equal(findTrunkInteraction({...vehicle,speed:NaN},hero),null);
let pure={...createTrunkState(),target:1,open:true};
for(let i=0;i<40;i++)pure=stepTrunkState(pure,1/60);
assert.equal(pure.amount,1);
pure=stepTrunkState(pure,.1,{speed:3});assert.equal(pure.target,0);assert(pure.amount<1);
assert.throws(()=>stepTrunkState(pure,-1));

const scene=new THREE.Scene(),car=createDemoCar(THREE,TestBox);scene.add(car.object);
const doorRest=new Map([...car.doors].map(([id,door])=>[id,{parent:door.parent,position:door.position.clone(),quaternion:door.quaternion.clone()}]));
const source=car.object.getObjectByName('Trunk_lid'),core=car.object.getObjectByName('Trunk_core'),sourceRest={parent:source.parent,position:source.position.clone(),quaternion:source.quaternion.clone(),scale:source.scale.clone()};
const shellCount=car.shell.length,initialLidBounds=new THREE.Box3().setFromObject(source),controller=createVehicleTrunk(THREE,TestBox,car,{scene});
assert(controller.enabled);assert.equal(core.visible,false);assert.equal(car.doors.size,4);assert.equal(car.interior.parts.seats.length,4);
assert.equal(source.parent,controller.hinge);assert.equal(car.shell.filter(item=>item===source).length,1);
const closedLidBounds=new THREE.Box3().setFromObject(source);
assert(closedLidBounds.min.distanceTo(initialLidBounds.min)<.08,'closed silhouette retained with an underside and handle');
const cargo=controller.cavity.userData.cargoBounds;
const probe=new THREE.Vector3((cargo.min[0]+cargo.max[0])/2,(cargo.min[1]+cargo.max[1])/2,(cargo.min[2]+cargo.max[2])/2);
assert(controller.containsItem(probe,[.15,.15,.15]));assert(!controller.acceptsItem(probe,[.15,.15,.15]));
assert(!controller.containsItem(probe,[NaN,.15,.15]));assert(!controller.containsItem(probe,[-.1,.15,.15]));
for(const collider of controller.cargoColliders){const mesh=car.object.getObjectByProperty('uuid',collider.meshUUID),actual=new THREE.Box3().setFromObject(mesh);assert(mesh);assert(new THREE.Vector3(...collider.min).distanceTo(actual.min)<1e-6);assert(new THREE.Vector3(...collider.max).distanceTo(actual.max)<1e-6)}
const visibleSolids=[];car.object.traverse(mesh=>{if(!mesh.isMesh||mesh.material?.transparent)return;for(let node=mesh;node;node=node.parent)if(!node.visible)return;visibleSolids.push(mesh)});
assert(!visibleSolids.some(mesh=>new THREE.Box3().setFromObject(mesh).containsPoint(probe)),'cargo is an actual hollow volume');
const context={hero,vehicleState:vehicle};
assert.deepEqual(controller.toggle({...context,vehicleState:{...vehicle,speed:2}}),{accepted:false,reason:'moving'});
assert.equal(controller.toggle({...context,hero:{x:1.9,y:0,z:-1.15}}).accepted,false);
assert(controller.toggle(context).accepted);
for(let i=0;i<45;i++)controller.update(1/60,{vehicleState:vehicle});
assert.equal(controller.state.amount,1);assert.equal(controller.hinge.rotation.x,VEHICLE_TRUNK_RULES.openAngle);
assert(controller.acceptsItem(probe,[.15,.15,.15]));
assert(controller.containsItem(probe,[.20,.20,.20]));assert(!controller.acceptsItem(probe,[.20,.20,.20]),'a box that fits inside but not through the raised-lid opening is rejected');
car.object.position.set(10,2,-20);car.object.rotation.y=Math.PI/2;car.object.updateWorldMatrix(true,true);
const worldProbe=controller.toCargoWorld(probe),worldHalf=[.15,.12,.25];
assert(controller.toCargoLocal(worldProbe).distanceTo(probe)<1e-6);assert(controller.containsItem(worldProbe,worldHalf,{world:true}));assert(controller.acceptsItem(worldProbe,worldHalf,{world:true}),'yawed world item is tested by local corners, not unrotated half extents');
assert.equal(controller.worldCargoBounds().corners.length,8);assert(controller.worldCargoColliders().every(c=>c.quaternion.length===4&&c.center.every(Number.isFinite)));
car.object.position.set(0,0,0);car.object.rotation.y=0;car.object.updateWorldMatrix(true,true);
const openBounds=new THREE.Box3().setFromObject(source);assert(openBounds.max.y>initialLidBounds.max.y+.35,'rear edge visibly lifts');
assert(openBounds.max.z<initialLidBounds.max.z+.015,'lid does not sweep through rear cabin glass');
assert.equal(controller.interaction(hero,vehicle).action,'close');
for(const [id,rest]of doorRest){const door=car.doors.get(id);assert.equal(door.parent,rest.parent);assert(door.position.equals(rest.position));assert(door.quaternion.equals(rest.quaternion))}
car.setDoorById(.6,'rear_left');assert.equal(car.doors.get('rear_left').rotation.y,-.66);assert.equal(controller.state.amount,1);
assert(controller.toggle(context).accepted);
for(let i=0;i<45;i++)controller.update(1/60,{vehicleState:vehicle});assert.equal(controller.state.amount,0);
assert.equal(controller.contactImpact({point:{x:0,y:1,z:2.14},normal:{x:0,y:0,z:1},impactSpeed:30},vehicle),false,'front crash cannot tear off rear lid');
const rearContact={point:{x:0,y:.9,z:-2.15},normal:{x:0,y:0,z:-1},impactSpeed:18};
assert(controller.contactImpact(rearContact,vehicle));assert.equal(controller.state.detached,true);assert.equal(source.visible,false);assert.equal(controller.stats().debris,1);assert.equal(controller.interaction(hero,vehicle),null);
assert.equal(controller.detach({contact:rearContact,vehicleState:vehicle}),false);assert.equal(controller.stats().debris,1,'idempotent detach');
const fragment=scene.getObjectByName('Trunk_detached_lid');assert(fragment);const fragmentStart=fragment.getWorldPosition(new THREE.Vector3());
car.object.position.set(90,0,90);controller.update(1/60,{vehicleState:{...vehicle,x:90,z:90}});
assert(fragment.getWorldPosition(new THREE.Vector3()).distanceTo(fragmentStart)<1,'debris is independent of car transform');
for(let i=0;i<1200;i++)controller.update(1/60,{vehicleState:vehicle});
assert.equal(controller.stats().debris,1,'no expiry timer');assert.equal(controller.stats().settledDebris,1);assert(new THREE.Box3().setFromObject(fragment).min.y>=.017,'settled fragment stays above ground');
controller.reset();assert.equal(controller.stats().debris,0);assert.equal(controller.state.detached,false);assert.equal(source.visible,true);assert.equal(core.visible,false);assert.equal(controller.hinge.rotation.x,0);
car.object.position.set(0,0,0);assert(controller.toggle(context).accepted);for(let i=0;i<45;i++)controller.update(1/60,{vehicleState:vehicle});
assert(controller.contactImpact({...rearContact,impactSpeed:9.5},vehicle));assert.equal(controller.state.detached,true,'open hinge breaks at lower rear impact');
controller.reset();source.visible=false;controller.update(1/60,{vehicleState:vehicle,damageState:{wrecked:true}});assert.equal(controller.state.externalDebris,true);assert.equal(controller.stats().debris,0,'existing damage debris is never duplicated');
controller.reset();controller.update(1/60,{vehicleState:vehicle,damageState:{wrecked:true}});assert.equal(controller.state.detached,true);assert.equal(controller.stats().debris,1);
controller.dispose();assert.equal(car.shell.length,shellCount);assert.equal(source.parent,sourceRest.parent);assert(source.position.equals(sourceRest.position));assert(source.quaternion.equals(sourceRest.quaternion));assert(source.scale.equals(sourceRest.scale));assert.equal(core.visible,true);assert.equal(scene.getObjectByName('Trunk_detached_lid'),undefined);assert.equal(car.object.getObjectByName('Trunk_cavity'),undefined);
assert.equal(createVehicleTrunk(THREE,TestBox,{object:new THREE.Group()}).enabled,false);
for(const mode of ['hatch','tailgate']){
  const object=new THREE.Group(),lidGroup=new THREE.Group();object.add(lidGroup);scene.add(object);lidGroup.name='Trunk_lid';
  const panel=new THREE.Mesh(new THREE.BoxGeometry(1.8,.9,.06),new THREE.MeshStandardMaterial());panel.position.set(0,1,-2.5);lidGroup.add(panel);
  const fixture={object,shell:[lidGroup],profile:{halfLength:2.56},trunkSpec:{lid:lidGroup,hingePoint:[0,mode==='hatch'?1.45:.55,-2.5],mode,createCavity:false,cavityBounds:{min:[-.9,.3,-2.45],max:[.9,1.4,-1]}}};
  const adapter=createVehicleTrunk(THREE,TestBox,fixture,{scene});assert(adapter.enabled);assert.equal(adapter.cavity.children.length,0,'artist cavity preserved');
  const probeLocal=new THREE.Vector3(0,mode==='hatch'?.55:1.45,-2.5),tip=lidGroup.worldToLocal(object.localToWorld(probeLocal.clone()));
  assert(adapter.toggle({hero:{x:0,y:0,z:-3.4},vehicleState:vehicle}).accepted);for(let i=0;i<45;i++)adapter.update(1/60,{vehicleState:vehicle});
  const openedTip=lidGroup.localToWorld(tip.clone());assert(openedTip.z<-3.2,'authored rear gate opens outward');if(mode==='hatch')assert(openedTip.y>1,'hatch rises');else assert(openedTip.y<.70,'tailgate lowers through at least 80 degrees');
  assert(adapter.detach({contact:{normal:{x:0,y:0,z:-1},impactSpeed:20},vehicleState:vehicle}));assert.equal(adapter.stats().debris,1);adapter.reset();adapter.dispose();object.removeFromParent();panel.geometry.dispose();panel.material.dispose();
}
console.log('PASS trunk rear-only E, distance/movement/occupied/destroyed gates, independent hinge, hollow cargo, four unchanged doors, directional breakage, persistent world debris, reset, disposal and artist Group hatch/tailgate contracts');
