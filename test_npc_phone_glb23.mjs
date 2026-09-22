import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';

const vendor=process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const threeUrl=pathToFileURL(vendor+'/build/three.module.js').href;
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?threeUrl:specifier,context)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./assets/maps/city_rebuild_v1/test_npc_death_offline_setup.mjs');
const {createHeroWalker}=await import('./assets/maps/city_rebuild_v1/hero_walk.mjs');
const phoneModule=await import('./assets/maps/city_rebuild_v1/npc_phone_visual.mjs');
const {createNpcPhoneVisual,createNpcPhoneVisualPool}=phoneModule;
const models={};
for(const [sex,file]of [['male','player_male.8130dfb1f7eb.glb'],['female','player_female.298d50e6244a.glb']]){
 const bytes=fs.readFileSync(new URL('./assets/maps/city_rebuild_v1/hero_models/'+file,import.meta.url));
 models[sex]=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
}
const reports=[],legNames=['thigh_l','thigh_r','shin_l','shin_r','foot_l','foot_r'];
const wp=node=>node.getWorldPosition(new THREE.Vector3());
const signature=c=>Object.values(c.bones).flatMap(b=>b.matrix.elements);
function fixture(sex,{height=1.9,yaw=0,module=phoneModule}={}){
 const walker=createHeroWalker({THREE,scene:clone(models[sex]),targetHeight:height}),context=walker.artistContext();
 walker.object.position.set(11,2,-9);walker.object.rotation.y=yaw;walker.object.updateMatrixWorld(true);
 const visual=module.createNpcPhoneVisual({THREE,walker});
 let time=0;
 function tick(dt,calling=true,extra={},moving=false){
  time+=dt;walker.update(dt,moving,false,null,{},moving?{gaitDistance:1.2*dt,motionSpeed:1.2}:{});
  const legs=legNames.map(n=>context.bones[n].matrix.elements.slice());
  const snapshot={time,sourceNowMs:1720000000000+time*1000,life:{phoneCalling:calling},...extra},before=JSON.stringify(snapshot);
  visual.update(dt,snapshot);assert.equal(JSON.stringify(snapshot),before,'presentation cannot mutate source clock or life state');
  assert.deepEqual(legNames.map(n=>context.bones[n].matrix.elements),legs,'calling must preserve authored leg gait');
 }
 return {walker,context,visual,tick,dispose(){visual.dispose();walker.dispose();}};
}
function earPoint(context,sex){
 // Measured outermost ear vertices in the actual head-weighted SKIN geometry.
 return context.bones.head.localToWorld(new THREE.Vector3(sex==='male'?.702:.652,.4,-.015));
}

test('black brick and antenna use one bounded shared geometry and one opaque vertex-colour material',()=>{
 const pool=createNpcPhoneVisualPool({THREE}),a=pool.acquire(),b=pool.acquire();
 assert.equal(a.geometry,b.geometry);assert.equal(a.material,b.material);assert.equal(a.children.length,0);
 assert.equal(a.geometry.groups.length,0);assert.equal(a.material.vertexColors,true);assert.equal(a.material.transparent,false);
 assert.equal(a.material.map,null);assert.equal(a.material.toneMapped,false);assert.equal(a.castShadow,false);assert.equal(a.receiveShadow,false);assert.equal(a.raycast(),undefined);
 const g=a.geometry,p=g.attributes.position,c=g.attributes.color;assert.equal(c.count,p.count);assert(p.count/3<=128,'small prop must stay below 128 triangles');
 const size=g.boundingBox.getSize(new THREE.Vector3());assert(Math.abs(size.x-.105)<1e-6);assert(size.y>.28&&size.y<.30);assert(size.z<.04);
 let dark=0,antenna=0;for(let i=0;i<c.count;i++){
  if(Math.max(c.getX(i),c.getY(i),c.getZ(i))<.035)dark++;
  if(p.getY(i)>.13){antenna++;assert(Math.abs(p.getX(i)+.032)<.007);assert(Math.abs(p.getZ(i))<.007);}
 }
 assert(dark/c.count>.65,'black housing dominates the baked colours');assert(antenna>=12,'visible narrow antenna above housing');
 reports.push({geometry:{drawsPerActivePhone:1,triangles:p.count/3,positionColourBytes:p.array.byteLength+c.array.byteLength,dimensions:size.toArray(),darkVertexFraction:dark/c.count}});
 pool.release(a);pool.release(b);pool.dispose();
});

