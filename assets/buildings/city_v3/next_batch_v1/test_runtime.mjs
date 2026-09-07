import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {webcrypto} from 'node:crypto';
import {prepareCityV3NextBuildings,installCityV3NextBuildings,NEXT_BUILDING_KEYS} from './runtime.v1.js';
globalThis.crypto??=webcrypto;
const dep=process.env.THREE_MODULE_ROOT||path.join(process.env.TEMP,'mafiozi-glass-three180/node_modules/three');
const THREE=await import(pathToFileURL(path.join(dep,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(dep,'examples/jsm/loaders/GLTFLoader.js')));
const fetchImpl=async url=>{const bytes=fs.readFileSync(url);return {ok:true,arrayBuffer:async()=>bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength)};};
const options={THREE,GLTFLoader,fetchImpl};
const prepared=await prepareCityV3NextBuildings(options);
assert.deepEqual(prepared.map(p=>p.contract.key),NEXT_BUILDING_KEYS);
for(const p of prepared){
  const box=new THREE.Box3().setFromObject(p.root);
  assert(Math.abs((box.min.x+box.max.x)/2)<.00001,`${p.contract.key}: recentered x`);
  assert(Math.abs((box.min.z+box.max.z)/2)<.00001,`${p.contract.key}: recentered z`);
  const c=p.contract;
  assert(c.footprint.maxR-c.footprint.minR<c.clearanceFootprint.maxR-c.clearanceFootprint.minR);
  assert(c.footprint.maxC-c.footprint.minC<=c.clearanceFootprint.maxC-c.clearanceFootprint.minC+.000001);
  assert(p.visibleMeshCount>0);
}
let calls=0,rollbacks=0,lastReceipt;
const token={},bridge={activateCityV3NextBuilding(receipt){calls++;lastReceipt=receipt;return {ok:true,rollbackToken:token};},rollbackCityV3NextBuilding(t){assert.equal(t,token);rollbacks++;return {ok:true};}};
const scene=new THREE.Scene(),renderer={domElement:{dataset:{}}};
const instance=await installCityV3NextBuildings({...options,scene,bridge,renderer,originR:20,originC:30,worldScale:2.8});
assert.equal(calls,1);assert.equal(lastReceipt.buildings.length,3);assert.equal(scene.children.length,3);
for(let i=0;i<3;i++){
  const root=instance.roots[i],c=lastReceipt.buildings[i];
  assert(c.registered&&c.loaded&&c.eligible);
  assert(Math.abs(root.position.x-(c.centerGridRC[1]-30)*2.8)<1e-8);
  assert(Math.abs(root.position.z-(c.centerGridRC[0]-20)*2.8)<1e-8);
  assert(Math.abs(root.scale.x-2.8/4.1)<1e-8);
}
instance.dispose();instance.dispose();assert.equal(rollbacks,1);assert.equal(scene.children.length,0);
const rejectScene=new THREE.Scene();
await assert.rejects(()=>installCityV3NextBuildings({...options,scene:rejectScene,bridge:{...bridge,activateCityV3NextBuilding(){return {ok:false,reason:'map-changed'};}},originR:0,originC:0,worldScale:4.1}),/map-changed/);
assert.equal(rejectScene.children.length,0);
let corruptReads=0;
await assert.rejects(()=>installCityV3NextBuildings({...options,scene,bridge,originR:0,originC:0,worldScale:4.1,fetchImpl:async url=>{
  const bytes=fs.readFileSync(url);if(String(url).endsWith('.glb')){corruptReads++;bytes[bytes.length-1]^=1;}
  return {ok:true,arrayBuffer:async()=>bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength)};
}}),/asset-sha/);
assert.equal(calls,1);assert.equal(scene.children.length,0);assert.equal(corruptReads,1);
const controller=new AbortController();controller.abort();
await assert.rejects(()=>prepareCityV3NextBuildings({...options,signal:controller.signal}),e=>e.name==='AbortError');
assert.equal(renderer.domElement.dataset.cityV3NextBuildings,'rolled-back');
console.log('PASS real THREE/GLTF: 3 frozen assets, raw-name association resolution, actual ground proxies, yaw/recenter, one atomic transaction, rejection cleanup, hash failure preserves legacy, pre-abort, idempotent rollback.');
console.log(JSON.stringify(prepared.map(p=>({key:p.contract.key,footprint:p.contract.footprint,visibleMeshCount:p.visibleMeshCount})),null,2));
