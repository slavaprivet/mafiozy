import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createMercenaryBreachDoor} from './mercenary_breach_door.mjs';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
test('actual inspected door centre/plank seams are targetable, walls still block, opened hinge releases centre ray',()=>{
 const scene=new THREE.Scene(),group=new THREE.Group();scene.add(group);const door=createMercenaryBreachDoor({THREE,site:{id:'qa:door',x:169,y:0,z:173},onCollisionChange:()=>true});group.add(door.object);const floor=new THREE.Mesh(new THREE.PlaneGeometry(100,100),new THREE.MeshBasicMaterial());floor.rotation.x=-Math.PI/2;floor.position.set(169,0,173);group.add(floor);group.updateMatrixWorld(true);
 const camera=new THREE.PerspectiveCamera(55,1,.1,500),focus=new THREE.Vector3(169,1.55,168),look=new THREE.Vector3(169,1.15,173),direction=look.clone().sub(focus).normalize();camera.position.copy(focus).addScaledVector(direction,-5);camera.lookAt(focus);camera.updateMatrixWorld(true);
 const ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2(),camera);const targets=createMercenaryTargets({THREE,camera,getBuildings:()=>door.getTargets(),getRoots:()=>[scene],getPickRoots:()=>[group]});const proxy=door.object.getObjectByName('Breach_Door_Command_Surface');assert(proxy);assert.equal(proxy.material.visible,false);assert.equal(proxy.castShadow,false);assert.equal(targets.pick().id,'qa:door');assert.equal(targets.pick().locked,true);assert.equal(targets.pickGround(),null,'door selection never falls through to rally behind it');
 // Reproduce original failure using the actual author geometry: the centre
 // line misses every plank and reaches the floor when its command surface is absent.
 proxy.visible=false;assert.equal(ray.intersectObject(door.object,true).filter(h=>h.object.visible).length,0);proxy.visible=true;
 for(const x of [-.75,-.5,-.25,0,.25,.5,.75]){camera.lookAt(169+x,1.15,173);camera.updateMatrixWorld(true);assert.equal(targets.pick()?.id,'qa:door','every vertical plank seam is targetable');}
 camera.lookAt(focus);camera.updateMatrixWorld(true);const wall=new THREE.Mesh(new THREE.BoxGeometry(8,6,.3),new THREE.MeshBasicMaterial());wall.position.set(169,2,170);group.add(wall);group.updateMatrixWorld(true);assert.equal(targets.pick(),null,'solid cover still blocks both direct and assisted picking');wall.visible=false;
 const colliders=door.colliders.length;assert(door.breakOpen({targetId:'qa:door'}).ok);for(let i=0;i<10;i++)door.update(.1);group.updateMatrixWorld(true);assert.equal(door.colliders.length,colliders);assert.equal(proxy.parent,door.leaf);const final=targets.pick();assert(!final||final.opened===true);assert(targets.pickGround(),'opened door no longer blocks the old closed opening');let disposed=false;proxy.material.addEventListener('dispose',()=>disposed=true);targets.dispose();door.dispose();assert(disposed);floor.geometry.dispose();floor.material.dispose();wall.geometry.dispose();wall.material.dispose();
});
