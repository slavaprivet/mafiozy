import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {buildingShadowCullingEnabled,shadowVolumeOutsideView,createVehicleShadowCulling,vehicleShadowCullingEnabled} from './vehicle_shadow_culling.mjs';
import {batchedShadowBoundsCurrent,stampBatchedShadowBounds} from './shadow_bounds_stamp.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
assert.equal(vehicleShadowCullingEnabled(''),true,'ordinary walk enables conservative vehicle shadow culling');
assert.equal(vehicleShadowCullingEnabled('?perfqa=1'),true,'unrelated QA parameters preserve the default');
assert.equal(vehicleShadowCullingEnabled('?vehicleshadowcull=1'),true,'legacy opt-in remains compatible');
assert.equal(vehicleShadowCullingEnabled('?vehicleshadowcull=0'),false,'explicit rollback disables the optimization');
assert.equal(buildingShadowCullingEnabled(''),true,'ordinary walk enables conservative building shadow culling');
assert.equal(buildingShadowCullingEnabled('?perfqa=1'),true,'unrelated QA parameters preserve the building default');
assert.equal(buildingShadowCullingEnabled('?buildingshadowcull=1'),true,'legacy building opt-in remains compatible');
assert.equal(buildingShadowCullingEnabled('?buildingshadowcull=0'),false,'explicit building rollback disables the optimization');
const camera=new T.PerspectiveCamera(45,16/9,.2,1500);camera.position.set(0,1.7,0);camera.lookAt(0,1.7,-10);camera.updateMatrixWorld(true);
const frustum=new T.Frustum().setFromProjectionMatrix(new T.Matrix4().multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse));
const direction=new T.Vector3(75,-130,-90).normalize();
assert(shadowVolumeOutsideView(frustum.planes,new T.Vector3(40,1,20),2,direction,320,.5));
assert(!shadowVolumeOutsideView(frustum.planes,new T.Vector3(0,1,-10),2,direction,320,.5));
// A caster behind the view can cast directly forward into the visible volume.
assert(!shadowVolumeOutsideView(frustum.planes,new T.Vector3(0,1,5),1,new T.Vector3(0,0,-1),40,.5));
assert(!shadowVolumeOutsideView(frustum.planes,new T.Vector3(0,1,5),NaN,direction,40,.5));
// Every sampled point in the swept sphere is rejected only outside the view.
let seed=39171,checks=0;const random=()=>((seed=(Math.imul(seed,1664525)+1013904223)>>>0)/4294967296);
for(let i=0;i<1500;i++){
 const c=new T.Vector3(random()*200-100,random()*40-20,random()*200-100),r=random()*8,len=random()*320,pad=.5;
 const rejected=shadowVolumeOutsideView(frustum.planes,c,r,direction,len,pad);
 if(!rejected)continue;
 for(let j=0;j<80;j++){
  const offset=new T.Vector3(random()*2-1,random()*2-1,random()*2-1).normalize().multiplyScalar(random()*(r+pad));
  const p=c.clone().addScaledVector(direction,random()*len).add(offset);assert(!frustum.containsPoint(p));checks++;
 }
}
const scene=new T.Scene(),sun=new T.DirectionalLight();sun.position.set(-75,130,90);sun.castShadow=true;scene.add(sun,sun.target);
Object.assign(sun.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});sun.shadow.mapSize.set(2048,2048);sun.shadow.bias=-.0003;sun.shadow.normalBias=.04;
const car=new T.Group();car.userData.vehicleFleetId='test';scene.add(car);
const mesh=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());mesh.castShadow=true;car.add(mesh);car.position.set(40,1,20);scene.updateMatrixWorld(true);
let calls=0,throwDraw=false;const renderer={shadowMap:{type:T.PCFSoftShadowMap,render(lights,s,c){renderer.renderBufferDirect(sun.shadow.camera,s,mesh.geometry,mesh.material,mesh,null);if(throwDraw)throw Error('draw failure');}},renderBufferDirect(){calls++;}};
const shadowOriginal=renderer.shadowMap.render,directOriginal=renderer.renderBufferDirect,helper=createVehicleShadowCulling({THREE:T,renderer,scene,sun});
const render=()=>renderer.shadowMap.render([sun],scene,camera);
render();assert.equal(calls,0);assert.equal(helper.stats.culled,1);assert(mesh.visible&&mesh.castShadow,'no gameplay flags changed');
renderer.renderBufferDirect(camera,scene,mesh.geometry,mesh.material,mesh,null);assert.equal(calls,1,'main pass never suppressed');
helper.setEnabled(false);render();assert.equal(calls,2);helper.setEnabled(true);
car.position.set(0,1,-10);scene.updateMatrixWorld(true);render();assert.equal(calls,3,'visible shadow kept');
car.position.set(40,1,20);scene.updateMatrixWorld(true);
mesh.material.onBeforeCompile=()=>{};render();assert.equal(calls,4,'custom shader left untouched');delete mesh.material.onBeforeCompile;
mesh.customDepthMaterial=new T.MeshDepthMaterial();render();assert.equal(calls,5);mesh.customDepthMaterial=null;
renderer.shadowMap.type=T.VSMShadowMap;render();assert.equal(calls,6);renderer.shadowMap.type=T.PCFSoftShadowMap;
const regular=mesh.material;mesh.material=new T.ShaderMaterial();render();assert.equal(calls,7,'arbitrary vertex shader is never bounded from positions');mesh.material=regular;
const callback=mesh.onBeforeShadow;mesh.onBeforeShadow=()=>{};render();assert.equal(calls,8,'custom shadow callback is never optimized');mesh.onBeforeShadow=callback;
// Geometry edits must invalidate cached bounds before a potentially unsafe skip.
const positions=mesh.geometry.attributes.position;for(let i=0;i<positions.count;i++){positions.setX(i,positions.getX(i)-40);positions.setZ(i,positions.getZ(i)-30);}positions.needsUpdate=true;
render();assert.equal(calls,9,'moved geometry now inside view must render');
throwDraw=true;assert.throws(render,/draw failure/);throwDraw=false;const before=calls;renderer.renderBufferDirect(sun.shadow.camera,scene,mesh.geometry,mesh.material,mesh,null);assert.equal(calls,before+1,'error clears shadow context');
helper.dispose();helper.dispose();assert.equal(renderer.shadowMap.render,shadowOriginal);assert.equal(renderer.renderBufferDirect,directOriginal);

