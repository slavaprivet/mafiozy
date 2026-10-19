import assert from 'node:assert/strict';
import {
 createWalkMapEditorCompileReceipt,
 createWalkMapEditorDocument,
 createWalkMapEditorSession,
 isWalkMapEditorCompileReceipt,
 serializeWalkMapEditorDocument
} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy,isWalkMapProtectionAuditReceipt} from './walk_map_editor_protection.mjs';
import {
 clearWalkMapEditorRecovery,
 createWalkMapEditorStorage,
 exportWalkMapEditorJson,
 importWalkMapEditorText,
 readWalkMapEditorRecovery,
 restoreWalkMapEditorRecovery,
 saveWalkMapEditorRecovery
} from './walk_map_editor_storage.mjs';

function memoryStorage(){const values=new Map();let calls=0;return {values,get calls(){return calls;},getItem(key){calls++;return values.has(key)?values.get(key):null;},setItem(key,value){calls++;values.set(key,String(value));},removeItem(key){calls++;values.delete(key);}};}
const rows=4,cols=4,worldUnitsPerCell=4.1,sourceDigests={topology:'a'.repeat(64),buildings:'b'.repeat(64),decor:'c'.repeat(64)};
const base={topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}};
const zero=()=>Array.from({length:rows},()=>Array(cols).fill(0)),protectedMask=zero();protectedMask[0][0]=1;
const policy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell,sourceDigests,masks:{protectedMask,policeMask:zero(),bridgeDeckMask:zero()},footprintAdapters:new Map([['custom',{id:'storage-test-custom',version:1,cellsFor:({snapshot,map})=>snapshot.transform?[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]]:[]} ]])});
const createdAt='2026-09-23T10:00:00.000Z';
const original=createWalkMapEditorDocument({documentId:'storage-test',createdAt,map:{rows,cols,worldUnitsPerCell},base});
const session=createWalkMapEditorSession(original),before=structuredClone(session),resolver=()=>({status:'absent'}),preflight=context=>{assert.equal(Object.isFrozen(context),true);assert.equal(Object.isFrozen(context.after),true);return {allowed:true,receiptId:'preflight-ok',compilerId:'test',compileReceipt:createWalkMapEditorCompileReceipt(context.after,{protectionPolicy:policy,sourceDigests,compilerId:'storage-test',compiledAt:createdAt,outputDigests:{placements:'d'.repeat(64)}})};};
const importOptions={protectionPolicy:policy,resolveBaseEntity:resolver,preflight,registeredObjectDatasets:['custom'],registeredSurfaceMaterials:['grass']};

const imported=structuredClone(original);
imported.objectPatches.push({source:{dataset:'custom',id:'lamp-1'},action:'add',before:null,after:{id:'lamp-1',assetId:'lamp',transform:{positionM:[8.2,0,8.2]}},derivedDirty:true});
imported.surfaceStrokes.push({id:'safe-grass',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[3,3]]}});
const importedText=serializeWalkMapEditorDocument(imported);

const protectedDocument=structuredClone(original);
protectedDocument.surfaceStrokes.push({id:'protected-grass',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[0,0]]}});
assert.throws(()=>importWalkMapEditorText(session,serializeWalkMapEditorDocument(protectedDocument),importOptions),/PROTECTED_EDIT/);
assert.deepEqual(session,before);

assert.throws(()=>importWalkMapEditorText(session,importedText,{...importOptions,expectedRevision:99}),/Stale editor revision/);
assert.deepEqual(session,before);

const mismatched=structuredClone(imported);mismatched.base.decor.sha256='d'.repeat(64);
assert.throws(()=>importWalkMapEditorText(session,serializeWalkMapEditorDocument(mismatched),importOptions),/PROTECTION_BASE_MISMATCH/);
assert.deepEqual(session,before);

assert.throws(()=>importWalkMapEditorText(session,importedText,{...importOptions,resolveBaseEntity:()=>undefined}),/BASE_RESOLUTION_INVALID/);
assert.deepEqual(session,before);
assert.throws(()=>importWalkMapEditorText(session,importedText,{...importOptions,preflight:()=>({allowed:false,receiptId:'no'})}),/IMPORT_PREFLIGHT_REJECTED/);
assert.deepEqual(session,before);
assert.throws(()=>importWalkMapEditorText(session,importedText,{...importOptions,preflight:()=>({allowed:true,receiptId:'forged',compileReceipt:{schema:'fake'}})}),/IMPORT_PREFLIGHT_REJECTED/);
assert.throws(()=>importWalkMapEditorText(session,'{bad json',importOptions),/JSON is invalid/);
assert.deepEqual(session,before);

const importedResult=importWalkMapEditorText(session,importedText,{...importOptions,updatedAt:'2026-09-23T10:01:00.000Z'});
assert.equal(importedResult.session.document.objectPatches[0].key,'custom:lamp-1');
assert.equal(importedResult.session.document.revision,1);
assert.equal(importedResult.session.undoStack.length,0);assert.equal(importedResult.session.redoStack.length,0);
assert.equal(importedResult.preflightReceipt.receiptId,'preflight-ok');
assert.equal(isWalkMapEditorCompileReceipt(importedResult.preflightReceipt.compileReceipt),true);
assert.equal(importedResult.protectionAudit.decision,'clear');assert.equal(isWalkMapProtectionAuditReceipt(importedResult.protectionAudit),true);

const storage=memoryStorage(),saved=saveWalkMapEditorRecovery(importedResult.session,{storage,savedAt:'2026-09-23T10:02:00.000Z'});
assert.match(saved.checksum,/^[a-f0-9]{8}$/);assert.ok(saved.bytes>0);
assert.deepEqual(readWalkMapEditorRecovery({storage}),importedResult.session.document);

const recoveryText=storage.values.get(saved.key),recoveryEnvelope=JSON.parse(recoveryText);recoveryEnvelope.checksum='00000000';storage.values.set(saved.key,JSON.stringify(recoveryEnvelope));
assert.throws(()=>readWalkMapEditorRecovery({storage}),/checksum mismatch/);
assert.throws(()=>restoreWalkMapEditorRecovery(session,{storage,...importOptions}),/checksum mismatch/);
assert.deepEqual(session,before);
storage.values.set(saved.key,recoveryText);
const restored=restoreWalkMapEditorRecovery(session,{storage,...importOptions,updatedAt:'2026-09-23T10:03:00.000Z'});
assert.equal(restored.session.document.objectPatches[0].key,'custom:lamp-1');
assert.equal(restored.protectionAudit.decision,'clear');

let downloaded=null;
const exported=exportWalkMapEditorJson(importedResult.session,{filename:'city.json',createBlob:(parts,options)=>({parts,options}),download:request=>{downloaded=request;}});
assert.equal(exported,downloaded);assert.equal(exported.filename,'city.json');assert.equal(exported.blob.options.type,'application/json;charset=utf-8');assert.equal(exported.blob.parts[0],serializeWalkMapEditorDocument(importedResult.session.document));

const controller=createWalkMapEditorStorage({storage,download:request=>{downloaded=request;},createBlob:(parts,options)=>({parts,options})});
assert.equal(controller.disposed,false);controller.readRecovery();const callsBeforeDispose=storage.calls;controller.dispose();controller.dispose();assert.equal(controller.disposed,true);
assert.throws(()=>controller.readRecovery(),/disposed/);assert.throws(()=>controller.exportJson(importedResult.session),/disposed/);assert.equal(storage.calls,callsBeforeDispose);

clearWalkMapEditorRecovery({storage});assert.equal(readWalkMapEditorRecovery({storage}),null);
console.log('walk map editor storage: PASS');
