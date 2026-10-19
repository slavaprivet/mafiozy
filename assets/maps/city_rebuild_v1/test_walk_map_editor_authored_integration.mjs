import assert from 'node:assert/strict';
import {createWalkMapAuthoredAdapter} from './walk_map_editor_authored_adapter.mjs';
import {createWalkMapAuthoredCommandPreparer} from './walk_map_editor_authored_prepare.mjs';
import {createWalkMapEditorWalkHost} from './walk_map_editor_walk_host.mjs';
import {createWalkMapEditorDocument,createWalkMapEditorSession,executeWalkMapEditorTransaction,walkMapEditorEntityKey} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';

const M=4.1,sourceDigests={topology:'a'.repeat(64),buildings:'b'.repeat(64),decor:'c'.repeat(64)};
const rect=(minC,minR,maxC,maxR)=>({minC,minR,maxC,maxR});
const base={
 id:'HOUSE-INTEGRATION',assetId:'garden_lane_house_v1',role:'residence',transform:{positionM:[41,0,82],yawDegrees:0,uniformScale:1,horizontalScale:[2,1],modelLocalOffsetM:[0,0,0],preserveSiteBounds:false},
 footprint:rect(9,19.5,11,20.5),clearance:rect(8.5,19,11.5,21),entry:{anchorRC:{c:10,r:20.5},roadProbeRC:{c:10,r:22.5}},entryCorridor:rect(9.8,20.4,10.2,22.6),
 collision:{worldBodies:[{id:'wall',polygonCR:[[9,19.5],[11,19.5],[11,20],[9,20]],rectangleRC:rect(9,19.5,11,20),minYM:0,maxYM:8.2}]},futureField:{kept:true}
};
const topology={grid:Array.from({length:40},()=>Array(40).fill(8)),roadMask:Array.from({length:40},()=>Array(40).fill(0)),protectedMask:Array.from({length:40},()=>Array(40).fill(0)),policeMask:Array.from({length:40},()=>Array(40).fill(0)),bridgeDeckMask:Array.from({length:40},()=>Array(40).fill(0))};
topology.roadMask[18][14]=1;topology.grid[18][14]=0;
const key=walkMapEditorEntityKey({dataset:'buildings',id:base.id});
const empty=()=>Array.from({length:40},()=>Array(40).fill(0));
function footprintCells({snapshot}){const box=snapshot.footprint,result=[];for(let r=Math.floor(box.minR);r<Math.ceil(box.maxR);r++)for(let c=Math.floor(box.minC);c<Math.ceil(box.maxC);c++)result.push([r,c]);return result;}
const protectionPolicy=createWalkMapProtectionPolicy({rows:40,cols:40,worldUnitsPerCell:M,sourceDigests,masks:{protectedMask:empty(),policeMask:empty(),bridgeDeckMask:empty()},trustedBaseEntities:new Map([[key,base]]),footprintAdapters:new Map([['buildings',{id:'derived-building-footprint',version:1,cellsFor:footprintCells}]])});

function vector(){return {x:0,y:0,z:0,fromArray(values){[this.x,this.y,this.z]=values},set(x,y,z){this.x=x;this.y=y;this.z=z},clone(){return vectorWith(this.x,this.y,this.z)},copy(other){this.x=other.x;this.y=other.y;this.z=other.z;return this}}}
function vectorWith(x=0,y=0,z=0){const value=vector();value.set(x,y,z);return value;}
function applyTransform(group,record){group.position.fromArray(record.transform.positionM);group.rotation.y=record.transform.yawDegrees*Math.PI/180;const h=record.transform.horizontalScale||[1,1],s=record.transform.uniformScale??1;group.scale.set(s*h[0],s,s*h[1]);}
const group={userData:{instance:base},position:vector(),rotation:{y:0},scale:vector(),visible:true,updateMatrixWorld(){}};applyTransform(group,base);
const adapter=createWalkMapAuthoredAdapter({buildingRecords:[base],groups:[group]});

let session=createWalkMapEditorSession(createWalkMapEditorDocument({map:{rows:40,cols:40,worldUnitsPerCell:M},base:{topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}},documentId:'authored-integration'}));
const originalSession=structuredClone(session),resolveBaseEntity=source=>source.dataset==='buildings'&&source.id===base.id?{status:'found',entity:base}:{status:'absent'};
const effective=()=>session.document.objectPatches.find(patch=>patch.key===key)?.after||base;
const prepareCommands=createWalkMapAuthoredCommandPreparer({resolveCurrentEntity:()=>effective(),topology,metresPerCell:M});
let beforeCommit=null,failNextRebuild=false,rebuilds=0,runtimeHooks,lastCommitMeta=null;
function rebuildScene(){const record=effective();adapter.replaceRecord(key,record,group);applyTransform(group,record);rebuilds++;}
const commitCommands=(commands,meta)=>{lastCommitMeta=meta;beforeCommit=session;session=executeWalkMapEditorTransaction(session,commands,{resolveBaseEntity,protectionPolicy,updatedAt:'2026-09-23T12:00:00.000Z'});return true;};
const requestRebuild=meta=>{if(meta.rollback&&beforeCommit){session=beforeCommit;beforeCommit=null;rebuildScene();return}if(meta.committed&&failNextRebuild){failNextRebuild=false;throw new Error('injected rebuild failure')}rebuildScene();beforeCommit=null;};

