// /walk adapter for the existing world.html vehicle rules; never a server authority.
import {createVehicleFireFx} from './vehicle_fire_fx.mjs';
import {isBreakableGlass} from './glass_breakage.mjs';
import {createVehicleCrash,subdivideVehicleGeometry} from './vehicle_crash.mjs';
export const VEHICLE_DAMAGE_RULES=Object.freeze({sedanHp:240,suvHp:360,vanHp:420,armor:1.65,smokeRatio:.55,fireRatio:.24,destructionSeconds:1.55,crashCooldown:.25,crashMax:80,metersPerTile:4.1,rpgCarRadius:1.55*4.1});
export function createVehicleDamageState({maxHp=240,armor=1}={}){
 if(!Number.isFinite(maxHp)||maxHp<120||!Number.isFinite(armor)||armor<1)throw Error('Invalid vehicle damage profile');
 return{maxHp,hp:maxHp,armor,smoking:false,burning:false,destroying:false,wrecked:false,destroyRemaining:0,wreckAge:0,explosions:0,recentHits:[],lastDamage:0};
}
export function vehicleCrashDamage(impactMetersPerSecond){
 if(!Number.isFinite(impactMetersPerSecond)||impactMetersPerSecond<=0)return 0;
 return Math.min(80,Math.round((impactMetersPerSecond/4.1)**2*1.4));
}
export function applyVehicleDamage(state,{damage,eventId=null,kind='gun'}={}){
 if(!Number.isFinite(damage)||damage<=0||state.destroying||state.wrecked||eventId!==null&&state.recentHits.includes(eventId))return state;
 const amount=kind==='rpg'?state.hp:kind==='collision'?Math.max(0,Math.min(100,Math.round(damage))):Math.max(4,Math.round(damage/state.armor));
 if(!amount)return state;
 const hp=Math.max(0,state.hp-amount),ratio=hp/state.maxHp,destroying=hp===0;
 return{...state,hp,lastDamage:amount,recentHits:eventId===null?state.recentHits:[...state.recentHits,eventId].slice(-64),smoking:state.smoking||ratio<=.55,burning:state.burning||(!destroying&&ratio<=.24),destroying,destroyRemaining:destroying?(kind==='collision'||kind==='rpg'?0:1.55):0,externalBlast:kind==='rpg'};
}
export function stepVehicleDamage(state,dt){
 if(!Number.isFinite(dt)||dt<0)throw Error('Invalid vehicle damage time');
 if(state.wrecked)return{...state,wreckAge:state.wreckAge+dt};
 if(!state.destroying)return state;
 const remaining=Math.max(0,state.destroyRemaining-dt);
 return remaining?{...state,destroyRemaining:remaining}:{...state,destroyRemaining:0,destroying:false,wrecked:true,wreckAge:Math.max(0,dt-state.destroyRemaining),smoking:true,burning:true,explosions:state.explosions+1};
}

