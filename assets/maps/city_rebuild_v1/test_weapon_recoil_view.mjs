import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createWeaponRecoilView} from './weapon_recoil_view.mjs';
import {createWeaponFireState,stepWeaponFire,sampleWeaponRecoil} from './hero_weapon_fire.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const render=createWeaponRecoilView(THREE),camera=new THREE.PerspectiveCamera(),scene=new THREE.Scene();camera.rotation.set(.2,.4,.1);const original=camera.quaternion.clone();
const recoil=sampleWeaponRecoil(stepWeaponFire(createWeaponFireState('deagle'),{triggerPressed:true},0).state);
let renders=0;const renderer={render(){renders++;assert(camera.quaternion.angleTo(original)>0,'view visibly kicks only during render')}};
for(let i=0;i<100;i++){render(renderer,scene,camera,recoil);assert(camera.quaternion.angleTo(original)<1e-7,'no cumulative aim drift')}
assert.throws(()=>render({render(){throw Error('test renderer failure')}},scene,camera,recoil),/renderer failure/);assert(camera.quaternion.angleTo(original)<1e-7);
let zeroRenders=0,zeroMatrixUpdates=0;const updateMatrixWorld=camera.updateMatrixWorld.bind(camera);camera.updateMatrixWorld=(...args)=>{zeroMatrixUpdates++;return updateMatrixWorld(...args)};
render({render(){zeroRenders++;assert(camera.quaternion.angleTo(original)<1e-7)}},scene,camera,null);assert.equal(zeroRenders,1,'zero recoil retains one normal render');assert.equal(zeroMatrixUpdates,0,'zero recoil does not create a temporary camera transform to restore');camera.updateMatrixWorld=updateMatrixWorld;
console.log(JSON.stringify({passed:true,checks:['render_only_kick','100_frames_no_aim_drift','restore_on_error','unarmed_no_kick'],renders}));
