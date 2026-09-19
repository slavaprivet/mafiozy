import assert from 'node:assert/strict';
import fs from 'node:fs';
import {registerHooks} from 'node:module';
import vm from 'node:vm';
import {pathToFileURL} from 'node:url';
import {createWindowedBuildingEntry} from './building_window_integration.mjs';
import {createInteriorRoomDoors} from './interior_room_doors.mjs';
import {createGlassBreakage,discoverGlassPanels} from './glass_breakage.mjs';

// Exercise the actual vendor lifecycle listener with an observable attribute
// backend. No GL context, renderer, full-city planner or timing benchmark.
const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor/';
registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'build/three.module.js').href:s,c);}});
const T=await import(pathToFileURL(vendor+'build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'addons/loaders/GLTFLoader.js'));
const source=fs.readFileSync(vendor+'build/three.module.js','utf8').replace(/\r\n/g,'\n'),start=source.indexOf('function WebGLObjects( gl, geometries, attributes, info ) {'),end=source.indexOf('\n/**\n * Uniforms of a program.',start);
assert(start>=0&&end>start,'recognize exact local WebGLObjects function boundary');
const WebGLObjects=vm.runInNewContext('('+source.slice(start,end).trim()+')');
const liveAttributes=new Set(),removals=new Map(),info={render:{frame:0}},objects=WebGLObjects({ARRAY_BUFFER:34962},{get:(o,g)=>g,update(){}},{update:a=>liveAttributes.add(a),remove:a=>{liveAttributes.delete(a);removals.set(a,(removals.get(a)||0)+1);}},info);
const placement=JSON.parse(fs.readFileSync(new URL('buildings_placement.v1.json',import.meta.url))),item=placement.instances.find(i=>i.assetId==='old_town_narrow_townhouse_v1');assert(item);
const bytes=fs.readFileSync(new URL('../../..'+item.binding.url,import.meta.url)),loader=new GLTFLoader().register(()=>({name:'DISPOSAL_TEXTURE_STUB',loadTexture:()=>Promise.resolve(new T.Texture())}));
const template=(await loader.parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene;
const originalGeometries=new Set();template.traverse(n=>{if(n.geometry)originalGeometries.add(n.geometry);});let sourceDisposes=0;for(const g of originalGeometries)g.addEventListener('dispose',()=>sourceDisposes++);
const scene=new T.Scene(),family=node=>node.name.startsWith('ResidentialWindow_')?'windows':/^InteriorDoor(?:Wood|Brass)$/.test(node.name)?'doors':/^(Storey_Floors|Storey_Walls_And_Ceilings|Room_Door_Frames)$/.test(node.name)?'storeys':/^(Stair_Treads_And_Posts|Brass_Stair_Handrails)$/.test(node.name)?'stairs':null;
function build(){
 const group=new T.Group(),visual=template.clone(true),t=item.transform;group.position.fromArray(t.positionM);group.rotation.y=t.yawDegrees*Math.PI/180;group.scale.setScalar(t.uniformScale);visual.position.fromArray(t.modelLocalOffsetM);group.add(visual);scene.add(group);group.updateMatrixWorld(true);
 const api=createWindowedBuildingEntry({THREE:T,visual,instance:item});assert(api.windows&&api.entry?.storeys&&api.entry.interiorDesign);
 const meshes=[];visual.traverse(node=>{if(node.isInstancedMesh&&family(node))meshes.push({node,family:family(node),matrix:node.instanceMatrix,color:node.instanceColor});});
 // This actual townhouse has open-plan rooms. Exercise the actual private-door
 // factory separately instead of changing its authored room layout for a test.
 const doorRoot=new T.Group(),doorController=createInteriorRoomDoors(T,{root:doorRoot,entry:{instance:{id:'disposal-door-fixture'}}});scene.add(doorRoot);doorController.create({x:0,y:0,z:0,width:1.3});doorController.finalize();
 for(const node of doorRoot.children)if(node.isInstancedMesh)meshes.push({node,family:'doors',matrix:node.instanceMatrix,color:node.instanceColor});
 for(const name of ['windows','doors','storeys','stairs'])assert(meshes.some(r=>r.family===name),'actual building exercises '+name);
 info.render.frame++;for(const {node}of meshes)objects.update(node);
 // Controlled replay of the old four teardown paths: they never dispatched
 // the object dispose event. Shared geometry/material lifecycle stays actual.
 if(process.argv.includes('--baseline-dispose'))for(const {node}of meshes)node.dispose=()=>{};
 const beforeGeometry=new Map(),beforeMaterial=new Map();for(const{node}of meshes){beforeGeometry.set(node,node.geometry);beforeMaterial.set(node,node.material);}
 return {api,group,visual,meshes,beforeGeometry,beforeMaterial,doorController,doorRoot};
}
function dispose(record){record.api.roomReveals.dispose();record.api.entry.dispose();record.api.windows.dispose();record.group.removeFromParent();record.doorController.dispose();record.doorRoot.removeFromParent();}
const first=build(),second=build(),ownResources=new Set(first.api.windows.group.children.flatMap(n=>[n.geometry,n.material])),sharedDisposals=new Map();for(const r of ownResources)r.addEventListener('dispose',()=>sharedDisposals.set(r,(sharedDisposals.get(r)||0)+1));
assert.equal(first.api.windows.glass.geometry,second.api.windows.glass.geometry);assert.equal(first.api.windows.glass.material,second.api.windows.glass.material);
const before=liveAttributes.size;
// A later unrelated owner can attach an instance under the generated room.
// Teardown must not recurse into and dispose other owners' instance buffers.
const outsider=new T.InstancedMesh(new T.BoxGeometry(),new T.MeshBasicMaterial(),1);first.api.entry.storeys.root.add(outsider);let outsiderDisposes=0;outsider.addEventListener('dispose',()=>outsiderDisposes++);
dispose(first);const retainedByFamily={};for(const record of first.meshes)if(liveAttributes.has(record.matrix))retainedByFamily[record.family]=(retainedByFamily[record.family]||0)+1;
console.log(JSON.stringify({kind:'actual-WebGLObjects-dispose-listener',instancesPerFixture:first.meshes.length,beforeAttributes:before,afterFirstAttributes:liveAttributes.size,retainedDisposedOwnerByFamily:retainedByFamily}));
if(!process.argv.includes('--report'))assert.deepEqual(retainedByFamily,{},'disposed owner releases every registered instance matrix');
assert.equal(outsiderDisposes,0,'unrelated attached instance is not ours to dispose');assert.equal(sharedDisposals.size,0,'sibling windows retain shared geometry/material');
for(const {node,matrix,color}of second.meshes){assert(liveAttributes.has(matrix));if(color)assert(liveAttributes.has(color));assert.equal(node.geometry,second.beforeGeometry.get(node));assert.equal(node.material,second.beforeMaterial.get(node));}
const afterFirst=liveAttributes.size;dispose(first);assert.equal(liveAttributes.size,afterFirst,'idempotent owner teardown');
dispose(second);if(!process.argv.includes('--report'))assert.equal(liveAttributes.size,0,'no registered instance attributes remain after last owner');
for(const resource of ownResources)assert.equal(sharedDisposals.get(resource),1,'shared resource released exactly once at last owner');
for(const r of [...first.meshes,...second.meshes])if(!process.argv.includes('--report')){assert.equal(removals.get(r.matrix),1);if(r.color)assert.equal(removals.get(r.color),1);}
assert.equal(sourceDisposes,0,'original GLB geometries are not disposed by generated owners');
const rebuilt=build();
if(!process.argv.includes('--baseline-dispose')){
 const mesh=rebuilt.api.windows.glass,original=mesh.instanceMatrix,registry=createGlassBreakage(T,scene,{maxShards:8,maxDecoratedPanels:1});registry.prepare(mesh);
 const faceIndex=discoverGlassPanels(mesh).panels[0].faces[0],g=mesh.geometry,p=g.attributes.position,vertex=i=>g.index?g.index.getX(faceIndex*3+i):faceIndex*3+i;
 const a=new T.Vector3().fromBufferAttribute(p,vertex(0)),b=new T.Vector3().fromBufferAttribute(p,vertex(1)),c=new T.Vector3().fromBufferAttribute(p,vertex(2)),normal=b.clone().sub(a).cross(c.clone().sub(a)).normalize(),instanceMatrix=new T.Matrix4();mesh.getMatrixAt(0,instanceMatrix);scene.updateMatrixWorld(true);
 const point=a.add(b).add(c).multiplyScalar(1/3).applyMatrix4(instanceMatrix).applyMatrix4(mesh.matrixWorld);
 assert.equal(registry.hit({object:mesh,instanceId:0,faceIndex,point,face:{normal}}).broken,true);registry.update(.1);
 const broken=mesh.instanceMatrix;assert.notEqual(broken,original);assert(!liveAttributes.has(original),'breakage releases original attribute before replacing it');
 info.render.frame++;objects.update(mesh);assert(liveAttributes.has(broken));
 registry.dispose();assert.equal(mesh.instanceMatrix,original);assert(!liveAttributes.has(broken),'glass reset releases replacement attribute');
 info.render.frame++;objects.update(mesh);assert(liveAttributes.has(original),'restored window may render before final owner cleanup');
}
dispose(rebuilt);if(!process.argv.includes('--report'))assert.equal(liveAttributes.size,0,'rebuild and broken/restored window return to empty instance attribute set');
outsider.dispose();outsider.geometry.dispose();outsider.material.dispose();objects.dispose();
console.log(process.argv.includes('--baseline-dispose')?'BASELINE report: old paths omit instance dispose events':'PASS bounded actual townhouse lifecycle: four generated instance owners, actual WebGLObjects listener, shared siblings, idempotence, original GLB and unrelated owner preserved, rebuild cleanup');
