import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createWalkMapEditorCompileReceipt,createWalkMapEditorDocument,createWalkMapEditorSession,serializeWalkMapEditorDocument} from './walk_map_editor_document.mjs';
import {createWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';
import {
 classifyWalkMapEditorImportText,
 createWalkMapEditorFilesWorkflow,
 createWalkMapEditorLegacyFilesBridge
} from './walk_map_editor_files_dialog.mjs';

const dir=new URL('.',import.meta.url),load=async name=>JSON.parse(await readFile(new URL(name,dir),'utf8'));
const [realLegacy,buildingsPlan,decorPlan]=await Promise.all([load('../../../map_overrides.json'),load('buildings_placement.v1.json'),load('decor_placement.v1.json')]);
const rows=200,cols=180,worldUnitsPerCell=4.1,createdAt='2026-09-23T19:00:00.000Z',sourceDigests={topology:'a'.repeat(64),buildings:'b'.repeat(64),decor:'c'.repeat(64)},base={topology:{sha256:sourceDigests.topology},buildings:{sha256:sourceDigests.buildings},decor:{sha256:sourceDigests.decor}};
const makeSession=(id='files-legacy-test',revision=0)=>{const document=createWalkMapEditorDocument({documentId:id,createdAt,map:{rows,cols,worldUnitsPerCell},base});document.revision=revision;return createWalkMapEditorSession(document)};
const zero=()=>Array.from({length:rows},()=>Array(cols).fill(0)),policy=createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell,sourceDigests,masks:{protectedMask:zero(),policeMask:zero(),bridgeDeckMask:zero()}});
const preflight=context=>({allowed:true,receiptId:'files-legacy-preflight',compilerId:'files-legacy-test',compileReceipt:createWalkMapEditorCompileReceipt(context.after,{protectionPolicy:policy,sourceDigests,compilerId:'files-legacy-test',compiledAt:createdAt,outputDigests:{placements:'d'.repeat(64)}})});
const importOptions={protectionPolicy:policy,resolveBaseEntity:()=>({status:'absent',entity:null}),preflight,registeredObjectDatasets:[],registeredSurfaceMaterials:['asphalt','grass'],updatedAt:'2026-09-23T19:01:00.000Z'};
let downloaded=null;
const bridge=createWalkMapEditorLegacyFilesBridge({
 getPreviewOptions:()=>({buildingRecords:buildingsPlan.instances,decorRecords:decorPlan.instances,trustedSourceBase:base,isProtectedCell:()=>false,protectedEntityIds:[]}),
 getImportOptions:()=>importOptions,
 downloadAudit:request=>{downloaded=request}
});

assert.equal(classifyWalkMapEditorImportText(serializeWalkMapEditorDocument(makeSession().document)).kind,'current');
assert.equal(classifyWalkMapEditorImportText(JSON.stringify(realLegacy)).kind,'legacy');
assert.deepEqual(classifyWalkMapEditorImportText(JSON.stringify({key:'/__studio_map',value:JSON.stringify(realLegacy)})),{kind:'legacy',sourceKey:'/__studio_map'});
assert.throws(()=>classifyWalkMapEditorImportText('{"other":true}'),/IMPORT_SCHEMA_UNKNOWN/);

let current=makeSession(),picker=serializeWalkMapEditorDocument(current.document),currentPrepareCalls=0,setCalls=0;
const currentPrepared=makeSession('current-import-result',1);
const workflow=createWalkMapEditorFilesWorkflow({
 getSession:()=>current,
 setSession:async next=>{setCalls++;current=next},
 pickImportText:async()=>picker,
 prepareImport:async()=>{currentPrepareCalls++;return {session:currentPrepared}},
 legacyImportBridge:bridge
});

// Current project routing remains unchanged and never enters the legacy bridge.
assert.equal(await workflow.importProject(),true);assert.equal(currentPrepareCalls,1);assert.equal(workflow.state.pending.kind,'import');assert.equal(workflow.state.pending.canApply,true);assert.equal(workflow.cancelPending(),true);assert.equal(current.document.documentId,'files-legacy-test');

// The checked-in editor-7.2 payload is staged atomically, but the live session stays untouched until confirmation.
picker=JSON.stringify(realLegacy);const before=current;assert.equal(await workflow.importProject(),true);assert.equal(workflow.state.pending.kind,'legacy');assert.equal(workflow.state.pending.canApply,true);assert.equal(workflow.state.pending.report.counts.converted,2);assert.equal(workflow.state.pending.report.counts.ambiguous,107);assert.equal(workflow.state.pending.report.counts.unsupported,4);assert.equal(current,before);assert.equal(setCalls,0);
assert.equal(await workflow.downloadPendingAudit(),true);assert.equal(current,before);assert.equal(downloaded.filename,'mafiozi-legacy-7.2-audit.json');assert.equal(downloaded.text.includes('palm'),false);assert.equal(downloaded.text.includes('decorFull'),true);assert.doesNotThrow(()=>JSON.parse(downloaded.text));
assert.equal(workflow.cancelPending(),true);assert.equal(current,before);

