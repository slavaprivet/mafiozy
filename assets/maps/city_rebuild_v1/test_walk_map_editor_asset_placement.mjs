import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {createWalkMapAssetPlacement} from './walk_map_editor_asset_placement.mjs';
import {createWalkMapEditorPalette,createWalkMapSurfacePalette} from './walk_map_editor_palette.mjs';

const here=new URL('.',import.meta.url),read=async file=>JSON.parse(await readFile(new URL(file,here),'utf8'));
const [buildingCatalog,decorCatalog,buildingPlacement,detentionPlacement,decorPlacement]=await Promise.all([
 read('buildings_catalog.v1.json'),read('decor_catalog.v1.json'),read('buildings_placement.v1.json'),read('detention_native_sites.v1.json'),read('decor_placement.v1.json')
]);
const currentRecords=[...buildingPlacement.instances,...detentionPlacement.instances,...decorPlacement.instances],palette=createWalkMapEditorPalette({buildingCatalog,decorCatalog,currentRecords});
const lamp=palette.find(item=>item.assetId==='lamp_pine_v1'),signal=palette.find(item=>item.assetId==='traffic_signal_4way_v1'),paintSurface=createWalkMapSurfacePalette()[0];
assert.ok(lamp?.available);assert.equal(signal?.available,false);

function vector(){return {x:0,y:0,z:0,fromArray(value){[this.x,this.y,this.z]=value},set(x,y,z){this.x=x;this.y=y;this.z=z}}}
function model(shared={}){return {position:vector(),rotation:{y:0},scale:vector(),userData:{},geometry:shared.geometry,material:shared.material,updateMatrixWorld(){this.updated=true}}}
function template(shared={}){return {...model(shared),clone(){return model(shared)}}}
function scene(){return {children:[],add(value){this.children.push(value)},remove(value){this.children=this.children.filter(item=>item!==value)}}}
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no});return {promise,resolve,reject}}
function compiler({asset,transform}){return {ok:true,dataset:'decor',sourceFile:'editor-placement-test',record:{assetId:asset.assetId,transform},dependencies:['decor-collision','lighting']}}
function placement(options={}){let sequence=0;return createWalkMapAssetPlacement({scene:options.scene||scene(),loadTemplate:options.loadTemplate||(()=>template(options.shared)),compileRecord:options.compileRecord||compiler,idFactory:options.idFactory||(()=>`placed-${++sequence}`),idExists:options.idExists,groundHeight:options.groundHeight||(()=>0),cloneTemplate:options.cloneTemplate,onPreview:options.onPreview,onCancel:options.onCancel})}

test('actual palette availability and trusted binding are enforced before loading',async()=>{
 const stage=scene();let loads=0;const api=placement({scene:stage,loadTemplate:async()=>{loads++;return template()}});
 await assert.rejects(()=>api.begin(signal),/дорожный адаптер привязки/i);await assert.rejects(()=>api.begin({...lamp,available:undefined}),/unavailable/i);
 await assert.rejects(()=>api.begin({...lamp,binding:{...lamp.binding,sha256:'bad'}}),/trusted model binding/i);await assert.rejects(()=>api.begin(paintSurface),/trusted model binding/i);
 assert.equal(loads,0);assert.equal(stage.children.length,0);assert.equal(api.preview,null);
 const root=await api.begin(lamp);assert.equal(loads,1);assert.equal(stage.children[0],root);api.cancel('qa');
});

test('template cache is reused after success and evicted for retry after failure',async()=>{
 const stage=scene();let loads=0;const api=placement({scene:stage,loadTemplate:async()=>{loads++;if(loads===1)throw new Error('temporary loader failure');return template()}});
 await assert.rejects(()=>api.begin(lamp),/temporary loader failure/);assert.equal(api.diagnostics().cachedTemplates,0);assert.equal(stage.children.length,0);
 await api.begin(lamp);api.cancel();await api.begin(lamp);assert.equal(loads,2,'successful retry becomes the cached template');api.cancel();
});

test('pending begin can be cancelled without a late scene insertion',async()=>{
 const gate=deferred(),stage=scene(),cancels=[];const api=placement({scene:stage,loadTemplate:()=>gate.promise,onCancel:event=>cancels.push(event)}),result=api.begin(lamp);
 await Promise.resolve();await Promise.resolve();assert.equal(api.loading,true);assert.equal(api.cancel('escape'),true);assert.equal(api.loading,false);gate.resolve(template());assert.equal(await result,null);
 assert.equal(stage.children.length,0);assert.equal(cancels.length,1);assert.equal(cancels[0].pending,true);assert.equal(cancels[0].root,null);assert.equal(cancels[0].reason,'escape');
});

