import {
 assessWalkMapEditorPublishReady,
 createWalkMapEditorRecoveryEnvelope,
 createWalkMapEditorSession,
 isWalkMapEditorCompileReceipt,
 normalizeWalkMapEditorDocument,
 parseWalkMapEditorDocument,
 parseWalkMapEditorRecoveryEnvelope,
 serializeWalkMapEditorDocument
} from './walk_map_editor_document.mjs';
import {
 isWalkMapProtectionPolicy,
 requireWalkMapProtectionAuthorization
} from './walk_map_editor_protection.mjs';

export const WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY='mafiozi.walk-map-editor.recovery.v1';

export class WalkMapEditorStorageError extends Error{constructor(message){super(message);this.name='WalkMapEditorStorageError';}}

function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function stable(value){if(Array.isArray(value))return value.map(stable);if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value;}
function equal(a,b){return JSON.stringify(stable(a))===JSON.stringify(stable(b));}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(isObject(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value);}
function immutableCopy(value){try{return deepFreeze(structuredClone(value));}catch(error){throw new WalkMapEditorStorageError(`Storage value is not cloneable: ${error.message}`);}}
function assertStorage(storage){if(!storage||typeof storage.getItem!=='function'||typeof storage.setItem!=='function'||typeof storage.removeItem!=='function')throw new WalkMapEditorStorageError('A Web Storage compatible adapter is required');return storage;}
function assertSession(session){if(!isObject(session)||!isObject(session.document)||!Array.isArray(session.undoStack)||!Array.isArray(session.redoStack)||!Number.isSafeInteger(session.revision)||session.revision<0)throw new WalkMapEditorStorageError('A valid editor session is required');return session;}
function assertKey(key){if(typeof key!=='string'||!key.trim()||key.length>512)throw new WalkMapEditorStorageError('Recovery key must be a non-empty string');return key;}

function validateBaseResolutions(document,resolveBaseEntity){
 if(!document.objectPatches.length)return;
 if(typeof resolveBaseEntity!=='function')throw new WalkMapEditorStorageError('Trusted tri-state base resolver is required for object imports');
 for(const patch of document.objectPatches){
  const resolution=resolveBaseEntity(immutableCopy(patch.source));
  if(!isObject(resolution)||!['found','absent'].includes(resolution.status))throw new WalkMapEditorStorageError(`BASE_RESOLUTION_INVALID: ${patch.key}`);
  if(resolution.status==='absent'){
   if(Object.prototype.hasOwnProperty.call(resolution,'entity')&&resolution.entity!==null)throw new WalkMapEditorStorageError(`BASE_RESOLUTION_INVALID: ${patch.key}`);
   if(patch.action!=='add')throw new WalkMapEditorStorageError(`ENTITY_MISSING: ${patch.key}`);
  }else{
   if(!isObject(resolution.entity))throw new WalkMapEditorStorageError(`BASE_RESOLUTION_INVALID: ${patch.key}`);
   if(patch.action==='add')throw new WalkMapEditorStorageError(`ENTITY_EXISTS: ${patch.key}`);
   if(!equal(resolution.entity,patch.before))throw new WalkMapEditorStorageError(`STALE_BEFORE: ${patch.key}`);
  }
 }
}

function runPreflight(preflight,context,{registeredObjectDatasets,registeredSurfaceMaterials}){
 if(typeof preflight!=='function')throw new WalkMapEditorStorageError('Trusted import preflight is required');
 const result=preflight(immutableCopy(context));
 if(!isObject(result)||result.allowed!==true||typeof result.receiptId!=='string'||!result.receiptId.trim()||result.receiptId.length>512||!isWalkMapEditorCompileReceipt(result.compileReceipt))throw new WalkMapEditorStorageError('IMPORT_PREFLIGHT_REJECTED');
 const readiness=assessWalkMapEditorPublishReady(context.after,{registeredObjectDatasets,registeredSurfaceMaterials,compileReceipt:result.compileReceipt});
 if(!readiness.ready)throw new WalkMapEditorStorageError(`IMPORT_PREFLIGHT_REJECTED: ${readiness.errors.join('; ')}`);
 const metadata=immutableCopy({receiptId:result.receiptId,compilerId:result.compilerId??null,details:result.details??null});
 return Object.freeze({...metadata,compileReceipt:result.compileReceipt});
}

