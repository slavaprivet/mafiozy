import {createWeaponModel} from './hero_arsenal.mjs';

// Presentation of local inventory drops; never creates inventory or ammo itself.
export function createGroundWeapons({THREE,scene,groundHeight=()=>0,scale=.368}={}){
 const items=new Map();
 const falling=new Set();let settled=0;
 const disposeNode=node=>{const geometries=new Set(),materials=new Set();node.traverse(n=>{if(n.geometry)geometries.add(n.geometry);for(const m of Array.isArray(n.material)?n.material:n.material?[n.material]:[])materials.add(m)});node.removeFromParent();geometries.forEach(g=>g.dispose());materials.forEach(m=>m.dispose())};
 function sync(drops){
  const ids=new Set(drops.map(d=>d.uid));
  for(const [uid,item] of items)if(!ids.has(uid)){if(item.age>=.4)settled--;else falling.delete(item);disposeNode(item.root);items.delete(uid)}
  for(const drop of drops){
   if(items.has(drop.uid))continue;
   const root=new THREE.Group(),model=createWeaponModel({THREE,id:drop.weaponId});
   root.name=`ground_weapon_${drop.uid}`;root.userData.weaponDropUid=drop.uid;
   model.scale.setScalar(scale);model.rotation.z=Math.PI/2;root.add(model);
   root.rotation.y=drop.yaw;root.position.set(drop.position.x,0,drop.position.z);root.updateMatrixWorld(true);
   const bounds=new THREE.Box3().setFromObject(root),center=bounds.getCenter(new THREE.Vector3());
   // Center the actual mesh over the pickup point, including asymmetric barrels.
   root.position.x+=drop.position.x-center.x;root.position.z+=drop.position.z-center.z;root.updateMatrixWorld(true);
   bounds.setFromObject(root);
   const sample=(x,z)=>groundHeight(x,z,drop.position.y);
   const floor=Math.max(drop.position.y,sample(bounds.min.x,bounds.min.z),sample(bounds.max.x,bounds.min.z),sample(bounds.min.x,bounds.max.z),sample(bounds.max.x,bounds.max.z));
   const restY=floor-bounds.min.y+.009;root.position.y=restY+.55;scene.add(root);
   const item={root,model,restY,age:0,position:{...drop.position}};items.set(drop.uid,item);falling.add(item);
  }
 }
 // Settled weapons no longer change; retaining them in the render scene is enough.
 function update(dt){for(const item of falling){item.age+=Math.max(0,Math.min(.1,dt));const t=Math.min(1,item.age/.4);item.root.position.y=item.restY+.55*(1-t*t);if(item.age>=.4){falling.delete(item);settled++}}}
 function dispose(){for(const item of items.values())disposeNode(item.root);items.clear();falling.clear();settled=0}
 return {sync,update,dispose,getObject:uid=>items.get(uid)?.root??null,stats:()=>({count:items.size,settled})};
}

// Range and sampled unobstructed path prevent pickups across walls/floors.
export function nearestWeaponDrop(drops,position,{range=1.65,maxHeight=.65,reachable=()=>true}={}){
 if(!position)return null;
 let nearest=null;
 for(const drop of drops){
  const p=drop.position,dx=p.x-position.x,dz=p.z-position.z,distance=Math.hypot(dx,dz);
  if(distance>range||Math.abs(p.y-position.y)>maxHeight||nearest&&nearest.distance<=distance)continue;
  let clear=true;const steps=Math.max(1,Math.ceil(distance/.12));
  for(let i=1;i<=steps;i++){const t=i/steps;if(!reachable(position.x+dx*t,position.z+dz*t)){clear=false;break}}
  if(clear)nearest={drop,distance};
 }
 return nearest;
}
