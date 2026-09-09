/** Cache boot bounds once, then transform only four capsule endpoints per frame. */
export function createGrassActorContact({THREE,hero,getGroundHeight}){
 const ctx=hero.artistContext(),bones=['l','r'].map(s=>ctx.bones['foot_'+s]),bounds=bones.map(()=>new THREE.Box3()),samples=bones.map(()=>[]),point=new THREE.Vector3();
 hero.object.updateMatrixWorld(true);
 const inverse=bones.map(b=>b.matrixWorld.clone().invert());
 // Bone influence identifies shoes in every pose and both appearances;
 // world-height filtering would accidentally select hands/head when prone.
 ctx.scene.traverse(mesh=>{if(!mesh.isSkinnedMesh)return;mesh.skeleton.update();const positions=mesh.geometry.attributes.position,indices=mesh.geometry.attributes.skinIndex,weights=mesh.geometry.attributes.skinWeight,sideByBone=mesh.skeleton.bones.map(b=>{for(let p=b;p;p=p.parent){const side=bones.indexOf(p);if(side>=0)return side}return -1});for(let i=0;i<positions.count;i++){const influence=[0,0];for(let j=0;j<4;j++){const side=sideByBone[indices.array[i*4+j]];if(side>=0)influence[side]+=weights.array[i*4+j]}const index=influence[0]>influence[1]?0:1;if(influence[index]<.5)continue;point.fromBufferAttribute(positions,i);mesh.applyBoneTransform(i,point);point.applyMatrix4(mesh.matrixWorld).applyMatrix4(inverse[index]);bounds[index].expandByPoint(point);samples[index].push(point.clone())}});
 const local=bounds.map((b,index)=>{if(b.isEmpty())throw Error('Cannot find foot-weighted geometry for '+bones[index].name);const size=b.getSize(new THREE.Vector3()),c=b.getCenter(new THREE.Vector3()),long=['x','y','z'].sort((a,d)=>size[d]-size[a])[0],a=c.clone(),d=c.clone(),cross=['x','y','z'].filter(k=>k!==long),inset=Math.min(size[cross[0]],size[cross[1]])*.5;a[long]=b.min[long]+inset;d[long]=b.max[long]-inset;const segment=new THREE.Line3(a,d),closest=new THREE.Vector3();let radius=0;for(const p of samples[index]){segment.closestPointToPoint(p,true,closest);radius=Math.max(radius,p.distanceTo(closest))}return {a,d,radius}});
 const actorFeet=bones.map(()=>({heel:new THREE.Vector3(),toe:new THREE.Vector3(),radius:0})),actorGround={x:0,y:0,z:0,slopeX:0,slopeZ:0},scale=new THREE.Vector3();
 const result={actorGround,actorFeet};
 return {update(){
  const position=hero.object.position,x=position.x,z=position.z,h=.15;actorGround.x=x;actorGround.z=z;actorGround.y=getGroundHeight(x,z);actorGround.slopeX=(getGroundHeight(x+h,z)-getGroundHeight(x-h,z))/(2*h);actorGround.slopeZ=(getGroundHeight(x,z+h)-getGroundHeight(x,z-h))/(2*h);
  for(let i=0;i<2;i++){const b=bones[i],l=local[i],f=actorFeet[i];f.heel.copy(l.a).applyMatrix4(b.matrixWorld);f.toe.copy(l.d).applyMatrix4(b.matrixWorld);b.getWorldScale(scale);f.radius=l.radius*Math.max(scale.x,scale.y,scale.z)+.018;}
  return result;
 }};
}
