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
 function posedVertices(mesh){
  const count=mesh.geometry.attributes.position.count;let values=cache.get(mesh);if(!values||values.length!==count*3){values=new Float64Array(count*3);cache.set(mesh,values);}
  mesh.skeleton.update();for(let i=0;i<count;i++){mesh.getVertexPosition(i,point).applyMatrix4(mesh.matrixWorld);values[i*3]=point.x;values[i*3+1]=point.y;values[i*3+2]=point.z;}return values;
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
  const blockers=obstacles();for(const obstacle of blockers)obstacle.updateWorldMatrix(true,true);let best=null,bestScore=Infinity;
  for(const actor of getActors()){
   if(!actor.object||actor.id===input.excludeId||!visible(actor.object))continue;
   actor.object.getWorldPosition(bodyCenter);bodyCenter.y+=1;
   nearAttacks.length=0;for(let i=0;i<attackCount;i++){const attack=attackPool[i];delta.subVectors(attack.to,attack.from);const t=delta.lengthSq()?clamp(candidate.subVectors(bodyCenter,attack.from).dot(delta)/delta.lengthSq()):0;if(candidate.copy(attack.from).addScaledVector(delta,t).distanceToSquared(bodyCenter)<=9)nearAttacks.push(attack);}if(!nearAttacks.length)continue;
   actor.object.updateWorldMatrix(true,false);actor.object.updateMatrixWorld(true);
   actor.object.traverse(mesh=>{
    if(!mesh.isSkinnedMesh||!visible(mesh))return;const positions=posedVertices(mesh),index=mesh.geometry.index,total=index?index.count:positions.length/3;
    for(let i=0;i<total;i+=3){const ia=index?index.getX(i):i,ib=index?index.getX(i+1):i+1,ic=index?index.getX(i+2):i+2;A.fromArray(positions,ia*3);B.fromArray(positions,ib*3);C.fromArray(positions,ic*3);normal.subVectors(B,A).cross(candidate.subVectors(C,A));if(normal.lengthSq()<1e-14)continue;normal.normalize();
     for(const attack of nearAttacks){const {from,to,radius}=attack;
      if(Math.max(A.x,B.x,C.x)<Math.min(from.x,to.x)-radius||Math.min(A.x,B.x,C.x)>Math.max(from.x,to.x)+radius||Math.max(A.y,B.y,C.y)<Math.min(from.y,to.y)-radius||Math.min(A.y,B.y,C.y)>Math.max(from.y,to.y)+radius||Math.max(A.z,B.z,C.z)<Math.min(from.z,to.z)-radius||Math.min(A.z,B.z,C.z)>Math.max(from.z,to.z)+radius)continue;
      const distanceSq=closest(from,to);if(distanceSq>radius*radius+1e-10)continue;
      const score=from.distanceToSquared(nearestLine)+distanceSq;if(score>=bestScore)continue;
      delta.subVectors(nearestPoint,from);const wallDistance=delta.length();if(wallDistance>1e-8){ray.set(from,delta.divideScalar(wallDistance));ray.near=0;ray.far=wallDistance;const wall=ray.intersectObjects(blockers,true).find(h=>visible(h.object));if(wall&&wall.distance<wallDistance-1e-5)continue;}
      point.copy(nearestPoint);linePoint.copy(nearestLine);outward.copy(normal);delta.subVectors(linePoint,point);if(delta.lengthSq()>1e-12?outward.dot(delta)<0:outward.dot(candidate.subVectors(to,from))>0)outward.negate();
      bestScore=score;best={npcId:actor.id,anchor:captureNpcContactAnchor({THREE,record:actor,mesh,face:{a:ia,b:ib,c:ic},point,normal:outward}),point:{x:point.x,y:point.y,z:point.z},normal:{x:outward.x,y:outward.y,z:outward.z},zone:zone(mesh,ia,ib,ic,point),distance:Math.sqrt(score),attackType:input.attackType||'punch'};
     }
    }
   });
  }
  return best;
 };
}
