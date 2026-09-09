import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {preserveBuildingSiteScale,isBuildingSiteNode} from './building_site_scale.mjs';
const vendor=process.env.MAFIOZI_THREE_VENDOR??'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(path.join(vendor,'build/three.module.js')).href:s,c)}});
const T=await import(pathToFileURL(path.join(vendor,'build/three.module.js')));
const {GLTFLoader}=await import(pathToFileURL(path.join(vendor,'addons/loaders/GLTFLoader.js')));
const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),placement=JSON.parse(fs.readFileSync(path.join(here,'buildings_placement.v1.json')));
const sameMatrix=(a,b)=>a.elements.every((v,i)=>Math.abs(v-b.elements[i])<1e-7);
for(const assetId of ['hospital','civic_hall']){
 const item=placement.instances.find(i=>i.assetId===assetId),bytes=fs.readFileSync(path.join(root,item.binding.url.slice(1)));
 const source=(await new GLTFLoader().register(()=>({name:'SITE_SCALE_TEST',loadTexture:()=>Promise.resolve(new T.Texture())})).parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
 for(const yaw of [0,Math.PI/2,.47]){
  const parent=new T.Group(),visual=source.clone(true);parent.position.set(140,0,220);parent.rotation.y=yaw;visual.position.fromArray(item.transform.modelLocalOffsetM);parent.add(visual);
  visual.traverse(n=>{if(/^(COLLISION|SOCKET|CLEARANCE|NAV_|COL_)/i.test(n.name)||(item.hideNodeNames??[]).some(name=>name.replace(/\./g,'')===n.name))n.visible=false});
  parent.updateMatrixWorld(true);const baseline=new Map(),geometry=new Map();visual.traverse(n=>{if(isBuildingSiteNode(assetId,n.name))baseline.set(n,n.matrixWorld.clone());if(n.isMesh)geometry.set(n,n.geometry)});
  parent.scale.set(1.45,1,1.45);parent.updateMatrixWorld(true);
  const report=preserveBuildingSiteScale({THREE:T,visual,assetId});assert.ok(report.knownScale>1.3);assert.ok(report.knownScale<=1.45);
  for(const[n,matrix]of baseline)assert.ok(sameMatrix(n.matrixWorld,matrix),'yard node moved or changed world scale: '+n.name);
  for(const[n,g]of geometry)assert.equal(n.geometry,g,'private transforms must not mutate shared geometry');
  for(const axis of [0,2]){assert.ok(report.fullBounds.min[axis]>=-15-1e-5);assert.ok(report.fullBounds.max[axis]<=15+1e-5)}
  assert.equal(preserveBuildingSiteScale({THREE:T,visual,assetId}),report,'idempotent before entry construction');
  console.log(JSON.stringify({assetId,yaw,knownScale:report.knownScale,fullBounds:report.fullBounds,changedNames:report.changedNames,roomArea:assetId==='hospital'?155.89*report.knownScale**2:88.11*report.knownScale**2}));
  report.restore();assert.equal(parent.scale.x,1.45);
 }
}
// An arbitrarily nested, rotated yard mesh retains the exact original world
// matrix; dividing its local X/Z scale alone would fail this case.
{
 const parent=new T.Group(),visual=new T.Group(),nested=new T.Group(),site=new T.Mesh(new T.BoxGeometry(1,1,1)),body=new T.Mesh(new T.BoxGeometry(12,4,12));
 site.name='Hospital_PublicBench_Nested_Test';nested.position.set(3,0,2);nested.rotation.set(.12,.67,.08);nested.scale.set(1.2,.8,.7);site.position.set(1,0,1);site.rotation.y=.44;nested.add(site);visual.add(nested,body);parent.add(visual);parent.updateMatrixWorld(true);const expected=site.matrixWorld.clone();parent.scale.set(1.45,1,1.45);parent.updateMatrixWorld(true);
 preserveBuildingSiteScale({THREE:T,visual,assetId:'hospital'});assert.ok(sameMatrix(site.matrixWorld,expected),'nested full matrix compensation');
}
console.log('PASS civic/hospital full visible envelope, unchanged yard world transforms, private shared geometry, nested rotated hierarchy');
