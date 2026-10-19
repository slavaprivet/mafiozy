import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import {createWalkMapEditorDocument,walkMapEditorEntityKey} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {
 compileWalkMapEditorDocument,
 createWalkMapEditorCompileSource,
 createWalkMapEditorDatasetAdapter,
 createWalkMapEditorSurfaceAdapter,
 createWalkMapEditorTopologyAdapter,
 isWalkMapEditorCompileResult
} from './walk_map_editor_compile.mjs';
import {createWalkMapEditorPublishBundle,downloadWalkMapEditorPublishBundle,isWalkMapEditorPublishBundle} from './walk_map_editor_publish_bundle.mjs';

const rows=2,cols=2,worldUnitsPerCell=4.1,revision='bundle-source-r1',topology={grid:[['earth','earth'],['earth','earth']]},building={id:'b1',assetId:'house',transform:{positionM:[4.1,0,4.1]}};
const sourceTexts={topology:JSON.stringify(topology),buildings:JSON.stringify([building]),decor:'[]',custom:'[]'},sources=Object.fromEntries(Object.entries(sourceTexts).map(([name,text])=>[name,createWalkMapEditorCompileSource(name,text,{revision})]));
const sourceDigests={topology:sources.topology.sha256,buildings:sources.buildings.sha256,decor:sources.decor.sha256},base={topology:{sha256:sources.topology.sha256,revision},buildings:{sha256:sources.buildings.sha256,revision},decor:{sha256:sources.decor.sha256,revision},extensions:{custom:{sha256:sources.custom.sha256,revision}}};
const datasetAdapters=new Map(['buildings','decor','custom'].map(dataset=>[dataset,createWalkMapEditorDatasetAdapter({dataset,readEntities:snapshot=>snapshot,writeEntities:(_snapshot,entities)=>entities})])),topologyAdapter=createWalkMapEditorTopologyAdapter({id:'grid',dimensions:snapshot=>({rows:snapshot.grid.length,cols:snapshot.grid[0].length}),readCell:(snapshot,row,col)=>snapshot.grid[row][col],writeCell:(snapshot,row,col,value)=>{snapshot.grid[row][col]=value;},eraseCell:(snapshot,row,col)=>{snapshot.grid[row][col]=null;}}),surfaceAdapters=new Map([['grass',createWalkMapEditorSurfaceAdapter({materialId:'grass',paintValue:'grass'})]]);
const zero=()=>Array.from({length:rows},()=>Array(cols).fill(0)),protectionPolicy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell,sourceDigests,masks:{protectedMask:zero(),policeMask:zero(),bridgeDeckMask:zero()},trustedBaseEntities:new Map([[walkMapEditorEntityKey({dataset:'buildings',id:'b1'}),building]]),footprintAdapters:new Map([['buildings',{cellsFor:({snapshot,map})=>[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]]}]])});
const document=createWalkMapEditorDocument({documentId:'bundle-test',createdAt:'2026-09-23T12:00:00.000Z',map:{rows,cols,worldUnitsPerCell},base}),moved={...building,transform:{...building.transform,yawDegrees:45}};document.objectPatches.push({source:{dataset:'buildings',id:'b1'},action:'modify',before:building,after:moved,derivedDirty:true});document.surfaceStrokes.push({id:'paint-grass',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[0,1]]}});
const compileResult=compileWalkMapEditorDocument(document,{trustedSources:sources,datasetAdapters,topologyAdapter,surfaceAdapters,protectionPolicy,compilerId:'bundle-compiler-v1',compiledAt:'2026-09-23T12:01:00.000Z'});assert.equal(isWalkMapEditorCompileResult(compileResult),true);
const options={registeredObjectDatasets:['buildings','decor','custom'],registeredSurfaceMaterials:['grass'],publisherId:'bundle-test-publisher'},first=createWalkMapEditorPublishBundle(compileResult,options),second=createWalkMapEditorPublishBundle(compileResult,options);
assert.equal(isWalkMapEditorPublishBundle(first),true);assert.deepEqual(first,second);assert.equal(first.files.length,5);assert.deepEqual(first.files.map(file=>file.kind),['manifest','topology','buildings','decor','custom']);assert.equal(new Set(first.files.map(file=>file.filename.toLowerCase())).size,5);
for(const file of first.files){assert.deepEqual(JSON.parse(file.text),JSON.parse(file.text));assert.equal(file.sha256,crypto.createHash('sha256').update(file.text).digest('hex'));assert.equal(file.bytes,new TextEncoder().encode(file.text).byteLength);assert.ok(file.filename.endsWith('.json'));}
assert.equal(first.manifest.document.documentId,document.documentId);assert.equal(first.manifest.document.revision,document.revision);assert.equal(first.manifest.sources.custom.sha256,sources.custom.sha256);for(const name of ['topology','buildings','decor','custom']){assert.equal(first.manifest.artifacts[name].sha256,compileResult.artifacts[name].sha256);assert.equal(first.manifest.artifacts[name].filename,first.files.find(file=>file.kind===name).filename);}assert.equal(first.manifestSha256,first.files[0].sha256);

