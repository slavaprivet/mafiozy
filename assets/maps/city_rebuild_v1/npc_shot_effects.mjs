import {createNpcVisualShotLatch} from './npc_visual_shot.mjs';
import {resolveWeaponShotTransforms} from './weapon_effects.mjs';

// Two pooled draw calls, no lights/rays/impact callbacks. Source owns damage.
export function createNpcShotEffects({THREE,scene,getActor,groundHeight=()=>0,worldScale=4.1,capacity=16,maxSources=96}={}){
 capacity=Math.max(1,Math.min(32,Math.floor(capacity)));maxSources=Math.max(1,Math.min(192,Math.floor(maxSources)));
 const root=new THREE.Group();root.name='NPC_Confirmed_Shot_Effects';root.userData.mercenaryPickIgnore=true;scene.add(root);
 const tracerGeometry=new THREE.CylinderGeometry(.012,.012,1,6),flashGeometry=new THREE.ConeGeometry(.032,.13,6);
 const tracerMaterial=new THREE.MeshBasicMaterial({color:0xffda87,transparent:true,opacity:.85,depthTest:true,depthWrite:false,toneMapped:false});
 const flashMaterial=new THREE.MeshBasicMaterial({color:0xffebad,transparent:true,opacity:.95,depthTest:true,depthWrite:false,toneMapped:false});
 const tracers=new THREE.InstancedMesh(tracerGeometry,tracerMaterial,capacity),flashes=new THREE.InstancedMesh(flashGeometry,flashMaterial,capacity);
 for(const mesh of[tracers,flashes]){mesh.count=0;mesh.frustumCulled=false;mesh.raycast=()=>{};mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);mesh.userData.mercenaryPickIgnore=true;root.add(mesh);}tracers.name='NPC_Shot_Tracers';flashes.name='NPC_Muzzle_Flashes';
 const sources=new Map(),pending=[],shots=[],up=new THREE.Vector3(0,1,0),scale=new THREE.Vector3(),point=new THREE.Vector3(),quaternion=new THREE.Quaternion(),matrix=new THREE.Matrix4();let disposed=false,totalShots=0,dropped=0,lastTime=null;
 function sync(rows,sourceNowMs,time){
  if(disposed)return;const visible=new Set();let count=0;
  for(const row of rows||[]){if(!row?.id||(!row._visualShot&&!row.mercenary&&!/^npc_crew_/.test(row.id)))continue;if(count++>=maxSources)break;visible.add(row.id);let latch=sources.get(row.id);if(!latch){latch=createNpcVisualShotLatch();sources.set(row.id,latch);}const shot=latch.observe(row,sourceNowMs,time);if(shot){if(pending.length>=capacity){pending.shift();dropped++;}pending.push(shot);}}
  for(const id of sources.keys())if(!visible.has(id))sources.delete(id);
  for(let i=pending.length-1;i>=0;i--)if(!visible.has(pending[i].shooterId))pending.splice(i,1);
 }
 function spawn(shot,time){
  const actor=getActor?.(shot.shooterId),weapon=actor?.weapon;if(!actor?.object?.visible||!weapon?.visible||!Array.isArray(weapon.userData?.muzzle)){dropped++;return;}
  const acceptedRay=shot.ray;
  if(acceptedRay&&![acceptedRay.origin?.x,acceptedRay.origin?.y,acceptedRay.origin?.z,acceptedRay.target?.x,acceptedRay.target?.y,acceptedRay.target?.z].every(Number.isFinite)){dropped++;return;}
  const origin=acceptedRay?new THREE.Vector3(acceptedRay.origin.x,acceptedRay.origin.y,acceptedRay.origin.z):resolveWeaponShotTransforms(THREE,weapon).origin;
  const x=shot.target.c*worldScale,z=shot.target.r*worldScale,target=acceptedRay?new THREE.Vector3(acceptedRay.target.x,acceptedRay.target.y,acceptedRay.target.z):new THREE.Vector3(x,groundHeight(x,z)+(Number(shot.target.elevation)||0)+1.05,z);
  const direction=target.sub(origin),range=direction.length();if(!Number.isFinite(range)||range<.01||range>160){dropped++;return;}direction.divideScalar(range);
  if(shots.length>=capacity){shots.shift();dropped++;}shots.push({shooterId:shot.shooterId,sequence:shot.sequence,at:time,origin,direction,range,life:Math.max(.12,Math.min(.24,range/100))});totalShots++;
 }
 function update(time){
  if(disposed||!Number.isFinite(time))return;if(lastTime!==null&&time<lastTime){pending.length=shots.length=0;sources.clear();}lastTime=time;
  for(const shot of pending)if(time-shot.presentedAt<=.3&&time>=shot.presentedAt)spawn(shot,time);else dropped++;pending.length=0;
  let tracerCount=0,flashCount=0;
  for(let i=shots.length-1;i>=0;i--){const shot=shots[i],actor=getActor?.(shot.shooterId),age=time-shot.at;if(age>=shot.life||!actor?.object?.visible){shots.splice(i,1);continue;}quaternion.setFromUnitVectors(up,shot.direction);
   const distance=Math.min(shot.range,Math.max(0,age/shot.life)*shot.range),length=Math.min(.58,shot.range),mid=Math.min(shot.range-length/2,Math.max(length/2,distance));point.copy(shot.origin).addScaledVector(shot.direction,mid);scale.set(1,length,1);matrix.compose(point,quaternion,scale);tracers.setMatrixAt(tracerCount++,matrix);
   if(age<.07){point.copy(shot.origin).addScaledVector(shot.direction,.055);scale.setScalar(Math.max(.15,1-age/.07));matrix.compose(point,quaternion,scale);flashes.setMatrixAt(flashCount++,matrix);}
  }
  tracers.count=tracerCount;flashes.count=flashCount;if(tracerCount)tracers.instanceMatrix.needsUpdate=true;if(flashCount)flashes.instanceMatrix.needsUpdate=true;
 }
 function dispose(){if(disposed)return;disposed=true;root.removeFromParent();tracerGeometry.dispose();flashGeometry.dispose();tracerMaterial.dispose();flashMaterial.dispose();sources.clear();pending.length=shots.length=0;}
 return{sync,update,dispose,stats:()=>({disposed,sources:sources.size,pending:pending.length,active:shots.length,totalShots,dropped,drawCalls:(tracers.count?1:0)+(flashes.count?1:0)}),inspect:()=>shots.map(s=>({shooterId:s.shooterId,sequence:s.sequence,origin:s.origin.toArray(),direction:s.direction.toArray()}))};
}
