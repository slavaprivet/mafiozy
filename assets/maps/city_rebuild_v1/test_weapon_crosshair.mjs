import assert from 'node:assert/strict';
import {createWeaponFireState,stepWeaponFire,sampleWeaponAccuracy,FIREARM_IDS} from './hero_weapon_fire.mjs';
import {createWeaponCrosshair,weaponCrosshairGap} from './weapon_crosshair.mjs';
for(const id of FIREARM_IDS){
 const initial=createWeaponFireState(id),fired=stepWeaponFire(initial,{triggerHeld:true},.5).state;
 for(const posture of ['stand','crouch','prone']){
  const input={posture,moving:false,aiming:false},sample=weaponCrosshairGap(fired,input),accuracy=sampleWeaponAccuracy(fired,input);
  assert.equal(sample.spread,accuracy.spread);assert(sample.gap>=3&&sample.gap<=64);assert(Number.isFinite(sample.gap));
 }
 assert(weaponCrosshairGap(fired,{posture:'prone'}).gap<=weaponCrosshairGap(fired,{posture:'stand'}).gap);
}
let spreadWrites=0;const host={style:{},children:[],dataset:new Proxy({}, {set(target,key,value){spreadWrites++;target[key]=value;return true;}}),append(...nodes){this.children.push(...nodes)},replaceChildren(...nodes){this.children=[...nodes]}},document={createElement:()=>({style:{}})},crosshair=createWeaponCrosshair({host,document}),state=createWeaponFireState('ak74'),input={posture:'stand',moving:false,aiming:false},view={height:720,fov:60};
const first=crosshair.update(state,input,view);assert.equal(host.dataset.spread,first.spread.toFixed(5));assert.equal(spreadWrites,1);crosshair.update(state,input,view);assert.equal(spreadWrites,1,'identical presented spread avoids a redundant dataset write');
const changed=crosshair.update(state,{...input,moving:true},view);assert.notEqual(changed.spread,first.spread);assert.equal(host.dataset.spread,changed.spread.toFixed(5));assert.equal(spreadWrites,2,'changed presented spread updates on the same call');crosshair.dispose();assert.equal(host.children.length,0);
console.log(JSON.stringify({passed:true,weapons:14,checks:['same_physical_cone','stance_precision','bounded_screen_gap']}));