for(const sex of ['male','female'])for(const fps of [7,15,60])test(`actual ${sex} GLB receiver, upright hand and gait at ${fps} FPS`,()=>{
 let worstGap=0,worstHandGap=0;
 for(const height of [1.6,1.9,2.2])for(const yaw of [0,1.37]){
  const f=fixture(sex,{height,yaw});
  for(let i=0;i<Math.ceil(fps*1.7);i++)f.tick(1/fps,true,{},true);
  assert.equal(f.visual.phase,'hold');
  for(let i=0;i<12;i++){
   f.tick(1/fps,true,{},true);const phone=f.visual.object;
   const receiver=phone.localToWorld(new THREE.Vector3(0,.074,.0182)),ear=earPoint(f.context,sex),gap=receiver.distanceTo(ear);
   worstGap=Math.max(worstGap,gap);assert(gap<.023,'receiver stays within 23 mm of real outer ear across both rigs and actor heights');
   const palm=wp(f.context.bones.socket_hand_r),wrist=wp(f.context.bones.hand_r),headUp=new THREE.Vector3(0,1,0).applyQuaternion(f.context.bones.head.getWorldQuaternion(new THREE.Quaternion()));
   assert(palm.clone().sub(wrist).dot(headUp)>.045,'wrist below palm instead of upside-down grip');
   const handGap=palm.distanceTo(wp(phone));worstHandGap=Math.max(worstHandGap,handGap);assert(handGap<.058,'phone remains inside hand-sized grip');
   const inward=new THREE.Vector3(0,0,1).applyQuaternion(phone.getWorldQuaternion(new THREE.Quaternion())),headRight=new THREE.Vector3(1,0,0).applyQuaternion(f.context.bones.head.getWorldQuaternion(new THREE.Quaternion()));
   assert(inward.dot(headRight)<-.99,'receiver faces ear, not camera or actor world axes');
   assert(Math.abs(phone.getWorldScale(new THREE.Vector3()).x-1)<1e-6,'phone retains physical dimensions');
  }
  f.dispose();
 }
 reports.push({sex,fps,maxReceiverEarGapMetres:worstGap,maxPalmPhoneGapMetres:worstHandGap});
});

for(const sex of ['male','female'])test(`actual ${sex} call stows continuously even when cancelled before reaching the ear`,()=>{
 for(const fps of [7,15,60])for(const callSeconds of [.1,.4,1.2]){
  const f=fixture(sex);for(let i=0;i<Math.max(1,Math.ceil(callSeconds*fps));i++)f.tick(1/fps);
  const mesh=f.visual.object,last=wp(mesh);let previous=last,maximumStep=0;
  for(let i=0;i<Math.ceil(fps*.85);i++){
   f.tick(1/fps,false);if(f.visual.object){const next=wp(f.visual.object);const step=next.distanceTo(previous);maximumStep=Math.max(maximumStep,step);assert(step<4*Math.min(.1,1/fps)+.01,'bounded stow speed');if(i===0)assert(step<.14,'cancel never jumps the phone to an unvisited ear pose');previous=next;}
  }
  assert(maximumStep<.41,`bounded draw/raise cancellation at ${fps} FPS (${maximumStep})`);
  assert.equal(f.visual.phase,'idle');assert.equal(f.visual.object,null);assert.equal(mesh.parent,null);f.dispose();
 }
});

test('medical visibility and combat/vehicle blocks stop phone immediately without changing a single rig bone',()=>{
 for(const sex of ['male','female'])for(const extra of [{visible:false},{phoneBlocked:true},{life:{phoneCalling:true,phoneBlocked:true}},{life:{phoneCalling:true,visible:false}}]){
  const f=fixture(sex);for(let i=0;i<12;i++)f.tick(.1);assert.equal(f.visual.phase,'hold');
  f.walker.update(.016,false);const original=signature(f.context);f.visual.update(.016,{life:{phoneCalling:true},...extra});
  assert.equal(f.visual.object,null);assert.equal(f.visual.phase,'idle');assert.deepEqual(signature(f.context),original,'higher priority owns its full pose');f.dispose();
 }
});

