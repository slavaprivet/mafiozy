// Actual GLB + real book triangles: normal source read expiry without finish.
// Baseline is reconstructed in memory by reversing only this scoped patch.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const socialUrl=new URL('./npc_social_pose.mjs',import.meta.url),actorUrl=new URL('./npc_actor.mjs',import.meta.url);
const current=fs.readFileSync(socialUrl,'utf8'),replaceOnce=(text,from,to)=>{assert.equal(text.split(from).length,2,'baseline source anchor');return text.replace(from,to)};
const envelope=`  let blend=activity.phase==='finish'?1-clamp(age/.6):clamp(age/.25);
  // Reading ends directly at until in the source, without a finish phase.
  if(activity.kind==='read'&&activity.phase==='active'&&Number.isFinite(activity.until))blend*=THREE.MathUtils.smoothstep((activity.until-time*1000)/1000,0,.6);
  if(blend<=0)return false;`;
let baseline=replaceOnce(current.replaceAll('\r\n','\n'),envelope,"  const blend=activity.phase==='finish'?1-clamp(age/.6):clamp(age/.25);if(blend<=0)return false;");
baseline=replaceOnce(baseline,'   if(blend<1){c.bones.socket_hand_l.getWorldPosition(from);c.bones.socket_hand_r.getWorldPosition(to);from.add(to).multiplyScalar(.5);from.y+=.015*unit;c.offset.worldToLocal(from);book.position.copy(from);}','');
const beforeSocial=socialUrl.href+'?reading-exit20-before',beforeActor=actorUrl.href+'?reading-exit20-before';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)},load(u,c,next){const result=next(u,c);if(u===beforeSocial)return {...result,source:baseline};if(u===beforeActor)return {...result,source:replaceOnce(String(result.source),"'./npc_social_pose.mjs'","'./npc_social_pose.mjs?reading-exit20-before'")};return result}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js'));
const {clone}=await import('./vendor/three_skeleton_utils.mjs');
const {createNpcActor:createBefore}=await import(beforeActor),{createNpcActor:createAfter,NPC_ASSETS}=await import(actorUrl.href);
const {createNpcSocialPose:createPoseBefore}=await import(beforeSocial),{createNpcSocialPose:createPoseAfter}=await import(socialUrl.href);
const position={x:4.1,y:0,z:8.2},seat={id:'reading-bench20',c:1,r:2,seatWorldY:.46,yaw:.2,phase:'sit',since:1000},activity={kind:'read',phase:'active',since:3000,until:6000};
const results=[],cpu={before:[],after:[]};
function surfaceDistance(point,book){
 let distance=Infinity;const a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3(),closest=new THREE.Vector3(),triangle=new THREE.Triangle(a,b,c);
 book.traverse(mesh=>{if(!mesh.isMesh)return;const vertices=mesh.geometry.attributes.position,index=mesh.geometry.index;for(let i=0;i<index.count;i+=3){a.fromBufferAttribute(vertices,index.getX(i)).applyMatrix4(mesh.matrixWorld);b.fromBufferAttribute(vertices,index.getX(i+1)).applyMatrix4(mesh.matrixWorld);c.fromBufferAttribute(vertices,index.getX(i+2)).applyMatrix4(mesh.matrixWorld);triangle.closestPointToPoint(point,closest);distance=Math.min(distance,point.distanceTo(closest))}});return distance;
}
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 const pair=[createBefore,createAfter].map(create=>create({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'read_exit20_'+sex,sex}));
 const tick=(actor,time,a,extra={})=>{actor.update(1/60,{time,position,yaw:.2,life:{seat,gesture:'read',activity:a,...extra}});assert.deepEqual(actor.object.position.toArray(),[4.1,0,8.2]);assert.equal(actor.object.rotation.y,.2)};
 for(const actor of pair){for(let frame=0;frame<=40;frame++)tick(actor,1+frame/60);tick(actor,4,activity)}
 const contexts=pair.map(a=>a.walker.artistContext()),books=pair.map(a=>a.object.getObjectByName('NPC_ReadingBook')),feet=contexts.map(c=>['l','r'].map(side=>c.worldPosition('foot_'+side)));
 assert.deepEqual(books[0].matrixWorld.toArray(),books[1].matrixWorld.toArray(),'full-weight authored book transform unchanged');
 for(const name of Object.keys(contexts[0].bones))assert.deepEqual(contexts[0].bones[name].matrixWorld.toArray(),contexts[1].bones[name].matrixWorld.toArray(),'full-weight pose unchanged '+name);
 const previous=contexts.map(c=>['l','r'].map(side=>c.worldPosition('socket_hand_'+side))),steps=[[],[]],expiry=[[],[]];let maxContact=0,maxSupportOffsetError=0,meshCount=0;
 pair[1].object.traverse(o=>{if(o.isMesh)meshCount++});
 for(let frame=0;frame<=42;frame++){
  const time=5.35+frame/60,a=time<6?activity:undefined;
  for(let i=0;i<2;i++){
   tick(pair[i],time,a);const c=contexts[i];for(const [j,side]of ['l','r'].entries()){const hand=c.worldPosition('socket_hand_'+side),delta=hand.distanceTo(previous[i][j]);steps[i].push(delta);if(time>=6&&time<6+1/60)expiry[i].push(delta);previous[i][j]=hand;assert(c.worldPosition('foot_'+side).distanceTo(feet[i][j])<1e-8,'bench foot anchor remains planted')}
  }
  if(time>5.4&&time<6){
   const c=contexts[1],palms=['l','r'].map(side=>c.worldPosition('socket_hand_'+side));
   for(const palm of palms)maxContact=Math.max(maxContact,surfaceDistance(palm,books[1]));
   const expected=palms[0].clone().add(palms[1]).multiplyScalar(.5);expected.y+=.015*pair[1].height/1.9;
   maxSupportOffsetError=Math.max(maxSupportOffsetError,books[1].getWorldPosition(new THREE.Vector3()).distanceTo(expected));
  }
  if(time>=6)assert(!books[1].visible,'no orphan book after source removes activity');
 }
 const beforeMax=Math.max(...steps[0]),afterMax=Math.max(...steps[1]);assert(beforeMax>.12);assert(afterMax<.02,'smooth lowering instead of expiry snap');assert(maxSupportOffsetError<1e-8,'real book transform follows actual palm pair');
 assert(maxContact<.008,'both palm anchors remain within 8mm of actual cover/page triangles');
 tick(pair[1],6.1,activity);assert(!books[1].visible,'expired stale snapshot cannot revive book');assert.equal(pair[1].diagnostics().lifeGesture,null,'read label cannot fall back to generic gesture');
 let afterMeshes=0;pair[1].object.traverse(o=>{if(o.isMesh)afterMeshes++});assert.equal(afterMeshes,meshCount,'no new meshes during lowering');
 for(const interruption of [{panic:true},{fleeing:true},{cuffed:true},{phoneCalling:true}]){
  for(const actor of pair)tick(actor,5.5,activity);assert(books[1].visible);
  for(const actor of pair)tick(actor,5.6,activity,interruption);assert(!books[1].visible,'interrupt immediately removes reading prop');
  for(const name of Object.keys(contexts[0].bones))assert.deepEqual(contexts[0].bones[name].matrixWorld.toArray(),contexts[1].bones[name].matrixWorld.toArray(),'immediate priority parity '+name);
 }
 results.push({sex,beforeMaxHandStepMetres:beforeMax,afterMaxHandStepMetres:afterMax,beforeExpiryHandSteps:expiry[0],afterExpiryHandSteps:expiry[1],maxPalmDistanceToActualBookTrianglesMetres:maxContact,maxBookSupportOffsetErrorMetres:maxSupportOffsetError});
 pair.forEach(actor=>actor.dispose());
 // Instrument only the social overlay's allocations, excluding walker internals.
 const actor=createAfter({THREE,scene:new THREE.Scene(),source,cloneSkeleton:clone,id:'read_resources20_'+sex,sex});
 let constructions=0;const counted={...THREE};for(const key of ['Vector3','Quaternion','Matrix4','Euler','BoxGeometry','CylinderGeometry','Mesh','Group','MeshStandardMaterial'])counted[key]=new Proxy(THREE[key],{construct(target,args){constructions++;return Reflect.construct(target,args)}});
 const overlays=[createPoseBefore({THREE:counted,walker:actor.walker}),createPoseAfter({THREE:counted,walker:actor.walker})];
 for(const pose of overlays){actor.walker.reset();pose.apply(activity,4)}const warm=constructions,resources=overlays.map(p=>p.diagnostics());
 for(let frame=0;frame<80;frame++)for(const i of frame%2?[1,0]:[0,1]){actor.walker.reset();const start=performance.now();overlays[i].apply(activity,5.4+(frame%36)/60);const elapsed=performance.now()-start;if(frame>=8)cpu[i?'after':'before'].push(elapsed);assert.equal(constructions,warm,'no warmed THREE constructors');assert.equal(overlays[i].diagnostics().resourceBuilds,resources[i].resourceBuilds,'no new prop resources')}
 overlays.forEach(p=>p.dispose());actor.dispose();
}
const stats=a=>{a.sort((x,y)=>x-y);return{samples:a.length,p50:a[Math.floor(a.length*.5)],p95:a[Math.floor(a.length*.95)]}};
console.log(JSON.stringify({pass:true,results,cpuOverlayMs:{before:stats(cpu.before),after:stats(cpu.after)},limits:'Actual male/female CPU rigs and actual book triangles; palm sockets are contact anchors, not a full finger/skin intersection proof. No LIVE/GPU/full-scene FPS acceptance.'},null,2));
