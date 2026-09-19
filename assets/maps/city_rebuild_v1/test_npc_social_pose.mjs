import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcSocialPose} from './npc_social_pose.mjs';
import {createWeaponModel} from './hero_arsenal.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const load=async url=>{const b=fs.readFileSync(url);return(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene};
const report={rigs:[],limits:'Actual male/female GLBs, CPU bones and prop resources only. No renderer or source social scheduling/FPS acceptance.'};
const position={x:4.1,y:0,z:8.2},seat={id:'bench',c:1,r:2,seatWorldY:.46,yaw:.6,phase:'sit',since:1000};
for(const sex of ['male','female']){
 const source=await load(new URL(NPC_ASSETS[sex].url));
 for(const height of [1.65,2.05]){
  const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'social_'+sex+'_'+height,sex,height}),c=actor.walker.artistContext();
  const tick=(time,life={},extra={})=>actor.update(.05,{time,position,yaw:.2,life,...extra});
  const activity=kind=>({kind,phase:'active',since:1000,until:100000});
  tick(1);assert(!actor.object.getObjectByName('NPC_ReadingBook'));assert(!actor.object.getObjectByName('NPC_Cigarette'));
  const neutralHand=c.worldPosition('socket_hand_r');tick(1.2,{activity:{...activity('read'),phase:'approach'}});assert(!actor.object.getObjectByName('NPC_ReadingBook'));assert(neutralHand.distanceTo(c.worldPosition('socket_hand_r'))<.02);
  tick(1.25,{talking:true,activity:{...activity('talk'),phase:'approach'}});assert(neutralHand.distanceTo(c.worldPosition('socket_hand_r'))<.02,'approach never leaks legacy talking arms');
  for(let i=0;i<12;i++)tick(1+i*.05,{seat});
  const seatedHip=c.worldPosition('thigh_l'),feet=['foot_l','foot_r'].map(name=>c.worldPosition(name));
  tick(2,{seat,activity:activity('read')});const book=actor.object.getObjectByName('NPC_ReadingBook');assert(book?.visible,'active reading shows book');
  assert(c.worldPosition('thigh_l').distanceTo(seatedHip)<.001,'reading retains bench hip anchor');
  for(let i=0;i<2;i++)assert(c.worldPosition(['foot_l','foot_r'][i]).distanceTo(feet[i])<.001,'reading preserves planted feet');
  const center=book.getWorldPosition(new THREE.Vector3()),handDistances=['l','r'].map(side=>c.worldPosition('socket_hand_'+side).distanceTo(center));
  assert(handDistances.every(d=>d>.06&&d<.26),'both hands grip open book edges '+JSON.stringify({sex,height,handDistances}));
  for(const kind of ['read','smoke','talk']){
   let previous=null,maxStep=0;
   for(let i=0;i<60;i++){
    tick(3+i/30,{...(kind==='read'?{seat}:{}),activity:activity(kind)});
    const hand=c.worldPosition('socket_hand_r');if(previous)maxStep=Math.max(maxStep,hand.distanceTo(previous));previous=hand;
    for(const [name,bone]of Object.entries(c.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert(p.distanceTo(c.rest[name].p)<1e-7,'rest length '+name);assert(s.distanceTo(c.rest[name].s)<1e-6,'rest scale '+name);assert(bone.matrix.elements.every(Number.isFinite));}
    assert.deepEqual(actor.object.position.toArray(),[position.x,position.y,position.z]);assert(Math.abs(actor.object.rotation.y-.2)<1e-10);
   }
   assert(maxStep<.16,'gesture does not jump '+JSON.stringify({sex,height,kind,maxStep}));
  }
  const cigarette=actor.object.getObjectByName('NPC_Cigarette');tick(6,{activity:activity('smoke')});assert(cigarette.visible);assert(!book.visible);
  tick(6.1,{activity:activity('talk')});assert(!book.visible&&!cigarette.visible);
  for(const [label,life,extra] of [['phone',{phoneCalling:true},{}],['panic',{panic:true},{}],['state panic',{state:'panic'},{}],['state flee',{state:'fleeing'},{}],['custody',{cuffed:true},{}],['flee',{fleeing:true},{}],['water',{}, {inWater:true,waterLevel:.2}],['vehicle',{}, {vehicle:{seated:1}}],['melee',{}, {action:{type:'punch',progress:.4}}],['jump',{}, {jump:{progress:.3}}],['walk',{}, {moving:true}]]){
   tick(7,{activity:activity('read')});assert(book.visible,label+' precondition');tick(7.1,{activity:activity('read'),...life},extra);assert(!book.visible&&!cigarette.visible,'priority '+label);
  }
  for(const fleeing of [{panic:true},{fleeing:true},{state:'panic'},{lifeState:'fleeing'},{state:'PANIC'}]){
   tick(7.2,{talking:true,...fleeing});assert.equal(actor.diagnostics().lifeGesture,null,'escaping does not leak legacy talking arms');
   tick(7.3,{phoneCalling:true,...fleeing});assert.equal(actor.object.getObjectByName('NPC_Phone').visible,false,'escaping hides phone across source state aliases');
   assert.equal(actor.diagnostics().lifeGesture,null,'escaping suppresses phone gesture across source state aliases');
  }
  tick(8,{activity:{kind:'read',phase:'finish',since:8000,until:8600}});assert(book.visible);tick(8.7,{activity:{kind:'read',phase:'finish',since:8000,until:8600}});assert(!book.visible);tick(9,{});assert(!book.visible&&!cigarette.visible);
  const weaponSource=createWeaponModel(THREE,'tt_pistol');actor.mountWeapon(weaponSource);tick(9.1,{activity:activity('read')});assert(!book.visible&&!cigarette.visible,'armed actor cannot continue a social prop');actor.mountWeapon(null);
  const weaponResources=new Set();weaponSource.traverse(n=>{if(n.geometry)weaponResources.add(n.geometry);if(n.material)weaponResources.add(n.material)});for(const resource of weaponResources)resource.dispose();
  // Instrument this module's THREE construction only. Existing walker base/seat
  // code allocates independently and is excluded from this particular assertion.
  let constructions=0;const counted={...THREE};for(const key of ['Vector3','Quaternion','Matrix4','Euler','BoxGeometry','CylinderGeometry','Mesh','Group','MeshStandardMaterial'])counted[key]=new Proxy(THREE[key],{construct(target,args){constructions++;return Reflect.construct(target,args);}});
  const pose=createNpcSocialPose({THREE:counted,walker:actor.walker});
  for(const kind of ['read','smoke']){actor.walker.reset();pose.apply(activity(kind),10,false);}
  const warm=pose.diagnostics(),builds=constructions,baseline=[],active=[];
  for(let i=0;i<80;i++){
   actor.walker.reset();const count=constructions,start=performance.now();pose.apply(activity(['read','smoke','talk'][i%3]),10+i/30,false);active.push(performance.now()-start);assert.equal(constructions,count,'no THREE constructions during warmed social apply');
   actor.walker.reset();const idleStart=performance.now();pose.apply(null,10+i/30,false);baseline.push(performance.now()-idleStart);
  }
  assert.equal(constructions,builds);assert.equal(pose.diagnostics().resourceBuilds,warm.resourceBuilds);assert.equal(warm.geometries,2);assert.equal(warm.materials,5);
  pose.dispose();tick(15,{activity:activity('read')});actor.receive({confirmed:true,id:'death',targetId:actor.id,dead:true});tick(15.1,{activity:activity('read')});assert(!book.visible&&!cigarette.visible);assert.equal(actor.surface.state.kind,'dead');
  let disposedResources=0;const resources=new Set();for(const group of [book,cigarette])group.traverse(n=>{if(n.geometry)resources.add(n.geometry);if(n.material)resources.add(n.material)});for(const r of resources)r.addEventListener('dispose',()=>disposedResources++);
  actor.dispose();assert.equal(disposedResources,resources.size,'props disposed once');
  const stats=a=>{a.sort((x,y)=>x-y);return {p50Ms:a[Math.floor(a.length*.5)],p95Ms:a[Math.floor(a.length*.95)]}};
  report.rigs.push({sex,height,handDistances,resources:{geometry:warm.geometries,materials:warm.materials,visibleMeshesPerProp:3},warmThreeConstructions:0,idleOverlay:stats(baseline),activeOverlay:stats(active)});
 }
}
fs.writeFileSync(new URL('../../../outputs/npc_social_pose_20260913.json',import.meta.url),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));console.log('PASS social poses actual male/female, bench anchors, props, nonstretch, interruption, cached allocations/disposal');