// A second preview can be applied; all conversion was already accepted by current protection and preflight.
assert.equal(await workflow.importProject(),true);assert.equal(await workflow.applyPending(),true);assert.equal(setCalls,1);assert.equal(current.document.surfaceStrokes.reduce((sum,stroke)=>sum+stroke.shape.cells.length,0),7);assert.equal(workflow.state.pending,null);

// Stale session between preview and Apply is fail-closed.
current=makeSession('stale-source',0);picker=JSON.stringify(realLegacy);assert.equal(await workflow.importProject(),true);const stalePending=workflow.state.pending;current=makeSession('external-change',1);const beforeStale=current,setBeforeStale=setCalls;assert.equal(await workflow.applyPending(),false);assert.equal(current,beforeStale);assert.equal(setCalls,setBeforeStale);assert.deepEqual(workflow.state.pending,stalePending);assert.match(workflow.state.status.text,/Карта изменилась/);assert.equal(workflow.cancelPending(),true);

// Ambiguous/untrusted source values are represented only as safe paths and counts.
current=makeSession('safe-report',0);picker=JSON.stringify({version:20,decorFull:[{kind:'<img onerror=attack>',r:1,c:1}],mapEdits:[{r:2,c:2,value:9}],html:'<script>attack()</script>',unlock:true});assert.equal(await workflow.importProject(),true);assert.equal(workflow.state.pending.report.counts.ambiguous,1);assert.equal(workflow.state.pending.report.counts.unsupported,1);assert.deepEqual(workflow.state.pending.report.paths.unknown,[{path:'$.html',type:'string'},{path:'$.unlock',type:'boolean'}]);assert.equal(JSON.stringify(workflow.state.pending.report).includes('attack'),false);assert.equal(workflow.cancelPending(),true);
picker='{"version":20,"mapEdits":[],"__proto__":{"polluted":true}}';assert.equal(await workflow.importProject(),false);assert.equal(workflow.state.pending,null);assert.equal({}.polluted,undefined);

// Failed current preflight leaves a visible dry-run report, disables Apply and cannot mutate the session.
const rejectingBridge=createWalkMapEditorLegacyFilesBridge({getPreviewOptions:()=>({buildingRecords:buildingsPlan.instances,decorRecords:decorPlan.instances,trustedSourceBase:base,isProtectedCell:()=>false}),getImportOptions:()=>({...importOptions,preflight:()=>({allowed:false})}),downloadAudit:()=>{}});
current=makeSession('rollback',0);const rollbackBefore=current;const rejecting=createWalkMapEditorFilesWorkflow({getSession:()=>current,setSession:async next=>{current=next},pickImportText:async()=>JSON.stringify(realLegacy),prepareImport:async()=>{throw new Error('wrong route')},legacyImportBridge:rejectingBridge});
assert.equal(await rejecting.importProject(),true);assert.equal(rejecting.state.pending.kind,'legacy');assert.equal(rejecting.state.pending.canApply,false);assert.equal(rejecting.state.pending.report.validation.code,'PREFLIGHT');assert.equal(await rejecting.applyPending(),false);assert.equal(current,rollbackBefore);assert.match(rejecting.state.status.text,/Текущая карта не изменена/);assert.equal(rejecting.cancelPending(),true);rejecting.dispose();

// If the host replacement does not install the staged session exactly, workflow restores the prior session.
current=makeSession('host-rollback',0);const hostBefore=current;const hostRollback=createWalkMapEditorFilesWorkflow({getSession:()=>current,setSession:async(next,context)=>{current=context.kind==='rollback'?next:makeSession('wrong-host-result',99)},pickImportText:async()=>JSON.stringify(realLegacy),prepareImport:async()=>{throw new Error('wrong route')},legacyImportBridge:bridge});
assert.equal(await hostRollback.importProject(),true);assert.equal(await hostRollback.applyPending(),false);assert.equal(current,hostBefore);assert.match(hostRollback.state.status.text,/Текущая карта сохранена/);assert.equal(hostRollback.cancelPending(),true);hostRollback.dispose();

workflow.dispose();
const source=await readFile(new URL('walk_map_editor_files_dialog.mjs',import.meta.url),'utf8');
for(const proof of ["root.addEventListener('cancel'","aria-disabled","Результаты безопасной проверки","Скачать отчёт проверки","previewTitle.focus","textContent=`${label}: ${value}`"])assert.ok(source.includes(proof),`missing keyboard/accessibility proof: ${proof}`);
assert.doesNotMatch(source,/auditDetails\.innerHTML/);
console.log('walk map editor files legacy 7.2 workflow: PASS');
