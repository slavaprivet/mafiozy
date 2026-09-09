import {captureNpcContactAnchor} from './npc_contact_anchor.mjs';
// Presentation contact only. The source world decides whether damage is accepted.
export function createNpcContactRay({THREE,getActors,obstacles=()=>[]}){
 const ray=new THREE.Raycaster(),a=new THREE.Vector3(),b=new THREE.Vector3(),c=new THREE.Vector3(),rayDirection=new THREE.Vector3(),actorCenter=new THREE.Vector3(),barycentric=new THREE.Vector3(),headPoint=new THREE.Vector3(),surfaces=[],owners=new Map();
 const visible=node=>{for(let n=node;n;n=n.parent)if(!n.visible)return false;return true;};
 const headInfluence=(bones,indices,weights,vertex,blend)=>{
  let total=0;if(bones[indices.getX(vertex)]?.name==='head')total+=weights.getX(vertex)*blend;if(bones[indices.getY(vertex)]?.name==='head')total+=weights.getY(vertex)*blend;if(bones[indices.getZ(vertex)]?.name==='head')total+=weights.getZ(vertex)*blend;if(bones[indices.getW(vertex)]?.name==='head')total+=weights.getW(vertex)*blend;return total;
 };
 return function contact({origin,direction,range=100}){
  if(!origin||!direction||![origin.x,origin.y,origin.z,direction.x,direction.y,direction.z,range].every(Number.isFinite)||range<=0||direction.lengthSq()<1e-12)return null;
  ray.set(origin,rayDirection.copy(direction).normalize());ray.near=0;ray.far=range;
  // A contact query is synchronous. Reuse its short-lived collector across
  // accepted shots; no mesh owner escapes this function.
  surfaces.length=0;owners.clear();
  for(const record of getActors()){
   if(!record.object||!visible(record.object))continue;
   // A generous broad phase avoids skinning distant crowds for every shot.
   record.object.getWorldPosition(actorCenter);actorCenter.y+=1;const distance=ray.ray.distanceSqToPoint(actorCenter);
   if(distance>9)continue;
   record.object.updateWorldMatrix(true,false);
   // SkinnedMesh.updateMatrixWorld refreshes bindMatrixInverse; updateWorldMatrix
   // alone skips that override and can double-transform a moved actor's skin.
   record.object.updateMatrixWorld(true);
   record.object.traverse(mesh=>{if(!mesh.isSkinnedMesh||!visible(mesh))return;
    mesh.skeleton.update();mesh.computeBoundingSphere();if(mesh.boundingBox)mesh.computeBoundingBox();
    surfaces.push(mesh);owners.set(mesh,record);
   });
  }
  const hit=ray.intersectObjects(surfaces,false)[0];if(!hit)return null;
  const blockers=obstacles();for(const obstacle of blockers)obstacle.updateWorldMatrix(true,true);
  const wall=ray.intersectObjects(blockers,true).find(h=>visible(h.object));
  if(wall&&wall.distance<=hit.distance)return null;
  const mesh=hit.object,face=hit.face;
  mesh.getVertexPosition(face.a,a);mesh.getVertexPosition(face.b,b);mesh.getVertexPosition(face.c,c);
  a.applyMatrix4(mesh.matrixWorld);b.applyMatrix4(mesh.matrixWorld);c.applyMatrix4(mesh.matrixWorld);
  THREE.Triangle.getBarycoord(hit.point,a,b,c,barycentric);
  const normal=b.sub(a).cross(c.sub(a)).normalize();if(normal.dot(ray.ray.direction)>0)normal.negate();
  const owner=owners.get(mesh),head=owner.object.getObjectByName('head');
  const hasHead=!!head;if(hasHead)head.getWorldPosition(headPoint);
  // The head joint sits below the face. A fixed radius mislabels the forehead
  // as torso; use the actual hit triangle's interpolated skin weights instead.
  let headWeight=0;const indices=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight;
  if(indices&&weights&&barycentric){const bones=mesh.skeleton.bones;headWeight=headInfluence(bones,indices,weights,face.a,barycentric.x)+headInfluence(bones,indices,weights,face.b,barycentric.y)+headInfluence(bones,indices,weights,face.c,barycentric.z);}
  else if(hasHead&&headPoint.distanceTo(hit.point)<.3)headWeight=1;
  const anchor=captureNpcContactAnchor({THREE,record:owner,mesh,face,point:hit.point,normal});
  return {npcId:owner.id,point:{x:hit.point.x,y:hit.point.y,z:hit.point.z},normal:{x:normal.x,y:normal.y,z:normal.z},zone:headWeight>=.5?'head':'body',distance:hit.distance,anchor};
 };
}
