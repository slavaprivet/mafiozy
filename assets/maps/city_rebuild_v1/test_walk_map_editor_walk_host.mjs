import assert from 'node:assert/strict';
import {createWalkMapEditorWalkHost} from './walk_map_editor_walk_host.mjs';

class V2{set(x,y){this.x=x;this.y=y;return this}}
class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}
class Plane{constructor(){}}
class Raycaster{
 static intersections=[{object:{userData:{editorKey:'buildings:house'}}}];
 constructor(){this.ray={intersectPlane:(_plane,out)=>{out.x=10;out.y=0;out.z=20;return out}}}
 setFromCamera(){}
 intersectObjects(){return Raycaster.intersections}
}
const THREE={Vector2:V2,Vector3:V3,Plane,Raycaster};
const renderer={domElement:{getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})}},scene={},camera={},controls={};

const commands=[],rebuilds=[],lifecycle=[],cancelReasons=[],surfaceBegins=[];
const selectionVisual={previewing:false,select(root,state){this.root=root;this.locked=state.isLocked;this.previewing=state.isPreview;this.selects=(this.selects||0)+1;return true},update(){this.updates=(this.updates||0)+1;return true},clear(){this.root=null;this.clears=(this.clears||0)+1},setPreviewing(value){this.previewing=!!value},dispose(){lifecycle.push('selection-dispose')}};
const selectedRoot={isObject3D:true};
const adapter={
 enumerate:()=>[{key:'buildings:house',label:'Дом'}],resolveIntersection:()=>({key:'buildings:house'}),recordFor:()=>({transform:{yawDegrees:0,uniformScale:1}}),
 resolvePoint:()=>({key:'generated:sign-1',distance:0}),
 rootFor:()=>selectedRoot,
 beginPreview(){},updatePreview(){},commitPreview:()=>({type:'move'}),deleteCommand:()=>({type:'delete'}),dependenciesFor:()=>['building'],
 cancelPreview(){cancelReasons.push('adapter-one')},cancelAllPreviews(){cancelReasons.push('adapter-all')},dispose(){lifecycle.push('adapter-dispose')}
};
let runtimeHooks;
const runtime={active:true,selection:{key:'buildings:house'},refreshCatalog(){lifecycle.push('refresh')},dispose:async()=>{runtime.disposed=true}};
const fakeCamera={
 enter:mode=>lifecycle.push(`camera-enter:${mode}`),restore:()=>{lifecycle.push('camera-restore');return true},setMode:()=>true,
 handleAction:action=>{lifecycle.push(`camera-action:${action.action}`);return action.action==='clear-input'},update:()=>{},dispose:()=>lifecycle.push('camera-dispose')
};
const surface={
 active:false,radiusM:null,begin(value){this.active=true;this.radiusM=value.radiusM;surfaceBegins.push(value)},move(){},
 finish(){this.active=false;return {type:'surface'}},setRadius(value){this.radiusM=value},
 cancel(reason){if(!this.active)return false;this.active=false;cancelReasons.push(`surface:${reason}`);return true},dispose(){lifecycle.push('surface-dispose')}
};
const placement={
 preview:null,async begin(){this.preview={transform:{positionM:[0,0,0],yawDegrees:0,uniformScale:1}};return {}},
 update(value){Object.assign(this.preview.transform,value)},async commit(){this.preview=null;return {command:{type:'add'},dependencies:['decor']}},
 cancel(reason){if(this.preview){this.preview=null;cancelReasons.push(`placement:${reason}`);return true}return false},dispose(){lifecycle.push('placement-dispose')}
};
const host=createWalkMapEditorWalkHost({
 THREE,renderer,scene,camera,controls,adapter,surface,placement,selectionVisual,palette:()=>[],getPickRoots:()=>[{}],
 releaseControls:()=>lifecycle.push('release-controls'),enterGameEditor:()=>lifecycle.push('game-enter'),leaveGameEditor:()=>lifecycle.push('game-leave'),
 prepareCommands:async values=>values,commitCommands:async values=>{commands.push(...values);return true},requestRebuild:meta=>rebuilds.push(meta),
 createRuntime:options=>{runtimeHooks=options.hooks;return runtime},createCamera:()=>fakeCamera
});

