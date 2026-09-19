// Read-only production audit: experimental matrix policies exist ONLY in this test.
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createExplorationDecor} from './exploration_decor.mjs';
import {EXPLORATION_DECOR_TYPES} from './exploration_decor_plan.mjs';
const vendor=pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js').href;
registerHooks({resolve(s,c,next){return next(s==='three'?vendor:s,c);}});
const T=await import(vendor);
const {RoundedBoxGeometry}=await import('../../../tools/vehicle_fleet_qa/RoundedBoxGeometry.mjs');
const plan={objects:Object.keys(EXPLORATION_DECOR_TYPES).map((kind,i)=>({id:kind,kind,x:(i%7)*256,y:(i%3)*.2,z:Math.floor(i/7)*256,yaw:i*.13,scale:1+i*.01,sizeClass:'adult',variant:i})),colliders:[],mapFeatures:[],stats:{}};

function fixture(){
 const decor=createExplorationDecor({THREE:T,RoundedBoxGeometry,plan}),scene=new T.Scene(),parent=new T.Group();
 scene.add(parent);parent.add(decor.object);scene.updateMatrixWorld(true);
 const leaves=decor.object.children.flatMap(chunk=>chunk.children);
 assert(leaves.every(n=>n.isInstancedMesh&&n.userData.explorationDecor&&n.userData.explorationShape&&!n.children.length));
 const snapshots=leaves.map(n=>({matrix:n.instanceMatrix.array.slice(),color:n.instanceColor.array.slice(),ids:[...n.userData.objectIds],bounds:n.boundingBox.clone(),material:n.material}));
 return {decor,scene,parent,leaves,snapshots};
}

// Explicitly owned immutable leaves only. Chunk and root transforms remain live.
// With world freezing the caller MUST call prepare before render/spatial queries.
function candidate(f,world=false){
 const states=f.leaves.map(node=>({node,local:node.matrixAutoUpdate,world:node.matrixWorldAutoUpdate}));
 const savedRoot=f.decor.object.matrixWorld.clone();let disposed=false,refits=0;
 for(const s of states){s.node.matrixAutoUpdate=false;if(world)s.node.matrixWorldAutoUpdate=false;}
 return {get refits(){return refits;},prepare(){
  if(disposed||!world)return;
  f.decor.object.updateWorldMatrix(true,false);
  if(savedRoot.equals(f.decor.object.matrixWorld))return;
  for(const s of states)s.node.matrixWorldAutoUpdate=true;
  try{f.decor.object.updateWorldMatrix(false,true);savedRoot.copy(f.decor.object.matrixWorld);refits++;}
  finally{for(const s of states)s.node.matrixWorldAutoUpdate=false;}
 },dispose(){if(disposed)return;disposed=true;for(const s of states){s.node.matrixAutoUpdate=s.local;s.node.matrixWorldAutoUpdate=s.world;}}};
}

function counts(f,policy){
 const selected=new Set(f.leaves),out={leafCompose:0,allCompose:0,leafVisits:0,allVisits:0,allMultiply:0};
 const compose=T.Object3D.prototype.updateMatrix,visit=T.Object3D.prototype.updateMatrixWorld,multiply=T.Matrix4.prototype.multiplyMatrices;
 T.Object3D.prototype.updateMatrix=function(...a){out.allCompose++;if(selected.has(this))out.leafCompose++;return compose.apply(this,a);};
 T.Object3D.prototype.updateMatrixWorld=function(...a){out.allVisits++;if(selected.has(this))out.leafVisits++;return visit.apply(this,a);};
 T.Matrix4.prototype.multiplyMatrices=function(...a){out.allMultiply++;return multiply.apply(this,a);};
 try{policy?.prepare();f.scene.updateMatrixWorld();}finally{T.Object3D.prototype.updateMatrix=compose;T.Object3D.prototype.updateMatrixWorld=visit;T.Matrix4.prototype.multiplyMatrices=multiply;}
 return out;
}

