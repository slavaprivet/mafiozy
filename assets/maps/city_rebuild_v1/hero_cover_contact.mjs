// The vehicle driving envelope includes mirror/crash clearance. Concealed
// presentation can approach the rendered body without shrinking that envelope
// or changing the pedestrian's physical capsule.
const skinCache=new WeakMap();
function visible(object){for(let n=object;n;n=n.parent)if(!n.visible)return false;return true;}
function solid(hit){
  if(!visible(hit.object))return false;
  const materials=Array.isArray(hit.object.material)?hit.object.material:[hit.object.material];
  return materials.some(m=>m&&(m.transmission||0)<.2&&(!m.transparent||m.opacity>.65));
}

/** Call on a freshly posed hero, before adding this frame's contact offset.
 * Returns a WORLD translation; caller translates the complete visualPivot so
 * palms, weapon and actual muzzle stay together. Never changes collision root.
 * A small projected silhouette grid bounds work; the nearest skin vertex in
 * each cell probes the actual opaque vehicle mesh, including wheels/doors.
 */
export function vehicleCoverContact(THREE,context,vehicle,normal,{maxShift=.48,clearance=.065,cellSize=.14}={}){
  const zero={x:0,y:0,z:0,distance:0,gap:null,rays:0};
  if(!context?.object||!vehicle||!Number.isFinite(normal?.x)||!Number.isFinite(normal?.z)||!(maxShift>0))return zero;
  const n=new THREE.Vector3(normal.x,0,normal.z);if(n.lengthSq()<1e-8)return zero;n.normalize();
  const tangent=new THREE.Vector3(n.z,0,-n.x),direction=n.clone().negate();
  let meshes=skinCache.get(context.object);
  if(!meshes){meshes=[];context.object.traverse(o=>{if(o.isSkinnedMesh)meshes.push(o);});skinCache.set(context.object,meshes);}
  context.object.updateMatrixWorld(true);vehicle.updateWorldMatrix(true,true);
  const origin=context.object.getWorldPosition(new THREE.Vector3()),samples=new Map(),point=new THREE.Vector3();
  const step=Math.max(.06,cellSize),originAlong=origin.dot(tangent);
  for(const mesh of meshes){
    if(!visible(mesh))continue;mesh.skeleton.update();
    const attribute=mesh.geometry.attributes.position;
    for(let i=0;i<attribute.count;i++){
      point.fromBufferAttribute(attribute,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld);
      const key=Math.floor((point.y-origin.y)/step)+':'+Math.floor((point.dot(tangent)-originAlong)/step),depth=point.dot(n),old=samples.get(key);
      if(!old||depth<old.depth)samples.set(key,{point:point.clone(),depth});
    }
  }
  let gap=Infinity,rays=0;const ray=new THREE.Raycaster();
  for(const sample of samples.values()){
    ray.set(sample.point,direction);ray.near=0;ray.far=maxShift+clearance+.02;rays++;
    const hit=ray.intersectObject(vehicle,true).find(solid);
    if(hit)gap=Math.min(gap,hit.distance);
  }
  // No surface in reach: do not move a silhouette through an open door or
  // around a corner merely because the inflated rectangle says 'vehicle'.
  if(!Number.isFinite(gap))return {...zero,rays};
  const distance=Math.max(0,Math.min(maxShift,gap-clearance));
  return {x:direction.x*distance,y:0,z:direction.z*distance,distance,gap,rays};
}