assert.equal(host.pick({event:{clientX:5,clientY:5}}).key,'buildings:house');Raycaster.intersections=[];assert.equal(host.pick({event:{clientX:5,clientY:5}}).key,'generated:sign-1');Raycaster.intersections=[{object:{userData:{editorKey:'buildings:house'}}}];assert.deepEqual(host.groundPoint(),new V3(10,0,20));
await runtimeHooks.enter({mode:'top'});await runtimeHooks.enter({mode:'top'});
assert.deepEqual(lifecycle.slice(0,3),['release-controls','game-enter','camera-enter:top'],'releaseControls must run before camera capture');
assert.equal(lifecycle.filter(value=>value==='release-controls').length,1);assert.equal(lifecycle.filter(value=>value==='game-enter').length,1);

runtimeHooks.clearInput('blur');assert.ok(lifecycle.includes('camera-action:clear-input'));
runtimeHooks.selectionChanged({key:'buildings:house',locked:false});assert.equal(selectionVisual.root,selectedRoot);assert.equal(selectionVisual.locked,false);
const initialRadius=host.brushRadiusM;await runtimeHooks.sceneAction({action:'brush-larger'},null,{tool:'paint'});assert.ok(host.brushRadiusM>initialRadius);
await runtimeHooks.sceneAction({action:'paint-start'},{clientX:1,clientY:1},{tool:'paint',activeAsset:{materialId:'asphalt'}});
assert.equal(surfaceBegins.at(-1).materialId,'asphalt');assert.equal(surfaceBegins.at(-1).radiusM,host.brushRadiusM);assert.equal(host.paintMaterialId,'asphalt');
await runtimeHooks.sceneAction({action:'cancel-pointer'},null,{tool:'paint'});assert.ok(cancelReasons.includes('surface:pointer-cancel'));assert.ok(cancelReasons.includes('adapter-all'));

await runtimeHooks.sceneAction({action:'paint-start'},{clientX:1,clientY:1},{tool:'paint',activeAsset:{materialId:'earth'}});
await runtimeHooks.sceneAction({action:'paint-end'},{clientX:2,clientY:2},{tool:'paint',activeAsset:{materialId:'earth'}});assert.equal(commands.at(-1).type,'surface');
assert.equal((await runtimeHooks.placeAsset({placementMode:'paint',materialId:'grass'})).tool,'paint');assert.equal(host.paintMaterialId,'grass');

await runtimeHooks.placeAsset({key:'lamp'});assert.ok(placement.preview);
await runtimeHooks.sceneAction({action:'primary-start'},{clientX:4,clientY:4},{tool:'place'});
await runtimeHooks.sceneAction({action:'primary-end'},{clientX:4,clientY:4},{tool:'place'});assert.equal(commands.at(-1).type,'add');
await runtimeHooks.deleteObject({item:{key:'buildings:house',label:'Дом'},confirmed:true});assert.equal(commands.at(-1).type,'delete');
await runtimeHooks.sceneAction({action:'primary-start'},{clientX:4,clientY:4},{tool:'move',selection:{key:'buildings:house'}});assert.equal(selectionVisual.previewing,true);
await runtimeHooks.sceneAction({action:'pointer-move'},{clientX:7,clientY:8},{tool:'move',selection:{key:'buildings:house'}});assert.ok(selectionVisual.updates>0);
await runtimeHooks.commit();assert.equal(commands.at(-1).type,'move');assert.equal(selectionVisual.previewing,false);

host.update(.016);await runtimeHooks.leave({reason:'test'});await runtimeHooks.leave({reason:'again'});
assert.equal(lifecycle.filter(value=>value==='camera-restore').length,1);assert.equal(lifecycle.filter(value=>value==='game-leave').length,1);
const firstDispose=host.dispose(),secondDispose=host.dispose();assert.equal(firstDispose,secondDispose);await firstDispose;
assert.equal(runtime.disposed,true);assert.equal(lifecycle.filter(value=>value==='placement-dispose').length,1);assert.equal(lifecycle.filter(value=>value==='surface-dispose').length,1);assert.equal(lifecycle.filter(value=>value==='adapter-dispose').length,1);
assert.equal(lifecycle.filter(value=>value==='camera-dispose').length,1);
assert.equal(lifecycle.filter(value=>value==='selection-dispose').length,1);

