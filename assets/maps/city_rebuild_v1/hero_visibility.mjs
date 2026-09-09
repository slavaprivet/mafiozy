// Actual Artist13 rig merges head/hands and torso/sleeves by material. Build
// alternate index buffers once; vertex attributes and skeleton remain shared.
export const INDOOR_HERO_BODY_MESH_NAMES=Object.freeze([
 'player_male_DEMO_core_FABRIC','player_male_DEMO_core_HAIR',
 'player_male_DEMO_core_SKIN','player_male_DEMO_core_TRIM',
 'player_male_DEMO_hair_HAIR','player_male_DEMO_headwear_FABRIC',
 'player_male_DEMO_headwear_HAIR',
]);
const known=new Set(INDOOR_HERO_BODY_MESH_NAMES),limb=/^(upperarm|forearm|hand|thigh|shin|foot)_[lr]$/,arm=/^(upperarm|forearm|hand)_[lr]$/,head=/^(head|neck|socket_head)$/;
const objectOf=value=>value?.isObject3D?value:value?.object?.isObject3D?value.object:null;
const ancestorOf=(ancestor,node)=>{for(let p=node;p;p=p.parent)if(p===ancestor)return true;return false};
const component=(a,i,j)=>j===0?a.getX(i):j===1?a.getY(i):j===2?a.getZ(i):a.getW(i);

function makeMask(T,mesh,source){
 const joints=source.attributes.skinIndex,weights=source.attributes.skinWeight,bones=mesh.skeleton?.bones;
 if(!mesh.isSkinnedMesh||!joints||!weights||!bones||joints.count!==weights.count)return{source,masked:null,supported:false,triangles:0,armTriangles:0};
 const allowed=new Uint8Array(joints.count),arms=new Uint8Array(joints.count);
 for(let i=0;i<joints.count;i++){
  let limbWeight=0,armWeight=0,headWeight=0,total=0;
  for(let j=0;j<Math.min(4,weights.itemSize);j++){const w=component(weights,i,j),name=bones[component(joints,i,j)]?.name??'';if(!Number.isFinite(w)||w<=0)continue;total+=w;if(limb.test(name))limbWeight+=w;if(arm.test(name))armWeight+=w;if(head.test(name))headWeight+=w}
  // Reject a triangle if any corner has meaningful head/neck influence.
  allowed[i]=total>0&&limbWeight/total>=.55&&headWeight/total<=1e-5?1:0;
  arms[i]=allowed[i]&&armWeight/total>=.55?1:0;
 }
 const index=source.index,count=index?.count??source.attributes.position.count,at=i=>index?index.getX(i):i,kept=[],groups=[];let armTriangles=0;
 const start=Math.max(0,source.drawRange.start),end=Math.min(count,Number.isFinite(source.drawRange.count)?start+source.drawRange.count:count);
 for(let i=start;i+2<end;i+=3){const a=at(i),b=at(i+1),c=at(i+2);if(!allowed[a]||!allowed[b]||!allowed[c])continue;const offset=kept.length;kept.push(a,b,c);if(arms[a]&&arms[b]&&arms[c])armTriangles++;if(source.groups.length){const group=source.groups.find(g=>i>=g.start&&i+2<g.start+g.count);if(group){const last=groups.at(-1);if(last&&last.materialIndex===group.materialIndex&&last.start+last.count===offset)last.count+=3;else groups.push({start:offset,count:3,materialIndex:group.materialIndex})}}}
 if(!kept.length)return{source,masked:null,supported:true,triangles:0,armTriangles:0};
 const masked=new T.BufferGeometry();masked.name=source.name+'_IndoorLimbMask';for(const[name,attribute]of Object.entries(source.attributes))masked.setAttribute(name,attribute);masked.setIndex(kept);
 masked.morphAttributes=source.morphAttributes;masked.morphTargetsRelative=source.morphTargetsRelative;masked.boundingBox=source.boundingBox?.clone()??null;masked.boundingSphere=source.boundingSphere?.clone()??null;
 for(const group of groups)masked.addGroup(group.start,group.count,group.materialIndex);
 return{source,masked,supported:true,triangles:kept.length/3,armTriangles};
}

export function createIndoorHeroVisibility({THREE:T,getHero,getWeapon=()=>null}={}){
 if(!T?.BufferGeometry||typeof getHero!=='function'||typeof getWeapon!=='function')throw Error('Indoor hero visibility requires THREE and getters');
 const snapshots=new Map(),records=new Map();let lastRoot=null,meshes=[],disposed=false;
 function restore(){for(const[node,state]of snapshots){node.visible=state.visible;node.geometry=state.geometry}snapshots.clear()}
 function releaseMasks(){for(const r of records.values())r.masked?.dispose();records.clear()}
 function update(hidden){
  if(disposed)return{supported:false,hidden:false,reason:'disposed'};
  const root=objectOf(getHero());if(root!==lastRoot){restore();releaseMasks();lastRoot=root;meshes=[];root?.traverse(node=>{if(node.isMesh&&known.has(node.name))meshes.push(node)})}
  if(!hidden||!root){restore();return{supported:meshes.length===INDOOR_HERO_BODY_MESH_NAMES.length,hidden:false,bodyMeshes:meshes.length}}
  const weapon=objectOf(getWeapon());let maskedMeshes=0,hiddenMeshes=0,triangles=0,armTriangles=0,supported=meshes.length===INDOOR_HERO_BODY_MESH_NAMES.length;
  for(const mesh of meshes){
   if(weapon&&(ancestorOf(mesh,weapon)||ancestorOf(weapon,mesh)))continue;
   let saved=snapshots.get(mesh);if(!saved){saved={geometry:mesh.geometry,visible:mesh.visible};snapshots.set(mesh,saved)}
   let record=records.get(mesh);if(!record||record.source!==saved.geometry){record?.masked?.dispose();record=makeMask(T,mesh,saved.geometry);records.set(mesh,record)}
   supported=supported&&record.supported;if(record.masked){mesh.geometry=record.masked;mesh.visible=saved.visible;maskedMeshes++;triangles+=record.triangles;armTriangles+=record.armTriangles}else{mesh.visible=false;hiddenMeshes++}
  }
  return{supported,hidden:maskedMeshes+hiddenMeshes>0,bodyMeshes:meshes.length,maskedMeshes,hiddenMeshes,triangles,armTriangles,armsVisible:armTriangles>0,weaponPreserved:true,mode:'audited-skinned-limb-index-mask'};
 }
 function dispose(){if(disposed)return;restore();releaseMasks();disposed=true;lastRoot=null;meshes=[]}
 return{update,restore,dispose,get active(){return snapshots.size>0}};
}
