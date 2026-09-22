// Independent actual-GLB groundPose parity and total-key-cost harness, CPU only.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createHeroWalker} from './hero_walk.mjs';
import {createArtist14Pose} from './hero_artist14_pose.mjs';
import {createNpcDeathPose20} from './npc_death_pose20.mjs';
import {createNpcGroundCorrectionMemo} from './npc_ground_correction_memo.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const pose=createNpcDeathPose20({THREE:T,basePose:createArtist14Pose(T)});
const profile={known:true,cause:'bullet',directionLocal:{x:.3,z:-1}};
function cloneOwned(source){
 const root=source.clone(true),originals=[],copies=[];source.traverse(n=>originals.push(n));root.traverse(n=>copies.push(n));const map=new Map(originals.map((n,i)=>[n,copies[i]])),geometries=new Map(),materials=new Map();
 for(let i=0;i<originals.length;i++){const a=originals[i],b=copies[i];if(a.geometry){if(!geometries.has(a.geometry))geometries.set(a.geometry,a.geometry.clone());b.geometry=geometries.get(a.geometry);}if(a.material){const copy=m=>{if(!materials.has(m))materials.set(m,m.clone());return materials.get(m)};b.material=Array.isArray(a.material)?a.material.map(copy):copy(a.material);}
  if(a.isSkinnedMesh){b.skeleton=a.skeleton.clone();b.skeleton.bones=a.skeleton.bones.map(bone=>map.get(bone));b.bindMatrix.copy(a.bindMatrix);b.bindMatrixInverse.copy(a.bindMatrixInverse);}
 }
 return root;
}
function fixture(source,{plain=false}={}){
 const scene=cloneOwned(source);
 if(plain){const mesh=new T.Mesh(new T.BoxGeometry(.2,.3,.2),new T.MeshBasicMaterial());mesh.name='Authored_Plain_Ground_Test';mesh.position.set(.1,.1,.1);scene.add(mesh);}
 const walker=createHeroWalker({THREE:T,scene}),context=walker.artistContext(),poseMeshes=[];scene.traverse(mesh=>{if(mesh.isMesh)poseMeshes.push(mesh)});
 return{scene,walker,context,poseMeshes,prepare(age=1,customProfile=profile){walker.reset();pose.reaction({kind:'dead',age,rawAge:age,side:1},{...context,groundPose(){}},customProfile);},dispose(){walker.dispose();}};
}
function compare(label,a,b,memo,{tolerance=0}={}){
 const beforeA=a.context.visualPivot.position.y,beforeB=b.context.visualPivot.position.y;a.context.groundPose();const result=memo.apply(),expected=a.context.visualPivot.position.y-beforeA,actual=b.context.visualPivot.position.y-beforeB;
 assert.equal(typeof result,'number',label+' delta return');assert.equal(result,actual,label+' reported delta equals applied delta');
 assert.ok(Math.abs(actual-expected)<=tolerance,label+` delta ${actual} != ${expected}`);
 assert.ok(Math.abs(a.context.visualPivot.position.y-b.context.visualPivot.position.y)<=tolerance,label+' final visualPivot.y');
 const left=[],right=[];a.context.object.traverse(n=>left.push(n));b.context.object.traverse(n=>right.push(n));assert.equal(left.length,right.length,label+' hierarchy preserved');
 for(let i=0;i<left.length;i++)for(let k=0;k<16;k++)assert.ok(Math.abs(left[i].matrixWorld.elements[k]-right[i].matrixWorld.elements[k])<=Math.max(1e-12,tolerance*5),label+' world matrix parity');
}
let cases=0;const reports=[];
for(const asset of ['player_male.8130dfb1f7eb.glb','player_female.298d50e6244a.glb']){
 const bytes=readFileSync(new URL('./hero_models/'+asset,import.meta.url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const a=fixture(source),b=fixture(source),memo=createNpcGroundCorrectionMemo({THREE:T,context:b.context,poseMeshes:b.poseMeshes});
 function run(label,change=()=>{},options={}){a.prepare(options.age??1,options.profile??profile);b.prepare(options.age??1,options.profile??profile);change(a);change(b);const misses=memo.stats().misses;compare(asset+': '+label,a,b,memo,options);if(options.expectMiss)assert.equal(memo.stats().misses,misses+1,label+' must invalidate root-dependent result');cases++;}
 run('prime');run('same fixed root/pose');assert(memo.stats().hits>0,'static death pose must actually hit cache');
 run('late death age saturated',()=>{},{age:2});
 run('bone local matrix changed',f=>f.context.rotateAdd('forearm_l',.24,0,.1));
 run('death direction changed',()=>{},{profile:{...profile,directionLocal:{x:-1,z:.2}}});
 run('visual pivot initial local Y',f=>{f.context.visualPivot.position.y+=.37;});
 // Repeating apply without resetting the pivot must not add the old lift again.
 compare(asset+': repeated apply 1',a,b,memo);compare(asset+': repeated apply 2',a,b,memo);cases+=2;
 // Root invariance was REJECTED: actual Float32 weights need not sum to one.
 // A translated water-height query differed by 1.09e-7 when world root was omitted.
 run('prime identical pose before root move');
 run('root translation/yaw',f=>{f.context.object.position.set(137.125,3.4,-89.25);f.context.object.rotation.y=.91;},{tolerance:1e-8,expectMiss:true});
 run('water/root height change',f=>{f.context.object.position.y=-.27;},{tolerance:1e-8,expectMiss:true});
 run('root yaw alone changes',f=>{f.context.object.rotation.y=.23;},{tolerance:1e-8,expectMiss:true});
 run('root tilt/nonuniform scale',f=>{f.context.object.rotation.set(.18,.91,-.12);f.context.object.scale.set(1.2,.83,.95);},{tolerance:1e-8});
 run('moving platform ancestor',f=>{const platform=new T.Group();platform.position.set(-20,2,14);platform.rotation.set(.1,-.4,.07);platform.scale.set(.9,1.1,1.03);platform.add(f.context.object);platform.updateMatrixWorld(true);},{tolerance:1e-8});
 run('local offset and scaled translation',f=>{f.context.offset.position.y-=.13;f.context.scaled.position.y=.22;},{tolerance:1e-8});
 run('scaled local nonuniform scale',f=>f.context.scaled.scale.multiply(new T.Vector3(.93,1.08,1.02)),{tolerance:1e-8});
 run('raw geometry edit without version bump',f=>{const p=f.poseMeshes[0].geometry.attributes.position,v=p.version;p.array[1]-=3;assert.equal(p.version,v);},{tolerance:1e-8});
 run('bruiser-style all-position deformation',f=>{for(const m of f.poseMeshes){const p=m.geometry.attributes.position;for(let i=0;i<p.count;i++){p.array[i*p.itemSize]*=1.15;p.array[i*p.itemSize+1]*=.94;}}},{tolerance:1e-8});
 run('raw skinWeight edit',f=>{const w=f.poseMeshes.find(m=>m.isSkinnedMesh).geometry.attributes.skinWeight;w.array[0]*=.75;},{tolerance:1e-8});
 run('raw boneInverse edit',f=>{const m=f.poseMeshes.find(m=>m.isSkinnedMesh);m.skeleton.boneInverses[0].elements[13]+=.03;},{tolerance:1e-8});
 run('bindMatrix edit',f=>{f.poseMeshes.find(m=>m.isSkinnedMesh).bindMatrix.elements[13]-=.06;},{tolerance:1e-8});
 run('rest bone edit used by next reset',f=>{const r=f.context.rest.forearm_r;r.matrix.elements[13]+=.04;f.context.bones.forearm_r.matrix.copy(r.matrix);f.context.bones.forearm_r.matrixWorldNeedsUpdate=true;},{tolerance:1e-8});
 // Baseline groundPose ignores morphs, visibility and post-construction wounds.
 run('morph added, raw values and influence changed',f=>{const m=f.poseMeshes[0],p=m.geometry.attributes.position,values=new Float32Array(p.array.length);values.fill(-2);m.geometry.morphAttributes.position=[new T.Float32BufferAttribute(values,3)];m.geometry.morphTargetsRelative=true;m.updateMorphTargets();m.morphTargetInfluences[0]=.7;},{tolerance:1e-8});
 run('invisible authored meshes remain in original grounding',f=>{f.poseMeshes[0].visible=false;},{tolerance:1e-8});
 run('dynamic wound excluded from authoritative fixed list',f=>{const wound=new T.Mesh(new T.BoxGeometry(1,1,1),new T.MeshBasicMaterial());wound.position.y=-100;wound.name='Dynamic_Wound_Test';f.scene.add(wound);},{tolerance:1e-8});
 memo.invalidate();run('explicit invalidation',()=>{},{tolerance:1e-8});
 // Missing authority must never infer a different descendant list.
 const fallback=createNpcGroundCorrectionMemo({THREE:T,context:b.context});a.prepare();b.prepare();compare(asset+': missing authoritative list',a,b,fallback,{tolerance:1e-8});assert(fallback.stats().fallbacks>0);fallback.dispose();cases++;
 // A custom applyBoneTransform preserves its side effects and goes native.
 const customA=a.poseMeshes.find(m=>m.isSkinnedMesh),customB=b.poseMeshes.find(m=>m.isSkinnedMesh),original=customA.applyBoneTransform;
 customA.applyBoneTransform=customB.applyBoneTransform=function(...args){return original.apply(this,args)};
 const fallbacks=memo.stats().fallbacks;run('unknown applyBoneTransform fallback',()=>{},{tolerance:1e-8});assert(memo.stats().fallbacks>fallbacks);delete customA.applyBoneTransform;delete customB.applyBoneTransform;
 const groundA=a.context.groundPose,groundB=b.context.groundPose;let decoratedCalls=0;
 a.context.groundPose=function(){return groundA.call(this)};b.context.groundPose=function(){decoratedCalls++;return groundB.call(this)};
 const beforeDecorated=memo.stats().fallbacks;run('current custom groundPose fallback',()=>{},{tolerance:1e-8});assert.equal(decoratedCalls,1);assert(memo.stats().fallbacks>beforeDecorated);a.context.groundPose=groundA;b.context.groundPose=groundB;
 // The authoritative list is fixed even if an original mesh leaves the graph;
 // only the old closure knows its intended stale-matrix behavior, so fall back.
 const meshA=a.poseMeshes[0],meshB=b.poseMeshes[0],parentA=meshA.parent,parentB=meshB.parent;
 meshA.removeFromParent();meshB.removeFromParent();const beforeRemoved=memo.stats().fallbacks;run('removed original mesh fallback',()=>{},{tolerance:1e-8});assert(memo.stats().fallbacks>beforeRemoved);parentA.add(meshA);parentB.add(meshB);
 // A skeleton may be rebound to a bone outside the tracked root: do not memo it.
 const skinA=a.poseMeshes.find(m=>m.isSkinnedMesh),skinB=b.poseMeshes.find(m=>m.isSkinnedMesh),savedBoneA=skinA.skeleton.bones[0],savedBoneB=skinB.skeleton.bones[0],outsideA=new T.Bone(),outsideB=new T.Bone();outsideA.position.y=outsideB.position.y=.17;outsideA.updateMatrixWorld(true);outsideB.updateMatrixWorld(true);skinA.skeleton.bones[0]=outsideA;skinB.skeleton.bones[0]=outsideB;
 const beforeOutside=memo.stats().fallbacks;run('outside skeleton bone fallback',()=>{},{tolerance:1e-8});assert(memo.stats().fallbacks>beforeOutside);skinA.skeleton.bones[0]=savedBoneA;skinB.skeleton.bones[0]=savedBoneB;
 // Exception must propagate and cannot convert the following call into a stale hit.
 b.prepare();customB.applyBoneTransform=()=>{throw Error('ground failure')};assert.throws(()=>memo.apply(),/ground failure/);delete customB.applyBoneTransform;run('after exception',()=>{},{tolerance:1e-8});
 const snapshot=memo.stats();memo.dispose();memo.dispose();a.dispose();b.dispose();
 const plainA=fixture(source,{plain:true}),plainB=fixture(source,{plain:true}),plainMemo=createNpcGroundCorrectionMemo({THREE:T,context:plainB.context,poseMeshes:plainB.poseMeshes});
 for(let i=0;i<2;i++){plainA.prepare();plainB.prepare();for(const f of [plainA,plainB]){const mesh=f.scene.getObjectByName('Authored_Plain_Ground_Test');mesh.position.y=-3;mesh.visible=false;}compare(asset+': authored plain hidden mesh retained',plainA,plainB,plainMemo);cases++;}
 assert(plainMemo.stats().hits>0);plainMemo.dispose();plainA.dispose();plainB.dispose();
 // Fresh fixtures isolate total key+correction cost from the negative cases.
 const native=fixture(source),candidate=fixture(source),bench=createNpcGroundCorrectionMemo({THREE:T,context:candidate.context,poseMeshes:candidate.poseMeshes}),nativeTimes=[],memoTimes=[];
 for(let i=0;i<20;i++){native.prepare(2);candidate.prepare(2);for(const mode of i%2?['memo','native']:['native','memo']){const start=performance.now();mode==='native'?native.context.groundPose():bench.apply();if(i>=4)(mode==='native'?nativeTimes:memoTimes).push(performance.now()-start);}}
 const summarize=values=>{values.sort((x,y)=>x-y);return{p50Ms:+values[7].toFixed(4),p95Ms:+values[14].toFixed(4)};};
 reports.push({asset,parity:snapshot,steady:bench.stats(),native:summarize(nativeTimes),memoTotalKeyAndApply:summarize(memoTimes)});
 bench.dispose();native.dispose();candidate.dispose();const resources=new Set();source.traverse(n=>{if(n.geometry)resources.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])resources.add(m);});for(const resource of resources)resource.dispose();
}
console.log(JSON.stringify({cases,reports,scope:'real walker groundPose + death20; CPU only, no actor/runtime integration or FPS claim'}));
