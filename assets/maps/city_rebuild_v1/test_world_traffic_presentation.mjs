import assert from 'node:assert/strict';
import {normalizeWorldTraffic,worldTrafficProfile,createWorldTrafficPresentation,trafficActorBlocks} from './world_traffic_presentation.mjs';
const collisionActor={object:{position:{x:10,y:5,z:20},rotation:{y:Math.PI/2},scale:{x:1,y:1,z:1}},profile:{halfWidth:1,halfLength:2.5,height:2,bounds:{min:[-1,0,-2.5],max:[1,2,2.5]}}};
assert(trafficActorBlocks(collisionActor,12,20));assert(!trafficActorBlocks(collisionActor,10,22));assert(trafficActorBlocks(collisionActor,10,21.1,.2));
assert(!trafficActorBlocks(collisionActor,12,20,.2,{y:0,height:1.9}));assert(trafficActorBlocks(collisionActor,12,20,.2,{y:5,height:1.9}));assert(!trafficActorBlocks(collisionActor,12,20,.2,{y:8,height:1.9}));
collisionActor.object.position.x=100;assert(!trafficActorBlocks(collisionActor,12,20));
const vec=()=>({x:0,y:0,z:0,set(x,y,z){Object.assign(this,{x,y,z})}});
let releases=0,loads=0,active=0,peak=0;
const object=()=>({position:vec(),rotation:{y:0},userData:{},traverse(fn){fn({geometry:{dispose(){releases++}}})},removeFromParent(){}});
const scene={add(){}},loader={async loadAsync(){loads++;active++;peak=Math.max(peak,active);await Promise.resolve();active--;return {scene:object()}}};
const calls=[];const fleet=createWorldTrafficPresentation({scene,loader,vehicleFactory:()=>({object:object(),profile:{halfWidth:1,halfLength:2,height:2},update(state){calls.push(state)}})});
const a={id:'source_car_17',r:2,c:3,ang:0,model:'sedan'},b={...a,id:'quest_native_91',model:'hatch'};
assert.equal(normalizeWorldTraffic(a).yaw,Math.PI/2);assert.equal(normalizeWorldTraffic(a).x,3*4.1);
assert.equal(worldTrafficProfile({...a,helicopter:true}),null);
assert.equal(worldTrafficProfile({...a,model:'police_armored_van'}),null);
fleet.sync([a,b,{...a,id:'third'}]);await fleet.whenIdle();assert.equal(loads,2);assert.equal(peak,1);
fleet.update(1/60);assert.equal(fleet.diagnostics().actors,1);assert(fleet.blocks(3*4.1,2*4.1));assert(!fleet.blocks(3*4.1,2*4.1,0,{ignoreId:a.id}));assert(!fleet.blocks(3*4.1,2*4.1,0,{y:5,height:1}));assert.equal(fleet.getActors()[0].id,a.id);fleet.update(1/60);fleet.update(1/60);assert.equal(fleet.diagnostics().actors,3);
const actual=fleet.getActor(a.id),before=actual.object.position.x;
fleet.sync([{...a,c:4},b]);fleet.update(1/60);assert(actual.object.position.x>before&&actual.object.position.x<4*4.1);assert.equal(fleet.getActor('third'),null);
fleet.sync([{...a,c:100},b]);fleet.update(1/60);assert(Math.abs(actual.object.position.x-410)<1e-9);assert.equal(calls.at(-2).distance,0);
assert.deepEqual(a,{id:'source_car_17',r:2,c:3,ang:0,model:'sedan'});
fleet.sync([{...a,id:'heli',helicopter:true}]);assert.equal(fleet.diagnostics().unsupported.length,1);assert.equal(fleet.diagnostics().actors,0);
fleet.dispose();const disposedCount=releases;fleet.dispose();assert.equal(releases,disposedCount);assert.equal(releases,5);
console.log(JSON.stringify({passed:true,checks:['original-identity','4.1-coordinates','unsupported-special-vehicles','sequential-model-cache','one-actor-per-update','interpolation-no-source-write','teleport-no-wheel-spin','disposal']}));

// Remote traffic interpolation runs every render frame. Its transient drive input
// and source metadata must stay owned by the actor until the next snapshot.
const reusedStates=[],reusedFleet=createWorldTrafficPresentation({scene,loader,vehicleFactory:()=>({object:object(),profile:{halfWidth:1,halfLength:2,height:2},update(state){reusedStates.push(state)}})});
const reusedRow={id:'reused-state',r:4,c:5,ang:0,model:'sedan',burning:false};
reusedFleet.sync([reusedRow]);await reusedFleet.whenIdle();reusedFleet.update(1/60);
const driveState=reusedStates.at(-1),sourceActor=reusedFleet.getActor(reusedRow.id),presentation=sourceActor.object.userData.sourcePresentation;
const staticUpdates=reusedStates.length;for(let i=0;i<120;i++)reusedFleet.update(1/60);
assert.equal(reusedStates.length,staticUpdates,'a settled parked vehicle does not repeat unchanged wheel/brake work for 120 frames');
assert(reusedStates.every(state=>state===driveState),'one actor retains its wheel-update input between frames');assert.equal(sourceActor.object.userData.sourcePresentation,presentation,'unchanged source metadata keeps its object');
reusedFleet.sync([{...reusedRow,burning:true,damageRatio:.4}]);reusedFleet.update(1/60);
assert.equal(sourceActor.object.userData.sourcePresentation,presentation,'new snapshot mutates the owned metadata object');assert.equal(presentation.burning,true);assert.equal(presentation.damageRatio,.4);
reusedFleet.sync([{...reusedRow,burning:true,damageRatio:.4,braking:true}]);reusedFleet.update(1/60);assert.equal(reusedStates.length,staticUpdates+1,'a brake-state change still reaches the authored brake lamps');
reusedFleet.sync([{...reusedRow,burning:true,damageRatio:.4,braking:true,steer:.25}]);reusedFleet.update(1/60);assert.equal(reusedStates.length,staticUpdates+2,'a steering-state change still reaches the authored front wheels');assert.equal(driveState.steer,.25);
reusedFleet.dispose();

