// Exact conservative rejection of an unnecessary contact-only floor correction.
// Bone influence boxes enclose every vertex before LBS; an affine projection of
// each box encloses its transformed vertices. Nonnegative weights preserve the
// bound. The sum-error term covers imperfectly normalized skin weights.
export function createContactGroundBound({THREE,meshes,root}){
 const inverse=new THREE.Matrix4(),post=new THREE.Matrix4(),matrix=new THREE.Matrix4(),p=new THREE.Vector3();
 const records=meshes.map(mesh=>{
  const position=mesh.geometry?.attributes?.position;if(!position)return {invalid:true};
  if(!mesh.isSkinnedMesh){const box=new THREE.Box3().setFromBufferAttribute(position);return {mesh,boxes:[{box}],minSum:1,error:0};}
  const skin=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight;if(!skin||!weights)return {invalid:true};
  const boxes=mesh.skeleton.bones.map(()=>({box:new THREE.Box3()}));let minSum=Infinity,error=0;
  for(let i=0;i<position.count;i++){
   p.fromBufferAttribute(position,i).applyMatrix4(mesh.bindMatrix);let sum=0;
   for(let component=0;component<4;component++){
    const weight=weights.getComponent(i,component),bone=skin.getComponent(i,component);
    if(!Number.isFinite(weight)||weight<0||!Number.isInteger(bone)||!boxes[bone])return {invalid:true};
    sum+=weight;if(weight>0)boxes[bone].box.expandByPoint(p);
   }
   if(!Number.isFinite(sum)||sum<=0)return {invalid:true};minSum=Math.min(minSum,sum);error=Math.max(error,Math.abs(1-sum));
  }
  return {mesh,boxes,minSum,error};
 });
 function minY(box,m){const e=m.elements;return e[13]+e[1]*(e[1]<0?box.max.x:box.min.x)+e[5]*(e[5]<0?box.max.y:box.min.y)+e[9]*(e[9]<0?box.max.z:box.min.z);}
 return function entirelyAboveFloor(){
  inverse.copy(root.matrixWorld).invert();
  for(const record of records){
   if(record.invalid)return false;const {mesh,boxes}=record;post.multiplyMatrices(inverse,mesh.matrixWorld);
   if(!mesh.isSkinnedMesh){if(!(minY(boxes[0].box,post)>=1e-7))return false;continue;}
   post.multiply(mesh.bindMatrixInverse);let lower=Infinity;
   for(let bone=0;bone<boxes.length;bone++)if(!boxes[bone].box.isEmpty()){
    matrix.multiplyMatrices(post,mesh.skeleton.bones[bone].matrixWorld).multiply(mesh.skeleton.boneInverses[bone]);
    lower=Math.min(lower,minY(boxes[bone].box,matrix));
   }
   if(!(lower*record.minSum-record.error*Math.abs(post.elements[13])>=1e-7))return false;
  }
  return true;
 };
}