// Building sources share the same mathematical proof but have a separate
// runtime switch. Their gameplay hierarchy and render flags stay intact.
{
 const world=new T.Scene(),light=new T.DirectionalLight();light.position.set(-75,130,90);light.castShadow=true;world.add(light,light.target);Object.assign(light.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});light.shadow.mapSize.set(2048,2048);
 const placement=new T.Group();placement.userData.instance={assetId:'test_house'};const wall=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());wall.castShadow=true;wall.position.set(40,1,20);placement.add(wall);world.add(placement);world.updateMatrixWorld(true);
 let submissions=0;const backend={shadowMap:{enabled:true,autoUpdate:true,type:T.PCFSoftShadowMap,render(){backend.renderBufferDirect(light.shadow.camera,world,wall.geometry,wall.material,wall,null)}},renderBufferDirect(){submissions++}};
 const guard=createVehicleShadowCulling({THREE:T,renderer:backend,scene:world,sun:light,enabled:false,buildingEnabled:false});
 backend.shadowMap.render([light],world,camera);assert.equal(submissions,1,'disabled building source renders normally');
 guard.setBuildingEnabled(true);backend.shadowMap.render([light],world,camera);assert.equal(submissions,1,'enabled path rejects only the proven outside building shadow volume');assert.equal(guard.stats.buildingCulled,1);assert.equal(guard.stats.vehicleCulled,0);
 wall.position.set(0,1,-10);world.updateMatrixWorld(true);backend.shadowMap.render([light],world,camera);assert.equal(submissions,2,'building caster that can affect the view is retained');assert.equal(placement.visible,true);assert.equal(wall.castShadow,true);guard.dispose();
}

