import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {createWalkMapEditorDocument,createWalkMapEditorSession} from './walk_map_editor_document.mjs';
import {createWalkMapEditorFilesWorkflow,walkMapEditorFilesErrorMessage} from './walk_map_editor_files_dialog.mjs';

const createdAt='2026-09-23T13:00:00.000Z',base={topology:{sha256:'a'.repeat(64)},buildings:{sha256:'b'.repeat(64)},decor:{sha256:'c'.repeat(64)}};
function sessionWith({revision=0,id='files-test',objects=0,surfaces=0}={}){const document=createWalkMapEditorDocument({documentId:id,createdAt,base});document.revision=revision;for(let i=0;i<objects;i++)document.objectPatches.push({source:{dataset:'custom',id:`o-${i}`},action:'add',before:null,after:{id:`o-${i}`},derivedDirty:true});for(let i=0;i<surfaces;i++)document.surfaceStrokes.push({id:`s-${i}`,materialId:'grass',mode:'paint',shape:{type:'cells',cells:[[i,0]]}});return createWalkMapEditorSession(document);}
let current=sessionWith(),setCalls=0,exportCalls=0,saveCalls=0,publishCalls=0,downloadBundleCalls=0,pickerValue=null,recoveryValue=null,importPrepared=sessionWith({revision:1,objects:2,surfaces:1});
let exportResolver=null,blockExport=false;
const workflow=createWalkMapEditorFilesWorkflow({
 getSession:()=>current,
 setSession:async next=>{setCalls++;current=next;},
 downloadProject:async()=>{exportCalls++;if(blockExport)await new Promise(resolve=>{exportResolver=resolve;});},
 pickImportText:async()=>pickerValue,
 prepareImport:async({session,text})=>{assert.equal(session,current);assert.equal(text,pickerValue);return {session:importPrepared,protectionAudit:{decision:'clear'}};},
 saveRecovery:async({session})=>{assert.equal(session,current);saveCalls++;},
 prepareRecovery:async()=>recoveryValue,
 preparePublish:async()=>({files:Array.from({length:5},(_,index)=>({filename:`f-${index}.json`}))}),
 downloadPublishBundle:async({bundle})=>{assert.equal(bundle.files.length,5);downloadBundleCalls++;},
 validatePublishBundle:bundle=>Array.isArray(bundle?.files)
});
const states=[];const unsubscribe=workflow.subscribe(state=>states.push(state));assert.match(workflow.state.status.text,/Выберите действие/);

blockExport=true;const firstExport=workflow.exportProject();await Promise.resolve();assert.equal(workflow.state.busy,true);assert.equal(await workflow.exportProject(),false);assert.equal(exportCalls,1);assert.match(workflow.state.status.text,/Дождитесь/);exportResolver();assert.equal(await firstExport,true);blockExport=false;assert.equal(workflow.state.busy,false);assert.match(workflow.state.status.text,/подготовлен/);

const beforeCancel=current;pickerValue=null;assert.equal(await workflow.importProject(),true);assert.equal(current,beforeCancel);assert.equal(setCalls,0);assert.equal(workflow.state.pending,null);assert.match(workflow.state.status.text,/Выбор файла отменён/);

pickerValue='{"schema":"mafiozi.walk-map-editor","valid":true}';assert.equal(await workflow.importProject(),true);assert.equal(current,beforeCancel);assert.equal(setCalls,0);assert.equal(workflow.state.pending.objectCount,2);assert.equal(workflow.state.pending.surfaceCount,1);assert.match(workflow.state.status.text,/нажмите «Применить»/);
assert.equal(await workflow.applyPending(),true);assert.equal(current,importPrepared);assert.equal(setCalls,1);assert.equal(workflow.state.pending,null);assert.match(workflow.state.status.text,/карта применена/);

const staleBase=current;importPrepared=sessionWith({revision:2,id:'stale-preview',objects:1});pickerValue='{"schema":"mafiozi.walk-map-editor","stale":true}';assert.equal(await workflow.importProject(),true);current=sessionWith({revision:staleBase.revision+1,id:'externally-changed'});const setBeforeStale=setCalls;assert.equal(await workflow.applyPending(),false);assert.equal(setCalls,setBeforeStale);assert.match(workflow.state.status.text,/Карта изменилась/);assert.equal(workflow.cancelPending(),true);assert.match(workflow.state.status.text,/Импорт отменён/);

assert.equal(await workflow.saveRecovery(),true);assert.equal(saveCalls,1);assert.match(workflow.state.status.text,/сохранена в этом браузере/);
recoveryValue=null;assert.equal(await workflow.inspectRecovery(),true);assert.match(workflow.state.status.text,/не найдена/);
const recoverySession=sessionWith({revision:current.revision+1,id:'recovered',objects:1});recoveryValue={session:recoverySession};assert.equal(await workflow.inspectRecovery(),true);assert.equal(workflow.state.pending.kind,'recovery');assert.equal(await workflow.applyPending(),true);assert.equal(current,recoverySession);

assert.equal(await workflow.publish(),true);assert.equal(downloadBundleCalls,1);assert.match(workflow.state.status.text,/manifest и четыре JSON-файла/);

let pickerResolver;pickerValue=undefined;const cancellable=createWalkMapEditorFilesWorkflow({getSession:()=>current,setSession:()=>{},pickImportText:()=>new Promise(resolve=>{pickerResolver=resolve;}),prepareImport:()=>{throw new Error('must not run')}});const pendingPicker=cancellable.importProject();await Promise.resolve();assert.equal(cancellable.cancelCurrent(),true);pickerResolver('{"late":true}');assert.equal(await pendingPicker,false);assert.equal(cancellable.state.pending,null);assert.match(cancellable.state.status.text,/отменено/);cancellable.dispose();

assert.equal(await workflow.exportProject(),true);assert.equal(exportCalls,2);unsubscribe();workflow.dispose();workflow.dispose();assert.equal(workflow.state.disposed,true);assert.throws(()=>workflow.cancelPending(),/закрыт/);

assert.match(walkMapEditorFilesErrorMessage(new Error('Recovery envelope checksum mismatch')),/повреждена/);assert.match(walkMapEditorFilesErrorMessage(new Error('PROTECTED_EDIT')),/защищённые/);assert.match(walkMapEditorFilesErrorMessage(new Error('COMPILE_SOURCE_MISMATCH')),/другой версии/);assert.match(walkMapEditorFilesErrorMessage(new Error('JSON invalid')),/JSON-файл/);
assert.ok(states.length>5);assert.ok(states.every(state=>Object.isFrozen(state)&&Object.isFrozen(state.status)));

const source=await readFile(new URL('walk_map_editor_files_dialog.mjs',import.meta.url),'utf8');
for(const phrase of ['Файлы карты','Скачать проект JSON','Импортировать JSON…','Сохранить копию восстановления','Проверить копию восстановления','Подготовить публикацию · 5 файлов','Применить проверенную карту','Отменить импорт','Исходные файлы игры не перезаписываются'])assert.ok(source.includes(phrase),`missing Russian UI phrase: ${phrase}`);
assert.match(source,/aria-live','polite'/);assert.match(source,/aria-labelledby','walk-map-editor-files-title'/);assert.match(source,/role','status'/);
console.log('walk map editor files dialog: PASS');