class V2{set(){return this}}class V3{constructor(x=0,y=0,z=0){this.x=x;this.y=y;this.z=z}clone(){return new V3(this.x,this.y,this.z)}}class Plane{}class Raycaster{constructor(){this.ray={intersectPlane:(_plane,out)=>{out.x=0;out.y=0;out.z=0;return out}}}setFromCamera(){}intersectObjects(){return []}}
const THREE={Vector2:V2,Vector3:V3,Plane,Raycaster},renderer={domElement:{getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})}},camera={},controls={},scene={};
const fakeCamera={enter(){},restore(){return true},setMode(){return true},handleAction(){return false},update(){},dispose(){}};
const runtime={active:true,selection:{key},refreshCatalog(){},dispose:async()=>{}};
const host=createWalkMapEditorWalkHost({THREE,renderer,camera,controls,scene,adapter,prepareCommands,commitCommands,requestRebuild,createCamera:()=>fakeCamera,createRuntime:options=>{runtimeHooks=options.hooks;return runtime}});

async function previewAndCommit(transform){adapter.beginPreview(key);adapter.updatePreview(key,transform);return runtimeHooks.commit();}

assert.equal(await previewAndCommit({positionM:[49.2,0,73.8],yawDegrees:90}),true);
let patch=session.document.objectPatches.find(item=>item.key===key),moved=patch.after;
assert.deepEqual(moved.transform.positionM,[49.2,0,73.8]);assert.deepEqual(moved.footprint,rect(11.5,17,12.5,19));assert.deepEqual(moved.clearance,rect(11,16.5,13,19.5));
assert.deepEqual(moved.collision.worldBodies[0].polygonCR,[[11.5,19],[11.5,17],[12,17],[12,19]]);assert.deepEqual(moved.entry.anchorRC,{r:18,c:12.5});assert.deepEqual(moved.entry.roadProbeRC,{r:18,c:14});assert.deepEqual(moved.entryCorridor,rect(12.5,17.7,14,18.3));
assert.equal(moved.futureField.kept,true);assert.equal(session.revision,1);assert.equal(session.undoStack.at(-1).protectionExecutions[0].decision,'clear');assert.equal(group.position.x,49.2);assert.equal(group.rotation.y,Math.PI/2);assert.ok(rebuilds>0);
for(const dependency of ['building-entry','walk-collision','vehicle-collision','minimap'])assert.ok(lastCommitMeta.dependencies.includes(dependency),`missing derived dependency: ${dependency}`);

const preparedDelete=await prepareCommands([adapter.deleteCommand(key)],{dependencies:[]});
assert.equal(preparedDelete.commands.length,1);assert.equal(preparedDelete.commands[0].patch.action,'delete');assert.deepEqual(preparedDelete.commands[0].patch.before,moved);
for(const dependency of ['building-entry','walk-collision','vehicle-collision','parking','minimap'])assert.ok(preparedDelete.dependencies.includes(dependency),`missing delete dependency: ${dependency}`);

const committedSnapshot=structuredClone(session),committedTransform=structuredClone(moved.transform),rebuildCount=rebuilds;
await assert.rejects(()=>previewAndCommit({positionM:[53.3,0,77.9],yawDegrees:45}),/UNSUPPORTED_BUILDING_YAW/);
assert.deepEqual(session,committedSnapshot,'validation failure must not mutate the document');assert.deepEqual([group.position.x,group.position.z,group.rotation.y],[committedTransform.positionM[0],committedTransform.positionM[2],committedTransform.yawDegrees*Math.PI/180]);assert.ok(rebuilds>rebuildCount);

failNextRebuild=true;const beforeFailedRebuild=structuredClone(session),beforeFailedTransform=structuredClone(effective().transform);
await assert.rejects(()=>previewAndCommit({positionM:[57.4,0,73.8],yawDegrees:90}),/injected rebuild failure/);
assert.deepEqual(session,beforeFailedRebuild,'rebuild failure must roll back the authoritative document');assert.deepEqual([group.position.x,group.position.z,group.rotation.y],[beforeFailedTransform.positionM[0],beforeFailedTransform.positionM[2],beforeFailedTransform.yawDegrees*Math.PI/180]);

assert.notDeepEqual(session,originalSession,'successful edit remains committed after isolated failure checks');
await host.dispose();
console.log('walk map editor authored integration: PASS');
