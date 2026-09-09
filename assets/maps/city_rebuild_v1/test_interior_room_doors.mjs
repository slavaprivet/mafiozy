import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createInteriorRoomDoors} from './interior_room_doors.mjs';

const THREE=await import(pathToFileURL(process.env.MAFIOZY_THREE||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));

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
