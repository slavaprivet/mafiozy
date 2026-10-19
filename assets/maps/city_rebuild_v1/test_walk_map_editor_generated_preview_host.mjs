import assert from 'node:assert/strict';
import {createWalkMapEditorWalkHost} from './walk_map_editor_walk_host.mjs';

class V2{set(x,y){this.x=x;this.y=y;return this}}
class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}
class Plane{}
let ground={x:12,y:0,z:22};
class Raycaster{constructor(){this.ray={intersectPlane:(_plane,out)=>Object.assign(out,ground)}}setFromCamera(){}intersectObjects(){return []}}
class BufferAttribute{constructor(array,itemSize){this.array=array;this.itemSize=itemSize}}
class BufferGeometry{setAttribute(name,value){this[name]=value;return this}dispose(){this.disposed=true}}
class LineBasicMaterial{constructor(options){this.options=options}dispose(){this.disposed=true}}
class Position{set(x,y,z){this.x=x;this.y=y;this.z=z}}
class Group{constructor(){this.position=new Position();this.rotation={y:0};this.userData={};this.children=[]}add(value){this.children.push(value)}}
class LineLoop{constructor(geometry,material){this.geometry=geometry;this.material=material}}
const THREE={Vector2:V2,Vector3:V3,Plane,Raycaster,BufferAttribute,BufferGeometry,LineBasicMaterial,Group,LineLoop};
const renderer={domElement:{getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})}},camera={},controls={};
const scene={children:[],add(value){this.children.push(value)},remove(value){const index=this.children.indexOf(value);if(index>=0)this.children.splice(index,1)}};
const item={key:'road-signs:sign-1',label:'Знак',capabilities:{move:true,rotate:true,delete:true},locked:false};
let runtimeHooks,validatorFailure=false,transformCalls=0,deleteCalls=0,liveRootWrites=0,disposed=0;
const committed=[],rebuilds=[];
const record={id:'sign-1',x:10,y:0,z:20,yaw:0,proxy:{type:'circle',x:10,z:20,radius:.65}};
const liveRoot={material:new Proxy({color:'untouched'},{set(target,key,value){liveRootWrites++;target[key]=value;return true}}),traverse(){throw new Error('generated live root must not be traversed')}};
const adapter={
 enumerate:()=>[item],resolveIntersection:()=>null,resolvePoint:()=>({key:item.key,entry:item,distance:0,proxy:record.proxy}),recordFor:()=>record,rootFor:()=>liveRoot,
 async transformCommand(key,transform){transformCalls++;if(validatorFailure)throw new Error('validator rejected move');return {type:'generated-transform',key,transform}},
 deleteCommand(){deleteCalls++;return {type:'generated-delete'}},dependenciesFor:()=>['road-signs','minimap'],cancelPreview:()=>false,cancelAllPreviews:()=>0,dispose(){disposed++}
};
const runtime={active:true,selection:item,refreshCatalog(){},dispose:async()=>{}};
const editorCamera={handleAction:()=>false,enter(){},restore(){return true},setMode(){return true},update(){},dispose(){}};
const selectionVisual={previewing:false,setPreviewing(value){this.previewing=!!value},select(){return true},clear(){},invalidate(){},dispose(){}};
const host=createWalkMapEditorWalkHost({THREE,renderer,scene,camera,controls,adapter,selectionVisual,getPickRoots:()=>[],
 prepareCommands:values=>values,commitCommands:values=>{committed.push(...values);return true},requestRebuild:meta=>rebuilds.push(meta),
 createRuntime:options=>{runtimeHooks=options.hooks;return runtime},createCamera:()=>editorCamera});

assert.equal(host.pick({event:{clientX:5,clientY:5}}).key,item.key,'proxy fallback must select the generated object');
assert.equal(await runtimeHooks.sceneAction({action:'primary-start'},null,{tool:'move',selection:item}),true);assert.equal(scene.children.length,1);
ground={x:30,y:2,z:40};await runtimeHooks.sceneAction({action:'pointer-move'},{clientX:8,clientY:8},{tool:'move',selection:item});
assert.deepEqual(host.generatedPreview.transform.positionM,[30,0,40]);runtimeHooks.cancel('escape');assert.equal(scene.children.length,0);assert.equal(transformCalls,0,'Esc must not compile or rebuild');assert.equal(rebuilds.length,0);

await runtimeHooks.sceneAction({action:'primary-start'},null,{tool:'move',selection:item});ground={x:31,y:2,z:41};await runtimeHooks.sceneAction({action:'pointer-move'},{clientX:8,clientY:8},{tool:'move',selection:item});
await runtimeHooks.sceneAction({action:'rotate-step',degrees:15},null,{tool:'rotate',selection:item});assert.equal(host.generatedPreview.transform.yawDegrees,15);
assert.equal(await runtimeHooks.commit(),true);assert.equal(transformCalls,1);assert.deepEqual(committed[0].transform,{positionM:[31,0,41],yawDegrees:15});assert.equal(rebuilds.filter(meta=>meta.committed).length,1);assert.equal(scene.children.length,0);
assert.equal(await runtimeHooks.commit(),false,'Enter without a staged generated edit is a no-op');assert.equal(transformCalls,1);

validatorFailure=true;await runtimeHooks.sceneAction({action:'primary-start'},null,{tool:'move',selection:item});ground={x:32,y:1,z:42};await runtimeHooks.sceneAction({action:'pointer-move'},{clientX:9,clientY:9},{tool:'move',selection:item});
const beforeRebuilds=rebuilds.length,beforeCommits=committed.length;await assert.rejects(()=>runtimeHooks.commit(),/validator rejected move/);assert.equal(scene.children.length,0);assert.equal(host.generatedPreview.active,false);assert.equal(committed.length,beforeCommits);assert.equal(rebuilds.length,beforeRebuilds,'validator failure changed no authoritative state and needs no rebuild');
assert.equal(selectionVisual.previewing,false,'validator failure must restore the normal selection guide');

assert.equal(await runtimeHooks.sceneAction({action:'right-cancel'},null,{tool:'move',selection:item}),false);assert.equal(deleteCalls,0,'RMB drag cancellation must not delete');
validatorFailure=false;await runtimeHooks.deleteObject({item,confirmed:true});assert.equal(deleteCalls,1,'only the confirmed short-click delete path may delete');assert.equal(committed.at(-1).type,'generated-delete');
assert.equal(liveRootWrites,0,'preview must never modify real object materials');

runtime.selection={...item,locked:true,capabilities:{move:false,rotate:false,delete:false}};assert.equal(await runtimeHooks.sceneAction({action:'primary-start'},null,{tool:'move',selection:runtime.selection}),false);assert.equal(scene.children.length,0);
const first=host.dispose(),second=host.dispose();assert.equal(first,second);await first;assert.equal(scene.children.length,0);assert.equal(disposed,1);
console.log('walk map editor generated preview host: PASS');
