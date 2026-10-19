// CPU experiment ONLY. No exported helper and no production integration.
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
assert.equal(T.REVISION,'180');
const skin=T.SkinnedMesh.prototype,meshProto=T.Mesh.prototype,active=new WeakMap();
const counts={requests:0,evaluations:0,cacheHits:0,scopes:0,fallbacks:0,nested:0};
const own=(o,k)=>Object.getOwnPropertyDescriptor(o,k);
function restore(o,k,descriptor){if(descriptor)Object.defineProperty(o,k,descriptor);else delete o[k];}
function setMethod(o,k,value){const d=own(o,k);Object.defineProperty(o,k,d?{...d,value}:{value,writable:true,configurable:true,enumerable:true});}
function replaceable(o,key){const d=own(o,key);return d?'value'in d&&(d.configurable||d.writable):Object.isExtensible(o);}
function suspend(mesh,run){
 const state=active.get(mesh);if(!state)return run();counts.nested++;
 restore(mesh,'getVertexPosition',state.descriptor);active.delete(mesh);
 try{return run();}finally{state.seen.fill(0);setMethod(mesh,'getVertexPosition',state.wrapper);active.set(mesh,state);}
}
function scope(mesh,run){
 if(active.has(mesh))return suspend(mesh,run);
 const count=mesh.geometry.attributes.position.count,descriptor=own(mesh,'getVertexPosition');
 const state={descriptor,seen:new Uint8Array(count),values:new Float64Array(count*3),wrapper:null};
 state.wrapper=function(index,target){
  counts.requests++;
  if(state.seen[index]){counts.cacheHits++;return target.fromArray(state.values,index*3);}
  counts.evaluations++;skin.getVertexPosition.call(this,index,target);
  target.toArray(state.values,index*3);state.seen[index]=1;return target;
 };
 setMethod(mesh,'getVertexPosition',state.wrapper);active.set(mesh,state);counts.scopes++;
 try{return run();}finally{active.delete(mesh);restore(mesh,'getVertexPosition',descriptor);}
}
function supported(mesh){
 if(Object.getPrototypeOf(mesh)!==skin||mesh.raycast!==skin.raycast||mesh.getVertexPosition!==skin.getVertexPosition||mesh.applyBoneTransform!==skin.applyBoneTransform||mesh._computeIntersections!==meshProto._computeIntersections||mesh.computeBoundingSphere!==skin.computeBoundingSphere)return false;
 if(!replaceable(mesh,'getVertexPosition')||!replaceable(mesh,'_computeIntersections'))return false;
 const g=mesh.geometry;if(!g.index||g.getAttribute!==T.BufferGeometry.prototype.getAttribute)return false;
 const attributes=[g.index,...Object.values(g.attributes),...Object.values(g.morphAttributes).flat()];
 if(attributes.some(a=>!a.isBufferAttribute||a.isInterleavedBufferAttribute||!['getX','getY','getZ','getW','getComponent'].every(k=>a[k]===T.BufferAttribute.prototype[k])))return false;
 // Reject material accessors which could mutate pose during the triangle loop.
 for(const material of Array.isArray(mesh.material)?mesh.material:[mesh.material]){const d=material&&own(material,'side');if(!d||!('value'in d))return false;}
 return true;
}
function memoRaycast(mesh,ray,hits){
 if(active.has(mesh))return suspend(mesh,()=>memoRaycast(mesh,ray,hits));
 if(!supported(mesh)){counts.fallbacks++;return mesh.raycast(ray,hits);}
 const descriptor=own(mesh,'_computeIntersections');
 setMethod(mesh,'_computeIntersections',function(...args){return scope(this,()=>meshProto._computeIntersections.apply(this,args));});
 try{return skin.raycast.call(mesh,ray,hits);}finally{restore(mesh,'_computeIntersections',descriptor);}
}

