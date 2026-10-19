// Conservative current-camera proof for one hidden service-room birth.
// All corners must be behind one visible opaque convex triangle/triangle pair.
// Sparse rays against unrelated occluders are deliberately not a proof.
export function createServiceSpawnVisibility23({THREE:T,getCamera,getOccluders,isCurrentSite,ready}={}){
 const frustum=new T.Frustum(),matrix=new T.Matrix4(),box=new T.Box3(),raycaster=new T.Raycaster(),origin=new T.Vector3(),centre=new T.Vector3(),direction=new T.Vector3(),hitPoint=new T.Vector3(),instance=new T.Matrix4();
 const corners=Array.from({length:8},()=>new T.Vector3()),clipPoint=new T.Vector3();let deniedUntil=-Infinity;
 const opaque=m=>!!m&&m.onBeforeCompile===T.Material.prototype.onBeforeCompile&&m.customProgramCacheKey===T.Material.prototype.customProgramCacheKey&&m.visible!==false&&m.colorWrite!==false&&m.depthWrite!==false&&m.depthTest!==false&&m.depthFunc===T.LessEqualDepth&&!m.stencilWrite&&!m.polygonOffset&&m.blending===T.NormalBlending&&!m.wireframe&&!m.alphaHash&&!m.alphaToCoverage&&m.opacity===1&&!m.transparent&&!m.alphaMap&&!m.displacementMap&&!(m.alphaTest>0)&&!(m.transmission>0)&&!m.clippingPlanes?.length&&(m.isMeshStandardMaterial||m.isMeshBasicMaterial||m.isMeshPhongMaterial||m.isMeshLambertMaterial);
 const visible=o=>{for(let p=o;p;p=p.parent)if(p.visible===false)return false;return true;};
 function triangle(mesh,faceIndex,instanceId){
  const geometry=mesh.geometry,p=geometry?.attributes?.position,index=geometry?.index;if(!p||!Number.isInteger(faceIndex)||faceIndex<0)return null;
  const start=faceIndex*3;if(start+2>=(index?.count??p.count))return null;
  const draw=geometry.drawRange;if(draw&&(start<draw.start||start+3>draw.start+draw.count))return null;
  let material=mesh.material;if(Array.isArray(material)){const group=geometry.groups.find(g=>start>=g.start&&start+3<=g.start+g.count);material=material[group?.materialIndex];}if(!opaque(material))return null;
  matrix.copy(mesh.matrixWorld);if(mesh.isInstancedMesh){if(!Number.isInteger(instanceId)||instanceId<0||instanceId>=mesh.count)return null;mesh.getMatrixAt(instanceId,instance);if(!(instance.determinant()>0))return null;matrix.multiply(instance);}
  const points=[0,1,2].map(i=>new T.Vector3().fromBufferAttribute(p,index?index.getX(start+i):start+i).applyMatrix4(matrix));
  points.side=material.side;points.frontSign=matrix.determinant()<0?-1:1;return points;
 }
 function convexPair(a,b){
  if(!a||!b)return false;
  const normal=new T.Vector3().subVectors(a[1],a[0]).cross(new T.Vector3().subVectors(a[2],a[0])).normalize(),other=new T.Vector3().subVectors(b[1],b[0]).cross(new T.Vector3().subVectors(b[2],b[0])).normalize();
  if(normal.dot(other)<.999999||b.some(p=>Math.abs(new T.Vector3().subVectors(p,a[0]).dot(normal))>1e-5))return false;
  const unique=[];for(const p of [...a,...b])if(!unique.some(q=>q.distanceToSquared(p)<1e-10))unique.push(p);
  if(unique.length!==4)return false;
  const shared=a.filter(p=>b.some(q=>q.distanceToSquared(p)<1e-10)),aa=a.find(p=>!shared.includes(p)),bb=b.find(p=>!shared.some(q=>q.distanceToSquared(p)<1e-10));
  if(shared.length!==2||!aa||!bb)return false;
  const edge=new T.Vector3().subVectors(shared[1],shared[0]);
  if(edge.clone().cross(new T.Vector3().subVectors(aa,shared[0])).dot(normal)*edge.clone().cross(new T.Vector3().subVectors(bb,shared[0])).dot(normal)>=-1e-10)return false;
  const mid=unique.reduce((v,p)=>v.add(p),new T.Vector3()).multiplyScalar(.25),u=new T.Vector3().subVectors(unique[0],mid).normalize(),v=new T.Vector3().crossVectors(normal,u);
  unique.sort((p,q)=>Math.atan2(new T.Vector3().subVectors(p,mid).dot(v),new T.Vector3().subVectors(p,mid).dot(u))-Math.atan2(new T.Vector3().subVectors(q,mid).dot(v),new T.Vector3().subVectors(q,mid).dot(u)));
  return unique.every((p,i)=>new T.Vector3().subVectors(unique[(i+1)%4],p).cross(new T.Vector3().subVectors(unique[(i+2)%4],unique[(i+1)%4])).dot(normal)>1e-8);
 }
 function covered(triangles,camera){
  return corners.every(corner=>{
   direction.subVectors(corner,origin);const distance=direction.length();if(distance<.1)return false;direction.multiplyScalar(1/distance);raycaster.ray.set(origin,direction);
   return triangles.some(t=>{
    const front=new T.Vector3().subVectors(t[1],t[0]).cross(new T.Vector3().subVectors(t[2],t[0])).dot(new T.Vector3().subVectors(origin,t[0]))*t.frontSign>0;
    if(t.side===T.FrontSide&&!front||t.side===T.BackSide&&front)return false;
    if(!raycaster.ray.intersectTriangle(t[0],t[1],t[2],false,hitPoint)||origin.distanceTo(hitPoint)>=distance-.03||origin.distanceTo(hitPoint)<=.01)return false;
    clipPoint.copy(hitPoint).project(camera);return clipPoint.z>=-1&&clipPoint.z<=1;
   });
  });
 }
 return function canSpawnHidden(layout,now){
  if(!Number.isFinite(now)||now<deniedUntil)return false;
  const deny=()=>{deniedUntil=now+250;return false;};
  try{
   if(ready?.()!==true||isCurrentSite?.(layout)!==true||!layout?.spawn||!['x','y','z'].every(k=>Number.isFinite(layout.spawn[k])))return deny();
   const camera=getCamera();if(!camera?.isPerspectiveCamera&&!camera?.isOrthographicCamera)return deny();
   camera.updateMatrixWorld(true);camera.getWorldPosition(origin);
   if(camera.coordinateSystem!==T.WebGLCoordinateSystem||!camera.projectionMatrix.elements.every(Number.isFinite)||!camera.matrixWorld.elements.every(Number.isFinite)||!camera.matrixWorldInverse.elements.every(Number.isFinite)||!Number.isFinite(camera.projectionMatrix.determinant())||Math.abs(camera.projectionMatrix.determinant())<1e-12)return deny();
   const p=layout.spawn;box.min.set(p.x-.9,p.y-.1,p.z-.9);box.max.set(p.x+.9,p.y+2.2,p.z+.9);
   if(box.containsPoint(origin))return deny();
   matrix.multiplyMatrices(camera.projectionMatrix,camera.matrixWorldInverse);frustum.setFromProjectionMatrix(matrix);
   if(!frustum.intersectsBox(box))return true;
   // An orthographic view uses parallel rays; this cone proof is perspective-only.
   if(!camera.isPerspectiveCamera)return deny();
   let i=0;for(const x of [box.min.x,box.max.x])for(const y of [box.min.y,box.max.y])for(const z of [box.min.z,box.max.z])corners[i++].set(x,y,z);
   const roots=getOccluders();if(!Array.isArray(roots)||roots.length>8)return deny();
   for(const root of roots)root.updateWorldMatrix(true,true);
   box.getCenter(centre);direction.subVectors(centre,origin);const distance=direction.length();raycaster.set(origin,direction.multiplyScalar(1/distance));raycaster.near=.01;raycaster.far=distance-.03;raycaster.layers.mask=camera.layers.mask;
   const hits=raycaster.intersectObjects(roots,true);
   for(const hit of hits.slice(0,24)){
    const mesh=hit.object;if(!visible(mesh)||mesh.isSkinnedMesh||mesh.morphTexture||mesh.morphTargetInfluences?.some(x=>x!==0))continue;
    const a=triangle(mesh,hit.faceIndex,hit.instanceId);if(!a)continue;
    if(covered([a],camera))return true;
    for(const offset of [-1,1]){const b=triangle(mesh,hit.faceIndex+offset,hit.instanceId);if(convexPair(a,b)&&covered([a,b],camera))return true;}
   }
  }catch{}
  return deny();
 };
}
