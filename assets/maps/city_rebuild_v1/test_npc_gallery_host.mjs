import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {createNpcGalleryHost,NPC_GALLERY_ROWS,npcGallerySampleRows} from './npc_gallery_host.mjs';
const THREE=await import(pathToFileURL((process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor')+'/build/three.module.js').href);
function element(tag){return {tag,children:[],style:{},setAttribute(){},appendChild(child){this.children.push(child)},remove(){this.removed=true}}}
const doc={createElement:element},parent=element('root'),scene=new THREE.Scene();let loads=0,disposed=0;
const host=await createNpcGalleryHost({THREE,scene,document:doc,parent,anchor:{x:12,y:0,z:20},groundHeight:()=>.2,loadSources:async()=>{loads++;return {male:new THREE.Group(),female:new THREE.Group()}},actorFactory:options=>{assert(options.id.startsWith('qa:'));const object=new THREE.Group();scene.add(object);return {object,update(dt,s){object.position.set(s.position.x,s.position.y,s.position.z)},dispose(){disposed++;object.removeFromParent()}}}});
assert.equal(loads,1);assert.equal(host.catalogue.length,48);assert.equal(new Set(NPC_GALLERY_ROWS.map(r=>r.id)).size,48);
assert(npcGallerySampleRows().some(r=>r.role==='boss'));assert(npcGallerySampleRows().some(r=>r.role==='police'));assert(npcGallerySampleRows().some(r=>r.role==='medic'));
await host.panel.children.find(n=>n.textContent==='Показать 13 вариантов').onclick();assert.equal(host.gallery.records.length,13);assert.equal(new Set(host.gallery.records.map(r=>r.descriptor.hairstyle)).size,13);
const select=host.panel.children.find(n=>n.tag==='select');select.value=NPC_GALLERY_ROWS.find(r=>r.role==='police').id;
await host.panel.children.find(n=>n.textContent==='13 причёсок выбранного персонажа').onclick();assert(host.gallery.records.every(r=>r.sourceId===select.value&&r.descriptor.role==='police'));assert.equal(disposed,13);
host.update(.016);host.dispose();host.dispose();assert.equal(disposed,26);assert.equal(scene.children.length,0);assert(host.panel.removed);
console.log('PASS gallery host: 48 real catalogue labels, mixed roles, 13 hairstyles, QA identities, selector, replace/dispose');