// Independent regressions from review. Emulate Three's manual-update gates
// and map replacement, while leaving all geometry/matrix math real.
function reviewFixture(object,{kind='vehicle'}={}){
 const world=new T.Scene(),light=new T.DirectionalLight();light.position.set(-75,130,90);world.add(light,light.target);light.castShadow=true;
 Object.assign(light.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});light.shadow.mapSize.set(2048,2048);light.shadow.bias=-.0003;light.shadow.normalBias=.04;
 const owner=new T.Group();if(kind==='building')owner.userData.instance={assetId:'review_building'};else owner.userData.vehicleFleetId='review';owner.add(object);world.add(owner);object.castShadow=true;world.updateMatrixWorld(true);
 const view=camera.clone();view.updateMatrixWorld(true);
 let submissions=0,passes=0,mapHasCaster=null;
 const backend={shadowMap:{enabled:true,autoUpdate:true,needsUpdate:false,type:T.PCFSoftShadowMap,render(lights=[light]){
  if(!backend.shadowMap.enabled||!backend.shadowMap.autoUpdate&&!backend.shadowMap.needsUpdate)return;
  for(const current of lights){if(!current.shadow||!current.shadow.autoUpdate&&!current.shadow.needsUpdate)continue;const before=submissions;passes++;if(current===light)backend.renderBufferDirect(light.shadow.camera,world,object.geometry,object.material,object,null);if(current===light)mapHasCaster=submissions>before;current.shadow.needsUpdate=false}
  backend.shadowMap.needsUpdate=false;
 }},renderBufferDirect(){submissions++;}};
 const guard=createVehicleShadowCulling({THREE:T,renderer:backend,scene:world,sun:light,enabled:kind==='vehicle',buildingEnabled:kind==='building'});
 return {world,light,view,owner,backend,guard,render:(lights=[light])=>backend.shadowMap.render(lights,world,view),get submissions(){return submissions},get passes(){return passes},get mapHasCaster(){return mapHasCaster}};
}

