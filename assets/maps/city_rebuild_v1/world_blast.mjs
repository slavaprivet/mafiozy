import {discoverGlassPanels,isBreakableGlass} from './glass_breakage.mjs';
const panelCache=new WeakMap();
function visible(mesh){for(let n=mesh;n;n=n.parent)if(!n.visible)return false;return true}
function panelsFor(T,mesh){
 let cached=panelCache.get(mesh);if(cached?.geometry===mesh.geometry)return cached.panels;
 const g=mesh.geometry,p=g.attributes.position,ix=g.index;
 const panels=discoverGlassPanels(mesh).panels.map(panel=>{const bounds=new T.Box3(),v=new T.Vector3();for(const face of panel.faces)for(let i=0;i<3;i++)bounds.expandByPoint(v.fromBufferAttribute(p,ix?ix.getX(face*3+i):face*3+i));return {...panel,bounds}});
 panelCache.set(mesh,{geometry:g,panels});return panels;
}
// Presentation blast only. Source geometry/IDs/ownership stay under their
// existing adapters; glass.hit owns its instance-local fracture resources.
export function applyWorldBlast(T,{point,radius,power=120,roots=[],glass,onSurfaceHit,maxMeshes=96,maxPanels=96,maxSurfaceHits=24,spatialPrune=true,staticBatchSurfaceFix=false}={}){
 const stats={broken:0,surfaceHits:0,candidates:0,panelsTested:0,prunedChunks:0,prunedInstancedMeshes:0,prunedInstanceRanges:0,prunedInstances:0,sphereRejectedInstances:0,instancesTested:0,truncated:false};
 if(!point||![point.x,point.y,point.z,radius,power].every(Number.isFinite)||radius<=0||power<=0)return stats;
 maxMeshes=Math.max(0,Math.min(256,Math.floor(maxMeshes)||0));maxPanels=Math.max(0,Math.min(256,Math.floor(maxPanels)||0));maxSurfaceHits=Math.max(0,Math.min(64,Math.floor(maxSurfaceHits)||0));
 const preserveStaticSurfaces=staticBatchSurfaceFix===true;
 const origin=new T.Vector3(point.x,point.y,point.z),selected=[],seen=new Set(),matrix=new T.Matrix4(),local=new T.Matrix4(),bounds=new T.Box3(),sphere=new T.Sphere();let candidateCount=0;
 // Keep precisely the prefix that a stable distance sort followed by slice(0,
 // maxMeshes) would select. Most dense-world candidates are never rendered or
 // hit-tested after a blast, so avoid cloning their matrix/bounds and sorting
 // an unbounded temporary list. Strict comparison preserves the old arrival
 // order for equal-distance candidates.
 const retainCandidate=(mesh,instanceId,distance,breakable)=>{
  candidateCount++;
  if(!maxMeshes||(selected.length===maxMeshes&&distance>=selected[selected.length-1].distance))return;
  const candidate={mesh,instanceId,matrix:matrix.clone(),bounds:bounds.clone(),distance,breakable};let at=selected.length;
  while(at>0&&distance<selected[at-1].distance)at--;
  selected.splice(at,0,candidate);if(selected.length>maxMeshes)selected.pop();
 };
 const outsideChunk=node=>{const b=node?.userData?.bounds;if(!spatialPrune||!b||!String(node.name||'').startsWith('ExplorationChunk_'))return false;const dx=Math.max(b.minX-origin.x,0,origin.x-b.maxX),dz=Math.max(b.minZ-origin.z,0,origin.z-b.maxZ);return dx*dx+dz*dz>radius*radius};
 const visit=(node,fn)=>{if(!node)return;if(outsideChunk(node)){stats.prunedChunks++;return}fn(node);for(const child of node.children||[])visit(child,fn)};
 for(const root of Array.isArray(roots)?roots:[roots]){
  root?.updateWorldMatrix?.(true,true);visit(root,mesh=>{
   // Batches only own drawing. Keep blast raycasts and decals on the exact
   // source meshes so face/instance IDs and authored geometry stay intact.
   if(preserveStaticSurfaces&&mesh.userData?.staticRenderBatch===true)return;
   if(seen.has(mesh)||!mesh.isMesh||!mesh.geometry?.attributes?.position||!visible(mesh)||mesh.userData.glassEffect||mesh.userData.worldBlastIgnore)return;seen.add(mesh);
   const materials=Array.isArray(mesh.material)?mesh.material:[mesh.material],breakable=materials.some(m=>isBreakableGlass(mesh,m));
   if(!breakable&&!materials.some(m=>m&&(m.visible!==false||preserveStaticSurfaces&&m.userData?.staticRenderSource===true)&&!m.transparent))return;
   const g=mesh.geometry;if(!g.boundingBox)g.computeBoundingBox();if(!g.boundingBox||g.boundingBox.isEmpty())return;
   // Explicitly opted-in static batches have conservative aggregate boxes.
   // Skip the whole batch before touching individual instance matrices. Never
   // infer this from draw usage: several dynamic systems keep stale boxes.
   if(spatialPrune&&mesh.isInstancedMesh&&(mesh.userData.explorationDecor||mesh.userData.worldBlastStaticBounds)){if(!mesh.boundingBox)mesh.computeBoundingBox();if(mesh.boundingBox){bounds.copy(mesh.boundingBox).applyMatrix4(mesh.matrixWorld);if(bounds.distanceToPoint(origin)>radius){stats.prunedInstancedMeshes++;return}}}
   const instanceCount=mesh.isInstancedMesh?mesh.count:1,candidateRanges=spatialPrune&&mesh.isInstancedMesh&&mesh.userData.worldBlastRangeCount===mesh.count?mesh.userData.worldBlastInstanceRanges:null;let instanceRanges=Array.isArray(candidateRanges)&&candidateRanges.length?candidateRanges:null;
   if(instanceRanges){let covered=0;for(const range of instanceRanges){if(range.start!==covered||!Number.isInteger(range.count)||range.count<=0||!range.bounds?.isBox3){instanceRanges=null;break}covered+=range.count}if(covered!==mesh.count)instanceRanges=null}
   for(let rangeIndex=0;rangeIndex<(instanceRanges?.length||1);rangeIndex++){
    const range=instanceRanges?.[rangeIndex],start=range?.start||0,end=range?start+range.count:instanceCount;
    if(range){bounds.copy(range.bounds).applyMatrix4(mesh.matrixWorld);if(bounds.distanceToPoint(origin)>radius){stats.prunedInstanceRanges++;stats.prunedInstances+=range.count;continue}}
    for(let id=start;id<end;id++){
    stats.instancesTested++;
    matrix.copy(mesh.matrixWorld);if(mesh.isInstancedMesh){mesh.getMatrixAt(id,local);if(Math.abs(local.determinant())<1e-12)continue;matrix.multiply(local)}
    // A transformed bounding sphere is conservative for every rotation and
    // non-uniform scale.  Most nearby forest-chunk instances are still well
    // outside a small blast; reject those before Box3.applyMatrix4 expands all
    // eight corners.  The exact AABB distance test remains the final gate.
    if(mesh.isInstancedMesh){if(!g.boundingSphere)g.computeBoundingSphere();if(g.boundingSphere){sphere.copy(g.boundingSphere).applyMatrix4(matrix);if(sphere.distanceToPoint(origin)>radius){stats.sphereRejectedInstances++;continue}}}
    bounds.copy(g.boundingBox).applyMatrix4(matrix);const distance=bounds.distanceToPoint(origin);if(distance>radius)continue;
    retainCandidate(mesh,mesh.isInstancedMesh?id:undefined,distance,breakable);
   }
   }
  });
 }
 stats.candidates=candidateCount;if(candidateCount>maxMeshes)stats.truncated=true;
 const opaque=[...new Set(selected.filter(c=>!c.breakable).map(c=>c.mesh))];
 const triangle=new T.Triangle(),closest=new T.Vector3(),a=new T.Vector3(),b=new T.Vector3(),c=new T.Vector3(),ray=new T.Raycaster();
 for(const candidate of selected){
  const {mesh,matrix:world,instanceId}=candidate,g=mesh.geometry,p=g.attributes.position,ix=g.index;
  if(candidate.breakable&&glass?.hit){
   // Avoid an unbounded mesh analysis on accidental mega-mesh input.
   if((ix?.count??p.count)>180000){stats.truncated=true;continue}
   for(const panel of panelsFor(T,mesh)){
    bounds.copy(panel.bounds).applyMatrix4(world);if(bounds.distanceToPoint(origin)>radius)continue;
    if(stats.panelsTested>=maxPanels){stats.truncated=true;break}stats.panelsTested++;
    let nearest=null,distance=radius;
    for(const faceIndex of panel.faces){
     a.fromBufferAttribute(p,ix?ix.getX(faceIndex*3):faceIndex*3);b.fromBufferAttribute(p,ix?ix.getX(faceIndex*3+1):faceIndex*3+1);c.fromBufferAttribute(p,ix?ix.getX(faceIndex*3+2):faceIndex*3+2);
     triangle.a.copy(a).applyMatrix4(world);triangle.b.copy(b).applyMatrix4(world);triangle.c.copy(c).applyMatrix4(world);if(triangle.getArea()<1e-12)continue;triangle.closestPointToPoint(origin,closest);const d=closest.distanceTo(origin);
     if(d<=distance){distance=d;nearest={object:mesh,instanceId,faceIndex,point:closest.clone(),face:{normal:new T.Vector3().subVectors(b,a).cross(new T.Vector3().subVectors(c,a)).normalize(),materialIndex:panel.materialIndex}}}
    }
    if(nearest){const direction=nearest.point.clone().sub(origin).normalize(),impulse=power*Math.max(.05,1-distance/radius);if(glass.hit(nearest,{direction,impulse,weaponId:'world_blast'}).broken)stats.broken++}
   }
  }else if(typeof onSurfaceHit==='function'&&stats.surfaceHits<maxSurfaceHits){
   // A ray toward the nearest bounds point refines to a real exposed surface.
   const target=candidate.bounds.clampPoint(origin,new T.Vector3());if(target.distanceToSquared(origin)<1e-8)candidate.bounds.getCenter(target);
   const direction=target.sub(origin);if(direction.lengthSq()<1e-8)continue;direction.normalize();ray.set(origin,direction);ray.near=.002;ray.far=radius;
   const hit=ray.intersectObjects(opaque,false)[0];if(!hit||hit.object!==mesh||(instanceId!==undefined&&hit.instanceId!==instanceId))continue;
   const normal=hit.face?.normal.clone().applyMatrix3(new T.Matrix3().getNormalMatrix(world)).normalize()||direction.clone().negate(),falloff=Math.max(0,1-hit.distance/radius);
   onSurfaceHit({hit,point:hit.point.clone(),normal,direction:direction.clone(),damage:power*falloff,falloff});stats.surfaceHits++;
  }
 }
 return stats;
}