test('newest begin wins async races and an older loader cannot leak a root',async()=>{
 const first=deferred(),second=deferred(),stage=scene(),assetB={...lamp,key:'asset:decor:lamp-race-b',assetId:'lamp-race-b',binding:{...lamp.binding,url:'/race-b.glb',sha256:'b'.repeat(64)}};
 const api=placement({scene:stage,loadTemplate:binding=>binding.url===lamp.binding.url?first.promise:second.promise}),oldRequest=api.begin(lamp);await Promise.resolve();await Promise.resolve();const newestRequest=api.begin(assetB);await Promise.resolve();await Promise.resolve();
 first.resolve(template());assert.equal(await oldRequest,null);assert.equal(stage.children.length,0);second.resolve(template());const newest=await newestRequest;assert.equal(stage.children.length,1);assert.equal(stage.children[0],newest);assert.equal(api.preview.asset.assetId,'lamp-race-b');api.cancel();
});

test('dispose during loading prevents insertion and is idempotent',async()=>{
 const gate=deferred(),stage=scene();const api=placement({scene:stage,loadTemplate:()=>gate.promise}),request=api.begin(lamp);await Promise.resolve();await Promise.resolve();assert.equal(api.loading,true);api.dispose();api.dispose();gate.resolve(template());assert.equal(await request,null);assert.equal(stage.children.length,0);assert.equal(api.diagnostics().disposed,true);await assert.rejects(()=>api.begin(lamp),/disposed/);
});

test('ground height and horizontal scale are applied on begin and update',async()=>{
 const stage=scene(),groundCalls=[];const api=placement({scene:stage,groundHeight:(x,z,asset)=>{groundCalls.push([x,z,asset.assetId]);return x+z}}),root=await api.begin(lamp,{positionM:[4,99,8],horizontalScale:[2,.5],modelLocalOffsetM:[0,.2,0],preserveSiteBounds:true});
 assert.deepEqual([root.position.x,root.position.y,root.position.z],[4,12,8]);assert.deepEqual([root.scale.x,root.scale.y,root.scale.z],[2,1,.5]);assert.deepEqual(api.preview.transform.modelLocalOffsetM,[0,.2,0]);assert.equal(api.preview.transform.preserveSiteBounds,true);
 const transform=api.update({positionM:[8,99,12],yawDegrees:90,uniformScale:1.5});assert.deepEqual(transform.positionM,[8,20,12]);assert.deepEqual(transform.horizontalScale,[2,.5]);assert.deepEqual([root.scale.x,root.scale.y,root.scale.z],[3,1.5,.75]);assert.ok(Math.abs(root.rotation.y-Math.PI/2)<1e-12);assert.deepEqual(groundCalls.map(call=>call.slice(0,2)),[[4,8],[8,12]]);api.cancel();
});

test('invalid ground height and clone failure fail before touching the scene',async()=>{
 const badGroundScene=scene(),badGround=placement({scene:badGroundScene,groundHeight:()=>NaN});await assert.rejects(()=>badGround.begin(lamp),/finite number/);assert.equal(badGroundScene.children.length,0);assert.equal(badGround.preview,null);
 const badCloneScene=scene(),badClone=placement({scene:badCloneScene,cloneTemplate:()=>null});await assert.rejects(()=>badClone.begin(lamp),/clone returned no model/);assert.equal(badCloneScene.children.length,0);assert.equal(badClone.preview,null);
});

test('cancel, commit and dispose never dispose shared template resources',async()=>{
 let geometryDisposals=0,materialDisposals=0;const shared={geometry:{dispose(){geometryDisposals++}},material:{dispose(){materialDisposals++}}},stage=scene(),api=placement({scene:stage,shared});
 const cancelled=await api.begin(lamp);assert.equal(cancelled.geometry,shared.geometry);assert.equal(cancelled.material,shared.material);api.cancel();
 const committedRoot=await api.begin(lamp);const result=await api.commit();assert.equal(result.root,committedRoot);api.dispose();assert.equal(stage.children.length,0);assert.equal(geometryDisposals,0);assert.equal(materialDisposals,0);
});

