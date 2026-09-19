import test from 'node:test';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createMercenaryTargets} from './mercenary_targets.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
test('panel power changes only after acknowledged callback; duplicate receipt never disables twice',async()=>{
 const scene=new THREE.Scene(),camera=new THREE.PerspectiveCamera();const panel=new THREE.Group();scene.add(panel);
 let approach={x:2,y:0,z:3},loot={x:3,y:0,z:4};panel.userData.mercenaryTarget={id:'power:test',kind:'power_panel',powered:true,getApproachPosition:()=>approach,getLootPosition:()=>loot};
 let resolve,calls=0;const targets=createMercenaryTargets({THREE,camera,getRoots:()=>[scene],getBuildings:()=>[panel],onDisablePower:()=>{calls++;return new Promise(r=>resolve=r);}});
 assert.deepEqual(targets.get('power:test').position,approach);assert.deepEqual(targets.get('power:test').lootPosition,loot);approach={x:4,y:1,z:2};assert.deepEqual(targets.get('power:test').position,approach,'authored location stays live');
 const effect={kind:'disable_power',targetId:'power:test',actionId:1},receipt=targets.performEffect(effect);assert.equal(targets.performEffect(effect),receipt);assert.equal(calls,1);assert.equal(panel.userData.mercenaryTarget.powered,true);
 resolve({ok:false});assert.equal((await receipt).ok,false);assert.equal(panel.userData.mercenaryTarget.powered,true);
 const accepted=targets.performEffect({...effect,actionId:2});resolve({ok:true});assert.equal((await accepted).ok,true);assert.equal(panel.userData.mercenaryTarget.powered,false);assert.equal(targets.performEffect({...effect,actionId:2}).duplicate,true);assert.equal(targets.performEffect({...effect,actionId:3}).reason,'power_already_off');targets.dispose();
});
test('unconnected power panel reports failure without changing authored power',()=>{
 const scene=new THREE.Scene(),panel=new THREE.Group();scene.add(panel);panel.userData.mercenaryTarget={id:'power:test',kind:'power_panel',powered:true};
 const targets=createMercenaryTargets({THREE,camera:new THREE.PerspectiveCamera(),getRoots:()=>[scene],getBuildings:()=>[panel]});assert.equal(targets.performEffect({kind:'disable_power',targetId:'power:test'}).reason,'effect_not_connected');assert.equal(panel.userData.mercenaryTarget.powered,true);targets.dispose();
});