const baseline=fixture(),local=fixture(),world=fixture(),localPolicy=candidate(local),worldPolicy=candidate(world,true);
const countReport={leaves:baseline.leaves.length,chunks:baseline.decor.object.children.length,baseline:counts(baseline),localOnly:counts(local,localPolicy),localAndWorldWithRootGuard:counts(world,worldPolicy)};
assert.equal(countReport.baseline.leafCompose,baseline.leaves.length);
assert.equal(countReport.localOnly.leafCompose,0);assert.equal(countReport.localAndWorldWithRootGuard.leafCompose,0);
assert.equal(countReport.localOnly.allMultiply,countReport.baseline.allMultiply,'Inherited world updates preserved by local-only');
assert.equal(countReport.localAndWorldWithRootGuard.allMultiply,countReport.baseline.allMultiply-baseline.leaves.length+2,'Root guard adds parent/root products');
assert.equal(countReport.localAndWorldWithRootGuard.leafVisits,baseline.leaves.length,'No traversal shortcut');

function parity(){
 for(const [f,policy] of [[baseline,null],[local,localPolicy],[world,worldPolicy]]){policy?.prepare();f.scene.updateMatrixWorld();}
 for(let i=0;i<baseline.leaves.length;i++)for(const f of [local,world]){
  const actual=f.leaves[i],expected=baseline.leaves[i],snapshot=f.snapshots[i];
  assert.deepEqual(actual.matrixWorld.elements,expected.matrixWorld.elements);
  assert.deepEqual(actual.geometry.attributes.position.array,expected.geometry.attributes.position.array);
  assert.deepEqual(actual.instanceMatrix.array,snapshot.matrix);assert.deepEqual(actual.instanceColor.array,snapshot.color);
  assert.deepEqual(actual.userData.objectIds,snapshot.ids);assert.deepEqual(actual.boundingBox,snapshot.bounds);assert.equal(actual.material,snapshot.material);
  assert.deepEqual(actual.boundingBox.clone().applyMatrix4(actual.matrixWorld),expected.boundingBox.clone().applyMatrix4(expected.matrixWorld));
 }
 for(const f of [local,world]){assert.deepEqual(f.decor.stats,baseline.decor.stats);assert.deepEqual(f.decor.object.children.map(n=>[n.visible,n.userData.detailLevel]),baseline.decor.object.children.map(n=>[n.visible,n.userData.detailLevel]));}
}
parity();
for(const focus of [{x:0,z:0},{x:0,z:-73},{x:0,z:-189},{x:1e6,z:1e6},{x:0,z:0}]){
 for(const f of [baseline,local,world])f.decor.update({focus,maxDistance:420});parity();
}
// Root and ancestor changes are handled before rendering or raycasting.
for(const f of [baseline,local,world]){f.parent.position.set(4,2,-7);f.parent.rotation.y=.25;f.parent.scale.set(1.1,1.2,.9);}
parity();assert.equal(worldPolicy.refits,1);
for(const f of [baseline,local,world]){f.decor.object.position.set(-2,4,3);f.decor.object.rotation.y=-.4;}
parity();assert.equal(worldPolicy.refits,2);
for(const f of [baseline,local,world]){const parent=new T.Group();parent.position.set(-30,3,70);f.scene.add(parent);parent.add(f.decor.object);}
parity();assert.equal(worldPolicy.refits,3);
// Verify world-space ray hits on actual meshes after reparent/refit.
const hitSignature=f=>{
 const mesh=f.leaves[0],point=mesh.boundingBox.getCenter(new T.Vector3()).applyMatrix4(mesh.matrixWorld),ray=new T.Raycaster(point.clone().add(new T.Vector3(0,200,0)),new T.Vector3(0,-1,0));
 return ray.intersectObject(mesh,false).map(hit=>({distance:hit.distance,point:hit.point.toArray(),instanceId:hit.instanceId}));
};
assert(hitSignature(baseline).length>0,'Ray parity must include real intersections');
assert.deepEqual(hitSignature(local),hitSignature(baseline));assert.deepEqual(hitSignature(world),hitSignature(baseline));
localPolicy.dispose();worldPolicy.dispose();localPolicy.dispose();worldPolicy.dispose();
for(const f of [local,world])assert(f.leaves.every(n=>n.matrixAutoUpdate&&n.matrixWorldAutoUpdate));
parity();for(const f of [baseline,local,world])f.decor.dispose();
console.log('PASS actual createExplorationDecor all-types fixture: exact matrices, LOD geometry, hidden/show, instance arrays, IDs, material, bounds, ancestor/root move, reparent, ray hits, restoration. Production unchanged.');
console.log(JSON.stringify(countReport));