function fixture(segments=36){
 const geometry=new T.SphereGeometry(1,segments,Math.floor(segments*.65)),position=geometry.attributes.position;
 const ids=new Uint16Array(position.count*4),weights=new Float32Array(position.count*4),morph=new Float32Array(position.count*3);
 for(let i=0;i<position.count;i++){
  const y=position.getY(i),w=Math.max(0,Math.min(1,(y+1)/2));ids[i*4+1]=1;ids[i*4+2]=2;
  weights[i*4]=(1-w)*.7;weights[i*4+1]=w*.7;weights[i*4+2]=.3;
  morph[i*3]=position.getX(i)*.13;morph[i*3+1]=y*.07;morph[i*3+2]=Math.sin(y*2)*.04;
 }
 geometry.setAttribute('skinIndex',new T.Uint16BufferAttribute(ids,4));geometry.setAttribute('skinWeight',new T.Float32BufferAttribute(weights,4));
 geometry.morphAttributes.position=[new T.Float32BufferAttribute(morph,3)];geometry.morphTargetsRelative=true;
 geometry.setAttribute('uv1',geometry.attributes.uv.clone());
 const material=new T.MeshStandardMaterial({side:T.DoubleSide}),mesh=new T.SkinnedMesh(geometry,material);
 const base=new T.Bone(),middle=new T.Bone(),tip=new T.Bone();base.add(middle);middle.add(tip);middle.position.y=.2;tip.position.y=.4;mesh.add(base);
 mesh.bind(new T.Skeleton([base,middle,tip]));mesh.updateMorphTargets();
 function pose(step){middle.rotation.z=step*.31;tip.rotation.x=step*.21;base.rotation.y=step*.07;mesh.morphTargetInfluences[0]=step*.33;mesh.updateMatrixWorld(true);mesh.skeleton.update();mesh.computeBoundingSphere();mesh.computeBoundingBox();}
 pose(0);return{mesh,geometry,material,bones:[base,middle,tip],pose,dispose(){geometry.dispose();material.dispose();}};
}
const signature=hits=>hits.map(h=>({distance:h.distance,point:h.point.toArray(),faceIndex:h.faceIndex,face:{a:h.face.a,b:h.face.b,c:h.face.c,normal:h.face.normal.toArray(),materialIndex:h.face.materialIndex},normal:h.normal?.toArray(),uv:h.uv?.toArray(),uv1:h.uv1?.toArray(),barycoord:h.barycoord?.toArray(),object:h.object.uuid}));
const ray=(x=0,y=0,near=0,far=20,z=4)=>new T.Raycaster(new T.Vector3(x,y,z),new T.Vector3(0,0,z>0?-1:1),near,far);
let assertions=0,hitCases=0;
function parity(mesh,r){const beforeVertex=own(mesh,'getVertexPosition'),beforeCompute=own(mesh,'_computeIntersections'),a=[],b=[];mesh.raycast(r,a);memoRaycast(mesh,r,b);assert.deepEqual(signature(b),signature(a));assert.deepEqual(own(mesh,'getVertexPosition'),beforeVertex);assert.deepEqual(own(mesh,'_computeIntersections'),beforeCompute);if(a.length)hitCases++;assertions++;return a;}
const f=fixture();
for(const step of [0,1,-.6,1.7]){
 f.pose(step);
 for(const side of [T.FrontSide,T.BackSide,T.DoubleSide]){f.material.side=side;for(const r of [ray(),ray(.23,.17),ray(-.42,-.19),ray(0,0,3.5,4.4),ray(0,0,0,2),ray(0,0,5,10),ray(4,4),ray(.2,.1,0,20,-4)])parity(f.mesh,r);}
}
assert(hitCases>30,'fixture must contain actual triangle hits, not just parity of empty lists');
// Absolute morph targets preserve the native morph-then-skin calculation too.
const morph=f.geometry.morphAttributes.position[0],position=f.geometry.attributes.position;
for(let i=0;i<morph.count;i++)morph.setXYZ(i,morph.getX(i)+position.getX(i),morph.getY(i)+position.getY(i),morph.getZ(i)+position.getZ(i));
f.geometry.morphTargetsRelative=false;f.pose(.8);parity(f.mesh,ray(.13,.1));
// Material groups and drawRange are interpreted only by the canonical loop.
const extra=new T.MeshBasicMaterial({side:T.BackSide}),indexCount=f.geometry.index.count,split=Math.floor(indexCount/6)*3;
f.geometry.clearGroups();f.geometry.addGroup(0,split,0);f.geometry.addGroup(split,indexCount-split,1);f.mesh.material=[f.material,extra];
for(const start of [0,split]){f.geometry.setDrawRange(start,split);parity(f.mesh,ray(.21,.14));}
f.geometry.setDrawRange(0,Infinity);f.mesh.material=f.material;extra.dispose();
// Cold bounds: both paths independently compute native bounds before memo setup.
f.mesh.boundingSphere=null;f.mesh.boundingBox=null;const coldNative=[];f.mesh.raycast(ray(.1,.1),coldNative);
f.mesh.boundingSphere=null;f.mesh.boundingBox=null;const coldMemo=[];memoRaycast(f.mesh,ray(.1,.1),coldMemo);assert.deepEqual(signature(coldMemo),signature(coldNative));assertions++;
// Fresh state between queries: move bones/morphs and the object transform.
const first=parity(f.mesh,ray(.13,.11));f.pose(-1.1);f.mesh.position.x=.2;f.mesh.scale.set(1.1,.8,1.2);f.mesh.updateMatrixWorld(true);const changed=parity(f.mesh,ray(.13,.11));assert.notDeepEqual(signature(changed),signature(first));
// Preserve inherited and explicitly owned descriptors, including read-only but configurable.
Object.defineProperty(f.mesh,'getVertexPosition',{value:skin.getVertexPosition,writable:false,configurable:true,enumerable:false});
Object.defineProperty(f.mesh,'_computeIntersections',{value:meshProto._computeIntersections,writable:false,configurable:true,enumerable:false});parity(f.mesh,ray());
delete f.mesh.getVertexPosition;delete f.mesh._computeIntersections;
// Exception inside canonical bone lookup must restore both methods exactly.
const indices=f.geometry.attributes.skinIndex,brokenVertex=f.geometry.index.getX(Math.floor(f.geometry.index.count/6)*3),previous=indices.getX(brokenVertex);indices.setX(brokenVertex,65535);f.mesh.boundingSphere=new T.Sphere(new T.Vector3(),100);f.mesh.boundingBox=null;
assert.throws(()=>memoRaycast(f.mesh,ray(),[]));assert.equal(own(f.mesh,'getVertexPosition'),undefined);assert.equal(own(f.mesh,'_computeIntersections'),undefined);indices.setX(brokenVertex,previous);f.pose(0);
// A nested native raycast sees canonical methods, and its finally clears any
// cached vertices from before a nested pose change. The outer descriptor returns.
const original=own(f.mesh,'getVertexPosition');scope(f.mesh,()=>{
 const wrapper=f.mesh.getVertexPosition;f.mesh.getVertexPosition(100,new T.Vector3());
 suspend(f.mesh,()=>f.pose(.45)); // Nested work must not consume the outer cache while changing pose.
 const a=[],b=[];memoRaycast(f.mesh,ray(.1,.1),a);assert.equal(f.mesh.getVertexPosition,wrapper);
 suspend(f.mesh,()=>f.mesh.raycast(ray(.1,.1),b));assert.deepEqual(signature(a),signature(b));
 const actual=f.mesh.getVertexPosition(100,new T.Vector3()),expected=skin.getVertexPosition.call(f.mesh,100,new T.Vector3());assert.deepEqual(actual.toArray(),expected.toArray());
 assert.throws(()=>suspend(f.mesh,()=>{throw Error('nested')}),/nested/);assert.equal(f.mesh.getVertexPosition,wrapper);
});assert.deepEqual(own(f.mesh,'getVertexPosition'),original);
assert.throws(()=>scope(f.mesh,()=>{throw Error('scope')}),/scope/);assert.deepEqual(own(f.mesh,'getVertexPosition'),original);
// Any supported entry-method override is kept on the native fallback path.
for(const key of ['raycast','getVertexPosition','applyBoneTransform','_computeIntersections','computeBoundingSphere']){
 const original=f.mesh[key],before=counts.fallbacks;f.mesh[key]=function(...args){return original.apply(this,args)};parity(f.mesh,ray());assert.equal(counts.fallbacks,before+1);delete f.mesh[key];
}
// Same applies to custom attribute reads and material side getters.
const attribute=f.geometry.attributes.position,oldGetX=attribute.getX;attribute.getX=function(i){return oldGetX.call(this,i)};{const before=counts.fallbacks;parity(f.mesh,ray());assert.equal(counts.fallbacks,before+1);}delete attribute.getX;
const sideDescriptor=own(f.material,'side');Object.defineProperty(f.material,'side',{get:()=>T.DoubleSide,configurable:true});{const before=counts.fallbacks;parity(f.mesh,ray());assert.equal(counts.fallbacks,before+1);}Object.defineProperty(f.material,'side',sideDescriptor);