export function createVehicleDamage(T,car,{profile={},onExplosion=()=>{},scene=car.object.parent,groundHeight=()=>0,allowed=()=>true,getState=()=>({}),trunk=car.trunk||null}={}){
 let state=createVehicleDamageState(profile),time=0,lastCrash=-Infinity,markCursor=0,disposed=false,idleWreckUpdates=0;
 const crash=createVehicleCrash(T,car,{scene,groundHeight,allowed,getState,trunk});
 car.object.userData.vehicleDamageTarget='walk_sedan';
 const object=new T.Group();object.name='Vehicle_damage_effects';car.object.add(object);
 const debrisObject=new T.Group();debrisObject.name='Vehicle_world_wreck_debris';(scene||car.object).add(debrisObject);
 const geometryRest=new Map(),authoredGeometry=new Map(),materialRest=new Map(),transformRest=new Map(),visibilityRest=new Map(),glass=[];
 car.object.traverse(mesh=>{if(mesh.isMesh&&mesh.geometry)authoredGeometry.set(mesh,mesh.geometry)});
 car.object.traverse(mesh=>{if(!mesh.isMesh)return;if(mesh.material?.transparent)glass.push(mesh);if(mesh.material?.color&&!materialRest.has(mesh.material))materialRest.set(mesh.material,{color:mesh.material.color.clone(),roughness:mesh.material.roughness});});
 for(const mesh of car.shell||[])transformRest.set(mesh,{position:mesh.position.clone(),rotation:mesh.rotation.clone(),scale:mesh.scale.clone()});
 const markMaterial=new T.MeshStandardMaterial({color:'#ffffff',vertexColors:true,roughness:.95,transparent:true,opacity:.8,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
 const scratchMaterial=new T.MeshStandardMaterial({color:'#adaca0',roughness:.72,metalness:.25,transparent:true,opacity:.85,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2});
 // A dark crater and exposed metal lip share one geometry/material/draw call.
 // Every mark still lives in the same bounded 32-slot pool.
 function craterGeometry(){
  const positions=[],colors=[],normal=[],dark=new T.Color('#231e19'),rim=new T.Color('#88857a');
  const emit=(a,b,c,color)=>{for(const v of [a,b,c]){positions.push(...v);colors.push(color.r,color.g,color.b);normal.push(0,0,1)}};
  for(let i=0;i<12;i++){
   const a=i*Math.PI/6,b=(i+1)*Math.PI/6,inner=t=>[Math.cos(t)*.018,Math.sin(t)*.018,0],outer=t=>[Math.cos(t)*.024,Math.sin(t)*.024,.001];
   emit([0,0,-.001],inner(a),inner(b),dark);emit(inner(a),outer(a),outer(b),rim);emit(inner(a),outer(b),inner(b),rim);
  }
  const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(positions,3));geometry.setAttribute('normal',new T.Float32BufferAttribute(normal,3));geometry.setAttribute('color',new T.Float32BufferAttribute(colors,3));return geometry;
 }
 const marks=Array.from({length:32},(_,i)=>{const mesh=new T.Mesh(i%3?craterGeometry():new T.PlaneGeometry(.22,.008),i%3?markMaterial:scratchMaterial);mesh.visible=false;mesh.raycast=()=>{};object.add(mesh);return mesh});
 const fireFx=createVehicleFireFx(T,car,{scene,groundHeight});
 // Ten bounded assemblies use the real door, lid and wheel geometry. The
 // persistent chassis keeps its original meshes; detached copies own resources.
 const debris=[];
 // Detached assemblies are the only short-lived per-frame wreck workload.
 // Reuse these scratch objects so an explosion never creates two math objects
 // per live part per animation frame (up to ten real assemblies at once).
 const debrisEuler=new T.Euler(),debrisRotation=new T.Quaternion(),debrisInverse=new T.Matrix4(),debrisVertex=new T.Vector3(),debrisWorld=new T.Vector3();
 function releasePart(part){part.mesh.removeFromParent();part.mesh.traverse(node=>{node.geometry?.dispose();if(Array.isArray(node.material))node.material.forEach(m=>m.dispose());else node.material?.dispose()})}
 function copyPart(source){
  if(!source.visible||source===object||marks.includes(source)||source.isLine||source.material?.transparent)return null;
  const node=source.isMesh?new T.Mesh(source.geometry.clone(),Array.isArray(source.material)?source.material.map(m=>m.clone()):source.material.clone()):new T.Group();
  node.name=source.name;node.position.copy(source.position);node.quaternion.copy(source.quaternion);node.scale.copy(source.scale);node.castShadow=true;node.raycast=()=>{};
  for(const child of source.children){const copy=copyPart(child);if(copy)node.add(copy)}return node;
 }
 function detachParts(){
  car.object.updateWorldMatrix(true,true);debrisObject.updateWorldMatrix(true,false);
  const sources=[...car.doors.values(),...(car.shell||[]).filter(m=>['Hood_lid','Trunk_lid'].includes(m.name)),...car.wheels.map(w=>w.pivot)];
  for(const [i,source]of sources.slice(0,10).entries()){
   const mesh=copyPart(source);if(!mesh)continue;
   const matrix=new T.Matrix4().copy(debrisObject.matrixWorld).invert().multiply(source.matrixWorld);matrix.decompose(mesh.position,mesh.quaternion,mesh.scale);
   debrisObject.add(mesh);visibilityRest.set(source,source.visible);source.visible=false;
   const start=mesh.position.clone(),origin=debrisObject.worldToLocal(car.object.getWorldPosition(new T.Vector3())),outward=start.clone().sub(origin);outward.y=0;if(outward.lengthSq()<.01)outward.set(Math.cos(i*2.399),0,Math.sin(i*2.399));outward.normalize();
   const angle=(Math.random()-.5)*1.2,strength=.65+Math.random()*.7;
   const velocity=outward.applyAxisAngle(new T.Vector3(0,1,0),angle).multiplyScalar((3.5+i%3*.65)*strength),motion=getState()||{},speed=Math.max(-35,Math.min(35,Number(motion.speed)||0)),heading=motion.travelYaw??motion.yaw??car.object.rotation.y;velocity.x+=Math.sin(heading)*speed;velocity.z+=Math.cos(heading)*speed;
   velocity.y=2.8+Math.random()*2.4;
   mesh.updateWorldMatrix(true,true);const localInverse=mesh.matrixWorld.clone().invert(),bounds=new T.Box3(),v=new T.Vector3();
   mesh.traverse(node=>{const p=node.geometry?.attributes?.position;if(p)for(let j=0;j<p.count;j++)bounds.expandByPoint(v.fromBufferAttribute(p,j).applyMatrix4(node.matrixWorld).applyMatrix4(localInverse))});
   const size=bounds.getSize(new T.Vector3()),thin=size.x<=size.y&&size.x<=size.z?new T.Vector3(1,0,0):size.y<=size.z?new T.Vector3(0,1,0):new T.Vector3(0,0,1);
   const landing=new T.Quaternion().setFromAxisAngle(new T.Vector3(0,1,0),Math.random()*Math.PI*2).multiply(new T.Quaternion().setFromUnitVectors(thin,new T.Vector3(0,1,0)));
   debris.push({mesh,start,quaternion:mesh.quaternion.clone(),landing,born:time,velocity,spin:new T.Vector3((Math.random()-.5)*6,(Math.random()-.5)*6,(Math.random()-.5)*6)});
  }
 }
 function owns(mesh){for(let node=mesh;node;node=node.parent)if(node===car.object)return true;return false}
 // Explicit pickup hook for future waste collection. Cleanup never respawns the
 // detached originals or resets the wreck's HP, fire or damage state.
 function clearDebris(){const count=debris.length+crash.clearDebris()+(trunk?.clearDebris?.()||0);for(const part of debris)releasePart(part);debris.length=0;return count}
 function deformableGeometry(original){
  // Rounded boxes often have very large flat triangles. Subdivide those faces
  // once so a shot in the panel centre creates a local dent, not just edge marks.
  const source=original.index?original.toNonIndexed():original.clone(),p=source.attributes.position,vertices=[];
  const distance=(a,b)=>(a[0]-b[0])**2+(a[1]-b[1])**2+(a[2]-b[2])**2;
  function split(a,b,c,depth){const ab=distance(a,b),bc=distance(b,c),ca=distance(c,a);if(depth>=10||Math.max(ab,bc,ca)<.0225){vertices.push(...a,...b,...c);return}if(bc>=ab&&bc>=ca){const m=b.map((v,i)=>(v+c[i])/2);split(a,b,m,depth+1);split(a,m,c,depth+1)}else if(ca>=ab){const m=c.map((v,i)=>(v+a[i])/2);split(a,b,m,depth+1);split(m,b,c,depth+1)}else{const m=a.map((v,i)=>(v+b[i])/2);split(a,m,c,depth+1);split(m,b,c,depth+1)}}
  for(let i=0;i<p.count;i+=3)split([p.getX(i),p.getY(i),p.getZ(i)],[p.getX(i+1),p.getY(i+1),p.getZ(i+1)],[p.getX(i+2),p.getY(i+2),p.getZ(i+2)],0);
  source.dispose();const geo=new T.BufferGeometry();geo.setAttribute('position',new T.Float32BufferAttribute(vertices,3));geo.computeVertexNormals();return geo;
 }
 function dent(mesh,point,normal,damage,collision=false){
  if(!mesh?.geometry?.attributes?.position||mesh.material?.transparent)return;
  for(let node=mesh;node;node=node.parent)if(node.userData?.vehicleWheelId)return; // Tyre adapter owns wheel deformation.
  if(!geometryRest.has(mesh)){const original=authoredGeometry.get(mesh)||mesh.geometry;if(!mesh.geometry.userData.vehicleCrashSubdivided)mesh.geometry=subdivideVehicleGeometry(T,mesh.geometry,.15,9000);geometryRest.set(mesh,{original,geometry:mesh.geometry,base:mesh.geometry.attributes.position.array.slice(),offset:new Float32Array(mesh.geometry.attributes.position.array.length)})}
  const rest=geometryRest.get(mesh);rest.maxDepth=Math.max(rest.maxDepth||0,collision?.40:.18);
  // Structural settling and bullets share one tessellated BufferGeometry.
  // Keep only the bullet offset here; cage movement is the changing baseline.
  if(rest.geometry!==mesh.geometry){rest.geometry=mesh.geometry;rest.base=mesh.geometry.attributes.position.array.slice();rest.offset=new Float32Array(rest.base.length)}
  const currentPositions=mesh.geometry.attributes.position;for(let i=0;i<rest.base.length;i++)rest.base[i]=currentPositions.array[i]-rest.offset[i];
  mesh.updateWorldMatrix(true,false);const local=mesh.worldToLocal(point.clone()),inverse=new T.Matrix4().copy(mesh.matrixWorld).invert(),n=normal.clone().transformDirection(inverse);
  const radius=collision?Math.min(1.1,.3+collision.impactSpeed*.035):.10+Math.min(.20,Math.sqrt(damage)*.014),depth=collision?Math.min(.30,.012+collision.impactSpeed**2*.0028):Math.min(.10,.008+damage*.00055),positions=mesh.geometry.attributes.position,base=geometryRest.get(mesh).base,v=new T.Vector3();
  for(let i=0;i<positions.count;i++){v.set(base[i*3],base[i*3+1],base[i*3+2]);const d=v.distanceTo(local);if(d>=radius)continue;const falloff=(1-d/radius)**2;v.fromBufferAttribute(positions,i).addScaledVector(n,-depth*falloff);const origin=new T.Vector3(base[i*3],base[i*3+1],base[i*3+2]),shift=v.clone().sub(origin);const maxDepth=rest.maxDepth;if(shift.length()>maxDepth)v.copy(origin).addScaledVector(shift.normalize(),maxDepth);positions.setXYZ(i,v.x,v.y,v.z);rest.offset.set([v.x-origin.x,v.y-origin.y,v.z-origin.z],i*3)}
  positions.needsUpdate=true;mesh.geometry.computeVertexNormals();mesh.geometry.computeBoundingBox();mesh.geometry.computeBoundingSphere();
 }
 function mark(mesh,point,normal,collision=false,damage=24){
  if(!collision)while((markCursor%marks.length)%3===0)markCursor++;
  const entry=marks[markCursor++%marks.length];mesh.updateWorldMatrix(true,false);mesh.add(entry);entry.visible=true;
  entry.position.copy(mesh.worldToLocal(point.clone()));const n=normal.clone().transformDirection(new T.Matrix4().copy(mesh.matrixWorld).invert());entry.position.addScaledVector(n,.007);entry.quaternion.setFromUnitVectors(new T.Vector3(0,0,1),n);entry.scale.setScalar(collision?2.2:Math.min(3.2,.75+Math.sqrt(Math.max(0,damage))*.16));entry.rotateZ(markCursor*2.399);
 }
 function impact(payload){
  const mesh=payload.object||payload.hit?.object,point=payload.point||payload.hit?.point,center=car.object.getWorldPosition(new T.Vector3()),explosive=!!payload.explosive&&point&&Math.hypot(point.x-center.x,point.z-center.z)<=VEHICLE_DAMAGE_RULES.rpgCarRadius;
  if(disposed||(!owns(mesh)&&!explosive)||!Number.isFinite(payload.damage)||payload.damage<=0)return false;
  // The glass adapter handles pane fracture independently. A bullet stopped by
  // glass must not also damage the body; blast damage still affects the car.
  const hit=payload.hit||payload,faceIndex=hit.faceIndex;
  const materialIndex=hit.face?.materialIndex??(Number.isInteger(faceIndex)?mesh?.geometry?.groups?.find(g=>faceIndex*3>=g.start&&faceIndex*3<g.start+g.count)?.materialIndex:undefined);
  const material=Array.isArray(mesh?.material)?mesh.material[materialIndex??0]:mesh?.material;
  if(!explosive&&isBreakableGlass(mesh,material))return false;
  const before=state;state=applyVehicleDamage(state,{damage:payload.damage,eventId:payload.shotId??payload.eventId??null,kind:explosive?'rpg':'gun'});
  if(owns(mesh)&&(!state.wrecked&&!state.destroying||before!==state)){if(point){const normal=payload.normal?.clone?.()||new T.Vector3(0,0,1);dent(mesh,point,normal,payload.damage);const surface=new T.Raycaster(point.clone().addScaledVector(normal,.5),normal.clone().negate(),0,1).intersectObject(mesh,false)[0];mark(mesh,surface?.point||point,surface?.face?.normal.clone().applyMatrix3(new T.Matrix3().getNormalMatrix(mesh.matrixWorld)).normalize()||normal,false,payload.damage)}}
  return before!==state;
 }
 // World-space surface contact; normal points out of the body toward the
 // obstacle. A supplied slideDirection follows the tangential relative motion.
 // The short ray finds the actual panel (and its current dent), never the wheel,
 // transparent pane or effect meshes. Legacy speed-loss callers remain valid.
 function contactImpact(contact){
  if(disposed||time-lastCrash<.25||state.destroying||state.wrecked)return false;
  const point=contact?.point,normal=contact?.normal,impactSpeed=Math.max(0,Number(contact?.impactSpeed)||0),slideSpeed=Math.max(0,Number(contact?.slideSpeed)||0);
  if(!point||!normal||![point.x,point.y,point.z,normal.x,normal.y,normal.z,impactSpeed,slideSpeed].every(Number.isFinite))return false;
  const n=new T.Vector3(normal.x,normal.y,normal.z);if(n.lengthSq()<1e-8)return false;n.normalize();
  const damage=vehicleCrashDamage(impactSpeed);if(!damage&&slideSpeed<1.5)return false;
  car.object.updateWorldMatrix(true,true);
  const center=car.object.localToWorld(new T.Vector3(0,.75,0)),p=new T.Vector3(point.x,point.y,point.z);
  if(n.dot(p.clone().sub(center))<0)n.negate();
  const candidates=[];car.object.traverse(mesh=>{if(!mesh.isMesh||!mesh.geometry||mesh.material?.transparent||marks.includes(mesh))return;for(let node=mesh;node;node=node.parent){if(!node.visible||node===object||node.userData?.vehicleWheelId)return}candidates.push(mesh)});
  const ray=new T.Raycaster(p.clone().addScaledVector(n,.8),n.clone().negate(),0,1.65),hit=ray.intersectObjects(candidates,false)[0];
  // A contact on a wheel or a gap can transfer impulse to the chassis, but must
  // not create a dent at an unrelated panel on the opposite side of the car.
  lastCrash=time;
  // Mechanical crash failure is not an automatic fuel explosion. Weapon and
  // blast destruction retain their existing authority/thresholds.
  if(damage){const burning=state.burning;state=applyVehicleDamage(state,{damage,kind:'collision'});state={...state,hp:Math.max(1,state.hp),destroying:false,destroyRemaining:0,burning}}
  crash.contactImpact({...contact,normal:n});trunk?.contactImpact?.({...contact,normal:n},getState());
  if(hit){
   const surfaceNormal=hit.face?.normal.clone().applyMatrix3(new T.Matrix3().getNormalMatrix(hit.object.matrixWorld)).normalize()||n;
   if(damage)dent(hit.object,hit.point,surfaceNormal,damage,{impactSpeed});
   // Re-project onto the deformed surface so paint damage stays on the panel.
   const marked=ray.intersectObject(hit.object,false)[0]||hit;
   if(slideSpeed>=1.5){
    const direction=contact.slideDirection, tangent=direction?new T.Vector3(direction.x,direction.y,direction.z):new T.Vector3(0,1,0).cross(surfaceNormal);
    tangent.addScaledVector(surfaceNormal,-tangent.dot(surfaceNormal));
    if(!Number.isFinite(tangent.lengthSq())||tangent.lengthSq()<1e-8)tangent.set(1,0,0).addScaledVector(surfaceNormal,-surfaceNormal.x);
    if(tangent.lengthSq()<1e-8)tangent.set(0,0,1);tangent.normalize();
    // Use a scratch slot rather than the round bullet hole slots.
    while(markCursor%3)markCursor++;
    // marks wraps at 32: find the next physical scratch slot as well.
    while((markCursor%marks.length)%3)markCursor++;
    const scratch=marks[markCursor%marks.length];mark(hit.object,marked.point,surfaceNormal,true);
    const inverse=new T.Matrix4().copy(hit.object.matrixWorld).invert(),localTangent=tangent.transformDirection(inverse);
    const z=new T.Vector3(0,0,1).applyQuaternion(scratch.quaternion),y=new T.Vector3().crossVectors(z,localTangent).normalize();
    scratch.quaternion.setFromRotationMatrix(new T.Matrix4().makeBasis(localTangent,y,z));
    scratch.scale.set(Math.min(5,1+slideSpeed*.16),1+Math.min(2,impactSpeed*.12),1);
   }else if(damage)mark(hit.object,marked.point,surfaceNormal,true);
  }
  return damage>0||!!hit;
 }
 function blastImpact({damage,eventId=null}={}){const before=state;state=applyVehicleDamage(state,{damage,eventId,kind:'blast'});return state!==before}
 function collision(before,after){
  if(!after?.bumped)return false;
  if(after.contact)return contactImpact(after.contact);
  const lost=Math.max(0,Math.abs(before.speed)-Math.abs(after.speed));
  car.object.updateWorldMatrix(true,true);const sign=before.speed>=0?1:-1,yaw=before.travelYaw??before.yaw??car.object.rotation.y,normal=new T.Vector3(Math.sin(yaw)*sign,0,Math.cos(yaw)*sign),center=car.object.localToWorld(new T.Vector3(0,.75,0));
  const ray=new T.Raycaster(center.clone().addScaledVector(normal,4),normal.clone().negate(),0,5),hit=ray.intersectObject(car.object,true).find(item=>item.object.visible&&!item.object.material?.transparent);
  return contactImpact({point:hit?.point||center.clone().addScaledVector(normal,2),normal,impactSpeed:lost,slideSpeed:0});
 }
 function update(dt){
  if(disposed)return;if(!Number.isFinite(dt)||dt<0)throw Error('Invalid vehicle damage time');
  // The normal fleet path has neither damage effects nor detached parts.  Do
  // not allocate a trunk stats snapshot there: it is relevant only while an
  // old wreck decides whether every persistent assembly has settled.  Keep
  // advancing the crash adapter exactly as before, because it owns mechanical
  // wear even when the visible damage presentation is idle.
  if(!state.smoking&&!state.burning&&!state.destroying&&!state.wrecked&&!debris.length){
   time+=dt;crash.update(dt);return;
  }
  const trunkStats=trunk?.stats?.(),trunkSettled=!trunkStats||!('settledDebris'in trunkStats)||trunkStats.debris===trunkStats.settledDebris;
  // After the finite fire/explosion sequence, an old wreck is immutable: its
  // charred frame and grounded real parts stay rendered, but need no CPU work.
  if(state.wrecked&&state.wreckAge>=5&&debris.every(part=>part.settled)&&crash.isIdle&&trunkSettled){idleWreckUpdates++;return}
  // Undamaged cars have no animated smoke, fire, blast or debris. Their
  // authored body and static impact marks need no frame-time work; effects
  // begin on the exact update after damage changes the state.
  time+=dt;
  crash.update(dt);
  const prior=state.explosions;state=stepVehicleDamage(state,dt);
  if(state.explosions>prior){for(const material of materialRest.keys())if(material.color&&!material.transparent){material.color.lerp(new T.Color('#100f0e'),.94);material.roughness=.99}onExplosion({vehicle:car,state,point:car.object.getWorldPosition(new T.Vector3())});for(const pane of glass)pane.visible=false;detachParts()}
  // Pooled shader flames, smoke, embers and the one vehicle blast.
  fireFx.update(dt,state,time);
  for(const part of debris){
   if(part.settled)continue;
   const age=time-part.born,t=Math.min(age,1.8),travel=(1-Math.exp(-t*.65))/.65;
   part.mesh.position.copy(part.start).addScaledVector(part.velocity,travel);
   part.mesh.position.y=Math.max(.20,part.start.y+part.velocity.y*t-4.9*t*t);
   part.mesh.quaternion.copy(part.quaternion).multiply(debrisRotation.setFromEuler(debrisEuler.set(part.spin.x*t,part.spin.y*t,part.spin.z*t)));
   part.mesh.quaternion.slerp(part.landing,Math.max(0,Math.min(1,(t-.8))));
   // Keep the real assemblies beside this wreck until reset/dispose. Put the
   // lowest vertex on the ground, rather than sinking a door/wheel around its
   // pivot, then stop all per-frame work for this settled assembly.
   if(age>=1.8){
    const inverse=debrisInverse.copy(debrisObject.matrixWorld).invert(),vertex=debrisVertex;let lowest=Infinity;
    part.mesh.updateWorldMatrix(true,true);
    part.mesh.traverse(node=>{const p=node.geometry?.attributes?.position;if(!p)return;for(let i=0;i<p.count;i++){vertex.fromBufferAttribute(p,i).applyMatrix4(node.matrixWorld).applyMatrix4(inverse);lowest=Math.min(lowest,vertex.y)}});
    const world=part.mesh.getWorldPosition(debrisWorld);if(Number.isFinite(lowest))part.mesh.position.y+=groundHeight(world.x,world.z)+.02-lowest;
    part.settled=true;
   }
  }
 }
 function repairPowertrain(){
  if(disposed||state.destroying||state.wrecked||state.burning)return{accepted:false,reason:disposed?'disposed':state.burning?'burning':'destroyed'};
  const mechanical=crash.state,changed=mechanical.engine<1||mechanical.radiator<1||mechanical.temperature>0;
  mechanical.engine=1;mechanical.radiator=1;mechanical.temperature=0;
  if(changed)mechanical.revision++;state={...state,smoking:false};fireFx.update(0,state,time);
  return{accepted:true,repaired:changed,components:['engine','radiator','cooling'],bodyHp:state.hp};
 }
function reset(){state=createVehicleDamageState(profile);time=0;lastCrash=-Infinity;markCursor=0;idleWreckUpdates=0;for(const mesh of marks){object.add(mesh);mesh.visible=false}fireFx.reset();for(const part of debris)releasePart(part);debris.length=0;for(const [part,visible]of visibilityRest)part.visible=visible;visibilityRest.clear();for(const [mesh,rest]of geometryRest){if(mesh.geometry!==rest.original)mesh.geometry.dispose();mesh.geometry=rest.original}geometryRest.clear();for(const [material,rest]of materialRest){material.color.copy(rest.color);material.roughness=rest.roughness}for(const [mesh,rest]of transformRest){mesh.position.copy(rest.position);mesh.rotation.copy(rest.rotation);mesh.scale.copy(rest.scale)}for(const pane of glass)pane.visible=true;crash.reset();trunk?.reset?.();car.hood?.reset?.()}
 function dispose(){if(disposed)return;reset();fireFx.dispose();crash.dispose();debrisObject.removeFromParent();disposed=true;const geometries=new Set(),materials=new Set();object.traverse(mesh=>{if(mesh.geometry)geometries.add(mesh.geometry);if(mesh.material)materials.add(mesh.material)});object.removeFromParent();for(const g of geometries)g.dispose();for(const m of materials)m.dispose()}
 return{object,debrisObject,crash,impact,collision,contactImpact,blastImpact,update,reset,dispose,clearDebris,repairPowertrain,get state(){return state},get crashEffects(){return crash.effects},get disabled(){return state.destroying||state.wrecked},stats:()=>({hp:state.hp,maxHp:state.maxHp,smoking:state.smoking,burning:state.burning,destroying:state.destroying,wrecked:state.wrecked,explosions:state.explosions,marks:Math.min(markCursor,marks.length),debris:debris.length+crash.stats().debris,structure:crash.stats(),flames:fireFx.stats().flames,visualFx:fireFx.stats(),idleWreckUpdates})};
}
