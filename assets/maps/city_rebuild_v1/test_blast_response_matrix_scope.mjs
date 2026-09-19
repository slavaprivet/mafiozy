import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createBlastResponse} from './blast_response.mjs';

const THREE=await import(pathToFileURL((process.env.MAFIOZI_THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const scene=new THREE.Scene(),hero={object:new THREE.Group()},blocker=new THREE.Group(),vehicle=new THREE.Group(),unrelated=new THREE.Group();
hero.object.position.set(0,0,6);vehicle.position.set(0,0,9);unrelated.position.set(0,0,13);
const wall=new THREE.Mesh(new THREE.PlaneGeometry(12,12),new THREE.MeshStandardMaterial({side:THREE.DoubleSide}));wall.position.z=8;blocker.add(wall);scene.add(hero.object,blocker,vehicle,unrelated);scene.updateMatrixWorld(true);
// Move all objects after the last full scene update.  The blast must see the
// moved cover/car while leaving the irrelevant branch untouched.
wall.position.z=2.5;vehicle.position.z=5;unrelated.position.z=3;let fullSceneUpdates=0,exposure=null,carHits=0;
scene.updateMatrixWorld=()=>{fullSceneUpdates++};
const blast=createBlastResponse(THREE,scene,{getHero:()=>hero,getVehicles:()=>[{car:{object:vehicle},damage:{state:{wrecked:false,destroying:false},blastImpact(){carHits++}},roll:{impact(){throw Error('cover must still prevent a vehicle roll')}}}],getRoots:()=>[blocker],getGlass:()=>({}),groundHeight:()=>0,onHeroLaunch:()=>{throw Error('current cover must prevent hero launch')},onHeroExposure:(_,value)=>{exposure=value}});
blast.enqueue({point:{x:0,y:0,z:0},power:1,radius:10});blast.update();
assert.equal(fullSceneUpdates,0,'blast must not walk unrelated scene branches');
assert.equal(blocker.matrixWorld.elements[14],0);assert.equal(wall.matrixWorld.elements[14],2.5,'moved cover has its current world matrix');
assert.equal(vehicle.matrixWorld.elements[14],5,'moved vehicle has its current world matrix');
assert.equal(unrelated.matrixWorld.elements[14],13,'unrelated branch remains outside scoped matrix work');
assert.equal(exposure.transmission,0,'scoped matrices preserve opaque cover');assert.equal(carHits,0,'scoped matrices preserve blocked-car admission');
blast.dispose();
console.log('PASS blast updates only queried roots and preserves current cover/vehicle behavior');