function replaceSessionAtomically(session,candidate,{expectedRevision=session.revision,updatedAt=new Date().toISOString(),transactionId=`import-${session.revision+1}`,resolveBaseEntity=null,protectionPolicy=null,authorizeProtected=null,protectedOverride=null,preflight=null,registeredObjectDatasets=[],registeredSurfaceMaterials=[]}={}){
 assertSession(session);
 if(expectedRevision!==session.revision)throw new WalkMapEditorStorageError(`Stale editor revision: expected ${expectedRevision}, current ${session.revision}`);
 if(typeof updatedAt!=='string'||!updatedAt||typeof transactionId!=='string'||!transactionId||transactionId.length>512||protectedOverride!==null&&!isObject(protectedOverride)||!Array.isArray(registeredObjectDatasets)||!Array.isArray(registeredSurfaceMaterials))throw new WalkMapEditorStorageError('Invalid import options');
 if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorStorageError('PROTECTION_POLICY_REQUIRED');
 let staged=normalizeWalkMapEditorDocument(candidate);
 validateBaseResolutions(staged,resolveBaseEntity);
 staged={...staged,revision:session.revision+1,updatedAt};
 staged=normalizeWalkMapEditorDocument(staged);
 const protectionReport=protectionPolicy.inspectFinalDelta({before:session.document,after:staged});
 const preflightReceipt=runPreflight(preflight,{before:session.document,after:staged,protectionReport},{registeredObjectDatasets,registeredSurfaceMaterials});
 const protectionAudit=requireWalkMapProtectionAuthorization(protectionPolicy,protectionReport,authorizeProtected,{...immutableCopy(protectedOverride??{}),transactionId,documentId:staged.documentId,operation:'commit',beforeRevision:session.revision,afterRevision:session.revision+1,reason:protectedOverride?.reason??'Импорт карты'});
 const nextSession=createWalkMapEditorSession(staged);
 return Object.freeze({session:nextSession,protectionAudit,preflightReceipt});
}

export function saveWalkMapEditorRecovery(session,{storage,key=WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY,savedAt=new Date().toISOString()}={}){
 assertSession(session);const target=assertStorage(storage),storageKey=assertKey(key),envelope=createWalkMapEditorRecoveryEnvelope(session.document,{savedAt}),text=JSON.stringify(envelope);
 target.setItem(storageKey,text);return Object.freeze({key:storageKey,savedAt:envelope.savedAt,checksum:envelope.checksum,bytes:new TextEncoder().encode(text).byteLength});
}

export function readWalkMapEditorRecovery({storage,key=WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY}={}){
 const text=assertStorage(storage).getItem(assertKey(key));
 if(text===null)return null;
 if(typeof text!=='string')throw new WalkMapEditorStorageError('Recovery storage returned a non-text value');
 let envelope;try{envelope=JSON.parse(text);}catch(error){throw new WalkMapEditorStorageError(`Recovery JSON is invalid: ${error.message}`);}
 return parseWalkMapEditorRecoveryEnvelope(envelope);
}

export function restoreWalkMapEditorRecovery(session,{storage,key=WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY,...options}={}){
 const document=readWalkMapEditorRecovery({storage,key});
 if(document===null)return null;
 return replaceSessionAtomically(session,document,options);
}

export function clearWalkMapEditorRecovery({storage,key=WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY}={}){assertStorage(storage).removeItem(assertKey(key));}

export function exportWalkMapEditorJson(session,{filename='mafiozi-walk-map.json',download,createBlob=globalThis.Blob?((parts,options)=>new Blob(parts,options)):null}={}){
 assertSession(session);
 if(typeof filename!=='string'||!filename.trim()||filename.length>255||/[\\/:*?"<>|\u0000-\u001f]/.test(filename))throw new WalkMapEditorStorageError('Export filename is invalid');
 if(typeof createBlob!=='function')throw new WalkMapEditorStorageError('A Blob factory is required');
 if(typeof download!=='function')throw new WalkMapEditorStorageError('A download callback is required');
 const text=serializeWalkMapEditorDocument(session.document),blob=createBlob([text],{type:'application/json;charset=utf-8'}),request=deepFreeze({filename,text,blob});
 download(request);return request;
}

export function importWalkMapEditorText(session,text,options={}){
 const candidate=parseWalkMapEditorDocument(text);
 return replaceSessionAtomically(session,candidate,options);
}

export function createWalkMapEditorStorage({storage,recoveryKey=WALK_MAP_EDITOR_DEFAULT_RECOVERY_KEY,download=null,createBlob=globalThis.Blob?((parts,options)=>new Blob(parts,options)):null}={}){
 let storageRef=assertStorage(storage),downloadRef=download,blobFactoryRef=createBlob,disposed=false;
 const active=()=>{if(disposed)throw new WalkMapEditorStorageError('Editor storage controller is disposed');};
 return Object.freeze({
  get disposed(){return disposed;},
  saveRecovery(session,options={}){active();return saveWalkMapEditorRecovery(session,{...options,storage:storageRef,key:options.key??recoveryKey});},
  readRecovery(options={}){active();return readWalkMapEditorRecovery({storage:storageRef,key:options.key??recoveryKey});},
  restoreRecovery(session,options={}){active();return restoreWalkMapEditorRecovery(session,{...options,storage:storageRef,key:options.key??recoveryKey});},
  clearRecovery(options={}){active();return clearWalkMapEditorRecovery({storage:storageRef,key:options.key??recoveryKey});},
  exportJson(session,options={}){active();return exportWalkMapEditorJson(session,{...options,download:options.download??downloadRef,createBlob:options.createBlob??blobFactoryRef});},
  importText(session,text,options={}){active();return importWalkMapEditorText(session,text,options);},
  dispose(){if(disposed)return;disposed=true;storageRef=null;downloadRef=null;blobFactoryRef=null;}
 });
}
