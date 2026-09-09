import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {ARSENAL} from './hero_arsenal.mjs';
import {createGroundWeapons,nearestWeaponDrop} from './ground_weapons.mjs';
import {createWeaponInventory} from './weapon_inventory.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const scene=new THREE.Scene(),inventory=createWeaponInventory(),floor=-2.3,scale=.368;
const renderer=createGroundWeapons({THREE,scene,scale,groundHeight:()=>floor});
for(const spec of ARSENAL.filter(s=>s.id!=='none')){
 inventory.equip(spec.id);const result=inventory.drop({position:{x:4,y:floor,z:6},yaw:.73});assert(result.ok);
}
renderer.sync(inventory.getDropped());assert.equal(renderer.stats().count,14);
const original=renderer.getObject(inventory.getDropped()[0].uid);renderer.sync(inventory.getDropped());assert.equal(renderer.getObject(inventory.getDropped()[0].uid),original);
for(let i=0;i<50;i++)renderer.update(.016);
for(const drop of inventory.getDropped()){
 const model=renderer.getObject(drop.uid),bounds=new THREE.Box3().setFromObject(model),center=bounds.getCenter(new THREE.Vector3());
 assert(Math.abs(bounds.min.y-floor-.009)<1e-8,`${drop.weaponId} rests on actual floor`);
 assert(Math.abs(center.x-drop.position.x)<1e-8&&Math.abs(center.z-drop.position.z)<1e-8,'pickup centered on actual mesh');
 assert.equal(model.children[0].scale.x,scale,'same scale as held');
 assert(bounds.max.y-bounds.min.y<.3,'gun lies on side');
}
assert.equal(renderer.stats().settled,14);
const drops=inventory.getDropped();
assert(nearestWeaponDrop(drops,{x:4,y:floor,z:5}));
assert.equal(nearestWeaponDrop(drops,{x:4,y:floor+1,z:5}),null,'other floor');
assert.equal(nearestWeaponDrop(drops,{x:4,y:floor,z:3}),null,'out of reach');
assert.equal(nearestWeaponDrop(drops,{x:4,y:floor,z:5},{reachable:(x,z)=>z<5.5}),null,'wall blocks reach');
let disposedGeometry=0,disposedMaterial=0;
original.traverse(n=>{n.geometry?.addEventListener('dispose',()=>disposedGeometry++);n.material?.addEventListener('dispose',()=>disposedMaterial++)});
inventory.pickup(drops[0].uid);renderer.sync(inventory.getDropped());assert.equal(renderer.stats().count,13);assert(disposedGeometry>0&&disposedMaterial>0);
assert.equal(renderer.stats().settled,13,'settled drops remain accounted for without re-updating them');
renderer.dispose();renderer.dispose();assert.equal(scene.children.length,0);
console.log(JSON.stringify({passed:true,weapons:14,checks:['grounded_3d','held_scale','lying_side','pickup_center','range','walls','floor_separation','reuse','disposal']}));
