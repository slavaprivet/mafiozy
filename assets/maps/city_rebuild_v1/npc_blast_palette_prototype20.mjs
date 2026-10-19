// ISOLATED feasibility prototype. No gameplay imports, receipts or source writes.
// prepare() is a loading-time operation, never a death-frame operation.
const names=['torso','head','arm_l','arm_r','leg_l','leg_r'];
const region=name=>/head|neck/.test(name)?1:/upperarm_l|forearm_l|hand_l|clavicle_l/.test(name)?2:/upperarm_r|forearm_r|hand_r|clavicle_r/.test(name)?3:/thigh_l|shin_l|foot_l/.test(name)?4:/thigh_r|shin_r|foot_r/.test(name)?5:0;
export function prepareNpcBlastPalette20(THREE,root,{maxTriangles=20000,maxMeshes=36}={}){
  root.updateWorldMatrix(true,true);
  const sources=[],geometries=[];let triangles=0,disposed=false,leases=0;
  root.traverse(mesh=>{
    if(!mesh.isMesh||!mesh.geometry?.attributes.position||mesh.userData.bulletWound)return;
    for(let p=mesh;p;p=p.parent)if(!p.visible)return;
    if(Array.isArray(mesh.material)||mesh.geometry.morphAttributes.position?.length)throw Error('Unsupported material/morph layout');
    const g=mesh.geometry,skin=g.attributes.skinIndex,weights=g.attributes.skinWeight;
    let bone=mesh.parent;while(bone&&!bone.isBone)bone=bone.parent;
    if(!mesh.isSkinnedMesh&&!bone)throw Error('Rigid geometry must be bone attached');
    const labels=mesh.isSkinnedMesh?mesh.skeleton.bones.map(b=>region(b.name)):null;
    if(labels&&(!skin||!weights))throw Error('Missing skin layout');
    const lists=Array.from({length:6},()=>[]),count=g.index?.count??g.attributes.position.count;
    triangles+=count/3;if(triangles>maxTriangles)throw Error('Triangle capacity');
    for(let i=0;i<count;i+=3){
      const tri=[0,1,2].map(j=>g.index?g.index.getX(i+j):i+j),scores=new Float64Array(6);
      let best=region(bone?.name??'');
      if(labels){for(const v of tri)for(let j=0;j<4;j++)scores[labels[skin.getComponent(v,j)]??0]+=weights.getComponent(v,j);best=0;for(let r=1;r<6;r++)if(scores[r]>scores[best])best=r;}
      lists[best].push(...tri);
    }
    // Owned CPU buffers: destruction or mutation of the source cannot change FX.
    const owned=g.clone();owned.clearGroups();
    const pieces=lists.map((indices,r)=>{
      if(!indices.length)return null;
      if(geometries.length>=maxMeshes)throw Error('Mesh capacity');
      const geometry=new THREE.BufferGeometry();
      for(const [name,attribute]of Object.entries(owned.attributes))geometry.setAttribute(name,attribute);
      geometry.setIndex(indices);geometries.push(geometry);return {geometry,region:r};
    }).filter(Boolean);
    sources.push({mesh,pieces,labels,position:g.attributes.position,index:g.index});
  });
  function dispose(){if(disposed)return;if(leases)throw Error('Active frozen victims retain prepared geometry');disposed=true;for(const g of geometries)g.dispose();sources.length=0;}
  function freeze({maxVictims=2}={}){
    if(disposed||leases>=Math.min(2,maxVictims))throw Error('Prepared palette unavailable');
    root.updateWorldMatrix(true,true);
    const group=new THREE.Group(),parts=names.map(name=>{const p=new THREE.Group();p.name='FrozenPalette20_'+name;group.add(p);return p;}),skeletons=new Map(),materials=new Map(),textures=[],pairs=[];
    const pivotSums=names.map(()=>new THREE.Vector3()),pivotCounts=names.map(()=>0);
    for(const {mesh,labels,position,index}of sources){
      if(mesh.geometry.attributes.position!==position||mesh.geometry.index!==index)throw Error('Prepared actor geometry replaced');
      if(!labels)continue;
      for(let i=0;i<labels.length;i++){pivotSums[labels[i]].add(new THREE.Vector3().setFromMatrixPosition(mesh.skeleton.bones[i].matrixWorld));pivotCounts[labels[i]]++;}
    }
    for(let r=0;r<6;r++)parts[r].position.copy(pivotCounts[r]?pivotSums[r].divideScalar(pivotCounts[r]):new THREE.Vector3().setFromMatrixPosition(root.matrixWorld));
    group.updateMatrixWorld(true);
    for(const {mesh,pieces,labels}of sources){
      let skeleton;
      if(labels){
        skeleton=skeletons.get(mesh.skeleton);
        if(!skeleton){
          const bones=mesh.skeleton.bones.map(source=>{const b=new THREE.Bone();b.name=source.name;b.matrixAutoUpdate=false;b.matrixWorld.copy(source.matrixWorld);return b;});
          skeleton=new THREE.Skeleton(bones,mesh.skeleton.boneInverses.map(m=>m.clone()));skeleton.update();skeletons.set(mesh.skeleton,skeleton);
        }
      }
      let material=materials.get(mesh.material);
      if(!material){material=mesh.material.clone();for(const key of Object.keys(material))if(material[key]?.isTexture){material[key]=material[key].clone();textures.push(material[key]);}materials.set(mesh.material,material);}
      for(const piece of pieces){
        const fragment=labels?new THREE.SkinnedMesh(piece.geometry,material):new THREE.Mesh(piece.geometry,material);
        if(skeleton){
          fragment.skeleton=skeleton;fragment.bindMode='detached';fragment.bindMatrix.copy(mesh.bindMatrix);fragment.bindMatrixInverse.copy(mesh.bindMatrixInverse);
          // A live attached mesh can have bindMatrixInverse != inverse(bindMatrix).
          // Freeze BOTH exact admission matrices. Standard detached update would
          // overwrite the inverse and double-apply the actor's world transform.
          fragment.updateMatrixWorld=function(force){THREE.Mesh.prototype.updateMatrixWorld.call(this,force);};
        }
        fragment.matrixAutoUpdate=false;fragment.matrix.copy(parts[piece.region].matrixWorld).invert().multiply(mesh.matrixWorld);
        // No per-frame CPU computeBoundingSphere on a skinned mesh. Conservative
        // region bounds / host distance cull remain integration requirements.
        fragment.frustumCulled=false;parts[piece.region].add(fragment);pairs.push({source:mesh,fragment,region:piece.region});
      }
    }
    leases++;group.updateMatrixWorld(true);let released=false;
    return {group,parts,pairs,skeletons:[...skeletons.values()],stats:{drawCalls:pairs.length,paletteFloats:[...skeletons.values()].reduce((n,s)=>n+s.boneMatrices.length,0)},dispose(){if(released)return;released=true;group.removeFromParent();group.clear();for(const s of skeletons.values())s.dispose();for(const m of materials.values())m.dispose();for(const t of textures)t.dispose();leases--;}};
  }
  return {freeze,dispose,stats:()=>({preparedMeshes:geometries.length,triangles,leases,disposed})};
}
