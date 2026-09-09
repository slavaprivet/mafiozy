import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {ARSENAL,createWeaponModel} from './hero_arsenal.mjs';

const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
const THREE=await import(pathToFileURL(path.join(deps,'build/three.module.js')));
const expected=['none','nagan','tt_pistol','revolver','deagle','golden_colt','sawn_off','shotgun','uzi','golden_uzi','ak74','m16','tommy_gun','sniper','rpg'];
assert.deepEqual(ARSENAL.map(item=>item.id),expected,'arsenal must preserve authoritative firearm ids and menu order');
assert.equal(new Set(ARSENAL.map(item=>item.id)).size,expected.length);
assert(ARSENAL.every(item=>item.label&&typeof item.twoHanded==='boolean'));

const signatures=new Set(),armed=[];
for(const spec of ARSENAL){
  const model=createWeaponModel({THREE,id:spec.id});
  assert(model.isGroup);assert.equal(model.weaponId,spec.id);assert.equal(model.twoHanded,spec.twoHanded);
  assert.equal(model.userData.weaponId,spec.id);assert.equal(model.userData.label,spec.label);assert.equal(model.userData.frontAxis,'+Z');
  assert.deepEqual(model.userData.gripOrigin,[0,0,0]);assert.equal(model.userData.visualOnly,true);
  const meshes=[];model.traverse(node=>{if(node.isMesh){meshes.push(node);assert.equal(node.castShadow,true);assert.equal(node.receiveShadow,true)}});
  if(spec.id==='none'){
    assert.equal(meshes.length,0);assert.equal(model.userData.muzzle,null);continue;
  }
  assert(meshes.length>=5,`${spec.id} needs a readable low-poly silhouette`);
  assert(model.getObjectByName('primary_grip'),`${spec.id} needs its authored grip at the socket origin`);
  const bounds=new THREE.Box3().setFromObject(model),size=bounds.getSize(new THREE.Vector3()),muzzle=model.userData.muzzle;
  assert(size.x>.08&&size.y>.2&&size.z>.5,`${spec.id} has invalid dimensions`);
  // Coordinates are in the Artist13 source rig and inherit the hero's ~0.368 scale at socket_weapon.
  assert(size.x<.8&&size.y<1.2&&size.z<3.2,`${spec.id} must remain hand-held scale`);
  assert(Array.isArray(muzzle)&&muzzle.length===3&&muzzle.every(Number.isFinite));
  assert(muzzle[2]>0&&muzzle[2]>=bounds.max.z-.16,`${spec.id} barrel/muzzle must face +Z`);
  assert(bounds.min.z<.08,`${spec.id} grip origin must sit within the held weapon`);
  const shoulderPad=model.getObjectByName('stock_pad');
  if(shoulderPad){
    const stockBounds=new THREE.Box3().setFromObject(shoulderPad);
    assert(stockBounds.min.z>=-.49,`${spec.id}: stock must fit between the forward grip and shoulder without extending through the back`);
  }
  const names=meshes.map(mesh=>mesh.name).sort();
  const signature=`${names.join(',')}|${size.toArray().map(n=>n.toFixed(3)).join(',')}`;
  assert(!signatures.has(signature),`${spec.id} must have a distinct structure or silhouette`);signatures.add(signature);
  armed.push({id:spec.id,meshes:meshes.length,length:+size.z.toFixed(3),twoHanded:spec.twoHanded});
}
assert(ARSENAL.filter(item=>!item.twoHanded).map(item=>item.id).includes('deagle'));
assert(ARSENAL.filter(item=>item.twoHanded).every(item=>!['nagan','tt_pistol','revolver','deagle','golden_colt'].includes(item.id)));
assert.throws(()=>createWeaponModel({THREE,id:'invented_gun'}),/Unknown weapon/);
assert.throws(()=>createWeaponModel({id:'nagan'}),/THREE host required/);
const alternate=createWeaponModel(THREE,'tt_pistol');assert.equal(alternate.weaponId,'tt_pistol','positional host form remains convenient for preview integration');

console.log(JSON.stringify({passed:true,checks:['authoritative_ids','russian_labels','grip_origin','barrel_positive_z','handheld_dimensions','distinct_low_poly_silhouettes','one_and_two_hand_metadata','visual_only_contract','invalid_id_guard'],weapons:armed}));
