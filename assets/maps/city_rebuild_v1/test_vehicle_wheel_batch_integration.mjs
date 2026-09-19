import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createVehicleFleet} from './vehicle_fleet.mjs';
import {createWorldTrafficPresentation} from './world_traffic_presentation.mjs';
import {createArtistVehicle} from './vehicle_fleet_models.mjs';
import {createDetailedVehicleWheel,createVehicleWheelMaterialPalette,updateVehicleWheelVisuals} from './vehicle_wheels.mjs';
import {getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
import {CAR} from './car_drive.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import('three'),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
class Box extends T.BoxGeometry{constructor(w,h,d){super(w,h,d)}}
function carFixture(){
 const object=new T.Group(),palette=createVehicleWheelMaterialPalette(T,{owner:object}),wheels=[];
 for(const [i,id]of ['front_left','front_right','rear_left','rear_right'].entries()){
  const pivot=new T.Group();pivot.userData.vehicleWheelId=id;pivot.position.set(i%2?-1:1,.4,i<2?1.5:-1.5);object.add(pivot);
  const detail=createDetailedVehicleWheel(T,{id,materialPalette:palette});pivot.add(detail.wheel);wheels.push({id,pivot,...detail,front:i<2,rollingRadius:.4,restPosition:pivot.position.clone()});
 }
 return {object,wheels,shell:[],doors:new Map(),seats:[],profile:{...CAR,id:'integration',massKg:1500,collisionHull:{}},update:state=>updateVehicleWheelVisuals(wheels,state)};
}
for(const [flag,capability]of [[false,true],[true,false],[true,true]]){
 const car=carFixture(),canonical=car.wheels[0].tire.material,noop={update(){},reset(){},dispose(){},stats(){return{}}};let disposed=0;
 const supplied={car,trunk:noop,hood:noop,roll:{...noop,angle:0},tyres:{...noop,state:[],effects:{speedFactor:1},update(){car.wheels[0].tire.scale.x=.8}},damage:{...noop,state:{hp:100,maxHp:100},crash:{applyWheels(){car.wheels[0].pivot.position.y=.31}},dispose(){disposed++;assert.equal(car.wheels[0].tire.material,canonical,'wheel proxy restored before damage teardown');}}};
 const fleet=createVehicleFleet(T,{scene:new T.Scene(),RoundedBox:Box,wheelRenderOptimization:flag,detailOptimization:capability}),record=fleet.addCar(supplied);
 if(flag&&capability){
  assert.equal(record.wheelRenderBatches.stats.members,20);const other=carFixture();fleet.activate(fleet.addCar({car:other,trunk:noop,hood:noop,roll:{...noop,angle:0},tyres:{...noop,state:[],effects:{speedFactor:1}},damage:{...noop,state:{hp:100,maxHp:100}}},{x:30,z:30}));record.state.steer=.3;record.state.distance=.2;fleet.update(.016);
  car.object.updateMatrixWorld(true);const batch=car.object.children.find(n=>n.userData.vehicleWheelRenderBatch&&n.material===canonical),matrix=new T.Matrix4();let matches=false;
  for(let i=0;i<batch.instanceCount;i++){batch.getMatrixAt(i,matrix);matrix.premultiply(batch.matrixWorld);if(matrix.elements.every((v,k)=>Math.abs(v-car.wheels[0].tire.matrixWorld.elements[k])<1e-6))matches=true;}
  assert(matches,'batch sees both tyre scale and later crash pivot change');assert.equal(fleet.stats().wheelRenderBatches.members,40);
 }else {assert.equal(record.wheelRenderBatches,undefined);assert.equal(car.wheels[0].tire.material,canonical);assert.equal(fleet.stats().wheelRenderBatches.batches,0);}
 fleet.dispose();assert.equal(disposed,1);assert.equal(car.wheels[0].tire.material,canonical);
}
const row={id:'wheel-traffic',r:2,c:3,ang:0,model:'compact_sedan'};
for(const [flag,capability]of [[false,true],[true,false]]){
 let calls=0;const presentation=createWorldTrafficPresentation({THREE:T,scene:new T.Scene(),loader:{async loadAsync(){return{scene:new T.Group()}}},wheelRenderOptimization:flag,detailOptimization:capability,vehicleFactory(...args){calls++;assert.equal(args.length,4,'OFF leaves mock factory call signature untouched');return {object:new T.Group(),profile:CAR,update(){}};}});
 presentation.sync([row]);await presentation.whenIdle();presentation.update(.016);assert.equal(calls,1);assert.equal(presentation.diagnostics().wheelRenderBatches.batches,0);presentation.dispose();
}
{
 const loader={async loadAsync(url){const name=url.split('/').pop(),bytes=readFileSync(new URL('models/artist_vehicle_pack/'+name,import.meta.url));return new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');}},calls=[];
 const presentation=createWorldTrafficPresentation({THREE:T,RoundedBox:Box,scene:new T.Scene(),loader,wheelRenderOptimization:true,detailOptimization:true,vehicleFactory(...args){calls.push(args);assert.deepEqual(args[4],{wheelRenderOptimization:true});return createArtistVehicle(...args);}});
 presentation.sync([row]);await presentation.whenIdle();presentation.update(.016);assert.equal(calls.length,1);assert.equal(presentation.diagnostics().wheelRenderBatches.members,20);
 const actor=presentation.getActor(row.id),batch=actor.object.children.find(n=>n.userData.vehicleWheelRenderBatch),texture=batch._matricesTexture,version=texture.version;
 for(let i=0;i<12;i++)presentation.update(.016);assert.equal(texture.version,version,'settled traffic retains existing driveChanged skip');
 actor.wheels[0].hub.geometry.attributes.position.needsUpdate=true;presentation.update(.016);assert.equal(presentation.diagnostics().wheelRenderBatches.fallbackMembers,1,'stationary external wheel geometry edits fall back without driveChanged');
 presentation.sync([{...row,c:4,steer:.3}]);presentation.update(.016);assert(texture.version>version,'movement/steering refreshes wheel batches');
 const oldSources=actor.wheels.flatMap(w=>{const all=[];w.wheel.traverse(n=>{if(n.isMesh)all.push([n,getVehicleRenderSourceMaterial(n)])});return all;});let disposed=0;batch.geometry.addEventListener('dispose',()=>{disposed++;for(const[n,material]of oldSources.filter(([n])=>getVehicleRenderSourceMaterial(n)===batch.material))assert.equal(n.material,material);});
 presentation.sync([{...row,model:'city_hatchback'}]);assert.equal(disposed,1);assert.equal(actor.object.parent,null);await presentation.whenIdle();presentation.update(.016);assert.equal(presentation.diagnostics().wheelRenderBatches.members,20);assert.notEqual(presentation.getActor(row.id),actor);
 const next=presentation.getActor(row.id),newBatch=next.object.children.find(n=>n.userData.vehicleWheelRenderBatch);let finalDisposed=0;newBatch.geometry.addEventListener('dispose',()=>finalDisposed++);presentation.dispose();presentation.dispose();assert.equal(finalDisposed,1);assert.equal(next.object.parent,null);
}
console.log('PASS wheel fleet/traffic integration: default and capability gates, old factory signature, update after tyre/crash, settled cadence, actual actor move/profile replacement, canonical disposal and diagnostics');