// Emulate the relevant Three scene traversal gates as well as the actual
// renderBufferDirect hook. This catches ownership changes without pretending
// that hidden, detached or layer-mismatched objects reach the shadow draw.
function traversalFixture(object,{building=true}={}){
 const world=new T.Scene(),light=new T.DirectionalLight();light.position.set(-75,130,90);world.add(light,light.target);light.castShadow=true;
 Object.assign(light.shadow.camera,{left:-90,right:90,top:90,bottom:-90,near:1,far:320});light.shadow.mapSize.set(2048,2048);light.shadow.bias=-.0003;light.shadow.normalBias=.04;
 const owner=new T.Group();if(building)owner.userData.instance={assetId:'traversal_building'};else owner.userData.vehicleFleetId='traversal_vehicle';owner.add(object);world.add(owner);object.castShadow=true;
 const view=camera.clone();view.updateMatrixWorld(true);let drawn=[];
 const backend={shadowMap:{enabled:true,autoUpdate:true,needsUpdate:false,type:T.PCFSoftShadowMap,render(){
  world.updateMatrixWorld(true);drawn=[];world.traverseVisible(node=>{if(node.isMesh&&node.castShadow&&node.layers.test(light.shadow.camera.layers))backend.renderBufferDirect(light.shadow.camera,world,node.geometry,node.material,node,null)});
 }},renderBufferDirect(_camera,_scene,_geometry,_material,node){drawn.push(node);}};
 const direct=backend.renderBufferDirect,shadow=backend.shadowMap.render,guard=createVehicleShadowCulling({THREE:T,renderer:backend,scene:world,sun:light,enabled:!building,buildingEnabled:building});
 return {world,light,view,owner,backend,guard,direct,shadow,render(){world.updateMatrixWorld(true);backend.shadowMap.render([light],world,view);return drawn.slice()},get drawn(){return drawn.slice()}};
}
{
 const instance=new T.InstancedMesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial(),1);
 instance.setMatrixAt(0,new T.Matrix4().makeTranslation(40,1,20));instance.computeBoundingSphere();
 instance.setMatrixAt(0,new T.Matrix4().makeTranslation(0,1,-10));instance.instanceMatrix.needsUpdate=true;
 const f=reviewFixture(instance);f.render();assert(frustum.containsPoint(new T.Vector3(0,1,-10)));assert.equal(f.submissions,1,'unknown instanced bounds cannot reject a newly visible instance');assert.equal(f.guard.stats.unsupported,1);f.guard.dispose();
}
{
 const instance=new T.InstancedMesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial(),1);instance.setMatrixAt(0,new T.Matrix4().makeTranslation(40,1,20));instance.computeBoundingSphere();
 const f=reviewFixture(instance,{kind:'building'});f.render();assert.equal(f.submissions,1,'fallback building InstancedMesh always fails open');assert.equal(f.guard.stats.unsupported,1);f.guard.dispose();
}
{
 // A scale-independent shear bound is essential: all column cross-products
 // are below 1e-12 here, but their relative shear is substantial. The old
 // epsilon shortcut rejected this valid nonsingular mesh with 26 visible vertices.
 const shape=new T.Mesh(new T.SphereGeometry(1e7,64,32),new T.MeshStandardMaterial());shape.matrixAutoUpdate=false;
 shape.matrix.set(1e-7,1e-7,1e-7,10.36,1e-7,1.2e-7,1e-7,1,1e-7,1e-7,1.2e-7,-10,0,0,0,1);
 const f=reviewFixture(shape),positions=shape.geometry.attributes.position,point=new T.Vector3();let inside=0;
 for(let i=0;i<positions.count;i++)if(frustum.containsPoint(point.fromBufferAttribute(positions,i).applyMatrix4(shape.matrixWorld)))inside++;
 assert(inside>0);assert(shape.matrixWorld.determinant()>0);f.render();assert.equal(f.submissions,1,'small nonsingular shear cannot undersize the world sphere');f.guard.dispose();
}
for(const manualTarget of ['renderer','light']){
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape);f.render();assert.equal(f.mapHasCaster,false,'first automatic map was pruned');
 (manualTarget==='renderer'?f.backend.shadowMap:f.light.shadow).autoUpdate=false;
 f.render();assert.equal(f.mapHasCaster,true,'switch to manual mode regenerates a complete map once');assert.equal(f.passes,2);
 f.render();assert.equal(f.passes,2,'completed manual map is not regenerated repeatedly');f.guard.dispose();
}
{
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape);f.render();assert.equal(f.mapHasCaster,false,'automatic pass created a pruned sun map');
 f.backend.shadowMap.autoUpdate=false;f.light.shadow.autoUpdate=false;
 const other=new T.DirectionalLight();other.castShadow=true;other.shadow.autoUpdate=false;other.shadow.needsUpdate=true;
 f.render([other]);assert.equal(other.shadow.needsUpdate,false,'other light completed');assert.equal(f.backend.shadowMap.needsUpdate,true,'other-only pass cannot consume the pending sun restore');assert.equal(f.light.shadow.needsUpdate,true);
 f.render();assert.equal(f.mapHasCaster,true,'pending restore clears only after the full sun pass');assert.equal(f.backend.shadowMap.needsUpdate,false);assert.equal(f.light.shadow.needsUpdate,false);f.guard.dispose();
}
for(const action of ['disable','dispose']){
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape);f.render();assert.equal(f.mapHasCaster,false);
 f.backend.shadowMap.autoUpdate=false;f.light.shadow.autoUpdate=false;
 if(action==='disable')f.guard.setEnabled(false);else f.guard.dispose();
 assert.equal(f.backend.shadowMap.needsUpdate,true);assert.equal(f.light.shadow.needsUpdate,true);
 f.render();assert.equal(f.mapHasCaster,true,action+' cannot leave a pruned map cached');f.guard.dispose();
}
{
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape,{kind:'building'});f.render();assert.equal(f.mapHasCaster,false,'automatic building pass created a pruned sun map');
 f.backend.shadowMap.autoUpdate=false;f.light.shadow.autoUpdate=false;f.guard.setBuildingEnabled(false);
 assert.equal(f.backend.shadowMap.needsUpdate,true);assert.equal(f.light.shadow.needsUpdate,true);
 f.render();assert.equal(f.mapHasCaster,true,'building opt-out cannot leave a pruned map cached');f.guard.dispose();
}
{
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape,{kind:'building'});f.render();assert.equal(f.submissions,0);
 f.light.intensity=.12;f.view.lookAt(shape.position);f.view.updateMatrixWorld(true);f.render();
 assert.equal(f.submissions,1,'night intensity and the current camera still retain a newly relevant building caster');f.guard.dispose();
}
{
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=traversalFixture(shape);assert.deepEqual(f.render(),[],'far building is culled through actual traversal gates');
 f.owner.visible=false;assert.deepEqual(f.render(),[],'hidden hierarchy never reaches the draw hook');assert.equal(f.guard.stats.tested,0);
 f.owner.visible=true;shape.layers.set(3);assert.deepEqual(f.render(),[],'shadow-camera layer mismatch never reaches the draw hook');assert.equal(f.guard.stats.tested,0);
 f.light.shadow.camera.layers.enable(3);assert.deepEqual(f.render(),[],'matching layer restores conservative far culling');assert.equal(f.guard.stats.buildingCulled,1);
 shape.removeFromParent();f.world.add(shape);assert.deepEqual(f.render(),[shape],'detached mesh without an audited owner fails open');assert.equal(f.guard.stats.tested,0);
 f.owner.add(shape);delete f.owner.userData.instance;assert.deepEqual(f.render(),[shape],'owner metadata mutation fails open');
 f.owner.userData.instance={assetId:'traversal_building'};shape.position.set(0,1,-10);assert.deepEqual(f.render(),[shape],'reattached visible building draws');
 shape.position.set(40,1,20);shape.scale.set(80,40,80);assert.deepEqual(f.render(),[shape],'large mutated bounds that reach the view draw');
 f.guard.dispose();assert.equal(f.backend.renderBufferDirect,f.direct);assert.equal(f.backend.shadowMap.render,f.shadow);
 const rebuilt=createVehicleShadowCulling({THREE:T,renderer:f.backend,scene:f.world,sun:f.light,enabled:false,buildingEnabled:true});shape.scale.set(1,1,1);assert.deepEqual(f.render(),[],'rebuilt guard resumes conservative culling');rebuilt.dispose();
}
{
 // The game translates sun and target with the focus and changes intensity at
 // day/evening/night. Exercise all three values, several focus/camera poses and
 // differently transformed bounds without assuming a particular cull count.
 const shape=new T.Mesh(new T.BoxGeometry(3,7,5),new T.MeshStandardMaterial());shape.position.set(40,3.5,20);shape.rotation.set(.11,.43,-.07);shape.scale.set(1.2,.8,1.7);
 const f=traversalFixture(shape),states=[[1.7,0,0,0,0,1.7,0,0,1.7,-10],[.45,80,0,-60,80,2,-50,40,2,20],[.12,-120,0,90,-120,3,80,-80,2,70]];
 let culled=0,kept=0;
 for(const [intensity,fx,fy,fz,cx,cy,cz,tx,ty,tz] of states){
  f.light.intensity=intensity;f.light.position.set(fx-75,fy+130,fz+90);f.light.target.position.set(fx,fy,fz);f.view.position.set(cx,cy,cz);f.view.lookAt(tx,ty,tz);f.view.updateMatrixWorld(true);
  const draw=f.render();if(draw.length)kept++;else culled++;
  assert.equal(shape.visible,true);assert.equal(shape.castShadow,true);assert.equal(shape.layers.mask,1);
  f.view.lookAt(shape.getWorldPosition(new T.Vector3()));f.view.updateMatrixWorld(true);assert.deepEqual(f.render(),[shape],`visible transformed bounds draw at intensity ${intensity}`);
 }
 assert(culled>0&&kept>0,'multi-view cycle exercises both proven rejection and retained draws');f.guard.dispose();
}
{
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape);f.render();assert.equal(f.submissions,0);
 f.view.lookAt(shape.position);f.view.updateMatrixWorld(true);f.render();assert.equal(f.submissions,1,'current rendered camera matrix, including render-only camera kicks, owns receiver visibility');f.guard.dispose();
}
for(const variant of ['perspective','parent','scaled','view-offset','manual-matrix','manual-world-matrix']){
 const shape=new T.Mesh(new T.BoxGeometry(2,2,4),new T.MeshStandardMaterial());shape.position.set(40,1,20);
 const f=reviewFixture(shape);
 if(variant==='perspective')f.light.shadow.camera=new T.PerspectiveCamera();
 if(variant==='parent')new T.Group().add(f.light.shadow.camera);
 if(variant==='scaled')f.light.shadow.camera.scale.x=2;
 if(variant==='view-offset')f.light.shadow.camera.view={enabled:true};
 if(variant==='manual-matrix')f.light.shadow.camera.matrixAutoUpdate=false;
 if(variant==='manual-world-matrix')f.light.shadow.camera.matrixWorldAutoUpdate=false;
 f.render();assert.equal(f.submissions,1,variant+' shadow camera is outside the proven directional-map contract');f.guard.dispose();
}
{
 const geometry=new T.BoxGeometry(2,2,4),batch=new T.BatchedMesh(1,geometry.attributes.position.count,geometry.index.count,new T.MeshStandardMaterial());
 const geometryId=batch.addGeometry(geometry),instance=batch.addInstance(geometryId);batch.setMatrixAt(instance,new T.Matrix4().makeTranslation(40,1,20));batch.computeBoundingBox();batch.computeBoundingSphere();stampBatchedShadowBounds(batch);
 const f=reviewFixture(batch);f.render();assert.equal(f.submissions,1,'unowned BatchedMesh is not assumed to maintain aggregate bounds');
 batch.userData.vehicleRenderBatch=true;f.render();assert.equal(f.submissions,1,'known owner/default callback permits conservative cull');
 batch.onBeforeRender=()=>{};f.render();assert.equal(f.submissions,2,'custom callback reached through onBeforeShadow bypasses geometry inference');
 batch.onBeforeRender=T.BatchedMesh.prototype.onBeforeRender;batch.userData.vehicleRenderBatch=false;batch.userData.staticRenderBatch=true;f.owner.userData.vehicleFleetId=null;f.guard.setEnabled(false);f.guard.setBuildingEnabled(true);f.render();assert.equal(f.submissions,2,'audited static building batch bounds use the same conservative proof');
 batch.setMatrixAt(instance,new T.Matrix4().makeTranslation(0,1,-10));f.render();assert.equal(f.submissions,3,'matrix mutation after the aggregate-bounds stamp fails open');assert.equal(f.guard.stats.unsupported,1);
 batch.computeBoundingBox();batch.computeBoundingSphere();stampBatchedShadowBounds(batch);f.render();assert.equal(f.submissions,4,'restamped visible batch renders from its current bounds');f.guard.dispose();
}
{
 const farGeometry=new T.BoxGeometry(2,2,4),nearGeometry=new T.BoxGeometry(2,2,4).translate(-40,0,-30),batch=new T.BatchedMesh(1,farGeometry.attributes.position.count+nearGeometry.attributes.position.count,farGeometry.index.count+nearGeometry.index.count,new T.MeshStandardMaterial());
 const farId=batch.addGeometry(farGeometry),nearId=batch.addGeometry(nearGeometry),instance=batch.addInstance(farId);batch.setMatrixAt(instance,new T.Matrix4().makeTranslation(40,1,20));batch.computeBoundingBox();batch.computeBoundingSphere();stampBatchedShadowBounds(batch);batch.userData.vehicleRenderBatch=true;
 const f=reviewFixture(batch);f.render();assert.equal(f.submissions,0,'stamped far geometry is conservatively culled');assert.equal(batchedShadowBoundsCurrent(batch),true);
 batch.setGeometryIdAt(instance,nearId);assert.equal(batchedShadowBoundsCurrent(batch),false,'geometry binding mutation invalidates aggregate bounds without a buffer-version signal');f.render();assert.equal(f.submissions,1,'mutated geometry binding fails open before any restamp');f.guard.dispose();
}
{
 const farGeometry=new T.BoxGeometry(2,2,4),nearGeometry=new T.BoxGeometry(2,2,4).translate(-40,0,-30),source=new T.BatchedMesh(1,farGeometry.attributes.position.count+nearGeometry.attributes.position.count,farGeometry.index.count+nearGeometry.index.count,new T.MeshStandardMaterial());
 const farId=source.addGeometry(farGeometry),nearId=source.addGeometry(nearGeometry),instance=source.addInstance(farId);source.setMatrixAt(instance,new T.Matrix4().makeTranslation(40,1,20));source.computeBoundingBox();source.computeBoundingSphere();stampBatchedShadowBounds(source);
 const copy=new T.BatchedMesh(1,farGeometry.attributes.position.count+nearGeometry.attributes.position.count,farGeometry.index.count+nearGeometry.index.count,new T.MeshStandardMaterial());copy.copy(source);copy.computeBoundingBox();copy.computeBoundingSphere();stampBatchedShadowBounds(copy);assert.equal(batchedShadowBoundsCurrent(copy),true);
 copy.setGeometryIdAt(instance,nearId);assert.equal(batchedShadowBoundsCurrent(copy),false,'copied userData cannot impersonate a mutation guard installed on another object');
}
{
 // Three's aggregate sphere uses max-column scale for each instance matrix;
 // even a freshly recomputed sphere can underbound a locally sheared batch.
 const geometry=new T.SphereGeometry(1e7,64,32),batch=new T.BatchedMesh(1,geometry.attributes.position.count,geometry.index.count,new T.MeshStandardMaterial());
 const geometryId=batch.addGeometry(geometry),instance=batch.addInstance(geometryId),local=new T.Matrix4();
 local.set(1e-7,1e-7,1e-7,10.36,1e-7,1.2e-7,1e-7,1,1e-7,1e-7,1.2e-7,-10,0,0,0,1);
 batch.setMatrixAt(instance,local);batch.computeBoundingBox();batch.computeBoundingSphere();stampBatchedShadowBounds(batch);batch.userData.vehicleRenderBatch=true;
 const f=reviewFixture(batch),positions=geometry.attributes.position,point=new T.Vector3();let inside=0;
 batch.getMatrixAt(instance,local);
 for(let i=0;i<positions.count;i++)if(frustum.containsPoint(point.fromBufferAttribute(positions,i).applyMatrix4(local).applyMatrix4(batch.matrixWorld)))inside++;
 assert(inside>0);f.render();assert.equal(f.submissions,1,'fresh aggregate batch sphere cannot assume per-instance matrices are shear-free');f.guard.dispose();
}
console.log(JSON.stringify({passed:true,sweptVolumePointChecks:checks,checks:['default_and_rollback_query','multiple_building_bounds','camera_and_day_evening_night_states','hidden_layer_detach_owner_mutation','geometry_and_transform_mutation','manual_shadow_map_restore','batched_and_instanced_fail_open','dispose_and_rebuild'],scope:'CPU geometry and actual THREE matrices; no GPU/FPS measurement'}));
