import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {registerHooks} from 'node:module';
import {createGlassBreakage,discoverGlassPanels,isBreakableGlass} from './glass_breakage.mjs';
import {applyResidentialWindows} from './residential_windows.mjs';
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c)}});
const T=await import(pathToFileURL(vendor+'build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const glass=new T.MeshPhysicalMaterial({name:'Smoked glass',transparent:true,opacity:.4}),brass=new T.MeshStandardMaterial({name:'Brass'});
const solidPane=new T.Mesh(new T.BoxGeometry(2,3,.015),glass);assert.equal(discoverGlassPanels(solidPane).panels.length,1,'single-material BoxGeometry groups are ignored by renderer');assert.equal(discoverGlassPanels(solidPane).panels[0].faces.length,12,'front/back/edges belong to one thin pane');solidPane.geometry.dispose();
const quad=(x,z=0)=>[x,0,z,x+1,0,z,x+1,2,z,x,0,z,x+1,2,z,x,2,z];
const g=new T.BufferGeometry();g.setAttribute('position',new T.Float32BufferAttribute([...quad(0),...quad(2),...quad(4)],3));g.addGroup(0,12,0);g.addGroup(12,6,1);g.computeVertexNormals();
const mesh=new T.Mesh(g,[glass,brass]),sibling=mesh.clone(),scene=new T.Scene();scene.add(mesh,sibling);
const registry=createGlassBreakage(T,scene,{maxShards:32,maxDecoratedPanels:2});registry.prepare(mesh);
assert.equal(discoverGlassPanels(mesh).panels.length,2);
assert.equal(isBreakableGlass(new T.Mesh(g,new T.MeshBasicMaterial({transparent:true})),{transparent:true}),false,'transparent non-glass does not shatter');
assert.equal(registry.hit({object:mesh,point:new T.Vector3(4.5,1,0),faceIndex:4,face:{normal:new T.Vector3(0,0,1)}}).broken,false,'frame preserved');
const first=registry.hit({object:mesh,point:new T.Vector3(.5,1,0),faceIndex:0,face:{normal:new T.Vector3(0,0,1)}},{direction:new T.Vector3(0,0,-1),impulse:28});
assert.equal(first.broken,true);assert.equal(first.triangles,2);assert.notEqual(mesh.geometry,g);assert.equal(sibling.geometry,g);assert.equal(g.index,null);
registry.update(.1);assert.deepEqual(Array.from(mesh.geometry.index.array).slice(0,6),[0,0,0,3,3,3]);assert.deepEqual(Array.from(mesh.geometry.index.array).slice(6),Array.from({length:12},(_,i)=>i+6));
assert.equal(registry.hit({object:mesh,point:new T.Vector3(.5,1,0),faceIndex:0}).reason,'already-broken');
const edges=mesh.children.find(n=>n.name==='Broken_Glass_Edges');assert.ok(edges);mesh.position.x=17;scene.updateMatrixWorld(true);assert.equal(edges.getWorldPosition(new T.Vector3()).x,17,'cracks/remnants follow moving vehicle or door');
assert.equal(scene.getObjectByName('World_Glass_Shards').position.x,0,'free shards do not follow vehicle');
registry.reset();assert.equal(mesh.geometry,g);assert.equal(mesh.children.length,0);assert.equal(registry.stats().activeShards,0);
assert.throws(()=>registry.update(NaN),'an idle glass pool must still reject an invalid timestep');

const instances=new T.InstancedMesh(g,[glass,brass],3);for(let i=0;i<3;i++)instances.setMatrixAt(i,new T.Matrix4().makeTranslation(i*7,0,0));scene.add(instances);const originalMatrix=instances.instanceMatrix,matrices=Array.from(originalMatrix.array);registry.prepare(instances);
const result=registry.hit({object:instances,instanceId:1,faceIndex:0,point:new T.Vector3(7.5,1,0),face:{normal:new T.Vector3(0,0,1)}});
assert.equal(result.broken,true);registry.update(.1);assert.notEqual(instances.instanceMatrix,originalMatrix);assert.deepEqual(Array.from(originalMatrix.array),matrices);
for(const id of [0,2])assert.deepEqual(Array.from(instances.instanceMatrix.array).slice(id*16,id*16+16),matrices.slice(id*16,id*16+16));
assert.equal(instances.geometry,g);const replacement=instances.children.find(n=>n.isMesh);assert.ok(replacement);assert.equal(replacement.material,instances.material);assert.deepEqual(Array.from(replacement.geometry.index.array).slice(6),Array.from({length:12},(_,i)=>i+6));
assert.equal(registry.hit({object:replacement,faceIndex:2,point:new T.Vector3(9.5,1,0),face:{normal:new T.Vector3(0,0,1)}}).broken,true,'second panel of same instance independently breaks');
assert.equal(registry.hit({object:instances,faceIndex:0,point:new T.Vector3(.5,1,0)}).broken,false,'instanceId mandatory');
const all=registry.shatterAll(instances);assert.equal(all.broken,4);registry.update(.1);assert.ok(registry.stats().activeShards<=32);assert.ok(registry.stats().decoratedPanels<=2);
assert.equal(registry.hit({object:mesh,point:new T.Vector3(17.5,1,0),faceIndex:0,face:{normal:new T.Vector3(0,0,1)}}).broken,true);
registry.reset(instances);assert.equal(instances.instanceMatrix,originalMatrix);assert.equal(instances.children.length,0);assert.equal(registry.stats().brokenPanels,1,'car-only reset must preserve city glass');assert.notEqual(mesh.geometry,g);
for(let i=0;i<60;i++)registry.update(.1);assert.equal(registry.stats().activeShards,0);registry.reset();assert.equal(instances.instanceMatrix,originalMatrix);assert.equal(instances.children.length,0);registry.dispose();assert.equal(scene.getObjectByName('World_Glass_Shards'),undefined);
console.log('PASS synthetic: panel isolation, brass preservation, per-instance mixed geometry, movement, bounded particles, restoration');
if(process.argv.includes('--synthetic-only'))process.exit(0);

const here=path.dirname(fileURLToPath(import.meta.url)),root=path.resolve(here,'../../..'),placement=JSON.parse(fs.readFileSync(path.join(here,'buildings_placement.v1.json'))),rows=[];
for(const assetId of [...new Set(placement.instances.map(i=>i.assetId))]){
 const item=placement.instances.find(i=>i.assetId===assetId),bytes=fs.readFileSync(path.join(root,item.binding.url.slice(1))),loader=new GLTFLoader().register(()=>({name:'GLASS_TEST_TEXTURE_ONLY',loadTexture:()=>Promise.resolve(new T.Texture())}));
 const source=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,visual=source.clone(true),world=new T.Scene();world.add(visual);const windows=applyResidentialWindows({THREE:T,visual,instance:item});visual.updateWorldMatrix(true,true);
 const r=createGlassBreakage(T,world,{maxShards:16,maxDecoratedPanels:2});r.prepare(visual);let count=0,hitNode=null,panel=null;
 visual.traverse(n=>{if(n.isMesh){const a=discoverGlassPanels(n);count+=a.panels.length;if(!hitNode&&a.panels.length){hitNode=n;panel=a.panels[0]}}});
 if(hitNode){const original=hitNode.geometry,p=original.attributes.position,f=panel.faces[0],vi=j=>original.index?original.index.getX(f*3+j):f*3+j,a=new T.Vector3().fromBufferAttribute(p,vi(0)),b=new T.Vector3().fromBufferAttribute(p,vi(1)),c=new T.Vector3().fromBufferAttribute(p,vi(2)),normal=b.clone().sub(a).cross(c.clone().sub(a)).normalize(),point=a.add(b).add(c).multiplyScalar(1/3).applyMatrix4(hitNode.matrixWorld),before=original.index?Array.from(original.index.array):null;
  if(hitNode.isInstancedMesh){const transform=new T.Matrix4();hitNode.getMatrixAt(0,transform);point.applyMatrix4(hitNode.matrixWorld.clone().invert()).applyMatrix4(transform).applyMatrix4(hitNode.matrixWorld)}
  assert.equal(r.hit({object:hitNode,instanceId:hitNode.isInstancedMesh?0:undefined,faceIndex:f,point,face:{normal}}).broken,true,assetId);r.update(.1);if(!hitNode.isInstancedMesh)assert.notEqual(hitNode.geometry,original);assert.deepEqual(original.index?Array.from(original.index.array):null,before);r.reset();assert.equal(hitNode.geometry,original);
 }assert.ok(count>0,`${assetId} glass must be discovered with runtime windows`);rows.push({assetId,panels:count});r.dispose();windows?.dispose();
}
console.log(JSON.stringify(rows));console.log(`PASS real GLB: ${rows.length} placed types; shared geometry intact; first actual glass panel fractured/restored where detected. LIVE render pending.`);
