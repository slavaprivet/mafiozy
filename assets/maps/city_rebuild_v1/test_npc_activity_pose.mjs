import fs from 'node:fs';
import {applyNpcAppearance,describeNpcAppearance} from './npc_appearance.mjs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeleton=await(await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeleton.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
for(const sex of ['male','female'])for(const height of [1.65,2.05]){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const a=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:sex+height,sex,height,applyAppearance:scene=>applyNpcAppearance({THREE,scene,descriptor:describeNpcAppearance(sex+height,{sex,height,build:height<1.9?'slim':'heavy'})})}),c=a.walker.artistContext();
 const position={x:4.1,y:0,z:8.8},seat={id:'bench',c:1,r:2,height:.46,yaw:Math.PI/2,phase:'sit',since:1000};
 const tick=(time,life={},extra={})=>a.update(.05,{time,position,yaw:0,life,...extra});
 tick(1);const initial=c.worldPosition('thigh_r').y;tick(1,{seat});const first=c.worldPosition('thigh_r').y;
 assert(Math.abs(first-initial)<.001,'no entry snap');
 for(let i=1;i<=11;i++)tick(1+i*.05,{seat});
 const hip=c.worldPosition('thigh_l').add(c.worldPosition('thigh_r')).multiplyScalar(.5);
 assert.deepEqual(a.object.position.toArray(),[4.1,0,8.8],'source root unchanged');assert(Math.abs(hip.x-4.1)<.001&&Math.abs(hip.z-8.2)<.001,'hips align seat anchor');
 assert(Math.abs(hip.y-(.46+.075*height/1.9))<.001,'hips above seat');assert(Math.abs(c.visualPivot.rotation.y-Math.PI/2)<.001,'native seat yaw');
 for(const side of ['l','r']){const foot=c.worldPosition('foot_'+side);assert(foot.y>-.02&&foot.y<.18,'ankles above floor without stretching short legs');}
 let sole=Infinity; c.scene.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const ids=mesh.geometry.attributes.skinIndex,w=mesh.geometry.attributes.skinWeight;for(let i=0;i<ids.count;i++){let fw=0;for(let j=0;j<4;j++)if(/^foot_/.test(mesh.skeleton.bones[ids.getComponent(i,j)]?.name||''))fw+=w.getComponent(i,j);if(fw>.5)sole=Math.min(sole,mesh.getVertexPosition(i,new THREE.Vector3()).applyMatrix4(mesh.matrixWorld).y);}}); assert(Number.isFinite(sole)&&sole>-.025,'actual sole geometry does not penetrate floor');console.log(sex,height,'sole clearance',sole.toFixed(3));
 tick(1.6,{seat,phoneCalling:true});assert(a.diagnostics().phone.visible,'phone actual call visible');assert.equal(c.bones.hand_r.getObjectByName('NPC_Phone'),undefined,'legacy phone disabled when the pooled phone visual owns the call');
 tick(1.65,{seat,state:'calling'});assert.equal(a.diagnostics().phone.phase,'stow','state label alone starts smooth phone stow');
 for(let i=0;i<11;i++)tick(1.7+i*.05,{});assert(!a.diagnostics().phone.visible,'phone stow finishes without a call flag');assert(c.visualPivot.position.length()<.001,'getup clears visual offset');
 tick(2.25,{activity:'look_around'});const look=c.bones.head.matrix.toArray();tick(2.25);assert(look.some((v,i)=>Math.abs(v-c.bones.head.matrix.elements[i])>1e-4),'source lookaround moves head');
 tick(2.3,{phoneCalling:true,cowering:true});assert(!a.diagnostics().phone.visible,'fear hides phone');
 tick(2.4,{phoneCalling:true},{stun:{active:true,age:1}});assert(!a.diagnostics().phone.visible,'stun hides phone');
 a.dispose();
}
console.log('PASS actual both GLB min/max heights: native sit contract, anchor/yaw, gradual entry/exit, actual sole clearance (short legs may hang), phone, threat/stun priority');
