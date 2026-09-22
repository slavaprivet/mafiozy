// ISOLATED CPU/scene prototype, deliberately not imported by gameplay.
// Only confirmed fatal blast receipts admit effects. No HP, root, bone, source
// visibility, ownership or corpse writes. Host must coordinate body replacement.
const regions=['torso','head','arm_l','arm_r','leg_l','leg_r'];
const regionOf=name=>/head|neck/.test(name)?1:/upperarm_l|forearm_l|hand_l|clavicle_l/.test(name)?2:/upperarm_r|forearm_r|hand_r|clavicle_r/.test(name)?3:/thigh_l|shin_l|foot_l/.test(name)?4:/thigh_r|shin_r|foot_r/.test(name)?5:0;
const finitePoint=p=>p&&[p.x,p.y,p.z].every(Number.isFinite);
const validId=id=>typeof id==='string'&&id.trim().length>0;
export function createNpcBlastPartsPrototype20(THREE,scene,{maxVictims=2,lifetime=8,maxMeshesPerVictim=36,maxTrianglesPerVictim=20000,maxTopologyEntries=32,maxReceipts=256}={}){
 if(![maxVictims,maxMeshesPerVictim,maxTrianglesPerVictim,maxTopologyEntries,maxReceipts].every(v=>Number.isSafeInteger(v)&&v>0)||!Number.isFinite(lifetime)||lifetime<=0||lifetime>10)throw Error('Invalid bounded parts budget');
 const active=[],receipts=new Set(),topologies=new Map(),materialCache=new Map();let disposed=false,admitted=0,cacheHits=0,cacheMisses=0,bakedVertices=0;
 function topology(mesh){
  const g=mesh.geometry,skin=g.attributes.skinIndex,weight=g.attributes.skinWeight,index=g.index;
  if(!mesh.isSkinnedMesh){
   let bone=mesh.parent;while(bone&&!bone.isBone)bone=bone.parent;
   if(!bone)return null;const groups=Array.from({length:6},()=>[]),region=regionOf(bone.name);
   for(let i=0;i<(index?.count??g.attributes.position.count);i++)groups[region].push(index?index.getX(i):i);return groups;
  }
  if(!skin||!weight||skin.count!==g.attributes.position.count)return null;
  // Exact topology key, no geometry/material identity guessed from model names.
  // Classification is shared across actor clones whose skin/index layout matches.
  const labels=mesh.skeleton.bones.map(b=>regionOf(b.name));
  const key=JSON.stringify([labels,Array.from(skin.array),Array.from(weight.array),index?Array.from(index.array):null]);
  let groups=topologies.get(key);if(groups){cacheHits++;return groups;}cacheMisses++;
  groups=Array.from({length:6},()=>[]);const scores=new Float64Array(6),count=index?.count??skin.count;
  for(let i=0;i<count;i+=3){
   scores.fill(0);const vertices=[0,1,2].map(j=>index?index.getX(i+j):i+j);
   for(const v of vertices)for(let slot=0;slot<4;slot++)scores[labels[skin.getComponent(v,slot)]??0]+=weight.getComponent(v,slot);
   let best=0;for(let j=1;j<6;j++)if(scores[j]>scores[best])best=j;
   groups[best].push(...vertices);
  }
  if(topologies.size>=maxTopologyEntries)topologies.delete(topologies.keys().next().value);
  topologies.set(key,groups);return groups;
 }
 function material(source){
  let cached=materialCache.get(source);if(cached){cached.refs++;return cached;}
  // Clone texture objects but share immutable image bytes: source actor disposal
  // cannot dispose our GPU handles; no image generation or duplicate bitmap.
  const value=source.clone(),textures=[];
  for(const key of Object.keys(value))if(value[key]?.isTexture){value[key]=value[key].clone();textures.push(value[key]);}
  cached={source,value,textures,refs:1};materialCache.set(source,cached);return cached;
 }
 function release(record){
  record.group.removeFromParent();
  for(const mesh of record.meshes)mesh.geometry.dispose();
  for(const lease of record.materials)if(--lease.refs===0){lease.value.dispose();for(const texture of lease.textures)texture.dispose();materialCache.delete(lease.source);}
 }
 function admit({receipt,actor,now}={}){
  if(disposed||!Number.isFinite(now)||!receipt||receipt.confirmed!==true||receipt.deathConfirmed!==true||receipt.cause!=='blast'||
     !validId(receipt.eventId)||!validId(receipt.deathKey)||!validId(receipt.actorId)||receipt.actorId!==actor?.id||!finitePoint(receipt.origin)||
     !Number.isFinite(receipt.impulse)||receipt.impulse<0)return {ok:false,reason:'unconfirmed-or-invalid-blast'};
  const key=JSON.stringify([receipt.actorId,receipt.deathKey,receipt.eventId]);
  if(receipts.has(key))return {ok:false,reason:'duplicate'};
  // One effect per actual death, even if additional blast receipts arrive.
  if([...receipts].some(saved=>{const [id,death]=JSON.parse(saved);return id===receipt.actorId&&death===receipt.deathKey;}))return {ok:false,reason:'death-already-presented'};
  if(receipts.size>=maxReceipts)return {ok:false,reason:'receipt-capacity'};
  if(active.length>=maxVictims)return {ok:false,reason:'effect-capacity'};
  const root=actor.walker?.artistContext?.().scene;if(!root)return {ok:false,reason:'rig-unavailable'};
  root.updateWorldMatrix(true,true);const sources=[];let triangles=0;
  root.traverse(mesh=>{
   if(!mesh.isMesh||!mesh.geometry?.attributes.position||mesh.userData.bulletWound)return;
   for(let n=mesh;n;n=n.parent)if(n.visible===false||n===actor.weapon)return;
   sources.push(mesh);triangles+=(mesh.geometry.index?.count??mesh.geometry.attributes.position.count)/3;
  });
  if(!sources.length||triangles>maxTrianglesPerVictim)return {ok:false,reason:'geometry-capacity'};
  const layouts=sources.map(mesh=>({mesh,groups:topology(mesh)}));
  if(layouts.some(row=>!row.groups)||layouts.reduce((n,row)=>n+row.groups.filter(x=>x.length).length,0)>maxMeshesPerVictim||sources.some(m=>Array.isArray(m.material)))return {ok:false,reason:'layout-unsupported',missing:layouts.filter(row=>!row.groups).map(row=>row.mesh.name),meshCount:layouts.reduce((n,row)=>n+(row.groups?.filter(x=>x.length).length||0),0),multiMaterials:sources.filter(m=>Array.isArray(m.material)).map(m=>m.name)};
  const group=new THREE.Group(),parts=regions.map(name=>{const p=new THREE.Group();p.name='BlastPart20_'+name;group.add(p);return p;}),meshes=[],materials=[],point=new THREE.Vector3();
  for(const {mesh,groups} of layouts){
   mesh.skeleton?.update();const posed=[];
   for(let i=0;i<mesh.geometry.attributes.position.count;i++){mesh.getVertexPosition(i,point).applyMatrix4(mesh.matrixWorld);posed.push(point.x,point.y,point.z);bakedVertices++;}
   for(let r=0;r<6;r++){
    if(!groups[r].length)continue;const remap=new Map(),positions=[],indices=[],uv=[],color=[],sourceUv=mesh.geometry.attributes.uv,sourceColor=mesh.geometry.attributes.color;
    for(const original of groups[r]){
     let target=remap.get(original);if(target===undefined){target=remap.size;remap.set(original,target);positions.push(...posed.slice(original*3,original*3+3));if(sourceUv)uv.push(sourceUv.getX(original),sourceUv.getY(original));if(sourceColor)color.push(sourceColor.getX(original),sourceColor.getY(original),sourceColor.getZ(original));}indices.push(target);
    }
    const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));geometry.setIndex(indices);
    if(uv.length)geometry.setAttribute('uv',new THREE.Float32BufferAttribute(uv,2));if(color.length)geometry.setAttribute('color',new THREE.Float32BufferAttribute(color,3));geometry.computeVertexNormals();geometry.computeBoundingBox();
    const lease=material(mesh.material),fragment=new THREE.Mesh(geometry,lease.value);materials.push(lease);parts[r].add(fragment);meshes.push(fragment);
   }
  }
  const motion=[];
  for(let i=0;i<parts.length;i++){
   const part=parts[i];if(!part.children.length)continue;
   const center=new THREE.Box3().setFromObject(part).getCenter(new THREE.Vector3());
   for(const mesh of part.children)mesh.geometry.translate(-center.x,-center.y,-center.z);part.position.copy(center);
   const direction=center.clone().sub(receipt.origin);direction.y=Math.max(.3,direction.y);if(direction.lengthSq()<1e-8)direction.set(0,1,0);direction.normalize();
   motion.push({part,start:center,velocity:direction.multiplyScalar(Math.min(8,receipt.impulse)*(1+i*.04)),spin:new THREE.Vector3(.4+i*.17,.3-i*.08,.15+i*.12)});
  }
  scene.add(group);active.push({group,meshes,materials,motion,at:now});receipts.add(key);admitted++;
  return {ok:true,parts:motion.length,meshes:meshes.length,triangles,group};
 }
 function update(now){
  if(disposed||!Number.isFinite(now))return;
  for(let i=active.length-1;i>=0;i--){const r=active[i],age=Math.max(0,now-r.at);if(age>=lifetime){release(r);active.splice(i,1);continue;}
   for(const m of r.motion){m.part.position.copy(m.start).addScaledVector(m.velocity,age);m.part.position.y-=4.905*age*age;m.part.rotation.set(m.spin.x*age,m.spin.y*age,m.spin.z*age);}
  }
 }
 return {admit,update,stats:()=>({activeVictims:active.length,meshes:active.reduce((n,r)=>n+r.meshes.length,0),topologyEntries:topologies.size,materialLeases:materialCache.size,receipts:receipts.size,admitted,cacheHits,cacheMisses,bakedVertices}),dispose(){if(disposed)return;disposed=true;for(const r of active)release(r);active.length=0;receipts.clear();topologies.clear();}};
}
