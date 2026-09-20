import fs from 'node:fs';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS,sampleNpcSurrenderGesture} from './npc_actor.mjs';
import {describeNpcAppearance,applyNpcAppearance} from './npc_appearance.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeletonSource=await (await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();
const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeletonSource.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
const sources={};for(const [sex,asset] of Object.entries(NPC_ASSETS)){const data=fs.readFileSync(new URL(asset.url));assert.equal(data.length,asset.bytes);assert.equal(createHash('sha256').update(data).digest('hex'),asset.sha256);sources[sex]=(await new GLTFLoader().parseAsync(data.buffer.slice(data.byteOffset,data.byteOffset+data.byteLength),'')).scene;}
const world=new THREE.Scene(),create=(id,sex='male',height=1.9)=>createNpcActor({THREE,scene:world,source:sources[sex],cloneSkeleton:clone,id,sex,height});
const surrenderSamples=[0,.37,1.2,2.8].map(sampleNpcSurrenderGesture);
for(const pose of surrenderSamples){
 assert.equal(pose.hands.length,2);assert(pose.chest.concat(pose.head,...pose.hands).every(Number.isFinite));
 const [left,right]=pose.hands,gap=right[0]-left[0];
 assert(left[0]<=-.76&&right[0]>=.75,'surrender hands clear the head and hats on their natural sides');
 assert(gap>=1.52&&gap<=1.58,'hands stay well outside the face while remaining below the old high Y');
 assert(left[1]>=4.03&&left[1]<=4.09&&right[1]>=4.10&&right[1]<=4.15,'raised hands retain relaxed asymmetry');
 assert(left[2]>=.49&&left[2]<=.51&&right[2]>=.48&&right[2]<=.50,'hands remain slightly forward with bent elbows');
}
assert.notDeepEqual(surrenderSamples[0],surrenderSamples[1],'surrender pose breathes instead of freezing');
for(let i=1;i<surrenderSamples.length;i++)for(let hand=0;hand<2;hand++)assert(new THREE.Vector3(...surrenderSamples[i-1].hands[hand]).distanceTo(new THREE.Vector3(...surrenderSamples[i].hands[hand]))<.05,'surrender motion stays subtle');
const a=create('citizen:42'),b=create('citizen:43'),f=create('citizen:44','female',1.65),tall=create('citizen:45','male',2.05);
assert.equal(f.height,1.65);assert.equal(tall.height,2.05);
const ac=a.walker.artistContext(),bc=b.walker.artistContext();assert.notEqual(ac.bones.head,bc.bones.head);
const templateHead=sources.male.getObjectByName('head');assert.notEqual(ac.bones.head,templateHead);
const beforeB=bc.bones.thigh_l.matrix.toArray(),beforeTemplate=templateHead.matrix.toArray();
a.update(.1,{position:{x:2,y:0,z:3},yaw:.8,moving:true});assert.notDeepEqual(ac.bones.thigh_l.matrix.toArray(),beforeB);assert.deepEqual(bc.bones.thigh_l.matrix.toArray(),beforeB);assert.deepEqual(templateHead.matrix.toArray(),beforeTemplate);
const firstMesh=root=>{let result;root.traverse(o=>{if(!result&&o.isSkinnedMesh)result=o;});return result;};
assert.notEqual(firstMesh(ac.scene).geometry,firstMesh(bc.scene).geometry);assert.notEqual(firstMesh(ac.scene).material,firstMesh(bc.scene).material);
for(let i=0;i<4;i++)a.update(.1,{inWater:true,waterLevel:.22});
const wetSum=root=>{let n=0;root.traverse(o=>{const a=o.geometry?.attributes?.aClothingWetness;if(a)for(const v of a.array)n+=v;});return n;};assert(wetSum(ac.scene)>0);assert.equal(wetSum(bc.scene),0);
assert.equal(a.receive({id:'bad',confirmed:false,fatal:true}),false);assert.equal(a.receive({id:'wrong',targetId:b.id,confirmed:true,fatal:true}),false);
const point=ac.bones.head.getWorldPosition(new THREE.Vector3());
assert.equal(a.receive({id:'head1',confirmed:true,zone:'head',point}),true);assert.equal(a.receive({id:'head1',confirmed:true,zone:'head',point}),false);
assert(ac.scene.getObjectByName('Artist14EyeBruise').parent.children.some(o=>o.name==='Artist14EyeBruise'&&o.visible));assert(!bc.scene.getObjectByName('Artist14EyeBruise').visible);
const gun=new THREE.Group();gun.userData={weaponClass:'pistol'};gun.add(new THREE.Mesh(new THREE.BoxGeometry(.1,.1,.2),new THREE.MeshStandardMaterial()));
const mounted=a.mountWeapon(gun);assert.notEqual(mounted,gun);assert.notEqual(mounted.children[0].geometry,gun.children[0].geometry);assert.equal(gun.parent,null);
a.update(.1,{});assert(mounted.parent);a.mountWeapon(null);
// Ray-confirmed chest impact creates a private persistent tear on this actor.
a.update(.1,{position:{x:0,y:0,z:0},yaw:0,inWater:false});
const rayStart=ac.offset.localToWorld(new THREE.Vector3(0,2.8,2)),rayDirection=new THREE.Vector3(0,0,-1),surfaces=[];ac.scene.traverse(o=>{if(o.isSkinnedMesh){o.skeleton.update();o.computeBoundingSphere();surfaces.push(o);}});
const hit=new THREE.Raycaster(rayStart,rayDirection,0,4).intersectObjects(surfaces,false)[0];assert(hit);
assert(a.receive({id:'bullet1',confirmed:true,kind:'bullet',point:hit.point,normal:{x:0,y:0,z:1},clothing:true}));
assert(ac.scene.getObjectByName('PersistentBulletWounds').children.length>0);assert.equal(bc.scene.getObjectByName('PersistentBulletWounds').children.length,0);
const tear=ac.scene.getObjectByName('PersistentBulletWounds').children[0];a.update(.1,{posture:{target:'crouch',value:1}});assert(tear.geometry.attributes.position.array.every(Number.isFinite));
let swimResult;for(let i=0;i<10;i++)swimResult=f.update(.1,{inWater:true,waterLevel:1.8,moving:true});assert(swimResult.swim.active);assert(f.object.position.y>0);assert.equal(b.object.position.y,0);
for(let i=0;i<35;i++)f.update(.1,{inWater:false});assert.equal(f.diagnostics().surface.swim.blend,0);assert.equal(f.object.position.y,0);
assert(a.receive({id:'death1',confirmed:true,fatal:true}));for(let i=0;i<10;i++)a.update(.1,{moving:true});assert.equal(a.diagnostics().reaction,'dead');assert.equal(b.diagnostics().reaction,'idle');
for(const npc of [f,tall])for(const posture of [{target:'stand',value:0},{target:'crouch',value:1},{target:'prone',value:2}]){npc.update(.1,{posture,moving:true});npc.object.traverse(o=>assert(o.matrixWorld.elements.every(Number.isFinite)));}
let sourceDisposed=0,otherDisposed=0;firstMesh(sources.male).geometry.addEventListener('dispose',()=>sourceDisposed++);firstMesh(bc.scene).geometry.addEventListener('dispose',()=>otherDisposed++);a.dispose();a.dispose();assert.equal(sourceDisposed,0);assert.equal(otherDisposed,0);assert.equal(a.object.parent,null);b.update(.1,{moving:true});assert.equal(b.object.parent,world);
assert.throws(()=>createNpcActor({THREE,scene:world,source:sources.male,cloneSkeleton:x=>x.clone(true),id:'broken'}),/skeleton/);
assert.throws(()=>b.update(.1,{position:{x:NaN,y:0,z:0}}),/finite/);
// Real life snapshots only select a pose, never move or damage the actor.
for(const [state,expected] of [['surrendered','surrender'],['cowering','cower'],['medicCarry','carry'],['helping','help'],['phoneCalling','phone'],['social','talk']]){
 for(let i=0;i<5;i++)b.update(.1,{life:{state},position:{x:3,y:0,z:5}});
 assert.equal(b.diagnostics().lifeGesture,expected);assert.deepEqual(b.object.position.toArray(),[3,0,5]);
 b.object.traverse(o=>assert(o.matrixWorld.elements.every(Number.isFinite)));
}
b.update(.1,{life:{state:'unknown'}});assert.equal(b.diagnostics().lifeGesture,null);
const p0=b.walker.diagnostics().phase;b.update(.1,{moving:true,life:{state:'panic'}});const panicDelta=b.walker.diagnostics().phase-p0;
const p1=b.walker.diagnostics().phase;b.update(.1,{moving:true,life:{}});assert(panicDelta>b.walker.diagnostics().phase-p1,'panic uses run cadence');
b.mountWeapon(gun);b.update(.1,{life:{surrendering:true}});assert.equal(b.diagnostics().lifeGesture,null,'never break armed grip');b.update(.1,{life:{cowering:true}});assert.equal(b.diagnostics().lifeGesture,null);assert(b.weapon.parent);b.mountWeapon(null);
b.update(.1,{life:{phoneCalling:true},inWater:true,waterLevel:2});assert.equal(b.diagnostics().lifeGesture,null,'swim wins even on entry frame');
assert(b.receive({id:'fall-life',confirmed:true,heavy:true,point:bc.bones.head.getWorldPosition(new THREE.Vector3())}));b.update(.1,{life:{surrendering:true}});assert.equal(b.diagnostics().lifeGesture,null,'confirmed fall wins');
const descriptor=describeNpcAppearance('officer:9',{role:'police',sex:'female',build:'heavy'});
const officer=createNpcActor({THREE,scene:world,source:sources.female,cloneSkeleton:clone,id:descriptor.id,sex:descriptor.sex,height:descriptor.height,applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor})});
officer.update(.1,{moving:true,position:{x:5,y:0,z:8}});assert.equal(officer.appearance.descriptor.role,'police');assert(officer.walker.artistContext().scene.userData.npcAppearance);officer.dispose();
for(const npc of [b,f,tall])npc.dispose();assert.equal(world.children.length,0);
console.log('PASS NPC actor: hashed male/female assets, height range, skeleton/material/wet/bruise/receipt isolation, weapon ownership, death, posture, independent disposal, invalid clone rejected');
