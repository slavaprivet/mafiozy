import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createWeaponRecoilView} from './weapon_recoil_view.mjs';
import {createWeaponFireState,stepWeaponFire,sampleWeaponRecoil} from './hero_weapon_fire.mjs';
import {createStableEntryLights} from './stable_entry_lights.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const render=createWeaponRecoilView(THREE),camera=new THREE.PerspectiveCamera(),scene=new THREE.Scene();camera.rotation.set(.2,.4,.1);const original=camera.quaternion.clone();
const recoil=sampleWeaponRecoil(stepWeaponFire(createWeaponFireState('deagle'),{triggerPressed:true},0).state);
let renders=0,beforeRenders=0,viewQuaternion=null;const beforeRender=finalCamera=>{beforeRenders++;viewQuaternion=finalCamera.quaternion.clone();assert(finalCamera.quaternion.angleTo(original)>0,'pre-render hook observes the final recoil camera')},renderer={render(){renders++;assert(camera.quaternion.angleTo(original)>0,'view visibly kicks only during render');assert(camera.quaternion.angleTo(viewQuaternion)<1e-7,'pre-render hook and renderer observe the same camera')}};
for(let i=0;i<100;i++){render(renderer,scene,camera,recoil,beforeRender);assert(camera.quaternion.angleTo(original)<1e-7,'no cumulative aim drift')}
assert.equal(beforeRenders,100);
// Exact regression from the Walk review: the base camera excludes this finite
// light sphere, while the final Deagle recoil camera includes it. The hook must
// therefore run after the temporary recoil transform and before renderer.render.
const room=new THREE.Group(),edgeLight=new THREE.PointLight(0xffd2a0,8,1,2);edgeLight.position.set(0,13.50988146,-30);room.add(edgeLight);scene.add(room);camera.fov=45;camera.aspect=1049/920;camera.near=.2;camera.far=1500;camera.updateProjectionMatrix();camera.rotation.set(0,0,0);camera.updateMatrixWorld(true);
const edgePool=createStableEntryLights(THREE,[{object:room}],scene,{maxLights:1,getFocus:()=>camera.position,viewCull:true}),edgeSlot=scene.getObjectByName('Stable_Entry_Light_Slots').children[0];edgePool.update({camera});assert.equal(edgeSlot.intensity,0,'base camera safely culls the edge light');
const edgeBase=camera.quaternion.clone();render({render(){assert.equal(edgeSlot.intensity,8,'final recoil camera restores the now-visible light before rendering')}},scene,camera,recoil,finalCamera=>edgePool.updateView(finalCamera));
assert(camera.quaternion.angleTo(edgeBase)<1e-7);render({render(){assert.equal(edgeSlot.intensity,0,'settled final camera culls the light again')}},scene,camera,null,finalCamera=>edgePool.updateView(finalCamera));edgePool.dispose();camera.quaternion.copy(original);camera.updateMatrixWorld(true);
assert.throws(()=>render({render(){throw Error('test renderer failure')}},scene,camera,recoil),/renderer failure/);assert(camera.quaternion.angleTo(original)<1e-7);
assert.throws(()=>render(renderer,scene,camera,recoil,()=>{throw Error('test pre-render failure')}),/pre-render failure/);assert(camera.quaternion.angleTo(original)<1e-7,'pre-render failure restores camera');
let zeroRenders=0,zeroMatrixUpdates=0;const updateMatrixWorld=camera.updateMatrixWorld.bind(camera);camera.updateMatrixWorld=(...args)=>{zeroMatrixUpdates++;return updateMatrixWorld(...args)};
let zeroBefore=0;render({render(){zeroRenders++;assert(camera.quaternion.angleTo(original)<1e-7)}},scene,camera,null,finalCamera=>{zeroBefore++;assert.equal(finalCamera,camera)});assert.equal(zeroBefore,1);assert.equal(zeroRenders,1,'zero recoil retains one normal render');assert.equal(zeroMatrixUpdates,0,'zero recoil does not create a temporary camera transform to restore');camera.updateMatrixWorld=updateMatrixWorld;
console.log(JSON.stringify({passed:true,checks:['render_only_kick','final_camera_pre_render_hook','100_frames_no_aim_drift','restore_on_render_or_hook_error','unarmed_no_kick'],renders}));
