import assert from 'node:assert/strict';
import {createWalkMapEditorGeneratedPreview} from './walk_map_editor_generated_preview.mjs';

let geometryCreates=0,geometryDisposes=0,materialCreates=0,materialDisposes=0;
class BufferAttribute{constructor(array,itemSize){this.array=array;this.itemSize=itemSize}}
class BufferGeometry{constructor(){geometryCreates++}setAttribute(name,value){this[name]=value;return this}dispose(){geometryDisposes++}}
class LineBasicMaterial{constructor(options){materialCreates++;this.options=options}dispose(){materialDisposes++}}
class Position{set(x,y,z){this.x=x;this.y=y;this.z=z}}
class Group{constructor(){this.position=new Position();this.rotation={y:0};this.userData={};this.children=[]}add(value){this.children.push(value)}}
class LineLoop{constructor(geometry,material){this.geometry=geometry;this.material=material}}
const THREE={BufferAttribute,BufferGeometry,LineBasicMaterial,Group,LineLoop};
const scene={children:[],add(value){this.children.push(value)},remove(value){const index=this.children.indexOf(value);if(index>=0)this.children.splice(index,1)}};
const commands=[],cancelled=[];
const adapter={
 async transformCommand(key,transform){commands.push({key,transform});return {type:'generated-transform',key,transform}},
 dependenciesFor:()=>['generated-plan','minimap'],cancelPreview:key=>{cancelled.push(key);return true}
};
const preview=createWalkMapEditorGeneratedPreview({THREE,scene,adapter,groundHeight:()=>3});
const item={key:'road-signs:one',capabilities:{move:true,rotate:true,delete:true},locked:false},realRoot={material:{color:'original'},traverse(){throw new Error('live hierarchy must never be traversed')}};

assert.equal(preview.recognizes({proxy:{type:'circle',x:10,z:20,radius:.8}}),true);
assert.equal(preview.begin({key:item.key,item,record:{x:10,z:20,yaw:Math.PI/2},proxy:{type:'circle',x:10,z:20,radius:.8},realRoot}),scene.children[0]);
assert.equal(preview.active,true);assert.deepEqual(preview.transform,{positionM:[10,3,20],yawDegrees:90});
assert.equal(scene.children[0].children[0].geometry.position.array.length,32*3);
for(let index=0;index<1000;index++)preview.update({positionM:[11+index/1000,4,21]});
assert.equal(geometryCreates,1,'pointer movement must reuse one outline geometry');
preview.rotate(15);assert.equal(preview.transform.yawDegrees,105);assert.equal(realRoot.material.color,'original');
const result=await preview.commit();assert.equal(result.command.type,'generated-transform');assert.deepEqual(result.dependencies,['generated-plan','minimap']);assert.deepEqual(commands[0].transform,{positionM:[11.999,4,21],yawDegrees:105});
assert.equal(preview.active,false);assert.equal(scene.children.length,0);assert.equal(geometryDisposes,1);assert.equal(materialDisposes,1);

preview.begin({key:'rect:one',item:{capabilities:{move:true,rotate:true}},record:{x:2,y:1,z:4,yaw:0},proxy:{type:'rect',x:2,z:4,halfWidth:3,halfDepth:2}});
assert.equal(scene.children[0].children[0].geometry.position.array.length,12);preview.cancel('escape');assert.equal(preview.active,false);assert.equal(commands.length,1,'Escape must not compile a command');

assert.equal(preview.begin({key:'locked',item:{locked:true,capabilities:{move:false,rotate:false}},record:{proxy:{x:0,z:0,radius:1}}}),false);
assert.equal(preview.begin({key:'delete-only',item:{capabilities:{move:false,rotate:false,delete:true}},record:{proxy:{x:0,z:0,radius:1}}}),false);

const rejectedScene={children:[],add:scene.add,remove:scene.remove};
const rejected=createWalkMapEditorGeneratedPreview({THREE,scene:rejectedScene,adapter:{transformCommand:async()=>{throw new Error('spatial validator rejected')},cancelPreview:()=>true}});
rejected.begin({key:'tree:bad',item:{capabilities:{move:true,rotate:true}},record:{proxy:{x:1,z:2,radius:2}}});
await assert.rejects(()=>rejected.commit(),/spatial validator rejected/);assert.equal(rejected.active,false);assert.equal(rejectedScene.children.length,0,'validator rejection must remove the ghost');

let release,cancelCalls=0;
const pending=createWalkMapEditorGeneratedPreview({THREE,scene:rejectedScene,adapter:{transformCommand:()=>new Promise(resolve=>{release=resolve}),cancelPreview:()=>{cancelCalls++;return true}}});
pending.begin({key:'tree:pending',item:{capabilities:{move:true,rotate:true}},record:{proxy:{x:1,z:2,radius:2}}});const pendingCommit=pending.commit();pending.cancel('escape-during-validation');
await assert.rejects(pendingCommit,error=>error?.name==='AbortError');assert.equal(cancelCalls,1);assert.equal(rejectedScene.children.length,0);release({type:'late'});
let releaseDispose;
const disposing=createWalkMapEditorGeneratedPreview({THREE,scene:rejectedScene,adapter:{transformCommand:()=>new Promise(resolve=>{releaseDispose=resolve}),cancelPreview:()=>true}});
disposing.begin({key:'tree:dispose',item:{capabilities:{move:true,rotate:true}},record:{proxy:{x:2,z:3,radius:1}}});const disposedCommit=disposing.commit();disposing.dispose();disposing.dispose();
await assert.rejects(disposedCommit,error=>error?.name==='AbortError');assert.equal(rejectedScene.children.length,0);releaseDispose({type:'late'});
pending.dispose();pending.dispose();rejected.dispose();rejected.dispose();preview.dispose();preview.dispose();
assert.equal(geometryCreates,geometryDisposes);assert.equal(materialCreates,materialDisposes);
console.log('walk map editor generated preview: PASS');