test('successful commit normalizes dependencies, id and command metadata',async()=>{
 const stage=scene(),received=[];const api=placement({scene:stage,groundHeight:()=>2,idFactory:()=> ' placed-stable ',compileRecord:async input=>{received.push(input);input.asset.label='mutated compiler copy';return {ok:true,dataset:'decor',sourceFile:'custom-map',record:{assetId:input.asset.assetId,transform:input.transform,tag:'kept'},dependencies:['lighting','lighting','decor-collision']}}});
 await api.begin(lamp,{positionM:[4,0,8],uniformScale:1.5,horizontalScale:[2,.5]});const result=await api.commit({metadata:{author:'qa',adapter:'cannot-override',dependencies:['cannot-override']}});
 assert.equal(stage.children.length,0);assert.equal(result.record.id,'placed-stable');assert.equal(result.source.id,result.record.id);assert.equal(result.source.dataset,'decor');assert.equal(result.source.sourceFile,'custom-map');assert.deepEqual(result.record.transform.horizontalScale,[2,.5]);assert.deepEqual(result.dependencies,['lighting','decor-collision']);
 assert.equal(result.command.type,'object.set-patch');assert.equal(result.command.patch.action,'add');assert.deepEqual(result.command.patch.after,result.record);assert.equal(result.command.patch.metadata.author,'qa');assert.equal(result.command.patch.metadata.adapter,'trusted-asset-placement-v1');assert.equal(result.command.patch.metadata.assetKey,lamp.key);assert.equal(result.command.patch.metadata.assetId,lamp.assetId);assert.deepEqual(result.command.patch.metadata.dependencies,['lighting','decor-collision']);
 assert.notEqual(received[0].asset,lamp);assert.equal(lamp.label,'Сосновый фонарь');assert.equal(api.diagnostics().issuedIds,1);
});

for(const [name,compileRecord,error] of [
 ['compiler throw',async()=>{throw new Error('compiler exploded')},/compiler exploded/],
 ['explicit rejection',async()=>({ok:false,code:'NO_SAFE_SITE'}),/NO_SAFE_SITE/],
 ['non-object record',async()=>({ok:true,record:[],dependencies:[]}),/trusted compilation/i],
 ['invalid dependencies',async({asset,transform})=>({ok:true,record:{assetId:asset.assetId,transform},dependencies:['lighting',null]}),/invalid dependencies/i],
 ['asset substitution',async({transform})=>({ok:true,record:{assetId:'different-asset',transform},dependencies:[]}),/changed the asset id/i],
 ['invalid compiled transform',async({asset,transform})=>({ok:true,record:{assetId:asset.assetId,transform:{...transform,horizontalScale:[0,1]}},dependencies:[]}),/invalid asset placement transform/i]
])test(`compileRecord fails closed: ${name}`,async()=>{
 const stage=scene(),cancels=[];const api=placement({scene:stage,compileRecord,onCancel:event=>cancels.push(event)});await api.begin(lamp);assert.equal(stage.children.length,1);await assert.rejects(()=>api.commit(),error);assert.equal(stage.children.length,0);assert.equal(api.preview,null);assert.equal(api.loading,false);assert.equal(cancels.at(-1)?.reason,'compile-reject');
});

test('duplicate stable ids are rejected without leaving the second preview',async()=>{
 const stage=scene(),api=placement({scene:stage,idFactory:()=> 'same-id'});await api.begin(lamp);await api.commit();await api.begin(lamp);await assert.rejects(()=>api.commit(),/Duplicate asset placement id: same-id/);assert.equal(stage.children.length,0);assert.equal(api.preview,null);assert.equal(api.diagnostics().issuedIds,1);
});

test('ids already owned by the document are rejected before command creation',async()=>{
 const stage=scene(),api=placement({scene:stage,idFactory:()=> 'existing-id',idExists:id=>id==='existing-id'});await api.begin(lamp);await assert.rejects(()=>api.commit(),/Duplicate asset placement id: existing-id/);assert.equal(stage.children.length,0);assert.equal(api.preview,null);assert.equal(api.diagnostics().issuedIds,0);
});

test('cancel during async compilation prevents a stale command and preserves a newer preview',async()=>{
 const gate=deferred(),stage=scene(),assetB={...lamp,key:'asset:decor:lamp-commit-b',assetId:'lamp-commit-b',binding:{...lamp.binding,url:'/commit-b.glb',sha256:'c'.repeat(64)}};let calls=0;
 const api=placement({scene:stage,compileRecord:async input=>{calls++;if(calls===1)return gate.promise;return compiler(input)}});await api.begin(lamp);const staleCommit=api.commit();await Promise.resolve();assert.equal(api.loading,true);const newerRoot=await api.begin(assetB);assert.equal(stage.children.length,1);assert.equal(stage.children[0],newerRoot);gate.resolve(compiler({asset:lamp,transform:{positionM:[0,0,0],yawDegrees:0,uniformScale:1,horizontalScale:[1,1],modelLocalOffsetM:[0,0,0],preserveSiteBounds:false}}));await assert.rejects(()=>staleCommit,/commit was cancelled/);assert.equal(stage.children.length,1);assert.equal(api.preview.asset.assetId,'lamp-commit-b');api.cancel();
});

test('constructor rejects a missing trusted compiler before any preview can exist',()=>{
 assert.throws(()=>createWalkMapAssetPlacement({scene:scene(),loadTemplate:()=>template()}),/Trusted asset record compiler is required/);
});
