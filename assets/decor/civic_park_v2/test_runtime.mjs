// node assets/decor/civic_park_v2/test_runtime.mjs <directory containing node_modules/three>
// Uses real Three.js + GLTFLoader, real pinned GLBs, local fetch, and a hostile host.
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL, fileURLToPath} from 'node:url';
import {mountCivicParkDecor, CIVIC_DECOR_OWNER} from './runtime.v1.js';
const dependency = resolve(process.argv[2] || '', 'node_modules/three');
const THREE = await import(pathToFileURL(resolve(dependency,'build/three.module.js')));
const {GLTFLoader} = await import(pathToFileURL(resolve(dependency,'examples/jsm/loaders/GLTFLoader.js')));
const params = new URLSearchParams('preview=1&previewcityv3=stage-a&cityv3decor=1&cityv3decorfocus=DEC-FNT-CENTRAL-01');
const originalFetch=globalThis.fetch;
let fetches=0, corrupt=false;
globalThis.fetch = async (url, options={}) => {
  options.signal?.throwIfAborted(); fetches++;
  const data = new Uint8Array(await readFile(fileURLToPath(url)));
  if (corrupt && String(url).endsWith('.glb')) data[data.length-1]^=1;
  return new Response(data,{status:200});
};
function host(mode='ok') {
  const scene=new THREE.Scene(), renderer={domElement:{dataset:{}},shadowMap:{}};
  const registered=new Map(); let classifyCalls=0,focused=null;
  const bridge={
    getCityV3DecorHost:()=>({mapRows:200,mapCols:180,worldUnitsPerGridCellM:4.1,classifySurface(){classifyCalls++;return mode==='unknown'?'unknown':'park';}}),
    registerCityV3DecorCollisions(owner,bodies){registered.set(owner,bodies);if(mode==='throw')throw new Error('forced-registration-failure');return {ok:true};},
    unregisterCityV3DecorCollisions:owner=>registered.delete(owner),
    previewApproachCityV3Decor:focus=>{focused=focus.id;return {ok:true};},
  };
  return {scene,renderer,bridge,registered,get classifyCalls(){return classifyCalls;},get focused(){return focused;}};
}
const args=h=>({THREE,GLTFLoader,...h,params,hostname:'127.0.0.1',originR:27,originC:67,worldScale:4.1});
try {
  const accepted=host();
  const instance=await mountCivicParkDecor(args(accepted));
  assert.equal(instance.objects.length,30);
  assert.equal(accepted.scene.children.length,1);
  assert.ok(instance.bodies.length>=30,`collision bodies ${instance.bodies.length}`);
  assert.equal(accepted.registered.size,1);
  assert.ok(accepted.classifyCalls>1000);
  assert.equal(accepted.focused,'DEC-FNT-CENTRAL-01');
  assert.equal(instance.root.name,CIVIC_DECOR_OWNER);
  // Collision must grow by exactly the same ratio as the rendered asset. Read
  // the real collision mesh with placement scale temporarily removed, then
  // compare against the body that the host actually received on registration.
  for (const object of instance.objects) {
    const scale=object.placement.uniformScale;
    assert.equal(object.item.scale.x,scale);
    assert.equal(object.item.scale.y,scale);
    assert.equal(object.item.scale.z,scale);
    object.item.scale.setScalar(1);instance.root.updateMatrixWorld(true);
    object.levels[0].traverse(node=>{
      if(!node.isMesh||!node.name.startsWith('COLLISION_'))return;
      const unscaledBox=new THREE.Box3().setFromObject(node);
      const installedBody=accepted.registered.get(CIVIC_DECOR_OWNER).find(body=>body.id===`${object.placement.id}:${node.name}`);
      assert.ok(installedBody);
      assert.ok(Math.abs((installedBody.maxR-installedBody.minR)*4.1-(unscaledBox.max.z-unscaledBox.min.z)*scale)<1e-6,object.placement.id+' collision depth scale');
      assert.ok(Math.abs((installedBody.maxC-installedBody.minC)*4.1-(unscaledBox.max.x-unscaledBox.min.x)*scale)<1e-6,object.placement.id+' collision width scale');
    });
    object.item.scale.setScalar(scale);
  }
  instance.root.updateMatrixWorld(true);
  instance.update(1000,{r:27,c:67},true);
  const central=instance.objects.find(o=>o.placement.id==='DEC-FNT-CENTRAL-01');
  assert.equal(central.levels[0].visible,true);
  assert.equal(central.levels.filter(l=>l.visible).length,1);
  assert.ok(central.water.length>0);
  const waterY=central.water[0].node.position.y;
  instance.update(2000,{r:27,c:75},true);
  assert.equal(central.levels[1].visible,true);
  assert.notEqual(central.water[0].node.position.y,waterY);
  instance.update(3000,{r:199,c:179},true);
  assert.equal(central.item.visible,false);
  instance.dispose(); instance.dispose();
  assert.equal(accepted.scene.children.length,0);
  assert.equal(accepted.registered.size,0);
  const rejecting=host('unknown'); const before=fetches;
  await assert.rejects(()=>mountCivicParkDecor(args(rejecting)),/unknown/);
  assert.equal(fetches-before,2,'unknown surface must reject before any GLB');
  assert.equal(rejecting.scene.children.length,0);
  const throwing=host('throw');
  await assert.rejects(()=>mountCivicParkDecor(args(throwing)),/forced-registration-failure/);
  assert.equal(throwing.scene.children.length,0);
  assert.equal(throwing.registered.size,0,'partial host registration must roll back');
  const cancelled=host(), abort=new AbortController();abort.abort(new Error('test-cancel'));
  await assert.rejects(()=>mountCivicParkDecor({...args(cancelled),signal:abort.signal}),/test-cancel/);
  assert.equal(cancelled.scene.children.length,0);
  const parsing=host(), parseAbort=new AbortController();
  class StalledLoader extends GLTFLoader {parse(){setTimeout(()=>parseAbort.abort(new Error('test-stalled-parse')),5);}}
  await assert.rejects(()=>mountCivicParkDecor({...args(parsing),GLTFLoader:StalledLoader,signal:parseAbort.signal}),/test-stalled-parse/);
  assert.equal(parsing.scene.children.length,0);
  corrupt=true; const badHash=host();
  await assert.rejects(()=>mountCivicParkDecor(args(badHash)),/asset_sha/);
  assert.equal(badHash.scene.children.length,0);
  assert.equal(badHash.registered.size,0);
  console.log(JSON.stringify({status:'PASS',objects:30,collisions:instance.bodies.length,checks:['real-glb-transform','three-lods','water-animation','distance-cull','idempotent-rollback','unknown-fail-closed','registration-throw-rollback','abort-before-load','tampered-glb-rollback']}));
} finally {globalThis.fetch=originalFetch;}
