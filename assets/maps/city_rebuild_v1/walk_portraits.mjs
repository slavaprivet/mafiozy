// Photographs of the actual game rigs. No alternate identity or gameplay state.
function stable(value){
 if(value===null||typeof value!=='object')return JSON.stringify(value);
 if(Array.isArray(value))return '['+value.map(stable).join(',')+']';
 return '{'+Object.keys(value).sort().map(key=>JSON.stringify(key)+':'+stable(value[key])).join(',')+'}';
}

// Intentionally excludes animated matrices and the root's first-person visibility.
// Call at the HUD's low-frequency refresh, not in the animation loop.
export function walkPortraitSignature(source,{key='',appearance=null}={}){
 if(!source?.traverse)return '';
 const parts=[String(key),source.uuid,stable(appearance)];
 source.traverse(node=>{
  if(node!==source)parts.push(node.uuid,node.visible?'1':'0');
  if(node.userData?.npcAppearance)parts.push(stable(node.userData.npcAppearance));
  if(!node.isMesh)return;
  const g=node.geometry;parts.push(g?.uuid,g?.index?.version);
  for(const name of ['position','color','normal'])parts.push(g?.attributes?.[name]?.version);
  parts.push((node.morphTargetInfluences||[]).join(','));
  for(const m of Array.isArray(node.material)?node.material:[node.material]){
   if(!m)continue;
   parts.push(m.uuid,m.version,m.visible,m.opacity,m.transparent,m.vertexColors,m.color?.getHexString(),m.emissive?.getHexString(),m.emissiveIntensity,m.roughness,m.metalness);
   for(const name of ['map','normalMap','roughnessMap','metalnessMap','alphaMap','emissiveMap'])parts.push(m[name]?.uuid,m[name]?.version);
  }
 });
 return parts.join('|');
}

function isolatedSkeletonClone(source){
 const clone=source.clone(true),original=[],copied=[];source.traverse(o=>original.push(o));clone.traverse(o=>copied.push(o));
 const mapping=new Map(original.map((node,index)=>[node,copied[index]]));
 for(let i=0;i<original.length;i++)if(original[i].isSkinnedMesh){
  const from=original[i],to=copied[i];to.skeleton=from.skeleton.clone();to.skeleton.bones=from.skeleton.bones.map(bone=>mapping.get(bone));
  if(to.skeleton.bones.some(bone=>!bone))throw Error('Portrait source must include complete rig');
  to.bindMatrix.copy(from.bindMatrix);to.bindMatrixInverse.copy(from.bindMatrixInverse);
 }
 return clone;
}

export function cloneWalkPortraitModel({THREE,source,cloneSkeleton=isolatedSkeletonClone,rest=null}){
 if(!source?.isObject3D)throw Error('Actual portrait model required');
 const model=cloneSkeleton(source),materials=new Set(),skeletons=new Set(),sourceBones=new Set(),sourceSkeletons=new Set();
 if(!model?.isObject3D||model===source)throw Error('Portrait requires an independent clone');
 source.traverse(node=>{if(node.isBone)sourceBones.add(node);if(node.skeleton)sourceSkeletons.add(node.skeleton)});
 // Validate before any material replacement or neutral posing, even if the host
 // accidentally passes Object3D.clone instead of SkeletonUtils.clone.
 model.traverse(node=>{if(sourceBones.has(node)||node.isSkinnedMesh&&(sourceSkeletons.has(node.skeleton)||node.skeleton.bones.some(b=>sourceBones.has(b))))throw Error('Portrait skeleton must be isolated')});
 // Sharing immutable geometry/textures is safe; material and bone state are owned.
 model.traverse(node=>{
  if(node.isBone&&sourceBones.has(node))throw Error('Portrait skeleton must be isolated');
  if(node.isMesh){
   node.material=Array.isArray(node.material)?node.material.map(copyMaterial):copyMaterial(node.material);
   node.castShadow=false;node.receiveShadow=false;node.frustumCulled=false;
  }
  if(node.isSkinnedMesh){if(node.skeleton.bones.some(b=>sourceBones.has(b)))throw Error('Portrait bones must be isolated');skeletons.add(node.skeleton)}
  // Props never obstruct a character's face, and do not affect bust bounds.
  if(node.name==='socket_weapon')for(const child of node.children)child.visible=false;
 });
 function copyMaterial(material){if(!material)return material;const copy=material.clone();materials.add(copy);return copy}
 model.position.set(0,0,0);model.quaternion.identity();model.visible=true;model.updateMatrix();
 // createHeroWalker wrappers contain temporary dive/vehicle/posture transforms.
 if(model.name==='Artist13_Walk_Hero'){
  const pivot=model.children[0],scaled=pivot?.children[0];
  if(pivot){pivot.position.set(0,0,0);pivot.quaternion.identity();pivot.updateMatrix()}
  if(scaled){scaled.position.y=0;scaled.updateMatrix()}
 }
 if(rest){model.traverse(node=>{if(node.isBone&&rest[node.name]){node.matrix.copy(rest[node.name].matrix);node.matrix.decompose(node.position,node.quaternion,node.scale);node.matrixWorldNeedsUpdate=true}})}
 else {for(const skeleton of skeletons)skeleton.pose();model.traverse(node=>{if(node.isBone)node.updateMatrix()})}
 model.updateMatrixWorld(true);for(const skeleton of skeletons)skeleton.update();
 let disposed=false;
 return {model,dispose(){if(disposed)return;disposed=true;model.removeFromParent();for(const material of materials)material.dispose();for(const skeleton of skeletons)skeleton.dispose?.()}};
}

