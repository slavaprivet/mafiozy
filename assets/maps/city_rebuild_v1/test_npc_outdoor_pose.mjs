import fs from 'node:fs';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';import {performance} from 'node:perf_hooks';
import {clone} from './test_npc_death_offline_setup.mjs';import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {createNpcActivityPose} from './npc_activity_pose.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const rows=[],costs={idle:[],sport:[]};
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const actor=createNpcActor({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'outdoor_'+sex,sex}),c=actor.walker.artistContext(),position={x:4.1,y:0,z:8.2};
 const tick=(time,life={},extra={})=>actor.update(.05,{time,position,yaw:.2,life,...extra});
 for(const kind of ['stretch','squat','lookaround']){
  tick(1);const neutral=c.worldPosition('socket_hand_r'),foot={l:c.worldPosition('foot_l'),r:c.worldPosition('foot_r')},hip=c.worldPosition('thigh_l'),head=c.bones.head.getWorldQuaternion(new THREE.Quaternion());let motion=0,slip=0,drop=0,headMotion=0,maxStep=0,previous=null,meshCount=0;actor.object.traverse(o=>{if(o.isMesh)meshCount++;});
  for(let i=0;i<=240;i++){
   const time=1+i*.05;tick(time,{activity:{kind,phase:'active',since:1000,until:13000}});
   const hand=c.worldPosition('socket_hand_r');motion=Math.max(motion,hand.distanceTo(neutral));headMotion=Math.max(headMotion,head.angleTo(c.bones.head.getWorldQuaternion(new THREE.Quaternion())));drop=Math.max(drop,hip.y-c.worldPosition('thigh_l').y);
   if(previous)maxStep=Math.max(maxStep,hand.distanceTo(previous));previous=hand;
   for(const side of ['l','r'])slip=Math.max(slip,foot[side].distanceTo(c.worldPosition('foot_'+side)));
   assert.deepEqual(actor.object.position.toArray(),[position.x,position.y,position.z]);
   for(const [name,bone]of Object.entries(c.bones)){const p=new THREE.Vector3(),q=new THREE.Quaternion(),s=new THREE.Vector3();bone.matrix.decompose(p,q,s);assert(p.distanceTo(c.rest[name].p)<1e-7,'rest length '+name);assert(s.distanceTo(c.rest[name].s)<1e-6);assert(bone.matrix.elements.every(Number.isFinite));}
  }
  assert(maxStep<.18,'smooth entry/exit '+kind+' '+sex+' '+maxStep);if(kind==='lookaround')assert(headMotion>.25);else assert(motion>.15,'visible arms '+kind);
  if(kind==='squat'){assert(drop>.12,'visible squat');assert(slip<.045,'feet stay planted '+sex+' '+slip);}
  let count=0;actor.object.traverse(o=>{if(o.isMesh)count++;});assert.equal(count,meshCount,'no new geometry/props');assert(!actor.object.getObjectByName('NPC_Phone').visible);
  tick(14);const neutralAfter=c.worldPosition('socket_hand_r');tick(14,{activity:{kind,phase:'active',since:1000,until:13000}});assert(c.worldPosition('socket_hand_r').distanceTo(neutralAfter)<.001);
  tick(14,{activity:{kind,phase:'active',since:1000,until:30000},panic:true});assert(!actor.object.getObjectByName('NPC_Phone').visible);
  rows.push({sex,kind,motion,slip,drop,maxStep,headMotion});
 }
 let constructions=0;const counted={...THREE};for(const key of ['Vector3','Quaternion','Matrix4','Euler','BoxGeometry','Mesh','Group','MeshStandardMaterial'])counted[key]=new Proxy(THREE[key],{construct(target,args){constructions++;return Reflect.construct(target,args);}});
 const overlay=createNpcActivityPose({THREE:counted,walker:actor.walker}),builds=constructions;
 for(const kind of ['stretch','squat','lookaround'])for(let i=0;i<30;i++){actor.walker.reset();overlay.apply({time:4+i*.05,life:{activity:{kind,phase:'active',since:1000,until:13000}}});assert.equal(constructions,builds,'no warmed THREE construction');}
 for(const flag of ['blocked','armed']){actor.walker.reset();c.object.updateMatrixWorld(true);const before=c.worldPosition('socket_hand_r');overlay.apply({time:5,[flag]:true,life:{activity:{kind:'stretch',phase:'active',since:1000,until:13000}}});assert(c.worldPosition('socket_hand_r').distanceTo(before)<1e-8,'overlay interrupted '+flag);}
 const owned=new Set();overlay.phone.traverse(o=>{if(o.geometry)owned.add(o.geometry);if(o.material)owned.add(o.material);});overlay.phone.removeFromParent();for(const resource of owned)resource.dispose();
 // Compare warmed alternating updates on the same actual actor/camera state.

 for(let i=0;i<200;i++){let t=performance.now();tick(20+i*.05);costs.idle.push(performance.now()-t);t=performance.now();tick(20+i*.05,{activity:{kind:i%2?'squat':'stretch',phase:'active',since:19000,until:40000}});costs.sport.push(performance.now()-t);}actor.dispose();
}
const stats=s=>{s.sort((a,b)=>a-b);return{p50:s[Math.floor(s.length*.5)],p95:s[Math.floor(s.length*.95)]}};
console.log(JSON.stringify({pass:true,rows,cpuMs:{idle:stats(costs.idle),sport:stats(costs.sport)},limits:'real male/female GLB bones; no GPU/scene FPS acceptance'}));
