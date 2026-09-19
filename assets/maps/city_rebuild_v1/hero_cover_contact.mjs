// The vehicle driving envelope includes mirror/crash clearance. Concealed
// presentation can approach the rendered body without shrinking that envelope
// or changing the pedestrian's physical capsule.
import {getVehicleRenderSourceMaterial} from './vehicle_render_batches.mjs';
const skinCache=new WeakMap(),geometryVersions=new WeakMap(),triangleChunks=new WeakMap(),chunkMeshes=new WeakMap();
function visible(object){for(let n=object;n;n=n.parent)if(!n.visible)return false;return true;}
function surface(hit,opaque=true){
  const object=hit.object.userData.coverContactSource||hit.object;
  if(!visible(object)||object.userData.vehicleRenderBatch)return false;
  // Vehicle batches retain source meshes for gameplay raycasts. Their hidden
  // replacement material is presentation-only; genuine material hiding still
  // removes a surface, including individual faces of multi-material meshes.
  const source=getVehicleRenderSourceMaterial(object);
  const materials=Array.isArray(source)?(hit.face?[source[hit.face.materialIndex]]:source):[source];
  return materials.some(m=>m&&m.visible!==false&&(opaque?((m.transmission||0)<.2&&(!m.transparent||m.opacity>.65)):(!m.transparent||m.opacity>.01)));
}

const solid=hit=>surface(hit,true);

// A long authored bus body can contain thousands of triangles in one mesh.
// Partition only its CPU raycast view along the longest local axis; all source
// triangles/attributes remain untouched, and every intersecting chunk uses the
// ordinary THREE raycaster. No render objects or collision hulls are changed.
function contactChunks(T,mesh){
  const g=mesh.geometry,p=g.attributes.position,index=g.index,count=index?.count??p.count;
  if(count<1536||count%3||mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.isBatchedMesh||mesh.raycast!==T.Mesh.prototype.raycast||Array.isArray(mesh.material)||Array.isArray(getVehicleRenderSourceMaterial(mesh))||Object.keys(g.morphAttributes||{}).length||g.drawRange.start!==0||g.drawRange.count!==Infinity)return null;
  let record=triangleChunks.get(g);
  if(!record||record.position!==p||record.positionVersion!==p.version||record.index!==index||record.indexVersion!==index?.version){
    if(record)for(const geometry of record.parts)geometry.dispose();
    const size=g.boundingBox.getSize(new T.Vector3()),axis=size.x>size.y?(size.x>size.z?0:2):(size.y>size.z?1:2),triangles=[];
    for(let i=0;i<count;i+=3){const ids=[0,1,2].map(j=>index?index.getX(i+j):i+j);triangles.push({ids,center:ids.reduce((sum,k)=>sum+p.getComponent(k,axis),0)});}
    triangles.sort((a,b)=>a.center-b.center);const parts=[],point=new T.Vector3();
    for(let i=0;i<triangles.length;i+=128){
      const ids=[],bounds=new T.Box3();for(const triangle of triangles.slice(i,i+128))for(const k of triangle.ids){ids.push(k);bounds.expandByPoint(point.fromBufferAttribute(p,k));}
      const geometry=new T.BufferGeometry();geometry.setAttribute('position',p);geometry.setIndex(ids);geometry.boundingBox=bounds;geometry.boundingSphere=bounds.getBoundingSphere(new T.Sphere());parts.push(geometry);
    }
    record={position:p,positionVersion:p.version,index,indexVersion:index?.version,parts};triangleChunks.set(g,record);
  }
  let cached=chunkMeshes.get(mesh);
  if(cached?.record!==record){cached={record,parts:record.parts.map(geometry=>{const part=new T.Mesh(geometry,mesh.material);part.matrixAutoUpdate=false;part.userData.coverContactSource=mesh;return part;})};chunkMeshes.set(mesh,cached);}
  const material=getVehicleRenderSourceMaterial(mesh);
  for(const part of cached.parts){part.material=material;part.matrixWorld.copy(mesh.matrixWorld);part.layers.mask=mesh.layers.mask;}
  return cached.parts;
}

