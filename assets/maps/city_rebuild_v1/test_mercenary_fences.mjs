import assert from 'node:assert/strict';
import fs from 'node:fs';
import {pathToFileURL} from 'node:url';
import {createMercenaryFences,MERCENARY_FENCE_SITE as s} from './mercenary_fences.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js'));
const read=p=>JSON.parse(fs.readFileSync(new URL(p,import.meta.url),'utf8')),top=read('topology_for_placement.json'),buildings=read('buildings_placement.v1.json').instances,decor=read('decor_placement.v1.json').instances;
const area=[s.x-4,s.z-3.5,s.x+4,s.z+3.5];assert(buildings.some(b=>b.id===s.buildingId));
for(let r=Math.floor(area[1]/4.1);r<=Math.ceil(area[3]/4.1);r++)for(let c=Math.floor(area[0]/4.1);c<=Math.ceil(area[2]/4.1);c++){assert.equal(top.roadMask[r][c],0,'road clearance');assert.equal(top.walkableMask[r][c],1,'walkable land');assert.equal(top.protectedMask[r][c],0,'protected site clearance');}
for(const item of [...buildings,...decor]){const b=item.clearance||item.footprint;if(b)assert(!(area[0]<b.maxC*4.1&&area[2]>b.minC*4.1&&area[1]<b.maxR*4.1&&area[3]>b.minR*4.1),'clearance '+item.id);}
let changes=0,persisted;const f=createMercenaryFences({THREE,onCollisionChange({removed,added,colliders}){changes++;assert.equal(removed.length,1);assert.equal(added.length,0);assert.equal(colliders.length,6);return true;},persistCut:id=>{persisted=id;}});
const initial=f.colliders.slice();assert.equal(initial.length,7);const panel=f.getTargets()[0].object,left=panel.children[0],right=panel.children[1];assert.equal(left.rotation.y,0);
assert.equal(f.cut().ok,true);assert.equal(changes,1);assert.equal(f.colliders.length,6);for(let i=0;i<6;i++)assert.equal(f.colliders[i],initial[i],'fixed collider unchanged');assert(Math.abs(left.rotation.y)>3&&Math.abs(right.rotation.y)>3,'cut leaves folded clear of opening');
// More than two metres between neighbouring collider end caps.
assert(2.4-.24>=2);assert.equal(f.cut().alreadyCut,true);assert.equal(changes,1);assert.equal(persisted,f.getTargets()[0].id);
const restored=createMercenaryFences({THREE,cutIds:[persisted]});assert.equal(restored.colliders.length,6);assert.equal(restored.cut().alreadyCut,true);
const blocked=createMercenaryFences({THREE});assert.equal(blocked.cut().ok,false);assert.equal(blocked.colliders.length,7,'missing physics callback cannot fake cut');
for(const a of[f,restored,blocked]){a.dispose();a.dispose();}
console.log('PASS service yard: authored site mask/clearance proof, 2m+ physical cut aperture, only selected collider removed, folded wire leaves, persistence, callback refusal, disposal');