assert.throws(()=>createWalkMapEditorPublishBundle({...compileResult},options),/TRUSTED_COMPILE_RESULT_REQUIRED/);
assert.throws(()=>createWalkMapEditorPublishBundle(compileResult,{...options,registeredObjectDatasets:[]}),/PUBLISH_NOT_READY/);
assert.throws(()=>createWalkMapEditorPublishBundle(compileResult,{...options,maxArtifactBytes:8}),/TOO_LARGE/);
assert.throws(()=>createWalkMapEditorPublishBundle(compileResult,{...options,filenames:{topology:'..\/topology.json'}}),/safe \.json basename/);
assert.throws(()=>createWalkMapEditorPublishBundle(compileResult,{...options,filenames:{topology:'same.json',decor:'SAME.json'}}),/Duplicate bundle filename/);
assert.throws(()=>createWalkMapEditorPublishBundle(compileResult,{...options,filenames:{unknown:'x.json'}}),/Unknown bundle filename slot/);

const downloads=[];const downloaded=await downloadWalkMapEditorPublishBundle(first,{createBlob:(parts,blobOptions)=>({parts,blobOptions}),download:request=>{assert.equal(Object.isFrozen(request),true);downloads.push(request);}});assert.equal(downloaded.downloadedCount,5);assert.equal(downloads.length,5);assert.deepEqual(downloaded.filenames,first.files.map(file=>file.filename));for(let i=0;i<downloads.length;i++){assert.equal(downloads[i].blob.parts[0],first.files[i].text);assert.equal(downloads[i].sha256,first.files[i].sha256);}

let blobCalls=0,downloadCalls=0;await assert.rejects(downloadWalkMapEditorPublishBundle(first,{createBlob:parts=>{blobCalls++;if(blobCalls===3)throw new Error('blob failed');return {parts};},download:()=>{downloadCalls++;}}),error=>/BLOB_PREPARATION_FAILED/.test(error.message)&&error.downloadedCount===0);assert.equal(downloadCalls,0);
let attempted=0;await assert.rejects(downloadWalkMapEditorPublishBundle(first,{createBlob:parts=>({parts}),download:()=>{attempted++;if(attempted===2)throw new Error('download failed');}}),error=>/DOWNLOAD_FAILED/.test(error.message)&&error.downloadedCount===1&&error.filename===first.files[1].filename);assert.equal(attempted,2);
await assert.rejects(downloadWalkMapEditorPublishBundle(structuredClone(first),{createBlob:parts=>({parts}),download:()=>{}}),/TRUSTED_PUBLISH_BUNDLE_REQUIRED/);
console.log('walk map editor publish bundle: PASS');

