function roundedBox(T){const g=new T.BoxGeometry(1,1,1,4,4,4),p=g.attributes.position,n=g.attributes.normal,v=new T.Vector3(),core=new T.Vector3(),normal=new T.Vector3();for(let i=0;i<p.count;i++){v.fromBufferAttribute(p,i);core.copy(v).clampScalar(-.445,.445);normal.copy(v).sub(core).normalize();v.copy(core).addScaledVector(normal,.055);p.setXYZ(i,v.x,v.y,v.z);n.setXYZ(i,normal.x,normal.y,normal.z)}g.computeBoundingBox();g.computeBoundingSphere();return g}
// Colour is per instance: furnishing variety never creates one draw per colour.
export function createInteriorMeshPool(T,root){
 const geometry={box:roundedBox(T),cylinder:new T.CylinderGeometry(.5,.5,1,12),sphere:new T.SphereGeometry(.5,12,8)};
 const materials=[new T.MeshStandardMaterial({roughness:.76}),new T.MeshStandardMaterial({roughness:.32,metalness:.65})];
 const buckets=new Map(),meshes=[],matrix=new T.Matrix4(),position=new T.Vector3(),scale=new T.Vector3(),rotation=new T.Quaternion(),axis=new T.Vector3(0,1,0),color=new T.Color();
 function add(part,transform){
  const shape=geometry[part.shape]?part.shape:'box',metal=(part.metalness??0)>.3?1:0,key=shape+metal;
  if(!buckets.has(key))buckets.set(key,[]);
  position.fromArray(part.position);scale.fromArray(part.size);rotation.setFromAxisAngle(axis,part.yaw??0);matrix.compose(position,rotation,scale);if(transform)matrix.premultiply(transform);
  buckets.get(key).push({matrix:matrix.clone(),color:part.color??'#9d8973'});
 }
 function flush(){for(const[key,parts]of buckets){const shape=key.slice(0,-1),metal=Number(key.slice(-1)),mesh=new T.InstancedMesh(geometry[shape],materials[metal],parts.length);mesh.name='Interior_Furnishings_'+key;for(let i=0;i<parts.length;i++){mesh.setMatrixAt(i,parts[i].matrix);mesh.setColorAt(i,color.set(parts[i].color))}mesh.castShadow=mesh.receiveShadow=true;mesh.computeBoundingBox();mesh.computeBoundingSphere();root.add(mesh);meshes.push(mesh)}return{parts:[...buckets.values()].reduce((n,a)=>n+a.length,0),draws:meshes.length}}
 return{add,flush,dispose(){for(const m of meshes)m.removeFromParent();for(const g of Object.values(geometry))g.dispose();for(const m of materials)m.dispose()}};
}
