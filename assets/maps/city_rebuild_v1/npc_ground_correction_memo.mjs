// Isolated NPC helper. Caller must supply the exact immutable mesh-reference
// list captured by the original groundPose, not a later scene traversal.
export function createNpcGroundCorrectionMemo({THREE:T,context:c,poseMeshes}={}){
 const meshes=Array.isArray(poseMeshes)?poseMeshes.slice():null,original=c?.groundPose;
 const counts={hits:0,misses:0,fallbacks:0};let cached=null,disposed=false;
 const skin=T?.SkinnedMesh?.prototype,obj=T?.Object3D?.prototype;
 const ownData=(o,k)=>{const d=Object.getOwnPropertyDescriptor(o,k);return !d||'value'in d;};
 const standard=(o,k,p)=>ownData(o,k)&&o[k]===p?.[k];
 function fallback(){counts.fallbacks++;cached=null;const before=c.visualPivot.position.y;c.groundPose();return c.visualPivot.position.y-before;}
 function prepare(){
  if(disposed||String(T?.REVISION)!=='180'||!meshes||c?.groundPose!==original||typeof original!=='function')return null;
  const root=c.object;if(!root?.isObject3D||!c.visualPivot?.isObject3D)return null;
  const all=[],seen=new Set(),stack=[root];
  while(stack.length){const n=stack.pop();if(!n||seen.has(n))return null;seen.add(n);all.push(n);
   if(!standard(n,'updateMatrixWorld',n.isSkinnedMesh?skin:obj)||!standard(n,'updateMatrix',obj)||n.matrixWorldAutoUpdate!==true)return null;
   for(const key of ['parent','children','position','quaternion','scale','matrix','matrixWorld'])if(!ownData(n,key))return null;
   if(!Array.isArray(n.children)||!n.matrix?.elements?.every(Number.isFinite)||!n.matrixWorld?.elements?.every(Number.isFinite))return null;
   if(![n.position.x,n.position.y,n.position.z,n.quaternion.x,n.quaternion.y,n.quaternion.z,n.quaternion.w,n.scale.x,n.scale.y,n.scale.z].every(Number.isFinite))return null;
   for(const child of n.children)stack.push(child);
  }
  if(!seen.has(c.visualPivot)||!seen.has(c.offset)||!seen.has(c.scaled))return null;
  for(const mesh of meshes){
   if(!seen.has(mesh)||!mesh.isMesh||!ownData(mesh,'geometry'))return null;
   const g=mesh.geometry;if(!g?.isBufferGeometry||!ownData(g,'attributes')||!ownData(g,'morphAttributes')||!g.attributes?.position)return null;
   const attributes=[g.attributes.position,...(mesh.isSkinnedMesh?[g.attributes.skinIndex,g.attributes.skinWeight]:[]),...Object.values(g.morphAttributes||{}).flat()];
   for(const a of attributes){
    if(!a?.isBufferAttribute||['array','version','count','itemSize','normalized'].some(k=>!ownData(a,k))||a.isInterleavedBufferAttribute||!ArrayBuffer.isView(a.array)||a.array instanceof DataView||typeof a.array[0]==='bigint'||a.count<=0||a.array.length!==a.count*a.itemSize)return null;
    if(!['getX','getY','getZ','getW','getComponent'].every(k=>standard(a,k,T.BufferAttribute.prototype)))return null;
   }
   if(mesh.isSkinnedMesh){
    if(['bindMode','bindMatrix','bindMatrixInverse','skeleton'].some(k=>!ownData(mesh,k))||mesh.bindMode!=='attached'||!standard(mesh,'applyBoneTransform',skin)||!standard(mesh.skeleton,'update',T.Skeleton.prototype))return null;
    if(mesh.skeleton.bones.length!==mesh.skeleton.boneInverses.length||mesh.skeleton.bones.some(b=>!seen.has(b)))return null;
    if(!mesh.bindMatrix.elements.every(Number.isFinite)||mesh.skeleton.boneInverses.some(m=>!m.elements.every(Number.isFinite)))return null;
   }
  }
  return all;
 }
 // Streaming exact comparisons: unchanged keys do not allocate a new numeric
 // snapshot. Raw typed-array reads detect unversioned edits; no hash collision
 // or position.version-only assumption can silently reuse stale grounding.
 function fingerprint(nodes){
  const old=cached?.key;let i=0,j=0,tokens=old?null:[],arrays=old?null:[],same=!!old;
  function token(value){if(!old||!Object.is(old.tokens[i],value)){same=false;if(tokens===null)tokens=old.tokens.slice(0,i);}if(tokens)tokens.push(value);i++;}
  function matrix(m){token(m);for(const v of m.elements)token(v);}
  function data(a){
   token(a);token(a.array);token(a.version);token(a.count);token(a.itemSize);token(a.normalized);
   const view=a.array,previous=old?.arrays[j];let equal=previous?.source===view&&previous.values.length===view.length;
   if(equal)for(let k=0;k<view.length;k++)if(!Object.is(view[k],previous.values[k])){equal=false;break;}
   if(!equal){same=false;if(arrays===null)arrays=old.arrays.slice(0,j);}
   if(arrays)arrays.push(equal?previous:{source:view,values:view.slice()});j++;
  }
  token(c.object);token(c.visualPivot);token(c.offset);token(c.scaled);token(c.scene);token(c.bones);token(c.rest);token(c.targetHeight);token(c.sourceHeight);
  // Real GLB Float32 skin weights need not sum to exactly one. A root-height
  // change produced >1e-7 local correction drift in native groundPose despite
  // inverseRoot. Preserve that result: moving/yawing roots/platforms invalidate.
  matrix(c.object.matrixWorld);
  for(const v of [c.object.scale.x,c.object.scale.y,c.object.scale.z,c.object.rotation.x,c.object.rotation.z,c.object.rotation.order])token(v);
  for(const node of nodes){token(node);token(node.parent);token(node.matrixAutoUpdate);if(node!==c.object)matrix(node.matrix);}
  for(const [name,bone]of Object.entries(c.bones||{})){token(name);token(bone);}
  for(const [name,r]of Object.entries(c.rest||{})){token(name);token(r);if(r.matrix?.elements)matrix(r.matrix);for(const k of ['p','q','s'])if(r[k]){token(r[k]);for(const v of r[k].toArray())token(v);}}
  for(const mesh of meshes){const g=mesh.geometry;token(mesh);token(g);token(g.morphTargetsRelative);data(g.attributes.position);
   if(mesh.isSkinnedMesh){token(mesh.skeleton);token(mesh.bindMode);matrix(mesh.bindMatrix);data(g.attributes.skinIndex);data(g.attributes.skinWeight);for(const b of mesh.skeleton.bones)token(b);for(const m of mesh.skeleton.boneInverses)matrix(m);}
   for(const [name,attrs]of Object.entries(g.morphAttributes||{})){token(name);for(const a of attrs)data(a);}for(const value of mesh.morphTargetInfluences||[])token(value);
  }
  if(old&&(i!==old.tokens.length||j!==old.arrays.length))same=false;
  return{same,key:same?old:{tokens:tokens??old.tokens.slice(0,i),arrays:arrays??old.arrays.slice(0,j)}};
 }
 function apply(){
  const nodes=prepare();if(!nodes)return fallback();
  c.object.updateMatrixWorld(true);
  if(!c.object.matrixWorld.elements.every(Number.isFinite)||c.object.matrixWorld.determinant()===0)return fallback();
  const state=fingerprint(nodes),before=c.visualPivot.position.y;
  if(state.same){
   // Preserve the original per-mesh skeleton updates for renderer consumers.
   for(const mesh of meshes)if(mesh.isSkinnedMesh)mesh.skeleton.update();
   c.visualPivot.position.y=cached.correctedY;c.object.updateMatrixWorld(true);counts.hits++;return cached.correctionY;
  }
  counts.misses++;cached=null;
  original.call(c);const correctionY=c.visualPivot.position.y-before;
  if(Number.isFinite(correctionY))cached={key:state.key,correctionY,correctedY:c.visualPivot.position.y};
  return correctionY;
 }
 return{apply,invalidate(){cached=null;},stats(){return{...counts,disposed};},dispose(){disposed=true;cached=null;}};
}
