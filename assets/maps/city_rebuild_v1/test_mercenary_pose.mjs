import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker,HERO_ASSET} from './hero_walk.mjs';
import {NPC_ASSETS} from './npc_actor.mjs';
import {createMercenaryPose} from './mercenary_pose.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
for(const asset of [HERO_ASSET,NPC_ASSETS.female]){
 const bytes=fs.readFileSync(new URL(asset.url)),gltf=await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
 const walker=createHeroWalker({THREE,scene:gltf.scene}),c=walker.artistContext(),pose=createMercenaryPose({THREE,walker});
 walker.object.position.set(30,2,17);walker.object.rotation.y=.8;
 const signature=()=>Object.values(c.bones).map(b=>b.matrix.elements.join(',')).join(';'),nodes=[];walker.object.traverse(o=>nodes.push(o));const count=nodes.length;
 walker.update(.016);const baseline=signature(),root=walker.object.position.toArray(),forms=new Set();
 for(const kind of ['revive','intimidate','unlock_safe','unlock_door','cut_fence','plant_bomb']){
  walker.update(.016);assert(pose.apply({kind,phase:'working',progress:.4},1));const working=signature();assert.notEqual(working,baseline,kind+' changes bones');forms.add(working);
  assert.deepEqual(walker.object.position.toArray(),root,'AI root never moved');
  walker.update(.016);pose.apply({kind,phase:'working',progress:.4},1);assert.equal(signature(),working,'same frame does not accumulate across normal updates');
  walker.update(.016);assert.equal(pose.apply({kind,phase:'approach',progress:.4},1),false);assert.equal(signature(),baseline,'approach preserves host pose');
 }
 assert.equal(forms.size,5,'five professions have distinct postures; locks share profession');
 for(const kind of ['revive','unlock_safe','cut_fence','plant_bomb']){
  walker.update(.016);pose.apply({kind,phase:'working',progress:.4},1);const a=signature();
  walker.update(.016);pose.apply({kind,phase:'working',progress:.4},1.23);assert.notEqual(signature(),a,kind+' animates over time');
 }
 const costs=[];for(let i=0;i<600;i++){walker.update(.016);const start=performance.now();pose.apply({kind:'cut_fence',phase:'working',progress:.4},i/60);if(i>=100)costs.push(performance.now()-start);}
 costs.sort((a,b)=>a-b);console.log('CPU pose only (not scene FPS): p50',costs[Math.floor(costs.length*.5)].toFixed(3),'ms; p95',costs[Math.floor(costs.length*.95)].toFixed(3),'ms');
 let after=0;walker.object.traverse(()=>after++);assert.equal(after,count,'no scene-node growth');assert.equal(pose.stats().geometries,3);assert.equal(pose.stats().materials,5);
 walker.update(.016);assert.equal(pose.apply(null,11),false);assert.equal(signature(),baseline,'none preserves ordinary fresh host pose');assert.equal(c.bones.hand_r.getObjectByName('Mercenary_Tools').visible,false);
 pose.dispose();pose.dispose();assert.equal(pose.stats().geometries,0);assert.equal(c.bones.hand_r.getObjectByName('Mercenary_Tools'),undefined);assert.equal(pose.apply({kind:'revive',phase:'working',progress:.5},12),false);
 walker.dispose();
}
console.log('PASS actual male/female GLBs: five distinct work poses, time animation, source transform unchanged, approach/none pass-through, no growth, disposal');
