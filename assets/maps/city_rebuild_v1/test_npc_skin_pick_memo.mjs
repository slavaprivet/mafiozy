import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {createNpcSkinPickMemo} from './npc_skin_pick_memo.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const own=(o,k)=>Object.getOwnPropertyDescriptor(o,k),signature=hits=>hits.map(h=>({object:h.object.uuid,distance:h.distance,point:h.point.toArray(),faceIndex:h.faceIndex,materialIndex:h.face?.materialIndex,faceNormal:h.face?.normal.toArray(),normal:h.normal?.toArray(),uv:h.uv?.toArray(),uv1:h.uv1?.toArray(),barycoord:h.barycoord?.toArray(),instanceId:h.instanceId}));
const ray=()=>new T.Raycaster(new T.Vector3(.13,.1,4),new T.Vector3(0,0,-1),0,10);
function fixture(){
 const root=new T.Group(),geometry=new T.SphereGeometry(1,16,12),material=new T.MeshBasicMaterial({side:T.DoubleSide}),mesh=new T.SkinnedMesh(geometry,material),n=geometry.attributes.position.count;
 const indices=new Uint16Array(n*4),weights=new Float32Array(n*4);for(let i=0;i<n;i++){indices[i*4+1]=1;weights[i*4]=weights[i*4+1]=.5;}
 geometry.setAttribute('skinIndex',new T.Uint16BufferAttribute(indices,4));geometry.setAttribute('skinWeight',new T.Float32BufferAttribute(weights,4));
 const base=new T.Bone(),tip=new T.Bone();base.add(tip);tip.position.y=.3;mesh.add(base);root.add(mesh);mesh.bind(new T.Skeleton([base,tip]));
 const helper=createNpcSkinPickMemo({THREE:T}),roots=[root];
 const pose=value=>{tip.rotation.z=value;root.updateMatrixWorld(true);mesh.skeleton.update();mesh.computeBoundingSphere();mesh.computeBoundingBox();};pose(0);
 return{root,roots,mesh,geometry,material,tip,helper,pose,dispose(){helper.dispose();geometry.dispose();material.dispose();}};
}
let passed=0;
function check(name,run){run();passed++;}
function activate(f){f.helper.setEnabled(true);f.helper.syncNpcRoots(f.roots);}
function parity(f,r=ray()){const expected=signature(r.intersectObjects(f.roots,true)),before=f.helper.stats();assert.deepEqual(signature(f.helper.intersect(r,f.roots)),expected);assert.equal(own(f.mesh,'getVertexPosition'),undefined);assert(f.helper.stats().cachedMeshes>before.cachedMeshes);}
check('default OFF has no root reads/hooks; set OFF removes hooks and preserves native',()=>{
 const f=fixture(),input={[Symbol.iterator](){throw Error('OFF must not iterate roots')}};f.helper.syncNpcRoots(input);assert.equal(own(f.mesh,'_computeIntersections'),undefined);
 assert.deepEqual(signature(f.helper.intersect(ray(),f.roots)),signature(ray().intersectObjects(f.roots,true)));activate(f);parity(f);f.helper.setEnabled(false);assert.equal(own(f.mesh,'_computeIntersections'),undefined);assert.equal(f.helper.stats().trackedMeshes,0);f.dispose();
});
check('only observed NPC skins, outside query native, no frame cache across posed calls',()=>{
 const f=fixture(),other=fixture();activate(f);assert.equal(own(other.mesh,'_computeIntersections'),undefined);
 const before=f.helper.stats().cachedMeshes;ray().intersectObjects(f.roots,true);assert.equal(f.helper.stats().cachedMeshes,before);parity(f);const a=signature(f.helper.intersect(ray(),f.roots));f.pose(.7);parity(f);assert.notDeepEqual(signature(f.helper.intersect(ray(),f.roots)),a);other.dispose();f.dispose();
});
check('root remove/replacement, method ownership, exact descriptors and dispose idempotence',()=>{
 const f=fixture();Object.defineProperty(f.mesh,'_computeIntersections',{value:T.Mesh.prototype._computeIntersections,writable:false,configurable:true,enumerable:false});const original=own(f.mesh,'_computeIntersections');activate(f);f.helper.syncNpcRoots([]);assert.deepEqual(own(f.mesh,'_computeIntersections'),original);activate(f);
 const foreign=function(...args){return T.Mesh.prototype._computeIntersections.apply(this,args)};Object.defineProperty(f.mesh,'_computeIntersections',{value:foreign,writable:true,configurable:true});f.helper.syncNpcRoots(f.roots);assert.equal(f.mesh._computeIntersections,foreign);assert.equal(f.helper.stats().trackedMeshes,0);f.dispose();assert.equal(f.mesh._computeIntersections,foreign);f.helper.dispose();
});
check('fresh guards for custom skin, vertices, bounds and attribute accessors',()=>{
 for(const key of ['raycast','getVertexPosition','applyBoneTransform','computeBoundingSphere']){const f=fixture();activate(f);const original=f.mesh[key];f.mesh[key]=function(...args){return original.apply(this,args)};const expected=signature(ray().intersectObjects(f.roots,true));assert.deepEqual(signature(f.helper.intersect(ray(),f.roots)),expected);assert.equal(f.helper.stats().cachedMeshes,0);delete f.mesh[key];parity(f);f.dispose();}
 for(const key of ['getX','getComponent']){const f=fixture();activate(f);const a=f.geometry.attributes.position,original=a[key];a[key]=function(...args){return original.apply(this,args)};f.helper.intersect(ray(),f.roots);assert.equal(f.helper.stats().cachedMeshes,0);delete a[key];parity(f);f.dispose();}
});
check('exceptions restore temporary getter and active query while persistent hook remains owned',()=>{
 const f=fixture();activate(f);const hook=f.mesh._computeIntersections,indices=f.geometry.attributes.skinIndex,v=f.geometry.index.getX(15),old=indices.getX(v);indices.setX(v,65535);
 assert.throws(()=>f.helper.intersect(ray(),f.roots));assert.equal(own(f.mesh,'getVertexPosition'),undefined);assert.equal(f.mesh._computeIntersections,hook);indices.setX(v,old);
 const count=f.helper.stats().cachedMeshes;ray().intersectObjects(f.roots,true);assert.equal(f.helper.stats().cachedMeshes,count);parity(f);f.dispose();assert.equal(own(f.mesh,'_computeIntersections'),undefined);
});
check('nested helper calls inside native intersection output restore scopes and descriptors',()=>{
 const f=fixture();activate(f);const r=ray(),native=r.intersectObjects;let entered=false;
 r.intersectObjects=function(roots){const hits=[];hits.push=function(...values){if(!entered){entered=true;const vertex=f.mesh.getVertexPosition;const nested=f.helper.intersect(ray(),f.roots);assert(nested.length);assert.equal(f.mesh.getVertexPosition,vertex);}return Array.prototype.push.apply(this,values);};return native.call(this,roots,true,hits);};
 const actual=f.helper.intersect(r,f.roots);assert(actual.length);assert(f.helper.stats().nestedFallbacks>0);assert.equal(own(f.mesh,'getVertexPosition'),undefined);assert.equal(f.helper.stats().trackedMeshes,1);parity(f);f.dispose();
});
check('nested exception and disposal during a query do not leave temporary getters',()=>{
 for(const mode of ['throw','dispose']){const f=fixture();activate(f);const r=ray(),native=r.intersectObjects;let entered=false;
  r.intersectObjects=function(roots){const hits=[];hits.push=function(...values){if(!entered){entered=true;if(mode==='dispose')f.helper.dispose();else{const nested=ray();nested.intersectObjects=()=>{throw Error('nested failure')};f.helper.intersect(nested,f.roots);}}return Array.prototype.push.apply(this,values);};return native.call(this,roots,true,hits);};
  if(mode==='throw')assert.throws(()=>f.helper.intersect(r,f.roots),/nested failure/);else assert(f.helper.intersect(r,f.roots).length);
  assert.equal(own(f.mesh,'getVertexPosition'),undefined);f.dispose();assert.equal(own(f.mesh,'_computeIntersections'),undefined);
 }
});
check('unsupported revision, non-indexed and readonly getter use native fallback',()=>{
 const f=fixture(),other=createNpcSkinPickMemo({THREE:{...T,REVISION:'181'}});assert.equal(other.setEnabled(true),false);other.syncNpcRoots(f.roots);assert.equal(own(f.mesh,'_computeIntersections'),undefined);other.dispose();
 Object.defineProperty(f.mesh,'getVertexPosition',{value:T.SkinnedMesh.prototype.getVertexPosition,writable:false,configurable:false});activate(f);assert.equal(f.helper.stats().trackedMeshes,0);f.dispose();
 const g=fixture(),original=g.geometry;g.mesh.geometry=original.toNonIndexed();activate(g);assert.equal(g.helper.stats().trackedMeshes,0);g.mesh.geometry.dispose();g.dispose();
});

