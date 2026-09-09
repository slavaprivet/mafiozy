import assert from 'node:assert/strict';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {createNpcGallery,npcGalleryVariants} from './npc_gallery.mjs';
const THREE=await import(pathToFileURL(path.join(process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor','build/three.module.js')).href);
const scene=new THREE.Scene(),made=[];
const factory=async options=>{const object=new THREE.Group();scene.add(object);const item={...options,object,updates:[],disposed:false,update(dt,snapshot){assert(!this.disposed);this.updates.push({dt,snapshot});object.position.set(snapshot.position.x,snapshot.position.y,snapshot.position.z)},dispose(){this.disposed=true;object.removeFromParent()}};made.push(item);return item};
// These deliberately synthetic fixtures are test catalogue inputs, never production roster.
const input=[{id:'fixture:catalogue:1',label:'Исходное имя',role:'police',sex:'female'},{id:'fixture:catalogue:2',name:'Второе исходное имя',role:'boss',sex:'male'}],rows=npcGalleryVariants(input);
assert.equal(rows.length,13);assert.equal(new Set(rows.map(r=>r.hairstyle)).size,13);assert(rows[0].label.startsWith(input[0].label));assert.equal(rows[0].sourceId,input[0].id);
const gallery=createNpcGallery({THREE,scene,createActor:factory,anchor:{x:10,y:2,z:5},groundHeight:(x,z)=>2+x*.01+z*.02});
await gallery.populate(rows);assert.equal(gallery.records.length,13);assert.equal(scene.children.length,13);assert.equal(gallery.mode,'примерка NPC');
for(const record of gallery.records){assert(record.id.startsWith('qa:'));assert(input.some(r=>r.id===record.sourceId));assert(record.actor.qa);assert.equal(record.actor.object.userData.qaMode,'примерка NPC');assert.equal(record.position.y,2+record.position.x*.01+record.position.z*.02);assert.equal(record.descriptor.sex,rows[record.index].sex)}
for(let i=0;i<gallery.records.length;i++)for(let j=i+1;j<gallery.records.length;j++){const a=gallery.records[i].position,b=gallery.records[j].position;assert(Math.hypot(a.x-b.x,a.z-b.z)>=2.59,'preview spacing protects silhouettes')}
for(const pose of ['stand','crouch','prone','walk','run','punch','kick','heavy','dropkick','block']){gallery.setPose(pose);gallery.update(.1);for(const item of gallery.records){const s=item.actor.updates.at(-1).snapshot;assert.deepEqual(s.position,item.position,'animation never moves authoritative root');assert(!s.hit,'pose panel does not create damage');if(pose==='prone')assert.equal(s.posture.value,2);if(pose==='block')assert(s.action.blocking)}}
assert.throws(()=>gallery.setPose('unknown'));await assert.rejects(()=>gallery.populate([{label:'missing id'}]));assert.equal(gallery.records.length,13);
const old=gallery.records.map(x=>x.actor);await gallery.populate(input);assert(old.every(x=>x.disposed));assert.equal(scene.children.length,2);gallery.dispose();gallery.dispose();assert.equal(scene.children.length,0);
// Cancellation during awaited factory disposes late actors without resurrecting a hidden gallery.
let resolve;const delayed=new Promise(r=>resolve=r),cancelled=createNpcGallery({THREE,scene,createActor:async options=>{await delayed;return factory(options)}});
const work=cancelled.populate(input);cancelled.dispose();resolve();await work;assert.equal(scene.children.length,0);assert.equal(cancelled.records.length,0);
console.log(JSON.stringify({passed:true,variants:13,poses:10,checks:['supplied catalogue labels and source ids','qa actor ids only','stable sex/appearance','ground-aware separated layout','no damage from pose controls','stationary preview roots','replace cleanup','async cancellation cleanup','idempotent disposal']}));