function commitHarness({prepare,commit,rebuild}={}){
 let hooks,commitCalls=0,previewConsumed=0;const recovery=[];
 const localAdapter={...adapter,commitPreview:()=>{previewConsumed++;return {type:'move-raw',transform:{positionM:[1,0,1]}}},dispose(){}};
 const localRuntime={active:true,selection:{key:'buildings:house'},refreshCatalog(){},dispose:async()=>{}};
 const localHost=createWalkMapEditorWalkHost({THREE,renderer,scene,camera,controls,adapter:localAdapter,
  prepareCommands:prepare||((values)=>values),commitCommands:async(...args)=>{commitCalls++;return commit?commit(...args):true},
  requestRebuild:async meta=>{recovery.push(meta);return rebuild?rebuild(meta):undefined},
  createRuntime:options=>{hooks=options.hooks;return localRuntime},createCamera:()=>fakeCamera});
 return {hooks,host:localHost,recovery,get commitCalls(){return commitCalls},get previewConsumed(){return previewConsumed}};
}

const prepareReject=commitHarness({prepare:()=>{throw new Error('derived validation failed')}});
await assert.rejects(()=>prepareReject.hooks.commit(),/derived validation failed/);assert.equal(prepareReject.commitCalls,0);assert.equal(prepareReject.previewConsumed,1);assert.ok(prepareReject.recovery.some(meta=>meta.rollback===true));await prepareReject.host.dispose();

const commitReject=commitHarness({commit:()=>false});
assert.equal(await commitReject.hooks.commit(),false);assert.equal(commitReject.commitCalls,1);assert.ok(commitReject.recovery.some(meta=>meta.rollback===true));await commitReject.host.dispose();

let failedCommittedRebuild=true;
const rebuildReject=commitHarness({rebuild:meta=>{if(meta.committed&&failedCommittedRebuild){failedCommittedRebuild=false;throw new Error('rebuild failed')}}});
await assert.rejects(()=>rebuildReject.hooks.commit(),/rebuild failed/);assert.equal(rebuildReject.commitCalls,1);assert.ok(rebuildReject.recovery.some(meta=>meta.committed===true));assert.ok(rebuildReject.recovery.some(meta=>meta.rollback===true));await rebuildReject.host.dispose();

let trustedSurfaceHooks,trustedSurfacePrepares=0;const trustedSurfaceCommands=[],trustedSurface={active:false,begin(){this.active=true},move(){},finish(){this.active=false;return {type:'surface.set-stroke',stroke:{id:'raw',materialId:'asphalt',mode:'paint',shape:{type:'cells',cells:[[1,1]]}}}},cancel(){this.active=false},dispose(){}};const trustedSurfaceHost=createWalkMapEditorWalkHost({THREE,renderer,scene,camera,controls,adapter,surface:trustedSurface,prepareSurfaceStroke:raw=>{trustedSurfacePrepares++;return {changed:true,command:{...raw,trusted:true},dependencies:['trusted-topology']}},prepareCommands:values=>values,commitCommands:values=>{trustedSurfaceCommands.push(...values);return true},requestRebuild:()=>{},createRuntime:options=>{trustedSurfaceHooks=options.hooks;return {active:true,selection:null,refreshCatalog(){},dispose:async()=>{}}},createCamera:()=>fakeCamera});await trustedSurfaceHooks.sceneAction({action:'paint-start'},null,{tool:'paint',activeAsset:{materialId:'asphalt'}});await trustedSurfaceHooks.sceneAction({action:'paint-end'},null,{tool:'paint',activeAsset:{materialId:'asphalt'}});assert.equal(trustedSurfacePrepares,1);assert.equal(trustedSurfaceCommands.at(-1).trusted,true,'host must commit only the topology compiler output');await trustedSurfaceHost.dispose();

assert.throws(()=>createWalkMapEditorWalkHost({THREE,renderer,scene,camera,controls,adapter,commitCommands:()=>true}),/prepareCommands/);

let failedEnterHooks,failedEnterLeaves=0;
const failedEnterHost=createWalkMapEditorWalkHost({THREE,renderer,scene,camera,controls,adapter,
 prepareCommands:values=>values,commitCommands:()=>true,enterGameEditor:()=>{throw new Error('enter failed')},leaveGameEditor:()=>{failedEnterLeaves++},
 createRuntime:options=>{failedEnterHooks=options.hooks;return {active:false,selection:null,refreshCatalog(){},dispose:async()=>{}}},createCamera:()=>fakeCamera});
await assert.rejects(()=>failedEnterHooks.enter({mode:'top'}),/enter failed/);assert.equal(failedEnterLeaves,1,'failed entry must restore game ownership');
await failedEnterHooks.leave({reason:'runtime-entry-recovery'});assert.equal(failedEnterLeaves,1,'runtime recovery after host recovery must be idempotent');await failedEnterHost.dispose();

console.log('walk map editor walk host: PASS');