// Bounded representative CPU fixture: indexed articulated surface, four-weight
// attributes, morphs, many shared vertices. Measure whole native raycast scope.
const bench=fixture(64);bench.pose(.7);const r=ray(.17,.11),hits=[];
const before={...counts};memoRaycast(bench.mesh,r,hits);const perQuery={requests:counts.requests-before.requests,skinEvaluations:counts.evaluations-before.evaluations,cacheHits:counts.cacheHits-before.cacheHits};
assert.equal(perQuery.requests,bench.geometry.index.count);assert(perQuery.skinEvaluations<perQuery.requests/3);
let nativeVertexCalls=0;bench.mesh.getVertexPosition=function(...args){nativeVertexCalls++;return skin.getVertexPosition.apply(this,args)};bench.mesh.raycast(r,[]);delete bench.mesh.getVertexPosition;assert.equal(nativeVertexCalls,perQuery.requests);
const nativeTimes=[],memoTimes=[];for(let i=0;i<10;i++){bench.mesh.raycast(r,[]);memoRaycast(bench.mesh,r,[]);}
for(let i=0;i<40;i++){for(const which of i%2?['memo','native']:['native','memo']){const begin=performance.now();which==='native'?bench.mesh.raycast(r,[]):memoRaycast(bench.mesh,r,[]);(which==='native'?nativeTimes:memoTimes).push(performance.now()-begin);}}
const stats=values=>{values.sort((a,b)=>a-b);return{p50Ms:+values[19].toFixed(4),p95Ms:+values[37].toFixed(4)};};
console.log(JSON.stringify({parityCases:assertions,hitCases,vertices:bench.geometry.attributes.position.count,triangles:bench.geometry.index.count/3,perQuery,native:stats(nativeTimes),memo:stats(memoTimes),fallbacks:counts.fallbacks,nested:counts.nested,scope:'single-query CPU prototype only; no actor/scene/runtime changes or FPS claim'}));
bench.dispose();f.dispose();

