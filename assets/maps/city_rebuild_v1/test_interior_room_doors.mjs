import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createInteriorRoomDoors} from './interior_room_doors.mjs';

const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));

test('empty room-door queries skip allocations/transforms while later doors retain live transformed proximity',()=>{
 let allocations=0,transforms=0;class CountedVector extends THREE.Vector3{constructor(...args){super(...args);allocations++;}}
 const scene=new THREE.Scene(),parent=new THREE.Group(),root=new THREE.Group();scene.add(parent);parent.add(root);parent.position.set(13,4,-9);parent.rotation.y=.37;root.scale.setScalar(1.25);
 const original=root.worldToLocal;root.worldToLocal=function(point){transforms++;return original.call(this,point);};
 const controller=createInteriorRoomDoors({...THREE,Vector3:CountedVector},{root,entry:{instance:{id:'empty-and-transformed'}}});
 try{
  for(let i=0;i<120;i++)assert.equal(controller.near({x:i/60,y:0,z:0}),null);
  assert.equal(allocations,0);assert.equal(transforms,0);assert.throws(()=>controller.near(undefined),TypeError,'existing point property access still validates missing input');
  const door=controller.create({x:2,y:0,z:3,name:'Жилая комната'});controller.finalize();
  for(const offset of [0,17]){
   parent.position.x=13+offset;const point=root.localToWorld(new THREE.Vector3(2.4,0,3)),expectedAnchor=root.localToWorld(new THREE.Vector3(2,1.65,3));
   const near=controller.near(point);assert.equal(near.door,door);assert.equal(near.instanceId,'empty-and-transformed');assert.equal(near.action,'Открыть · Жилая комната');assert(Math.abs(near.distance-.4)<1e-10);assert(near.anchor.distanceTo(expectedAnchor)<1e-10);
   assert.equal(controller.near(root.localToWorld(new THREE.Vector3(12,0,3))),null);assert.equal(controller.near(root.localToWorld(new THREE.Vector3(2,2,3))),null);
  }
  assert(transforms>0,'populated controller still evaluates current ancestor transforms');
 }finally{controller.dispose();}
});

test('wide private-room leaves match their opening and retain one wood/brass batch',()=>{
 const root=new THREE.Group(),entry={instance:{id:'wide-doors'}},controller=createInteriorRoomDoors(THREE,{root,entry});
 try{for(const [i,width]of[1.65,1.8,2].entries())controller.create({x:i*4,z:0,y:0,width});controller.finalize();assert.equal(controller.stats().draws,2);const bodies=controller.bodies();bodies.forEach((b,i)=>{const xs=b.polygonCR.map(p=>p[0]*4.1);assert.ok(Math.abs(Math.max(...xs)-Math.min(...xs)-([1.65,1.8,2][i]-.12))<1e-8)});const first=controller.doors[0];assert.equal(controller.interact({x:-1,y:0,z:1}).accepted,true);for(let i=0;i<8;i++)controller.update(.1,{x:-1,y:0,z:1});assert.equal(first.fraction,1);assert.notStrictEqual(controller.bodies(),bodies)}finally{controller.dispose()}
});

test('closed interior doors have no recurring transform or collider work, while their full opening motion remains intact',()=>{
 const scene=new THREE.Scene(),root=new THREE.Group(),entry={instance:{id:'door-idle-fixture'}};scene.add(root);scene.updateMatrixWorld(true);
 const controller=createInteriorRoomDoors(THREE,{root,entry}),door=controller.create({x:0,z:0,y:0,axis:'x'});controller.finalize();const idleOrigin=controller.stats().idleUpdates;
 try{
  assert.equal(controller.stats().draws,2,'wood and brass stay two dynamic draws regardless of a door leaf\'s detail count');
  const wood=root.children.find(node=>node.name==='InteriorDoorWood'),panelMatrix=new THREE.Matrix4();wood.getMatrixAt(0,panelMatrix);assert.ok(panelMatrix.elements[12]===0&&panelMatrix.elements[14]===0,'batched closed panel begins at its authored doorway position');
  const clearSide={x:-1,y:0,z:1};
  for(let i=0;i<600;i++)controller.update(1/60,clearSide);
  assert.equal(door.pivot.rotation.y,0);assert.equal(controller.stats().idleUpdates-idleOrigin,600);
  assert(controller.interact(clearSide).accepted);
  for(let i=0;i<8;i++)controller.update(.1,clearSide);
  assert.equal(door.fraction,1);assert(Math.abs(door.pivot.rotation.y-Math.PI/2)<1e-8);wood.getMatrixAt(0,panelMatrix);assert.ok(Math.abs(panelMatrix.elements[12]+.6)<1e-6&&Math.abs(panelMatrix.elements[14]+.6)<1e-6,'batched panel follows the same opened hinge arc');assert.equal(controller.active,false);
  const settled=controller.stats().idleUpdates;for(let i=0;i<120;i++)controller.update(1/60,clearSide);
  assert.equal(controller.stats().idleUpdates-settled,120);assert.equal(door.fraction,1);
 }finally{controller.dispose()}
});