function coverRayTargets(THREE,vehicle,sweptBounds,includeTransparent=false){
  const targets=[];
  vehicle.traverse(mesh=>{
    const geometry=mesh.geometry,attribute=geometry?.attributes?.position;
    if(!mesh.isMesh||!attribute||!surface({object:mesh},!includeTransparent))return;
    if(!geometry.boundingBox||geometryVersions.get(geometry)!==attribute.version){geometry.computeBoundingBox();geometryVersions.set(geometry,attribute.version);}
    // The prototype geometry is not the world footprint of an InstancedMesh.
    // Rebuild instance bounds at query time so setMatrixAt/count changes and
    // owner/root rotations are reflected even before the next GPU upload.
    if(mesh.isInstancedMesh){mesh.computeBoundingBox();mesh.computeBoundingSphere();}
    const bounds=mesh.isInstancedMesh?mesh.boundingBox:geometry.boundingBox;
    if(!bounds.clone().applyMatrix4(mesh.matrixWorld).intersectsBox(sweptBounds))return;
    const chunks=contactChunks(THREE,mesh);
    if(chunks){for(const part of chunks)if(part.geometry.boundingBox.clone().applyMatrix4(mesh.matrixWorld).intersectsBox(sweptBounds))targets.push(part);}
    else targets.push(mesh);
  });
  return targets;
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
  const origin=context.object.getWorldPosition(new THREE.Vector3()),samples=new Map(),point=new THREE.Vector3(),skinBounds=new THREE.Box3();
  const step=Math.max(.06,cellSize),originAlong=origin.dot(tangent);
  for(const mesh of meshes){
    if(!visible(mesh))continue;mesh.skeleton.update();
    const attribute=mesh.geometry.attributes.position;
    for(let i=0;i<attribute.count;i++){
      point.fromBufferAttribute(attribute,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld);
      skinBounds.expandByPoint(point);
      const key=Math.floor((point.y-origin.y)/step)+':'+Math.floor((point.dot(tangent)-originAlong)/step),depth=point.dot(n),old=samples.get(key);
      if(!old||depth<old.depth)samples.set(key,{point:point.clone(),depth});
    }
  }
  // Broadphase only: keep the exact same rays/triangles, but avoid visiting
  // opposite-side wheels, cabin furniture and trim for every silhouette ray.
  const far=maxShift+clearance+.02,shift=direction.clone().multiplyScalar(far);
  const sweptBounds=skinBounds.clone().union(skinBounds.clone().translate(shift)).expandByScalar(.001),targets=[];
  targets.push(...coverRayTargets(THREE,vehicle,sweptBounds));
  let gap=Infinity,rays=0;const ray=new THREE.Raycaster();
  for(const sample of samples.values()){
    ray.set(sample.point,direction);ray.near=0;ray.far=far;rays++;
    const hit=ray.intersectObjects(targets,false).find(solid);
    if(hit)gap=Math.min(gap,hit.distance);
  }
  // No surface in reach: do not move a silhouette through an open door or
  // around a corner merely because the inflated rectangle says 'vehicle'.
  if(!Number.isFinite(gap))return {...zero,rays};
  const distance=Math.max(0,Math.min(maxShift,gap-clearance));
  return {x:direction.x*distance,y:0,z:direction.z*distance,distance,gap,rays};
}

/** Opaque near-wall height, not the car roof AABB. normal points OUT of cover.
 * The first visible surface on each ray wins: glass cannot reveal a seat or
 * the opposite wall as protection. Returns world topY/baseY and feet-relative
 * height. At an exposed corner height retains the central wall's height, but
 * fullWidth/continuous are false: height alone never promises head protection.
 * Host may throttle on movement/door changes; geometry caches are shared with
 * contact queries, but this result itself never outlives a changed car state.
 */
export function vehicleOpaqueCoverHeight(THREE,vehicle,{position,normal,width=.50,maxHeight=2.4,maxDistance=1.2,step=.08,maxBaseHeight=.8,minBandHeight=.32,depthTolerance=.16}={}){
  const empty={height:0,topY:position?.y??0,baseY:position?.y??0,continuous:false,fullWidth:false,probes:0};
  if(!vehicle||!position||![position.x,position.y,position.z,normal?.x,normal?.z].every(Number.isFinite)||maxDistance<=0)return empty;
  const outward=new THREE.Vector3(normal.x,0,normal.z);if(outward.lengthSq()<1e-8)return empty;outward.normalize();
  const direction=outward.clone().negate(),tangent=new THREE.Vector3(outward.z,0,-outward.x),origin=new THREE.Vector3(position.x,position.y,position.z);
  const spacing=Math.max(.04,step),heightLimit=Math.min(3.5,Math.max(.4,maxHeight)),lanes=[-.5,0,.5],rows=[];
  for(let height=.25;height<=heightLimit+1e-8;height+=spacing)rows.push(height);
  const bounds=new THREE.Box3();for(const side of [-.5,.5])for(const y of [.25,heightLimit])for(const depth of [0,maxDistance])bounds.expandByPoint(origin.clone().addScaledVector(tangent,side*width).addScaledVector(direction,depth).add(new THREE.Vector3(0,y,0)));
  vehicle.updateWorldMatrix(true,true);const targets=coverRayTargets(THREE,vehicle,bounds.expandByScalar(.001),true),ray=new THREE.Raycaster(),samples=[],nearest=lanes.map(()=>Infinity);let probes=0;
  for(const height of rows){const row=[];for(let lane=0;lane<lanes.length;lane++){
    const start=origin.clone().addScaledVector(tangent,lanes[lane]*width);start.y+=height;ray.set(start,direction);ray.near=0;ray.far=maxDistance;probes++;
    const hit=ray.intersectObjects(targets,false).find(h=>surface(h,false));
    // Steps below knee height protrude beyond the body and are not the wall
    // plane against which a concealed head is protected.
    if(hit&&height>=.65)nearest[lane]=Math.min(nearest[lane],hit.distance);row.push(hit?{distance:hit.distance,opaque:solid(hit)}:null);
  }samples.push(row);}
  const findBand=indices=>{
    let base=null,top=null,best=null;
    for(let i=0;i<rows.length;i++){
      const protectedRow=indices.every(lane=>{const hit=samples[i][lane];return hit?.opaque&&hit.distance<=nearest[lane]+depthTolerance;});
      if(protectedRow){if(base===null)base=rows[i];top=rows[i];}
      if(!protectedRow||i===rows.length-1){
        if(base!==null&&base<=maxBaseHeight&&top-base>=minBandHeight&&(!best||top>best.top))best={base,top};
        base=top=null;
      }
    }
    return best;
  };
  const complete=findBand([0,1,2]),central=complete?null:findBand([1]);
  // Keep an actual edge anchor when an outer column is wholly outside the
  // object. A partial hole/window in a column is not such an edge: it must not
  // promote an isolated sill or a cabin seat to full-height door protection.
  const edge=central&&[0,2].some(lane=>rows.every((height,i)=>height<central.base||height>central.top||!samples[i][lane]));
  const best=complete||(edge?central:null),fullWidth=!!complete;
  if(!best)return {...empty,probes};
  const height=Math.max(0,best.top-.015);
  return {height,topY:position.y+height,baseY:position.y+best.base,continuous:fullWidth,fullWidth,probes};
}
