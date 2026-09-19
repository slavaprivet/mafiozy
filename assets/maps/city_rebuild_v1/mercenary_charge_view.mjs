// Visual feedback for authoritative armed charges only. No fuse/effect simulation.
export function createMercenaryChargeView({THREE,getTarget,getCharges=()=>[],nowSeconds=()=>performance.now()/1000,scene}){
 const geometry=new THREE.BoxGeometry(.075,.14,.22),material=new THREE.MeshStandardMaterial({color:0x4b5943,roughness:.88,metalness:.08}),active=new Map(),local=new THREE.Vector3();let disposed=false,last=-Infinity;
 function remove(id){const r=active.get(id);if(r){r.mesh.removeFromParent();active.delete(id);}}
 function update(time=typeof nowSeconds==='function'?nowSeconds():nowSeconds){
  if(disposed||!Number.isFinite(time))return;if(time>=last&&time-last<.1)return;last=time;
  const seen=new Set(),charges=getCharges()||[];
  for(const charge of charges){
   const actionId=typeof charge?.actionId==='string'&&charge.actionId.trim()?charge.actionId:Number.isSafeInteger(charge?.actionId)&&charge.actionId>0?String(charge.actionId):null;
   if(!actionId||typeof charge.targetId!=='string'||!Number.isFinite(charge.detonateAt)||(charge.detonateAt<=time&&!charge.waitingForSafety)||charge.armed===false||['approach','working'].includes(charge.phase))continue;
   const target=getTarget(charge.targetId),parent=target?.object;if(!parent?.isObject3D||target.valid===false||target.kind&&!['vehicle','door'].includes(target.kind))continue;
   // Resolve at most 10 Hz; ordinary object parenting follows the car every frame.
   seen.add(actionId);let record=active.get(actionId);
   if(record&&(record.parent!==parent||record.targetId!==charge.targetId)){remove(actionId);record=null;}
   if(!record){
    if(target.position&&Number.isFinite(target.position.x)&&Number.isFinite(target.position.z)){local.set(target.position.x,target.position.y||0,target.position.z);parent.updateWorldMatrix(true,false);parent.worldToLocal(local);}else local.set(1.75,0,0);
    const sign=local.x<0?-1:1,halfWidth=Number(parent.userData.collisionHalfWidth??parent.userData.halfWidth)||Math.max(.4,Math.abs(local.x)-.75);
    const mesh=new THREE.Mesh(geometry,material);mesh.name='Mercenary_Armed_Charge';mesh.userData.mercenaryPickIgnore=true;mesh.userData.mercenaryChargeId=actionId;
    if(target.kind==='door'&&target.workPoint){local.copy(target.workPoint);if(target.workNormal)local.addScaledVector(target.workNormal,.05);parent.worldToLocal(local);mesh.position.copy(local);mesh.rotation.y=Math.PI/2;}
    else mesh.position.set(sign*(halfWidth+.025),.75,0);
    mesh.castShadow=true;mesh.receiveShadow=true;parent.add(mesh);record={mesh,parent,targetId:charge.targetId};active.set(actionId,record);
   }
  }
  for(const id of active.keys())if(!seen.has(id))remove(id);
 }
 function dispose(){if(disposed)return;disposed=true;for(const id of active.keys())remove(id);geometry.dispose();material.dispose();}
 return {update,dispose,stats:()=>({active:active.size,geometries:disposed?0:1,materials:disposed?0:1,disposed})};
}
