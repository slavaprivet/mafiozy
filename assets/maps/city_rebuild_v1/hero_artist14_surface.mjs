import {createLazyHeadBruiseProjector} from './hero_bruise_projection.mjs';
import {validateSurfaceReceipts} from './npc_surface_state.mjs';
import {createWetClothing} from './artist14/wet_clothing.mjs';
import {createBulletWounds} from './artist14/bullet_wounds.mjs';
import {createSwimMotion} from './artist14/swim_motion.mjs';

// Presentation only. No damage, health, collision, locomotion or receipt creation.
export function createArtist14Surface({THREE,context,scene,applyReaction,applySwim}={}){
 if(!THREE||!context?.scene||!context?.object||!scene)throw Error('Artist14 context and world scene required');
 const model={root:context.scene,bones:context.bones},unit=context.targetHeight/context.sourceHeight;
 if(!(unit>0&&Number.isFinite(unit)))throw Error('Invalid author-to-world scale');
 const wet=createWetClothing(THREE),wounds=createBulletWounds(THREE,{worldScale:unit}),swim=createSwimMotion(THREE),receipts=new Set();
 // Attach wetness before wounds to avoid treating cosmetic geometry as clothes.
 wet.attach(model);
 // Project accepted author-space under-eye patches onto actual bind skin, then
 // carry them in head-local coordinates. Never substitute a floating plane.
 const bruises=[],bruiseStrength=[0,0];
 const projectBruise=createLazyHeadBruiseProjector(THREE,context);
 if(model.bones.head)for(const side of [-1,1]){
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute([],3));
  const material=new THREE.MeshStandardMaterial({vertexColors:true,transparent:true,opacity:0,depthWrite:false,roughness:1,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-1});
  const mark=new THREE.Mesh(geometry,material);mark.name='Artist14EyeBruise';mark.visible=false;mark.raycast=()=>{};mark.userData.bulletWound=true;model.bones.head.add(mark);bruises.push(mark);
 }
 function ensureBruise(index){const mark=bruises[index];if(mark&&!mark.userData.projectedBruise){const geometry=projectBruise(index===0?-1:1);if(geometry){mark.geometry.dispose();mark.geometry=geometry;mark.userData.projectedBruise=true;}}return mark;}
 wounds.attach(model);
 const particles=Array.from({length:112},()=>({life:0,maxLife:0,p:new THREE.Vector3(),v:new THREE.Vector3(),water:false}));
 const mesh=new THREE.InstancedMesh(new THREE.SphereGeometry(.028*unit,6,4),new THREE.MeshStandardMaterial({roughness:.55,transparent:true,opacity:.85}),particles.length);
 mesh.name='Artist14ContactParticles';mesh.frustumCulled=false;mesh.count=0;mesh.raycast=()=>{};scene.add(mesh);
 const transform=new THREE.Object3D(),color=new THREE.Color(),origin=new THREE.Vector3();
 let cursor=0,time=0,disposed=false,wasIn=false,exitAt=-Infinity,waterBudget=0,deepest=0,reaction={kind:'idle',at:0,side:1,zone:null};
 function emit(point,water,count,normal){for(let i=0;i<count;i++){const p=particles[cursor++%particles.length],a=cursor*2.399963;p.water=water;p.life=p.maxLife=water?.3+(i%3)*.05:.35+(i%5)*.07;p.p.copy(point);p.v.set(Math.sin(a)*(water?.7:1.5),water?.85:1.1+(i%4)*.4,Math.cos(a)*(water?.7:1.3)).multiplyScalar(unit);if(normal)p.v.addScaledVector(normal,.6*unit);}}
 const finite=v=>v&&Number.isFinite(v.x)&&Number.isFinite(v.y)&&Number.isFinite(v.z);
 function receive(event){
  if(disposed||event?.confirmed!==true||event.id===undefined||event.id===null||receipts.has(String(event.id)))return false;
  // A death receipt may omit point. All visible injury effects require exact contact.
  if(!event.fatal&&!event.dead&&!finite(event.point))return false;
  receipts.add(String(event.id));while(receipts.size>512)receipts.delete(receipts.values().next().value);
  const blocked=event.blocked===true,dead=event.fatal===true||event.dead===true;
  const alreadyDown=reaction.kind==='fall'&&time-reaction.at<2.7;
  const knockdown=event.knockdown===true||(event.knockdown!==false&&(event.heavy===true||event.kind==='dropkick'));
  if(reaction.kind!=='dead')reaction={kind:dead?'dead':alreadyDown?'fall':blocked?'block':knockdown?'fall':'hit',at:alreadyDown&&!dead?reaction.at:time,side:event.side===-1?-1:1,zone:event.zone||null};
  if(!blocked&&finite(event.point)&&event.zone==='head'){const eye=event.side===-1?0:1;bruiseStrength[eye]=Math.min(1,bruiseStrength[eye]+.45);if(ensureBruise(eye)){bruises[eye].visible=true;bruises[eye].material.opacity=bruiseStrength[eye]*.82;}}
  if(!blocked&&finite(event.point)){
   const point=new THREE.Vector3(event.point.x,event.point.y,event.point.z),normal=finite(event.normal)?new THREE.Vector3(event.normal.x,event.normal.y,event.normal.z).normalize():null;
   emit(point,false,event.heavy?18:10,normal);
   if(normal&&(event.kind==='bullet'||event.projectile===true))wounds.add(model,{...event,point,normal});
  }
  return true;
 }
 function update(dt,{time:now,waterLevel=null,inWater=false,moving=false,fast=false,chestWorldY,groundWorldY,blocked=false}={}){
  if(disposed)return null;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid surface dt');dt=Math.min(dt,.25);time=Number.isFinite(now)?now:time+dt;
  context.object.updateWorldMatrix(true,true);context.object.getWorldPosition(origin);
  const ground=Number.isFinite(groundWorldY)?groundWorldY:origin.y,water=inWater&&Number.isFinite(waterLevel)?waterLevel:null;
  const chest=Number.isFinite(chestWorldY)?chestWorldY:ground+3*unit;
  const sw=swim.step({dt,time,waterLevel:water===null?null:(water-ground)/unit,chestHeight:(chest-ground)/unit,hasMovement:moving,fast,blocked:blocked||reaction.kind==='dead'||reaction.kind==='fall'});
  const age=time-reaction.at,duration={hit:.48,block:.30,fall:2.7}[reaction.kind];if(duration&&age>=duration)reaction={kind:'idle',at:time,side:1,zone:null};
  // Host callbacks run after its base pose, before surface anchors/sample update.
  if(applySwim)applySwim({...sw,liftWorld:sw.lift*unit,speedWorld:sw.speed*unit},context);
  if(applyReaction&&reaction.kind!=='idle')applyReaction({...reaction,age:Math.max(0,time-reaction.at),unit},context);
  context.object.updateWorldMatrix(true,true);wet.setWaterLevel(water);wet.update(model,time,dt);wounds.update(model);
  if(water!==null)deepest=wasIn?Math.max(deepest,water-ground):water-ground;
  if(wasIn&&water===null){exitAt=time;waterBudget=0;}wasIn=water!==null;
  const shedding=water===null&&time-exitAt>=0&&time-exitAt<5;
  if(moving&&(water!==null||shedding)){waterBudget+=dt;while(waterBudget>=.11){waterBudget-=.11;const name=shedding&&deepest>2.2*unit&&cursor%3===0?'chest':'foot_'+(cursor%2?'l':'r'),bone=model.bones[name];if(!bone)continue;bone.getWorldPosition(origin);if(water!==null)origin.y=Math.max(origin.y,water+.025*unit);emit(origin,true,3);}}else waterBudget=0;
  let count=0;for(const p of particles){if(p.life<=0)continue;p.life-=dt;if(p.life<=0)continue;p.v.y-=9.8*unit*dt;p.p.addScaledVector(p.v,dt);if(p.p.y<ground){p.life=0;continue;}transform.position.copy(p.p);transform.scale.set(.7,1.5,.7).multiplyScalar(Math.min(1,p.life*8));transform.updateMatrix();mesh.setMatrixAt(count,transform.matrix);color.set(p.water?0x9ec6cf:0x8c1524);mesh.setColorAt(count++,color);}
  mesh.count=count;mesh.instanceMatrix.needsUpdate=true;if(mesh.instanceColor)mesh.instanceColor.needsUpdate=true;
  return {swim:{...sw,liftWorld:sw.lift*unit,speedWorld:sw.speed*unit},reaction:{...reaction,age:Math.max(0,time-reaction.at)},shedding,secondsLeft:shedding?5-(time-exitAt):0};
 }
 function reset(){wet.reset(model);wounds.reset(model);swim.reset();receipts.clear();reaction={kind:'idle',at:time,side:1,zone:null};bruiseStrength.fill(0);for(const mark of bruises){mark.visible=false;mark.material.opacity=0;}for(const p of particles)p.life=0;mesh.count=0;wasIn=false;exitAt=-Infinity;waterBudget=0;deepest=0;}
 function dispose(){if(disposed)return;reset();disposed=true;mesh.removeFromParent();mesh.geometry.dispose();mesh.material.dispose();for(const mark of bruises){mark.removeFromParent();mark.geometry.dispose();mark.material.dispose();}}
 function snapshot(){if(disposed)throw Error('Surface disposed');return {version:1,time,reaction:{kind:reaction.kind,age:Math.max(0,time-reaction.at),side:reaction.side,zone:reaction.zone},bruises:[...bruiseStrength],receipts:[...receipts],wet:wet.snapshot(model),wounds:wounds.snapshot(model)};}
 function restore(data,{time:now,elapsedSeconds=0}={}){
  if(disposed)throw Error('Surface disposed');
  if(data?.version!==1||!Number.isFinite(data.time)||!Number.isFinite(elapsedSeconds)||elapsedSeconds<0||now!==undefined&&!Number.isFinite(now))throw Error('Invalid surface state time/version');
  const r=data.reaction;if(!r||!['idle','hit','block','fall','dead'].includes(r.kind)||!Number.isFinite(r.age)||r.age<0||![-1,1].includes(r.side)||r.zone!==null&&(typeof r.zone!=='string'||r.zone.length>128)||!Array.isArray(data.bruises)||data.bruises.length!==2||data.bruises.some(v=>!Number.isFinite(v)||v<0||v>1))throw Error('Invalid surface reaction/bruises');
  if(!Number.isFinite(now??data.time+elapsedSeconds)||!Number.isFinite(r.age+elapsedSeconds))throw Error('Surface time overflow');
  validateSurfaceReceipts(data.receipts);wet.validateSnapshot(model,data.wet);wounds.validateSnapshot(model,data.wounds);
  // Validate the complete payload before mutating anything. Never replay a hit in world space.
  reset();time=now??data.time+elapsedSeconds;wet.restore(model,data.wet,{elapsedSeconds});wounds.restore(model,data.wounds);
  for(const id of data.receipts)receipts.add(id);
  for(let i=0;i<2;i++){bruiseStrength[i]=data.bruises[i];if(bruiseStrength[i]>0)ensureBruise(i);if(bruises[i]){bruises[i].visible=bruiseStrength[i]>0;bruises[i].material.opacity=bruiseStrength[i]*.82;}}
  const age=r.age+elapsedSeconds,duration={hit:.48,block:.30,fall:2.7}[r.kind];reaction={kind:duration&&age>=duration?'idle':r.kind,at:time-age,side:r.side,zone:r.zone};
  return true;
 }
 return {receive,update,reset,dispose,snapshot,restore,model,particles:mesh,get state(){return {...reaction};},get scale(){return unit;}};
}
