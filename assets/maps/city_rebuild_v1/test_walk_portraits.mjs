import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createHeroWalker} from './hero_walk.mjs';
import {walkPortraitSignature,cloneWalkPortraitModel,frameWalkPortrait,createWalkPortraitRenderer} from './walk_portraits.mjs';
import {loadAppearanceHero,playerAppearanceFromWorld} from './walk_hero_appearance.mjs';
const vendor=process.env.THREE_VENDOR||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor',threeUrl=pathToFileURL(path.join(vendor,'build/three.module.js')).href;
registerHooks({resolve(s,c,n){return n(s==='three'?threeUrl:s,c)}});
const THREE=await import(threeUrl),{GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js'))),clone=undefined;
const here=path.dirname(fileURLToPath(import.meta.url)),loader=new GLTFLoader();
const bytes=fs.readFileSync(path.join(here,'hero_models/player_male.8130dfb1f7eb.glb')),gltf=await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'');
const hero=createHeroWalker({THREE,scene:gltf.scene}),context=hero.artistContext();hero.object.position.set(75,8,-34);hero.object.rotation.y=2.4;hero.update(.2,true,true,null,{}, {posture:{target:'prone',value:2}});
const snapshot=()=>{const nodes=[];hero.object.traverse(o=>nodes.push([o.uuid,o.matrix.toArray(),o.geometry?.uuid,o.material?.uuid,o.skeleton?.bones.map(b=>b.uuid)]));return JSON.stringify(nodes)};
const before=snapshot(),signature=walkPortraitSignature(hero.object),ownedGeometry=new Set(),ownedMaterial=new Set();let sourceDisposals=0;
assert.throws(()=>cloneWalkPortraitModel({THREE,source:hero.object,cloneSkeleton:source=>source}),/independent clone/);
assert.throws(()=>cloneWalkPortraitModel({THREE,source:hero.object,cloneSkeleton:source=>source.clone(true)}),/skeleton must be isolated/);
assert.equal(snapshot(),before,'unsafe clone rejected before any source mutation');
hero.object.traverse(o=>{if(o.geometry)ownedGeometry.add(o.geometry);for(const m of Array.isArray(o.material)?o.material:o.material?[o.material]:[])ownedMaterial.add(m)});
for(const r of [...ownedGeometry,...ownedMaterial])r.addEventListener('dispose',()=>sourceDisposals++);
const portrait=cloneWalkPortraitModel({THREE,source:hero.object,cloneSkeleton:clone,rest:context.rest}),framing=frameWalkPortrait(THREE,portrait.model);
assert.equal(snapshot(),before,'cloning and neutral pose never changes original matrices/materials/bones');
assert(framing.bounds.max.y>1.5&&framing.bounds.max.y<2.2,'camera not in live world position');
for(const x of [framing.bounds.min.x,framing.bounds.max.x])for(const y of [framing.bounds.min.y,framing.bounds.max.y]){const p=new THREE.Vector3(x,y,framing.center.z).project(framing.camera);assert(Math.abs(p.x)<1&&Math.abs(p.y)<1,'bust fits thumbnail')}
portrait.model.traverse(o=>{if(o.isMesh){assert(ownedGeometry.has(o.geometry),'immutable geometry shared');for(const m of Array.isArray(o.material)?o.material:[o.material])assert(!ownedMaterial.has(m),'materials isolated')}});
portrait.dispose();portrait.dispose();assert.equal(sourceDisposals,0,'original GPU assets never disposed');
hero.object.position.x+=12;hero.object.visible=false;assert.equal(walkPortraitSignature(hero.object),signature,'animation/root visibility do not invalidate');
let mesh;hero.object.traverse(o=>{if(!mesh&&o.isMesh)mesh=o});mesh.visible=!mesh.visible;assert.notEqual(walkPortraitSignature(hero.object),signature);mesh.visible=!mesh.visible;
const material=Array.isArray(mesh.material)?mesh.material[0]:mesh.material;material.color.set('#abcdef');assert.notEqual(walkPortraitSignature(hero.object),signature,'clothing color invalidates');
const signature2=walkPortraitSignature(hero.object);mesh.geometry.attributes.color.needsUpdate=true;assert.notEqual(walkPortraitSignature(hero.object),signature2,'vertex colors invalidate');
assert.notEqual(walkPortraitSignature(hero.object,{appearance:{hair:1}}),walkPortraitSignature(hero.object,{appearance:{hair:2}}));
let contexts=0,renders=0,disposals=0,lost=0;
class Renderer{constructor({canvas}){this.domElement=canvas;contexts++}setPixelRatio(){}setSize(){}setClearColor(){}render(scene,camera){renders++;assert(scene.children.some(o=>o.name==='Artist13_Walk_Hero'));assert(camera.isOrthographicCamera)}dispose(){disposals++}forceContextLoss(){lost++}}
const thumbs=createWalkPortraitRenderer({THREE:{...THREE,WebGLRenderer:Renderer},cloneSkeleton:clone,document:{createElement(){return {toDataURL(){return 'data:image/png;base64,portrait'+renders}}}},maxCache:2});
assert.equal(contexts,0);assert.match(thumbs.renderHero(hero.object,{rest:context.rest}),/^data:image\/png/);assert.equal(contexts,1);thumbs.renderHero(hero.object,{rest:context.rest});assert.equal(renders,1);
thumbs.renderHero(hero.object,{key:'second',rest:context.rest});thumbs.renderHero(hero.object,{key:'third',rest:context.rest});assert.equal(thumbs.size,2);assert.equal(contexts,1);thumbs.invalidate();assert.equal(thumbs.size,0);thumbs.dispose();thumbs.dispose();assert.equal(disposals,1);assert.equal(lost,1);assert.equal(thumbs.renderHero(hero.object),null);assert.equal(sourceDisposals,0);
assert.equal(createWalkPortraitRenderer().renderHero(hero.object),null);
const fetchLocal=async url=>{const b=fs.readFileSync(fileURLToPath(url));return {ok:true,arrayBuffer:async()=>b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)}};
const loaded=[];
for(const gender of [0,1]){
 const look={gender,skin:4,body:2,hair:5,face:2,hat:1,suit:'#258059',shirt:'#aa349c',hairColor:'#d8ad59'},a=await loadAppearanceHero({THREE,loader,look,fetch:fetchLocal});loaded.push(a);
 assert.equal(a.appearance.sex,gender?'female':'male');assert.equal(a.appearance.skin,'#7A3B10');assert.equal(a.appearance.outfit,look.suit);assert.equal(a.appearance.shirt,look.shirt);assert.equal(a.appearance.hairColor,look.hairColor);
 assert.equal(a.hero.object.getObjectByName('npc_hair_cap').material.color.getHexString(),'d8ad59','actual hair material follows source');
 let shirtVertices=0;const targetShirt=new THREE.Color(look.shirt);a.hero.object.traverse(o=>{if(!o.name.includes('FABRIC'))return;const colors=o.geometry.attributes.color;for(let i=0;i<colors.count;i++){const ratio=colors.getX(i)/targetShirt.r;if(ratio>.1&&Math.abs(colors.getY(i)/targetShirt.g-ratio)<.02&&Math.abs(colors.getZ(i)/targetShirt.b-ratio)<.02)shirtVertices++}});assert(shirtVertices>20,'actual shirt vertex palette follows source');
 const clone2=cloneWalkPortraitModel({THREE,source:a.hero.object,cloneSkeleton:clone,rest:a.hero.artistContext().rest});assert(clone2.model.getObjectByName('npc_fedora_crown'));frameWalkPortrait(THREE,clone2.model);clone2.dispose();
}
const keys=[{hair:1},{hair:2},{skin:1},{skin:2},{shirt:'#ffffff'},{shirt:'#111111'}].map(look=>JSON.stringify(playerAppearanceFromWorld(look)));assert.equal(new Set(keys).size,keys.length);
for(const record of loaded){record.dispose();record.dispose()}
assert.equal(sourceDisposals,0);console.log(JSON.stringify({passed:true,checks:['actual_male_female_glb','neutral_isolated_skeleton','bust_camera','no_source_mutation_or_disposal','single_lazy_context','bounded_cache','appearance_invalidation','vertex_color_invalidation','model_visibility_invalidation','world_palette_mapping','fresh_owned_appearance_rig','idempotent_disposal']}));