// Real male GLB used by npc_actor/HERO_ASSET. CPU parsing only, no actor factory,
// browser, texture uploads or external fetches. Exercise bind/rest and articulated bones.
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(vendor+'/build/three.module.js').href:specifier,context);}});
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
for(const asset of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
const bytes=readFileSync(new URL('./hero_models/'+asset,import.meta.url));
const actual=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const skins=[],bones=new Map();actual.traverse(node=>{if(node.isSkinnedMesh)skins.push(node);if(node.isBone)bones.set(node.name,node);});
assert(skins.length>0);assert(skins.every(supported),'all actual GLB skins must pass canonical guards');
const rest=new Map([...bones.values()].map(bone=>[bone,bone.quaternion.clone()]));
function actualPose(step){
 for(const [bone,q]of rest)bone.quaternion.copy(q);
 for(const [name,axis,factor]of [['chest','z',.1],['head','y',.3],['upperarm_l','z',.35],['forearm_l','x',.55],['upperarm_r','x',-.2],['thigh_l','x',.25],['shin_l','x',-.4]]){const bone=bones.get(name);assert(bone,'real articulated bone '+name);bone.rotation[axis]+=step*factor;}
 actual.updateMatrixWorld(true);for(const mesh of skins){mesh.skeleton.update();mesh.computeBoundingSphere();mesh.computeBoundingBox();}
}
function actualRay(name,dx=0){const point=bones.get(name).getWorldPosition(new T.Vector3());point.x+=dx;return new T.Raycaster(point.clone().add(new T.Vector3(0,0,5)),new T.Vector3(0,0,-1),0,10);}
function actualCast(ray,memo){const hits=[];for(const mesh of skins)memo?memoRaycast(mesh,ray,hits):mesh.raycast(ray,hits);return hits.sort((a,b)=>a.distance-b.distance);}
let actualCases=0,actualHitCases=0;
for(const pose of [0,1,-.7]){actualPose(pose);for(const name of ['chest','head','thigh_l','hand_l'])for(const dx of [0,.08]){const r=actualRay(name,dx),a=actualCast(r,false),b=actualCast(r,true);assert.deepEqual(signature(b),signature(a));actualCases++;if(a.length)actualHitCases++;}}
assert(actualHitCases>10,'real source must produce actual ray hits');
actualPose(1);const actualQuery=actualRay('chest',.04),nativeCallsByMesh={};
for(const mesh of skins){nativeCallsByMesh[mesh.name]=0;setMethod(mesh,'getVertexPosition',function(...args){nativeCallsByMesh[this.name]++;return skin.getVertexPosition.apply(this,args)});}
actualCast(actualQuery,false);for(const mesh of skins)delete mesh.getVertexPosition;
const actualBefore={...counts};actualCast(actualQuery,true);const actualPerQuery={requests:counts.requests-actualBefore.requests,skinEvaluations:counts.evaluations-actualBefore.evaluations,cacheHits:counts.cacheHits-actualBefore.cacheHits};
assert.equal(actualPerQuery.requests,Object.values(nativeCallsByMesh).reduce((a,b)=>a+b,0));
for(let i=0;i<6;i++){actualCast(actualQuery,false);actualCast(actualQuery,true);}
const actualNative=[],actualMemo=[];
for(let i=0;i<24;i++)for(const mode of i%2?['memo','native']:['native','memo']){const start=performance.now();actualCast(actualQuery,mode==='memo');(mode==='native'?actualNative:actualMemo).push(performance.now()-start);}
const actualStats=a=>{a.sort((x,y)=>x-y);return{p50Ms:+a[11].toFixed(4),p95Ms:+a[22].toFixed(4)};};
const actualResources=new Set();actual.traverse(node=>{if(node.geometry)actualResources.add(node.geometry);for(const m of Array.isArray(node.material)?node.material:node.material?[node.material]:[])actualResources.add(m);});
console.log(JSON.stringify({asset,skins:skins.length,vertices:skins.reduce((n,m)=>n+m.geometry.attributes.position.count,0),indices:skins.reduce((n,m)=>n+m.geometry.index.count,0),actualCases,actualHitCases,guardPasses:skins.filter(supported).length,nativeCallsByMesh,perQuery:actualPerQuery,native:actualStats(actualNative),memo:actualStats(actualMemo),scope:'actual source GLB, rest/articulated bones, CPU only; not current Marat appearance or live FPS'}));
for(const resource of actualResources)resource.dispose();
}
