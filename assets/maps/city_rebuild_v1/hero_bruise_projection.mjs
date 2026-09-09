// CPU-only bounded cache. Returned BufferGeometry belongs exclusively to its actor.
const layouts=new Map(),projections=new Map(),LIMIT=32;let projectionBuilds=0,projectionHits=0;
const remember=(map,key,value)=>{map.set(key,value);while(map.size>LIMIT)map.delete(map.keys().next().value);return value;};
const hashNumbers=values=>{let hash=2166136261;for(const value of values){let n=Math.round(value*1e5);for(let i=0;i<4;i++){hash^=n&255;hash=Math.imul(hash,16777619);n>>=8;}}return(hash>>>0).toString(16);};
export function bruiseProjectionCacheStats(){return {layouts:layouts.size,projections:projections.size,projectionBuilds,projectionHits};}
export function createLazyHeadBruiseProjector(THREE,context){
 const head=context.bones.head;if(!head)return ()=>null;
 context.object.updateWorldMatrix(true,false);context.object.updateMatrixWorld(true);
 const toHead=head.matrixWorld.clone().invert(),author=context.offset||context.scene,authorToHead=toHead.clone().multiply(author.matrixWorld),positions=[],indices=[],p=new THREE.Vector3();
 context.scene.traverse(mesh=>{
  if(!mesh.isSkinnedMesh||mesh.userData.bulletWound)return;
  const skin=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight;if(!skin||!weights)return;
  mesh.skeleton.update();const eligible=new Uint8Array(skin.count),mapped=new Map();
  for(let i=0;i<skin.count;i++){let weight=0;for(const getter of ['getX','getY','getZ','getW'])if(mesh.skeleton.bones[skin[getter](i)]?.name==='head')weight+=weights[getter](i);eligible[i]=weight>=.5?1:0;}
  const index=mesh.geometry.index,count=index?index.count:skin.count;
  for(let i=0;i<count;i+=3){const ids=[index?index.getX(i):i,index?index.getX(i+1):i+1,index?index.getX(i+2):i+2];if(ids.some(v=>!eligible[v]))continue;
   for(const id of ids){if(!mapped.has(id)){mesh.getVertexPosition(id,p).applyMatrix4(mesh.matrixWorld).applyMatrix4(toHead);mapped.set(id,positions.length/3);positions.push(p.x,p.y,p.z);}indices.push(mapped.get(id));}
  }
 });
 const key=positions.length+':'+indices.length+':'+hashNumbers(positions)+':'+hashNumbers(indices)+':'+hashNumbers(authorToHead.elements);
 let layout=layouts.get(key);if(!layout)layout=remember(layouts,key,{positions,indices,matrix:authorToHead.toArray()});
 return function project(side){
  const eyeKey=key+':'+side;let data=projections.get(eyeKey);
  if(!data){
   const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(layout.positions,3));geometry.setIndex(layout.indices);geometry.computeBoundingSphere();
   const material=new THREE.MeshBasicMaterial({side:THREE.DoubleSide}),proxy=new THREE.Mesh(geometry,material);proxy.updateMatrixWorld(true);
   const matrix=new THREE.Matrix4().fromArray(layout.matrix),direction=new THREE.Vector3(0,0,-1).transformDirection(matrix),axisLength=new THREE.Vector3(0,0,1).applyMatrix4(matrix).distanceTo(new THREE.Vector3().applyMatrix4(matrix)),ray=new THREE.Raycaster(),n=24,coords=[],colors=[],triangles=[],valid=[];
   for(let ring=0;ring<=4;ring++)for(let i=0;i<n;i++){
    const radius=ring/4,angle=i/n*Math.PI*2,start=new THREE.Vector3(side*.23+Math.cos(angle)*.16*radius,4.19+Math.sin(angle)*.085*radius,1).applyMatrix4(matrix);ray.set(start,direction);ray.near=0;ray.far=2*axisLength;
    const hit=ray.intersectObject(proxy,false)[0];valid.push(!!hit);const point=hit?hit.point.clone().addScaledVector(direction,-.003*axisLength):new THREE.Vector3();coords.push(...point.toArray());colors.push(.28,.09,.20,1-radius*radius);
   }
   for(let r=0;r<4;r++)for(let i=0;i<n;i++){const a=r*n+i,b=r*n+(i+1)%n,c=a+n,d=b+n;if(valid[a]&&valid[c]&&valid[b])triangles.push(a,c,b);if(valid[b]&&valid[c]&&valid[d])triangles.push(b,c,d);}
   geometry.dispose();material.dispose();data=remember(projections,eyeKey,{positions:coords,colors,indices:triangles});projectionBuilds++;
  }else projectionHits++;
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(data.positions,3));geometry.setAttribute('color',new THREE.Float32BufferAttribute(data.colors,4));geometry.setIndex(data.indices);geometry.computeVertexNormals();return geometry;
 };
}
