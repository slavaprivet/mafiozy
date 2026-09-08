import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createVehicleDamage} from './vehicle_damage.mjs';
const T=await import(pathToFileURL('D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/build/three.module.js'));
const {createDemoCar}=await import('./car_drive.mjs');
const car=createDemoCar(T,T.BoxGeometry);let explosions=0;
const damage=createVehicleDamage(T,car,{onExplosion:()=>explosions++});
const hood=car.shell.find(m=>m.name==='Hood_lid');
damage.impact({object:hood,damage:190,shotId:'ignite'});damage.update(.01);
assert.equal(damage.stats().flames,24);
damage.impact({object:hood,damage:100,shotId:'fatal'});
for(let i=0;i<90;i++){
 damage.impact({object:hood,damage:100,shotId:'extra-'+i});damage.update(1/60);
 assert.equal(damage.stats().flames,24,'fatal or repeated shot must never extinguish existing fire');
 assert.equal(damage.state.explosions,0,'original countdown retained');
}
damage.update(.1);assert.equal(explosions,1);assert.equal(damage.stats().flames,24);
for(let i=0;i<30;i++){damage.impact({object:hood,damage:100,shotId:'wreck-'+i});damage.update(.1)}
assert.equal(explosions,1);damage.reset();damage.update(.01);assert.equal(damage.stats().flames,0);damage.dispose();
console.log('PASS existing 24 flames continuous through fatal/repeated hits, original countdown, exactly one explosion, reset');
