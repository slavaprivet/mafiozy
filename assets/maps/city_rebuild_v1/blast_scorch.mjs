// Bounded presentation decals. Hit points/normals are already world-space from
// applyWorldBlast; the original surface geometry and material remain untouched.
export function createBlastScorch(T,scene,{capacity=32}={}){
 capacity=Math.max(1,Math.min(64,Math.floor(capacity)||32));
 let cursor=0,total=0,disposed=false;
 const material=new T.MeshBasicMaterial({color:'#15110e',transparent:true,opacity:.68,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-2,toneMapped:false,vertexColors:true});
 // Irregular fan; 20 edge points plus centre are projected only on a hit.
 // Every slot remains one tiny geometry and one draw, with a shared material.
 const position=[],color=[];
 const emit=(a,b,c,colors)=>{for(const [i,v]of [a,b,c].entries()){position.push(...v);color.push(...colors[i])}};
 for(let i=0;i<20;i++){
  const edge=j=>{const a=j*Math.PI/10,r=.88+.08*Math.sin(j*2.71)+.04*Math.cos(j*5.13);return [Math.cos(a)*r,Math.sin(a)*r,0]};
  const a=edge(i),b=edge((i+1)%20);emit([0,0,0],a,b,[[.6,.6,.6],[1,1,1],[1,1,1]]);
 }
 const geometry=new T.BufferGeometry();geometry.setAttribute('position',new T.Float32BufferAttribute(position,3));geometry.setAttribute('color',new T.Float32BufferAttribute(color,3));geometry.computeVertexNormals();
 const pool=Array.from({length:capacity},()=>{const mesh=new T.Mesh(geometry.clone(),material);mesh.name='Blast_surface_scorch';mesh.visible=false;mesh.userData.breakableGlass=false;mesh.userData.blastEffect=true;mesh.raycast=()=>{};scene.add(mesh);return mesh});
 const forward=new T.Vector3(0,0,1),normal=new T.Vector3(),point=new T.Vector3(),scale=new T.Vector3(),quaternion=new T.Quaternion(),matrix=new T.Matrix4(),inverse=new T.Matrix4(),decalInverse=new T.Matrix4(),vertex=new T.Vector3(),ray=new T.Raycaster();
 function hit(payload){
  if(disposed)return false;const target=payload?.hit?.object||payload?.object,p=payload?.point||payload?.hit?.point,n=payload?.normal;
  if(!target?.isMesh||!p||!n||![p.x,p.y,p.z,n.x,n.y,n.z,payload.damage,payload.falloff].every(Number.isFinite)||payload.damage<=0||payload.falloff<=0||target.userData.blastEffect)return false;
  const materials=Array.isArray(target.material)?target.material:[target.material],selected=materials[payload.hit?.face?.materialIndex??0];
  if(!selected||selected.transparent||selected.transmission>0)return false;
  for(let parent=target;parent;parent=parent.parent)if(!parent.visible)return false;
  normal.set(n.x,n.y,n.z);if(normal.lengthSq()<1e-8)return false;normal.normalize();point.set(p.x,p.y,p.z);
  target.updateWorldMatrix(true,false);if(Math.abs(target.matrixWorld.determinant())<1e-12)return false;
  // Reuse the exact surface point and a millimetre offset; no bounds-centre
  // approximation that would leave a patch hovering over a dented panel.
  const entry=pool[cursor++%capacity],size=Math.min(.8,.10+Math.sqrt(payload.damage)*.052)*Math.min(1,.4+payload.falloff);
  quaternion.setFromUnitVectors(forward,normal).multiply(new T.Quaternion().setFromAxisAngle(forward,total*2.399963229728653));scale.setScalar(size);
  matrix.compose(point.clone().addScaledVector(normal,.003),quaternion,scale);decalInverse.copy(matrix).invert();
  const base=geometry.attributes.position,positions=entry.geometry.attributes.position,projected=new Map();
  for(let i=0;i<base.count;i++){
   const key=base.getX(i)+','+base.getY(i);let local=projected.get(key);
   if(!local){
    vertex.fromBufferAttribute(base,i).applyMatrix4(matrix);ray.set(vertex.clone().addScaledVector(normal,.5),normal.clone().negate());ray.near=0;ray.far=1;
    const intersection=ray.intersectObject(target,false).find(h=>payload.hit?.instanceId===undefined||h.instanceId===payload.hit.instanceId);
    local=(intersection?.point.clone()||point.clone()).addScaledVector(normal,.003).applyMatrix4(decalInverse);projected.set(key,local);
   }
   positions.setXYZ(i,local.x,local.y,local.z);
  }
  positions.needsUpdate=true;entry.geometry.computeBoundingSphere();
  inverse.copy(target.matrixWorld).invert();matrix.premultiply(inverse);
  target.add(entry);entry.matrixAutoUpdate=false;entry.matrix.copy(matrix);entry.matrixWorldNeedsUpdate=true;entry.visible=true;total++;return true;
 }
 function reset(){if(disposed)return;cursor=0;total=0;for(const entry of pool){scene.add(entry);entry.visible=false;entry.matrix.identity();entry.matrixWorldNeedsUpdate=true}}
 function dispose(){if(disposed)return;disposed=true;for(const entry of pool){entry.removeFromParent();entry.geometry.dispose()}geometry.dispose();material.dispose()}
 return {hit,reset,dispose,stats:()=>({capacity,total,active:disposed?0:pool.filter(n=>n.visible).length,disposed})};
}
