// Run once on one independently cloned NPC, after SkeletonUtils.bind and before
// its first render. Never pass the immutable template or a whole population.
// Rig topology and inverse-array ownership must remain immutable afterwards;
// a future per-part rebind must first give that part its own Skeleton again.
const STANDARD_FIELDS=new Set(['uuid','bones','boneInverses','boneMatrices','boneTexture']);

export function shareNpcCloneSkeletons({THREE,root}={}){
 if(!THREE?.Skeleton||!root?.isObject3D)throw Error('THREE and one independent NPC clone required');
 const meshes=[],localBones=new Set();
 root.traverse(node=>{if(node.isBone)localBones.add(node);if(node.isSkinnedMesh)meshes.push(node);});
 const before=new Set(meshes.map(mesh=>mesh.skeleton)),eligible=new Map(),groups=[];
 for(const skeleton of before){
  // Do not change uploaded resources, subclasses, custom methods/state, or rigs
  // referring to bones outside this clone. Unknown future THREE fields opt out.
  const standard=skeleton&&Object.getPrototypeOf(skeleton)===THREE.Skeleton.prototype&&
   Reflect.ownKeys(skeleton).every(key=>STANDARD_FIELDS.has(key)&&'value' in Object.getOwnPropertyDescriptor(skeleton,key))&&
   skeleton.boneTexture===null&&Array.isArray(skeleton.bones)&&skeleton.bones.length>0&&
   skeleton.bones.every(bone=>localBones.has(bone))&&Array.isArray(skeleton.boneInverses)&&
   skeleton.boneInverses.length===skeleton.bones.length&&
   skeleton.boneMatrices instanceof Float32Array&&skeleton.boneMatrices.length===skeleton.bones.length*16;
  eligible.set(skeleton,!!standard);
 }
 let sharedMeshes=0;
 for(const mesh of meshes){
  const skeleton=mesh.skeleton;if(!eligible.get(skeleton))continue;
  const canonical=groups.find(other=>other.boneInverses===skeleton.boneInverses&&
   other.bones.length===skeleton.bones.length&&other.bones.every((bone,index)=>bone===skeleton.bones[index])&&
   other.boneMatrices.every((value,index)=>Object.is(value,skeleton.boneMatrices[index])));
  if(!canonical){groups.push(skeleton);continue;}
  if(canonical!==skeleton){mesh.skeleton=canonical;sharedMeshes++;}
 }
 // Displaced skeletons have no texture and need no disposal; do not invoke
 // disposal hooks. Their CPU arrays become collectible. Mesh bind matrices,
 // materials, geometries, morphs and transforms are deliberately untouched.
 return {skinnedMeshes:meshes.length,skeletonsBefore:before.size,
  skeletonsAfter:new Set(meshes.map(mesh=>mesh.skeleton)).size,sharedMeshes,
  skippedSkeletons:[...eligible.values()].filter(value=>!value).length};
}