export function frameWalkPortrait(THREE,model,aspect=.8){
 model.updateMatrixWorld(true);
 const points=[],point=new THREE.Vector3(),bounds=new THREE.Box3();
 model.traverseVisible(node=>{
  if(!node.isMesh||!node.geometry?.attributes?.position)return;
  const count=node.geometry.attributes.position.count;
  for(let i=0;i<count;i++){
   if(node.getVertexPosition)node.getVertexPosition(i,point);else point.fromBufferAttribute(node.geometry.attributes.position,i);
   point.applyMatrix4(node.matrixWorld);bounds.expandByPoint(point);points.push(point.clone());
  }
 });
 if(bounds.isEmpty())throw Error('Portrait has no visible geometry');
 const height=Math.max(.1,bounds.max.y-bounds.min.y),cropBottom=bounds.min.y+height*.48,bust=new THREE.Box3();
 for(const p of points)if(p.y>=cropBottom)bust.expandByPoint(p);
 bust.min.y=cropBottom;
 const center=bust.getCenter(new THREE.Vector3()),size=bust.getSize(new THREE.Vector3());
 const halfHeight=Math.max(size.y*.54,size.x/(2*aspect)*1.055),camera=new THREE.OrthographicCamera(-halfHeight*aspect,halfHeight*aspect,halfHeight,-halfHeight,.01,height*12);
 camera.position.set(center.x,center.y,center.z+height*4);camera.lookAt(center);camera.updateMatrixWorld(true);camera.updateProjectionMatrix();
 return {camera,bounds:bust,center};
}

export function createWalkPortraitRenderer({THREE,document:doc=globalThis.document,cloneSkeleton,width=256,height=320,maxCache=32}={}){
 const cache=new Map();let renderer=null,scene=null,disposed=false,failed=false,renders=0,lastError=null;
 const limit=Math.max(1,Math.min(64,Math.floor(maxCache)||32));
 const imageWidth=Math.max(64,Math.min(512,Math.floor(width)||256)),imageHeight=Math.max(64,Math.min(640,Math.floor(height)||320));
 function initialize(){
  if(disposed||failed||!THREE?.WebGLRenderer||!doc?.createElement)return false;
  try{
   renderer=new THREE.WebGLRenderer({canvas:doc.createElement('canvas'),alpha:true,antialias:true,preserveDrawingBuffer:true});
   renderer.setPixelRatio(1);renderer.setSize(imageWidth,imageHeight,false);renderer.setClearColor(0x000000,0);
   if(THREE.SRGBColorSpace)renderer.outputColorSpace=THREE.SRGBColorSpace;
   renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
   scene=new THREE.Scene();scene.add(new THREE.HemisphereLight(0xe7efff,0x514047,2));
   for(const [color,intensity,x,y,z] of [[0xffe7c9,2.8,-3,4,5],[0xbbd5ea,1.3,3,2,3],[0xe8bb7c,1.8,1,3,-3]]){const light=new THREE.DirectionalLight(color,intensity);light.position.set(x,y,z);scene.add(light)}
   return true;
  }catch(error){lastError=error.message;failed=true;renderer?.dispose();renderer?.forceContextLoss?.();renderer=null;return false}
 }
 function render(source,options={}){
  if(disposed||!source?.isObject3D)return null;
  const signature=walkPortraitSignature(source,options);
  if(cache.has(signature)){const url=cache.get(signature);cache.delete(signature);cache.set(signature,url);return url}
  if(!renderer&&!initialize())return null;
  let portrait;
  try{
   portrait=cloneWalkPortraitModel({THREE,source,cloneSkeleton,rest:options.rest});
   const {camera}=frameWalkPortrait(THREE,portrait.model,imageWidth/imageHeight);scene.add(portrait.model);renderer.render(scene,camera);
   const url=renderer.domElement.toDataURL('image/png');cache.set(signature,url);renders++;
   while(cache.size>limit)cache.delete(cache.keys().next().value);
   lastError=null;return url;
  }catch(error){lastError=error.message;return null}
  finally{portrait?.dispose()}
 }
 return {renderHero:render,renderNpc:render,invalidate(){cache.clear()},get size(){return cache.size},get renders(){return renders},get error(){return lastError},
  dispose(){if(disposed)return;disposed=true;cache.clear();renderer?.dispose();renderer?.forceContextLoss?.();renderer=null;scene=null}};
}