test('actual actor hook keeps call grip and gives medical, danger, weapon and vehicle poses priority',async()=>{
 const {createNpcActor}=await import('./assets/maps/city_rebuild_v1/npc_actor.mjs');
 const {createWeaponModel}=await import('./assets/maps/city_rebuild_v1/hero_arsenal.mjs');
 for(const sex of ['male','female'])for(const state of ['medical','stun','dead','flee','cower','surrender','cash','weapon','vehicle']){
  const scene=new THREE.Scene(),car=new THREE.Group();scene.add(car);
  const vehicle={object:car,yaw:0,getDriverRootWorld:()=>new THREE.Vector3(0,.65,0)};
  const actor=createNpcActor({THREE,scene,source:models[sex],cloneSkeleton:clone,id:'phone23-'+sex+'-'+state,sex,getVehicle:()=>vehicle});
  const base={position:{x:0,y:0,z:0},yaw:0,posture:{target:'stand',value:0}};
  for(let i=0;i<12;i++)actor.update(.1,{...base,time:i*.1,life:{phoneCalling:true}});
  assert.equal(actor.diagnostics().phone.phase,'hold');
  const phone=actor.object.getObjectByName('NPC_Phone_Visual');assert(phone?.visible);
  assert(phone.localToWorld(new THREE.Vector3(0,.074,.0182)).distanceTo(earPoint(actor.walker.artistContext(),sex))<.023,'actual actor uses the real phone module');
  let life={phoneCalling:true},extra={},weaponSource=null;
  if(state==='medical'){life.downed=true;extra.posture={target:'prone',value:1};}
  if(state==='stun')extra.stun={active:true,age:.2};
  if(state==='dead')assert(actor.receive({id:'phone-test-death',confirmed:true,fatal:true}));
  if(state==='flee')life.fleeing=true;
  if(state==='cower')life.cowering=true;
  if(state==='surrender')life.surrendering=true;
  if(state==='cash')life.cashOffering=true;
  if(state==='weapon'){weaponSource=createWeaponModel(THREE,'tt_pistol');actor.mountWeapon(weaponSource);}
  if(state==='vehicle')Object.assign(life,{civilianTripRiding:true,civilianTripCarId:'phone-test-car'});
  actor.update(.016,{...base,time:1.3,life,...extra});assert.equal(actor.diagnostics().phone.visible,false,state+' immediately wins over an already active call');
  assert.equal(phone.parent,null);actor.dispose();weaponSource?.traverse(node=>{node.geometry?.dispose();if(node.material)for(const material of Array.isArray(node.material)?node.material:[node.material])material.dispose();});
 }
});

test('warmed phone pose creates no THREE objects and reuses the same pooled draw',()=>{
 const constructors=['Vector3','Quaternion','Euler','Mesh','BufferGeometry','MeshBasicMaterial'];let constructions=0;
 const tracked={...THREE};for(const name of constructors)tracked[name]=new Proxy(THREE[name],{construct(target,args){constructions++;return Reflect.construct(target,args);}});
 const walker=createHeroWalker({THREE,scene:clone(models.male)}),visual=createNpcPhoneVisual({THREE:tracked,walker});
 for(let i=0;i<60;i++){walker.update(1/60,true);visual.update(1/60,{time:i/60,phoneCalling:true});}
 const mesh=visual.object;constructions=0;
 for(let i=0;i<120;i++){walker.update(1/60,true);visual.update(1/60,{time:1+i/60,phoneCalling:true});assert.equal(visual.object,mesh);}
 assert.equal(constructions,0,'phone scratch objects and geometry are constructed only once; IK is owned by existing walker');
 visual.dispose();walker.dispose();reports.push({warmPhoneThreeConstructions:constructions,scope:'phone module only; existing walker IK allocations excluded'});
});

test('bounded pose-only cost reports comparable actual-rig samples without claiming loaded scene FPS',async()=>{
 const baseline=process.env.NPC_PHONE_BASELINE_MODULE?await import(pathToFileURL(process.env.NPC_PHONE_BASELINE_MODULE).href):null;
 for(const sex of ['male','female']){
  const variants={after:fixture(sex)};if(baseline)variants.before=fixture(sex,{module:baseline});
  const timings=Object.fromEntries(Object.keys(variants).map(k=>[k,[]]));
  for(let i=0;i<700;i++)for(const key of i%2?Object.keys(variants).reverse():Object.keys(variants)){
   const f=variants[key];f.walker.update(1/60,true);const start=performance.now();f.visual.update(1/60,{time:i/60,life:{phoneCalling:true}});if(i>=200)timings[key].push(performance.now()-start);
  }
  if(baseline)for(const name of ['chest','head'])assert(variants.after.context.bones[name].matrix.elements.every((v,i)=>Math.abs(v-variants.before.context.bones[name].matrix.elements[i])<1e-12),'allocation-free rotations preserve existing conversational head/chest pose');
  const result={};for(const [key,values]of Object.entries(timings)){values.sort((a,b)=>a-b);result[key]={p50Ms:values[Math.floor(values.length*.5)],p95Ms:values[Math.floor(values.length*.95)]};variants[key].dispose();}
  reports.push({sex,poseOnlyCost:result});
 }
 console.log(JSON.stringify({scope:'actual GLBs, production functions; no renderer or loaded-scene FPS claim',reports},null,2));
});
