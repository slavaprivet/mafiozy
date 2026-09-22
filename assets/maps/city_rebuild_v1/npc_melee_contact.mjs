import {captureNpcContactAnchor} from './npc_contact_anchor.mjs';
// Presentation-only swept limb contact with the current skinned triangles.
// No damage admission, HP mutation, target selection by distance, or hit receipt creation.
export function createNpcMeleeContact({THREE,getActors,obstacles=()=>[]}){
 const triangle=new THREE.Triangle(),ray=new THREE.Raycaster(),rayGeom=new THREE.Ray(),cache=new WeakMap();
 const A=new THREE.Vector3(),B=A.clone(),C=A.clone(),normal=A.clone(),point=A.clone(),linePoint=A.clone(),candidate=A.clone(),delta=A.clone(),bodyCenter=A.clone();
 const d1=A.clone(),d2=A.clone(),r=A.clone(),edgePoint=A.clone(),edgeLine=A.clone(),nearestPoint=A.clone(),nearestLine=A.clone(),rayDirection=A.clone(),barycentric=A.clone(),outward=A.clone();
 const attackPool=Array.from({length:4},()=>({from:new THREE.Vector3(),to:new THREE.Vector3(),radius:0})),nearAttacks=[];
 const visible=node=>{for(let n=node;n;n=n.parent)if(!n.visible)return false;return true;};
 const finite=v=>v&&Number.isFinite(v.x)&&Number.isFinite(v.y)&&Number.isFinite(v.z);
 const clamp=x=>Math.max(0,Math.min(1,x));
 function segmentEdge(from,to,p,q){
  d1.subVectors(to,from);d2.subVectors(q,p);r.subVectors(from,p);const a=d1.lengthSq(),e=d2.lengthSq(),f=d2.dot(r);let s=0,t=0;
  if(a<1e-14)t=e>1e-14?clamp(f/e):0;
  else{const c=d1.dot(r);if(e<1e-14)s=clamp(-c/a);else{const b=d1.dot(d2),den=a*e-b*b;s=den>1e-14?clamp((b*f-c*e)/den):0;t=(b*s+f)/e;if(t<0){t=0;s=clamp(-c/a);}else if(t>1){t=1;s=clamp((b-c)/a);}}}
  edgeLine.copy(from).addScaledVector(d1,s);edgePoint.copy(p).addScaledVector(d2,t);return edgeLine.distanceToSquared(edgePoint);
 }
 function closest(from,to){
  triangle.set(A,B,C);delta.subVectors(to,from);const length=delta.length();
  if(length>1e-10){rayGeom.set(from,rayDirection.copy(delta).divideScalar(length));const hit=rayGeom.intersectTriangle(A,B,C,false,candidate);if(hit&&from.distanceToSquared(hit)<=length*length+1e-10){nearestPoint.copy(hit);nearestLine.copy(hit);return 0;}}
  triangle.closestPointToPoint(from,candidate);let best=from.distanceToSquared(candidate);nearestPoint.copy(candidate);nearestLine.copy(from);
  triangle.closestPointToPoint(to,candidate);let distance=to.distanceToSquared(candidate);if(distance<best){best=distance;nearestPoint.copy(candidate);nearestLine.copy(to);}
  distance=segmentEdge(from,to,A,B);if(distance<best){best=distance;nearestPoint.copy(edgePoint);nearestLine.copy(edgeLine);}
  distance=segmentEdge(from,to,B,C);if(distance<best){best=distance;nearestPoint.copy(edgePoint);nearestLine.copy(edgeLine);}
  distance=segmentEdge(from,to,C,A);if(distance<best){best=distance;nearestPoint.copy(edgePoint);nearestLine.copy(edgeLine);}
  return best;
 }
 function posedVertices(mesh,revision){
  const count=mesh.geometry.attributes.position.count;let record=cache.get(mesh);if(!record||record.values.length!==count*3){record={values:new Float64Array(count*3),revision:null};cache.set(mesh,record);}
  if(revision!=null&&record.revision===revision)return record;
  const values=record.values;mesh.skeleton.update();for(let i=0;i<count;i++){mesh.getVertexPosition(i,point).applyMatrix4(mesh.matrixWorld);values[i*3]=point.x;values[i*3+1]=point.y;values[i*3+2]=point.z;}
  const index=mesh.geometry.index,total=index?index.count:count;
  if(!record.indices||record.indices.length!==total){record.indices=new Uint32Array(total);record.bounds=new Float64Array(total*2);for(let i=0;i<total;i++)record.indices[i]=index?index.getX(i):i;}
  for(let i=0;i<total;i+=3){const a=record.indices[i]*3,b=record.indices[i+1]*3,c=record.indices[i+2]*3,j=i*2;for(let axis=0;axis<3;axis++){record.bounds[j+axis]=Math.min(values[a+axis],values[b+axis],values[c+axis]);record.bounds[j+3+axis]=Math.max(values[a+axis],values[b+axis],values[c+axis]);}}
  record.revision=revision??null;return record;
 }
 function zone(mesh,ia,ib,ic,target){
  const skin=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight,bary=THREE.Triangle.getBarycoord(target,A,B,C,barycentric);let head=0;
  if(skin&&weights&&bary){const add=(vertex,blend)=>{if(mesh.skeleton.bones[skin.getX(vertex)]?.name==='head')head+=weights.getX(vertex)*blend;if(mesh.skeleton.bones[skin.getY(vertex)]?.name==='head')head+=weights.getY(vertex)*blend;if(mesh.skeleton.bones[skin.getZ(vertex)]?.name==='head')head+=weights.getZ(vertex)*blend;if(mesh.skeleton.bones[skin.getW(vertex)]?.name==='head')head+=weights.getW(vertex)*blend;};add(ia,bary.x);add(ib,bary.y);add(ic,bary.z);}
  return head>=.5?'head':'body';
 }
 return function contact(input={}){
  if(input.active===false)return null;
  const contacts=input.contacts,attackCount=contacts?contacts.length:1;
  if(!attackCount||attackCount>attackPool.length)return null;
  for(let i=0;i<attackCount;i++){const source=contacts?contacts[i]:input,from=source.previous||source.from,to=source.current||source.to,radius=source.radius??input.radius??(/kick|foot/i.test(input.attackType||'')?.14:.10);if(!finite(from)||!finite(to)||!Number.isFinite(radius)||radius<=0||radius>.5)return null;const attack=attackPool[i];attack.from.copy(from);attack.to.copy(to);attack.radius=radius;}
  const blockers=obstacles();for(const obstacle of blockers)obstacle.updateWorldMatrix(true,true);let best=null,bestScore=Infinity,bestActor=null,bestMesh=null,bestFace=null;
  for(const actor of getActors()){
   if(!actor.object||actor.id===input.excludeId||!visible(actor.object))continue;
   actor.object.getWorldPosition(bodyCenter);bodyCenter.y+=1;
   nearAttacks.length=0;for(let i=0;i<attackCount;i++){const attack=attackPool[i];delta.subVectors(attack.to,attack.from);const t=delta.lengthSq()?clamp(candidate.subVectors(bodyCenter,attack.from).dot(delta)/delta.lengthSq()):0;if(candidate.copy(attack.from).addScaledVector(delta,t).distanceToSquared(bodyCenter)<=9)nearAttacks.push(attack);}if(!nearAttacks.length)continue;
   actor.object.updateWorldMatrix(true,false);actor.object.updateMatrixWorld(true);
   actor.object.traverse(mesh=>{
    if(!mesh.isSkinnedMesh||!visible(mesh))return;const posed=posedVertices(mesh,input.poseRevision),positions=posed.values,index=posed.indices,bounds=posed.bounds,total=index.length;
    for(let i=0;i<total;i+=3){const j=i*2,ia=index[i],ib=index[i+1],ic=index[i+2];let prepared=false;
     for(const attack of nearAttacks){const {from,to,radius}=attack;
      if(bounds[j+3]<Math.min(from.x,to.x)-radius||bounds[j]>Math.max(from.x,to.x)+radius||bounds[j+4]<Math.min(from.y,to.y)-radius||bounds[j+1]>Math.max(from.y,to.y)+radius||bounds[j+5]<Math.min(from.z,to.z)-radius||bounds[j+2]>Math.max(from.z,to.z)+radius)continue;
      if(!prepared){A.fromArray(positions,ia*3);B.fromArray(positions,ib*3);C.fromArray(positions,ic*3);normal.subVectors(B,A).cross(candidate.subVectors(C,A));if(normal.lengthSq()<1e-14)continue;normal.normalize();prepared=true;}
      const distanceSq=closest(from,to);if(distanceSq>radius*radius+1e-10)continue;
      const score=from.distanceToSquared(nearestLine)+distanceSq;if(score>=bestScore)continue;
      delta.subVectors(nearestPoint,from);const wallDistance=delta.length();if(wallDistance>1e-8){ray.set(from,delta.divideScalar(wallDistance));ray.near=0;ray.far=wallDistance;const wall=ray.intersectObjects(blockers,true).find(h=>visible(h.object));if(wall&&wall.distance<wallDistance-1e-5)continue;}
      // A sampled hand may already be beyond a thin wall at window start.
      // Preserve body-to-target occlusion as well as the swept limb segment.
      if(finite(input.origin)&&blockers.length){delta.subVectors(nearestPoint,input.origin);const distance=delta.length();if(distance>1e-8){ray.set(input.origin,delta.divideScalar(distance));ray.near=0;ray.far=distance;const wall=ray.intersectObjects(blockers,true).find(h=>visible(h.object));if(wall&&wall.distance<distance-1e-5)continue;}}
      point.copy(nearestPoint);linePoint.copy(nearestLine);outward.copy(normal);delta.subVectors(linePoint,point);if(delta.lengthSq()>1e-12?outward.dot(delta)<0:outward.dot(candidate.subVectors(to,from))>0)outward.negate();
      bestScore=score;bestActor=actor;bestMesh=mesh;bestFace={a:ia,b:ib,c:ic};best={npcId:actor.id,point:{x:point.x,y:point.y,z:point.z},normal:{x:outward.x,y:outward.y,z:outward.z},zone:zone(mesh,ia,ib,ic,point),distance:Math.sqrt(score),attackType:input.attackType||'punch'};
     }
    }
   });
  }
  // Capture only the winning surface. Earlier candidate triangles are not
  // receipts and must not repeatedly reskin vertices during a sample batch.
  if(best)best.anchor=captureNpcContactAnchor({THREE,record:bestActor,mesh:bestMesh,face:bestFace,point:best.point,normal:best.normal});
  return best;
 };
}