// Real source parity, independently loaded male AND female with articulated bones.
const sources=[],actualReports=[];
for(const asset of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
 const bytes=readFileSync(new URL('./hero_models/'+asset,import.meta.url)),root=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,skins=[],bones=new Map();root.traverse(n=>{if(n.isSkinnedMesh)skins.push(n);if(n.isBone)bones.set(n.name,n)});sources.push(root);
 const helper=createNpcSkinPickMemo({THREE:T}),rest=new Map([...bones.values()].map(b=>[b,b.quaternion.clone()]));helper.setEnabled(true);helper.syncNpcRoots([root]);assert.equal(helper.stats().trackedMeshes,skins.length);
 let cases=0;for(const pose of [0,.8,-.6]){for(const[b,q]of rest)b.quaternion.copy(q);bones.get('chest').rotation.z+=pose*.15;bones.get('upperarm_l').rotation.z+=pose*.35;bones.get('thigh_l').rotation.x+=pose*.3;root.updateMatrixWorld(true);for(const mesh of skins){mesh.skeleton.update();mesh.computeBoundingSphere();mesh.computeBoundingBox();}
  for(const name of ['chest','head','thigh_l','hand_l']){const p=bones.get(name).getWorldPosition(new T.Vector3()),r=new T.Raycaster(p.clone().add(new T.Vector3(0,0,5)),new T.Vector3(0,0,-1),0,10);const expected=r.intersectObjects([root],true);assert(expected.length);assert.deepEqual(signature(helper.intersect(r,[root])),signature(expected));cases++;}
 }
 actualReports.push({asset,cases,skins:skins.length,...helper.stats()});helper.dispose();assert(skins.every(mesh=>own(mesh,'_computeIntersections')===undefined&&own(mesh,'getVertexPosition')===undefined));
}
// Total workflow cost includes every syncNpcRoots traversal, not intersect alone.
function cloneSkin(source){const clone=source.clone(true),originals=[],copies=[];source.traverse(n=>originals.push(n));clone.traverse(n=>copies.push(n));const map=new Map(originals.map((n,i)=>[n,copies[i]]));for(let i=0;i<originals.length;i++)if(originals[i].isSkinnedMesh){copies[i].skeleton=originals[i].skeleton.clone();copies[i].skeleton.bones=originals[i].skeleton.bones.map(b=>map.get(b));copies[i].bindMatrix.copy(originals[i].bindMatrix);copies[i].bindMatrixInverse.copy(originals[i].bindMatrixInverse);}return clone;}
const roots=Array.from({length:10},(_,i)=>{const r=cloneSkin(sources[i%2]);r.position.x=i*5;r.updateMatrixWorld(true);r.traverse(n=>{if(n.isSkinnedMesh){n.skeleton.update();n.computeBoundingSphere();n.computeBoundingBox();}});return r;});
const chest=roots[0].getObjectByName('chest').getWorldPosition(new T.Vector3()),hitRay=new T.Raycaster(chest.clone().add(new T.Vector3(0,0,5)),new T.Vector3(0,0,-1),0,10),missRay=new T.Raycaster(chest.clone().add(new T.Vector3(0,10,5)),new T.Vector3(0,0,-1),0,10),helper=createNpcSkinPickMemo({THREE:T});
const timing=a=>{a.sort((x,y)=>x-y);return{p50Ms:+a[7].toFixed(4),p95Ms:+a[14].toFixed(4)};},totalWorkflow={};
for(const [name,r]of [['hit',hitRay],['miss',missRay]]){
 const samples={native:[],off:[],on:[]};
 for(const mode of ['native','off','on']){helper.setEnabled(mode==='on');helper.syncNpcRoots(roots);for(let i=0;i<20;i++){const start=performance.now();if(mode==='native')r.intersectObjects(roots,true);else{helper.syncNpcRoots(roots);helper.intersect(r,roots);}if(i>=4)samples[mode].push(performance.now()-start);} }
 totalWorkflow[name]=Object.fromEntries(Object.entries(samples).map(([mode,values])=>[mode,timing(values)]));
}
helper.dispose();for(const root of roots)root.traverse(n=>{if(n.isSkinnedMesh)assert.equal(own(n,'_computeIntersections'),undefined)});
const resources=new Set();for(const root of sources)root.traverse(n=>{if(n.geometry)resources.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])resources.add(m);});for(const resource of resources)resource.dispose();
console.log(JSON.stringify({passed,actualReports,totalWorkflow,benchmarkRoots:10,scope:'CPU only, whole sync+intersect measured; no live FPS assertion'}));
