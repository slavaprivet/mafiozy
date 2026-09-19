// Only the two audited public sites used a whole-yard, whole-building-height
// envelope. Cache actual authored part bounds once at assembly; never traverse
// meshes while walking. Existing entrance clipping still subtracts its room and
// doorway from these bodies, and its live door bodies remain authoritative.
export function createBuildingSiteBodies({THREE,visual,instance,metresPerCell=4.1,nodes,exclude=new Set()}){
 if(!['civic_hall','hospital'].includes(instance.assetId))return null;
 const bodies=[];
 for(const node of nodes){
  if(!node.isMesh||exclude.has(node)||!node.geometry?.attributes.position)continue;
  let visible=true;for(let n=node;n;n=n.parent){if(!n.visible){visible=false;break;}if(n===visual)break;}
  if(!visible||/^(?:CANON_|COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(node.name))continue;
  const b=new THREE.Box3().setFromBufferAttribute(node.geometry.attributes.position);
  if(b.isEmpty())continue;
  const corners=[];for(const x of[b.min.x,b.max.x])for(const y of[b.min.y,b.max.y])for(const z of[b.min.z,b.max.z])corners.push(new THREE.Vector3(x,y,z).applyMatrix4(node.matrixWorld));
  // Convex projected box retains placement rotation and scale; a world AABB
  // would reintroduce broad false walls around rotated public buildings.
  const points=corners.map(p=>[p.x/metresPerCell,p.z/metresPerCell]).sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
  const cross=(o,a,b)=>(a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0]);
  const lower=[],upper=[];
  for(const p of points){while(lower.length>1&&cross(lower.at(-2),lower.at(-1),p)<=1e-12)lower.pop();lower.push(p);}
  for(const p of points.slice().reverse()){while(upper.length>1&&cross(upper.at(-2),upper.at(-1),p)<=1e-12)upper.pop();upper.push(p);}
  const polygonCR=lower.slice(0,-1).concat(upper.slice(0,-1));if(polygonCR.length<3)continue;
  bodies.push({polygonCR,minYM:Math.min(...corners.map(p=>p.y)),maxYM:Math.max(...corners.map(p=>p.y)),buildingEntryId:instance.id,node:node.name,authoredSitePart:true});
 }
 return bodies;
}
