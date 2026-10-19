import assert from 'node:assert/strict';
import {createWalkMapProtectionPolicy,isWalkMapProtectionPolicy,isWalkMapProtectionAuditReceipt,requireWalkMapProtectionAuthorization,walkMapEditorEntityKey} from './walk_map_editor_protection.mjs';
import {createWalkMapEditorDocument} from './walk_map_editor_document.mjs';

const rows=6,cols=6,Z=()=>[0,0,0,0,0,0];
const protectedMask=[Z(),[0,1,1,0,0,0],Z(),Z(),Z(),Z()];
const policeMask=[Z(),Z(),Z(),[0,1,0,0,0,0],Z(),Z()];
const bridgeDeckMask=[Z(),Z(),Z(),Z(),[0,0,0,1,1,0],Z()];
const sourceDigests={topology:'a'.repeat(64),buildings:'b'.repeat(64),decor:'c'.repeat(64)};
const shop={id:'shop',assetId:'cell-box',gameplayActive:false,transform:{positionM:[16.4,0,0]}};
const shopKey=walkMapEditorEntityKey({dataset:'buildings',id:'shop'});
const civic={id:'civic-hall',assetId:'cell-box',gameplayActive:false,transform:{positionM:[0,0,0]}};
const civicKey=walkMapEditorEntityKey({dataset:'buildings',id:'civic-hall'});
const policy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell:4.1,sourceDigests,masks:{protectedMask,policeMask,bridgeDeckMask},protectedEntityIds:[civicKey],trustedBaseEntities:new Map([[shopKey,shop],[civicKey,civic]]),footprintAdapters:new Map([['buildings',{cellsFor:({snapshot,map})=>[[Math.floor(snapshot.transform.positionM[2]/map.worldUnitsPerCell),Math.floor(snapshot.transform.positionM[0]/map.worldUnitsPerCell)]]}]])});
assert.equal(isWalkMapProtectionPolicy(policy),true);
assert.equal(isWalkMapProtectionPolicy({isProtectionPolicy:true}),false);

const base={topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}};
const before=createWalkMapEditorDocument({map:{rows,cols,worldUnitsPerCell:4.1},base,documentId:'protection-test'});
const surfaceAfter=structuredClone(before);surfaceAfter.surfaceStrokes.push({id:'paint-protected',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[1,1]]}});
let report=policy.inspectFinalDelta({before,after:surfaceAfter});
assert.equal(report.allowed,false);assert.equal(report.protectedTouches[0].code,'PROTECTED_CELL');

const safeAfter=structuredClone(before);safeAfter.surfaceStrokes.push({id:'paint-safe',materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[2,4]]}});
report=policy.inspectFinalDelta({before,after:safeAfter});assert.equal(report.allowed,true);

const movedShop={...shop,gameplayActive:false,transform:{...shop.transform,positionM:[4.1,0,12.3]},footprint:{forgedSafe:true}};
const buildingAfter=structuredClone(before);buildingAfter.objectPatches.push({key:shopKey,source:{dataset:'buildings',id:'shop'},action:'modify',before:shop,after:movedShop,derivedDirty:true});
report=policy.inspectFinalDelta({before,after:buildingAfter});
assert.ok(report.protectedTouches.some(touch=>touch.masks.includes('policeMask')));
const auditScope={transactionId:'tx-protected-1',documentId:before.documentId,operation:'commit',beforeRevision:0,afterRevision:1};
assert.throws(()=>requireWalkMapProtectionAuthorization(policy,report,null,{...auditScope,reason:'test'}),/PROTECTED_EDIT/);
const audit=requireWalkMapProtectionAuthorization(policy,report,()=>({allowed:true,approvalId:'qa-1',actor:'test'}),{...auditScope,reason:'Проверка'});
assert.equal(audit.approvalId,'qa-1');assert.equal(audit.reason,'Проверка');
assert.equal(audit.decision,'approved');assert.equal(audit.scope.documentId,before.documentId);assert.equal(isWalkMapProtectionAuditReceipt(audit),true);
assert.throws(()=>{audit.touches[0].cell[0]=5},TypeError);

const clearReport=policy.inspectFinalDelta({before,after:safeAfter});
const clearAudit=requireWalkMapProtectionAuthorization(policy,clearReport,null,{transactionId:'tx-clear-1',documentId:before.documentId,operation:'commit',beforeRevision:0,afterRevision:1});
assert.equal(clearAudit.decision,'clear');assert.equal(isWalkMapProtectionAuditReceipt(clearAudit),true);

const civicAfter=structuredClone(before);civicAfter.objectPatches.push({key:civicKey,source:{dataset:'buildings',id:'civic-hall'},action:'delete',before:civic,after:null,derivedDirty:true});
report=policy.inspectFinalDelta({before,after:civicAfter});assert.ok(report.protectedTouches.some(touch=>touch.code==='PROTECTED_ENTITY'));

assert.throws(()=>policy.assertCompatible({...before,map:{...before.map,rows:7}}),/PROTECTION_MAP_MISMATCH/);
console.log('walk map editor protection: PASS');
