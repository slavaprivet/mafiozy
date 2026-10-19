import {getWalkMapProtectionPolicyDigest,isWalkMapProtectionPolicy,requireWalkMapProtectionAuthorization} from './walk_map_editor_protection.mjs';

export const WALK_MAP_EDITOR_SCHEMA='mafiozi.walk-map-editor';
export const WALK_MAP_EDITOR_SCHEMA_VERSION=1;
export const WALK_MAP_EDITOR_RECOVERY_SCHEMA='mafiozi.walk-map-editor-recovery';
export const WALK_MAP_EDITOR_COMPILE_RECEIPT_SCHEMA='mafiozi.walk-map-editor-compile-receipt';

export const WALK_MAP_EDITOR_DATASETS=Object.freeze({
 TOPOLOGY:'topology',
 BUILDINGS:'buildings',
 DECOR:'decor',
 ROAD_DRESSING:'road-dressing',
 LANDSCAPE:'landscape',
 GRASS:'grass',
 RAILWAY:'railway',
 CUSTOM:'custom'
});

export const WALK_MAP_EDITOR_SURFACES=Object.freeze([
 'asphalt','paved-road','dirt-road','earth','grass','water','rail-bed','custom'
]);

const MAX_OBJECT_PATCHES=100000;
const MAX_SURFACE_STROKES=50000;
const MAX_CELLS_PER_STROKE=100000;
const MAX_TOTAL_SURFACE_POINTS=1000000;
const MAX_POLYGON_POINTS=10000;
const MAX_JSON_DEPTH=64;
const MAX_JSON_NODES=1500000;
const MAX_JSON_TEXT_BYTES=64*1024*1024;
const MAX_STRING_LENGTH=4*1024*1024;
const MAX_TRANSACTION_COMMANDS=10000;
const MAX_HISTORY=200;
const trustedCompileReceipts=new WeakMap();

export class WalkMapEditorDocumentError extends Error{
 constructor(message,issues=[]){super(message);this.name='WalkMapEditorDocumentError';this.issues=issues;}
}

function own(value,key){return Object.prototype.hasOwnProperty.call(value,key);}
function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function finite(value){return typeof value==='number'&&Number.isFinite(value);}
function assertJsonValue(value,label='value'){
 const seen=new WeakSet();let nodes=0;
 function visit(current,depth){
  if(++nodes>MAX_JSON_NODES)throw new WalkMapEditorDocumentError(`${label} is too complex`);
  if(depth>MAX_JSON_DEPTH)throw new WalkMapEditorDocumentError(`${label} is nested too deeply`);
  if(current===null||typeof current==='boolean')return;
  if(typeof current==='string'){if(current.length>MAX_STRING_LENGTH)throw new WalkMapEditorDocumentError(`${label} contains an oversized string`);return;}
  if(typeof current==='number'){if(!Number.isFinite(current))throw new WalkMapEditorDocumentError(`${label} contains a non-finite number`);return;}
  if(typeof current!=='object')throw new WalkMapEditorDocumentError(`${label} contains a non-JSON value`);
  if(seen.has(current))throw new WalkMapEditorDocumentError(`${label} contains a cycle`);seen.add(current);
  if(Array.isArray(current)){for(const item of current)visit(item,depth+1);seen.delete(current);return;}
  if(Object.getPrototypeOf(current)!==Object.prototype&&Object.getPrototypeOf(current)!==null)throw new WalkMapEditorDocumentError(`${label} contains a non-plain object`);
  for(const [key,item] of Object.entries(current)){
   if(['__proto__','prototype','constructor'].includes(key))throw new WalkMapEditorDocumentError(`${label} contains a dangerous key`);
   visit(item,depth+1);
  }
  seen.delete(current);
 }
 visit(value,0);return value;
}
function clone(value){if(value===undefined)return undefined;assertJsonValue(value);return structuredClone(value);}
function assertString(value,label){if(typeof value!=='string'||!value.trim())throw new WalkMapEditorDocumentError(`${label} must be a non-empty string`);const result=value.trim();if(result.length>512||/[\u0000-\u001f]/.test(result))throw new WalkMapEditorDocumentError(`${label} is invalid or too long`);return result;}

function normalizeSource(source){
 if(!isObject(source))throw new WalkMapEditorDocumentError('Object source must be an object');
 return {...clone(source),dataset:assertString(source.dataset,'source.dataset'),id:assertString(source.id,'source.id')};
}

export function walkMapEditorEntityKey(source){
 const normalized=normalizeSource(source);
 return `${encodeURIComponent(normalized.dataset)}:${encodeURIComponent(normalized.id)}`;
}

function normalizeTransform(transform={}){
 if(!isObject(transform))throw new WalkMapEditorDocumentError('transform must be an object');
 const result={...clone(transform)};
 if(own(transform,'positionM')){
  if(!Array.isArray(transform.positionM)||transform.positionM.length!==3||!transform.positionM.every(finite))throw new WalkMapEditorDocumentError('transform.positionM must contain three finite numbers');
  if(transform.positionM.some(value=>Math.abs(value)>100000))throw new WalkMapEditorDocumentError('transform.positionM exceeds the supported world bounds');
  result.positionM=[...transform.positionM];
 }
 if(own(transform,'yawDegrees')&&(!finite(transform.yawDegrees)||Math.abs(transform.yawDegrees)>1000000000))throw new WalkMapEditorDocumentError('transform.yawDegrees must be finite and bounded');
 if(own(transform,'uniformScale')&&(!finite(transform.uniformScale)||transform.uniformScale<=0||transform.uniformScale>1000))throw new WalkMapEditorDocumentError('transform.uniformScale must be between 0 and 1000');
 if(own(transform,'scaleM')){
  if(!Array.isArray(transform.scaleM)||transform.scaleM.length!==3||!transform.scaleM.every(value=>finite(value)&&value>0&&value<=1000))throw new WalkMapEditorDocumentError('transform.scaleM must contain three positive finite numbers no greater than 1000');
  result.scaleM=[...transform.scaleM];
 }
 return result;
}

function normalizeObjectSnapshot(snapshot,label){
 if(snapshot===null)return null;
 if(!isObject(snapshot))throw new WalkMapEditorDocumentError(`${label} must be an object or null`);
 const result=clone(snapshot);
 if(own(result,'transform'))result.transform=normalizeTransform(result.transform);
 return result;
}

function normalizeObjectPatch(patch){
 if(!isObject(patch))throw new WalkMapEditorDocumentError('Object patch must be an object');
 const source=normalizeSource(patch.source);
 const key=walkMapEditorEntityKey(source);
 if(own(patch,'key')&&patch.key!==key)throw new WalkMapEditorDocumentError(`Object patch key does not match source: ${patch.key}`);
 const action=assertString(patch.action,'patch.action');
 if(!['add','modify','delete'].includes(action))throw new WalkMapEditorDocumentError(`Unsupported object patch action: ${action}`);
 const before=normalizeObjectSnapshot(patch.before??null,'patch.before');
 const after=normalizeObjectSnapshot(patch.after??null,'patch.after');
 if(action==='add'&&(before!==null||after===null))throw new WalkMapEditorDocumentError('An add patch requires before=null and a complete after snapshot');
 if(action==='modify'&&(before===null||after===null))throw new WalkMapEditorDocumentError('A modify patch requires complete before and after snapshots');
 if(action==='delete'&&(before===null||after!==null))throw new WalkMapEditorDocumentError('A delete patch requires a complete before snapshot and after=null');
 return {...clone(patch),key,action,source,before,after,derivedDirty:patch.derivedDirty!==false};
}

function normalizeCell(cell){
 if(Array.isArray(cell)&&cell.length===2&&cell.every(Number.isInteger))return [cell[0],cell[1]];
 if(isObject(cell)&&Number.isInteger(cell.r)&&Number.isInteger(cell.c))return [cell.r,cell.c];
 throw new WalkMapEditorDocumentError('Surface cells must be [row,column] integer pairs');
}

function normalizeSurfaceStroke(stroke,map){
 if(!isObject(stroke))throw new WalkMapEditorDocumentError('Surface stroke must be an object');
 const id=assertString(stroke.id,'stroke.id');
 const materialId=assertString(stroke.materialId,'stroke.materialId');
 const mode=stroke.mode??'paint';
 if(!['paint','erase','restore'].includes(mode))throw new WalkMapEditorDocumentError(`Unsupported surface stroke mode: ${mode}`);
 if(!isObject(stroke.shape))throw new WalkMapEditorDocumentError('stroke.shape must be an object');
 const shape=clone(stroke.shape);
 if(shape.type==='cells'){
  if(!Array.isArray(shape.cells)||shape.cells.length===0||shape.cells.length>MAX_CELLS_PER_STROKE)throw new WalkMapEditorDocumentError(`A cell stroke must contain 1-${MAX_CELLS_PER_STROKE} cells`);
  shape.cells=shape.cells.map(normalizeCell);
  const seen=new Set();for(const [r,c] of shape.cells){if(r<0||c<0||r>=map.rows||c>=map.cols)throw new WalkMapEditorDocumentError(`Surface cell is outside the ${map.rows}x${map.cols} map`);const key=`${r}:${c}`;if(seen.has(key))throw new WalkMapEditorDocumentError(`Duplicate surface cell: ${key}`);seen.add(key);}
 }else if(shape.type==='rect'){
  if(!['minR','minC','maxR','maxC'].every(key=>finite(shape[key])))throw new WalkMapEditorDocumentError('A rect stroke requires finite minR/minC/maxR/maxC');
  if(shape.minR<0||shape.minC<0||shape.maxR>map.rows||shape.maxC>map.cols||shape.minR>=shape.maxR||shape.minC>=shape.maxC)throw new WalkMapEditorDocumentError('A rect stroke must be ordered and inside the map');
 }else if(shape.type==='polygon'){
  if(!Array.isArray(shape.points)||shape.points.length<3||shape.points.length>MAX_POLYGON_POINTS||!shape.points.every(point=>Array.isArray(point)&&point.length===2&&point.every(finite)))throw new WalkMapEditorDocumentError(`A polygon stroke requires 3-${MAX_POLYGON_POINTS} finite [row,column] points`);
  if(shape.points.some(([r,c])=>r<0||c<0||r>map.rows||c>map.cols))throw new WalkMapEditorDocumentError('A polygon stroke must stay inside the map');
  const unique=new Set(shape.points.map(([r,c])=>`${r}:${c}`));if(unique.size<3)throw new WalkMapEditorDocumentError('A polygon stroke requires three distinct points');
  let twiceArea=0;for(let i=0;i<shape.points.length;i++){const [r1,c1]=shape.points[i],[r2,c2]=shape.points[(i+1)%shape.points.length];twiceArea+=c1*r2-c2*r1;}if(Math.abs(twiceArea)<1e-8)throw new WalkMapEditorDocumentError('A polygon stroke must have non-zero area');
  shape.points=shape.points.map(point=>[...point]);
 }else throw new WalkMapEditorDocumentError(`Unsupported surface shape: ${shape.type}`);
 return {...clone(stroke),id,materialId,mode,shape};
}

function defaultBase(base={}){
 if(base===null||base===undefined)base={};
 if(!isObject(base))throw new WalkMapEditorDocumentError('base must be an object');
 return {
  topology:null,
  buildings:null,
  decor:null,
  extensions:{},
  ...clone(base),
  extensions:isObject(base.extensions)?clone(base.extensions):{}
 };
}

export function createWalkMapEditorDocument({map={},base={},metadata={},createdAt=new Date().toISOString(),documentId=globalThis.crypto?.randomUUID?.()??`walk-map-${Date.now().toString(36)}`}={}){
 if(!isObject(metadata))throw new WalkMapEditorDocumentError('metadata must be an object');
 const rows=Number.isInteger(map.rows)&&map.rows>0?map.rows:200;
 const cols=Number.isInteger(map.cols)&&map.cols>0?map.cols:180;
 const worldUnitsPerCell=finite(map.worldUnitsPerCell)&&map.worldUnitsPerCell>0?map.worldUnitsPerCell:4.1;
 return {
  schema:WALK_MAP_EDITOR_SCHEMA,
  schemaVersion:WALK_MAP_EDITOR_SCHEMA_VERSION,
  documentId:assertString(documentId,'documentId'),
  revision:0,
  createdAt,
  updatedAt:createdAt,
  map:{...clone(map),rows,cols,worldUnitsPerCell},
  base:defaultBase(base),
  objectPatches:[],
  surfaceStrokes:[],
  metadata:clone(metadata)
 };
}

export function normalizeWalkMapEditorDocument(value){
 assertJsonValue(value,'Editor document');
 if(!isObject(value))throw new WalkMapEditorDocumentError('Editor document must be an object');
 const result=clone(value);
 if(value.schema!==WALK_MAP_EDITOR_SCHEMA)throw new WalkMapEditorDocumentError(`Unsupported editor document schema: ${value.schema}`);
 if(value.schemaVersion!==WALK_MAP_EDITOR_SCHEMA_VERSION)throw new WalkMapEditorDocumentError(`Unsupported editor document version: ${value.schemaVersion}`);
 if(!isObject(value.map))throw new WalkMapEditorDocumentError('Editor document map descriptor is missing');
 const {rows,cols,worldUnitsPerCell}=value.map;
 if(!Number.isSafeInteger(rows)||rows<=0||rows>10000||!Number.isSafeInteger(cols)||cols<=0||cols>10000||rows*cols>1000000||!finite(worldUnitsPerCell)||worldUnitsPerCell<=0||worldUnitsPerCell>1000)throw new WalkMapEditorDocumentError('Invalid editor document map dimensions');
 if(!Array.isArray(value.objectPatches)||value.objectPatches.length>MAX_OBJECT_PATCHES)throw new WalkMapEditorDocumentError(`objectPatches must contain at most ${MAX_OBJECT_PATCHES} records`);
 if(!Array.isArray(value.surfaceStrokes)||value.surfaceStrokes.length>MAX_SURFACE_STROKES)throw new WalkMapEditorDocumentError(`surfaceStrokes must contain at most ${MAX_SURFACE_STROKES} records`);
 result.map={...clone(value.map),rows,cols,worldUnitsPerCell};
 result.base=defaultBase(value.base);
 result.objectPatches=value.objectPatches.map(normalizeObjectPatch);
 result.documentId=assertString(value.documentId,'documentId');
 result.revision=value.revision??0;if(!Number.isSafeInteger(result.revision)||result.revision<0)throw new WalkMapEditorDocumentError('revision must be a non-negative safe integer');
 result.surfaceStrokes=value.surfaceStrokes.map(stroke=>normalizeSurfaceStroke(stroke,result.map));
 if(!isObject(value.metadata))throw new WalkMapEditorDocumentError('metadata must be an object');result.metadata=clone(value.metadata);
 const patchKeys=new Set(),strokeIds=new Set();
 for(const patch of result.objectPatches){if(patchKeys.has(patch.key))throw new WalkMapEditorDocumentError(`Duplicate object patch: ${patch.key}`);patchKeys.add(patch.key);}
 for(const stroke of result.surfaceStrokes){if(strokeIds.has(stroke.id))throw new WalkMapEditorDocumentError(`Duplicate surface stroke: ${stroke.id}`);strokeIds.add(stroke.id);}
 const totalSurfacePoints=result.surfaceStrokes.reduce((sum,stroke)=>sum+(stroke.shape.cells?.length??stroke.shape.points?.length??Math.ceil((stroke.shape.maxR-stroke.shape.minR)*(stroke.shape.maxC-stroke.shape.minC))),0);
 if(totalSurfacePoints>MAX_TOTAL_SURFACE_POINTS)throw new WalkMapEditorDocumentError(`Surface edits exceed the ${MAX_TOTAL_SURFACE_POINTS} point limit`);
 return result;
}

export function validateWalkMapEditorDocument(value){
 try{return {ok:true,document:normalizeWalkMapEditorDocument(value),issues:[]};}
 catch(error){return {ok:false,document:null,issues:error instanceof WalkMapEditorDocumentError?(error.issues.length?error.issues:[error.message]):[String(error)]};}
}

export function serializeWalkMapEditorDocument(value,space=2){
 return JSON.stringify(normalizeWalkMapEditorDocument(value),null,space);
}

export function parseWalkMapEditorDocument(text){
 if(typeof text!=='string')throw new WalkMapEditorDocumentError('Editor document JSON must be text');
 if(new TextEncoder().encode(text).byteLength>MAX_JSON_TEXT_BYTES)throw new WalkMapEditorDocumentError(`Editor document exceeds ${MAX_JSON_TEXT_BYTES} bytes`);
 let value;
 try{value=JSON.parse(text);}catch(error){throw new WalkMapEditorDocumentError(`Editor document JSON is invalid: ${error.message}`);}
 return normalizeWalkMapEditorDocument(value);
}

function replaceByKey(items,key,next,keyOf){
 const index=items.findIndex(item=>keyOf(item)===key);
 if(next===null){if(index>=0)items.splice(index,1);return;}
 if(index>=0)items[index]=next;else items.push(next);
}

function jsonEqual(a,b){return JSON.stringify(stableValue(a))===JSON.stringify(stableValue(b));}
function mergePatch(previous,next,action,before,after){return normalizeObjectPatch({...clone(previous),...clone(next),metadata:{...(clone(previous?.metadata)||{}),...(clone(next?.metadata)||{})},action,before,after,derivedDirty:previous?.derivedDirty!==false||next?.derivedDirty!==false});}
function normalizeBaseResolution(resolution,key){
 if(!isObject(resolution)||!['found','absent'].includes(resolution.status))throw new WalkMapEditorDocumentError(`BASE_RESOLUTION_INVALID: ${key}`);
 if(resolution.status==='absent'){if(own(resolution,'entity')&&resolution.entity!==null)throw new WalkMapEditorDocumentError(`BASE_RESOLUTION_INVALID: ${key}`);return {status:'absent',entity:null};}
 if(!isObject(resolution.entity))throw new WalkMapEditorDocumentError(`BASE_RESOLUTION_INVALID: ${key}`);
 return {status:'found',entity:clone(resolution.entity)};
}

function composeObjectPatch(previous,next,baseResolution){
 if(!previous){
  const base=baseResolution?.entity??null;
  if(next.action==='add'){if(baseResolution?.status!=='absent')throw new WalkMapEditorDocumentError(`ENTITY_EXISTS: ${next.key}`);return next;}
  if(baseResolution?.status!=='found')throw new WalkMapEditorDocumentError(`ENTITY_MISSING: ${next.key}`);
  if(!jsonEqual(next.before,base))throw new WalkMapEditorDocumentError(`STALE_BEFORE: ${next.key}`);
  if(next.action==='modify'&&jsonEqual(next.before,next.after))return null;
  return next;
 }
 if(!next)return null;
 const effective=previous.action==='delete'?null:previous.after;
 if(next.action==='add'){
  if(effective!==null)throw new WalkMapEditorDocumentError(`ENTITY_EXISTS: ${next.key}`);
  if(previous.action!=='delete')return next;
  if(jsonEqual(previous.before,next.after))return null;
  return mergePatch(previous,next,'modify',previous.before,next.after);
 }
 if(effective===null)throw new WalkMapEditorDocumentError(`ENTITY_MISSING: ${next.key}`);
 if(!jsonEqual(next.before,effective))throw new WalkMapEditorDocumentError(`STALE_BEFORE: ${next.key}`);
 if(previous.action==='add'){
  if(next.action==='delete')return null;
  if(next.action==='modify')return mergePatch(previous,next,'add',null,next.after);
 }
 if(previous.action==='modify'){
  if(next.action==='modify')return jsonEqual(previous.before,next.after)?null:mergePatch(previous,next,'modify',previous.before,next.after);
  if(next.action==='delete')return mergePatch(previous,next,'delete',previous.before,null);
 }
 throw new WalkMapEditorDocumentError(`Object patch cannot follow ${previous.action} with ${next.action}`);
}

function canonicalCommand(command,document,{compose=true,resolveBaseEntity=null}={}){
 if(!isObject(command))throw new WalkMapEditorDocumentError('Editor command must be an object');
 if(command.type==='object.set-patch'){
  const patch=command.patch?normalizeObjectPatch(command.patch):null,key=patch?.key??assertString(command.key,'command.key');
  const previous=document.objectPatches.find(item=>item.key===key)??null;
  const baseResolution=compose&&!previous&&patch?normalizeBaseResolution(resolveBaseEntity(patch.source),key):null;
  return {type:command.type,key,patch:compose?composeObjectPatch(previous,patch,baseResolution):patch};
 }
 if(command.type==='surface.set-stroke'){
  const stroke=command.stroke?normalizeSurfaceStroke(command.stroke,document.map):null,id=stroke?.id??assertString(command.id,'command.id');
  return {type:command.type,id,stroke};
 }
 if(command.type==='document.set-metadata'){if(!isObject(command.metadata))throw new WalkMapEditorDocumentError('command.metadata must be an object');return {type:command.type,metadata:clone(command.metadata)};}
 throw new WalkMapEditorDocumentError(`Unsupported editor command: ${command.type}`);
}

function applyCanonical(document,command){
 const next=normalizeWalkMapEditorDocument(document);
 let inverse;
 if(command.type==='object.set-patch'){
  const previous=next.objectPatches.find(item=>item.key===command.key)??null;
  inverse={type:command.type,key:command.key,patch:clone(previous)};
  replaceByKey(next.objectPatches,command.key,clone(command.patch),item=>item.key);
 }else if(command.type==='surface.set-stroke'){
  const previous=next.surfaceStrokes.find(item=>item.id===command.id)??null;
  inverse={type:command.type,id:command.id,stroke:clone(previous)};
  replaceByKey(next.surfaceStrokes,command.id,clone(command.stroke),item=>item.id);
 }else{
  inverse={type:command.type,metadata:clone(next.metadata)};
  next.metadata=clone(command.metadata);
 }
 return {document:next,inverse};
}

export function createWalkMapEditorSession(document=createWalkMapEditorDocument()){
 const normalized=normalizeWalkMapEditorDocument(document);return {document:normalized,undoStack:[],redoStack:[],revision:normalized.revision};
}

export function executeWalkMapEditorTransaction(session,commands,{expectedRevision=session.revision,label='Изменение карты',updatedAt=new Date().toISOString(),resolveBaseEntity=null,protectionPolicy=null,authorizeProtected=null,protectedOverride=null,historyLimit=MAX_HISTORY,transactionId=`tx-${session.revision+1}`}={}){
 if(expectedRevision!==session.revision)throw new WalkMapEditorDocumentError(`Stale editor revision: expected ${expectedRevision}, current ${session.revision}`);
 if(!Array.isArray(commands)||commands.length===0||commands.length>MAX_TRANSACTION_COMMANDS)throw new WalkMapEditorDocumentError(`Editor transaction requires 1-${MAX_TRANSACTION_COMMANDS} commands`);
 let staged=normalizeWalkMapEditorDocument(session.document);const forward=[],inverse=[];
 for(const raw of commands){
  if(raw?.type==='object.set-patch'&&typeof resolveBaseEntity!=='function')throw new WalkMapEditorDocumentError('Trusted base resolver is required for object edits');
  const command=canonicalCommand(raw,staged,{compose:true,resolveBaseEntity}),result=applyCanonical(staged,command);
  staged=result.document;forward.push(command);inverse.unshift(result.inverse);
 }
 const unchanged=jsonEqual({objectPatches:staged.objectPatches,surfaceStrokes:staged.surfaceStrokes,metadata:staged.metadata},{objectPatches:session.document.objectPatches,surfaceStrokes:session.document.surfaceStrokes,metadata:session.document.metadata});
 if(unchanged)return session;
 const spatial=forward.some(command=>command.type==='object.set-patch'||command.type==='surface.set-stroke');let protectedAudit=null;
 if(spatial){if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorDocumentError('PROTECTION_POLICY_REQUIRED');const inspection=protectionPolicy.inspectFinalDelta({before:session.document,after:staged,commands:forward,resolveBaseEntity});protectedAudit=requireWalkMapProtectionAuthorization(protectionPolicy,inspection,authorizeProtected,{...clone(protectedOverride||{}),transactionId,documentId:staged.documentId,operation:'commit',beforeRevision:session.revision,afterRevision:session.revision+1});}
 staged.updatedAt=updatedAt;staged.revision=session.revision+1;
 staged=normalizeWalkMapEditorDocument(staged);
 const record={id:transactionId,label,forward,inverse,beforeUpdatedAt:session.document.updatedAt,beforeDocumentRevision:session.document.revision,afterUpdatedAt:staged.updatedAt,afterDocumentRevision:staged.revision,protectionExecutions:protectedAudit?[protectedAudit]:[]};
 return {document:staged,undoStack:[...session.undoStack,record].slice(-Math.max(1,historyLimit)),redoStack:[],revision:staged.revision};
}

export function executeWalkMapEditorCommand(session,command,options={}){
 return executeWalkMapEditorTransaction(session,[command],options);
}

export function undoWalkMapEditorCommand(session,{expectedRevision=session.revision,updatedAt=new Date().toISOString(),protectionPolicy=null,authorizeProtected=null,protectedOverride=null,transactionId=`undo-${session.revision+1}`}={}){
 if(expectedRevision!==session.revision)throw new WalkMapEditorDocumentError(`Stale editor revision: expected ${expectedRevision}, current ${session.revision}`);
 if(!session.undoStack.length)return session;
 const undoStack=[...session.undoStack],record=undoStack.pop();let document=session.document;
 for(const command of record.inverse)document=applyCanonical(document,canonicalCommand(command,document,{compose:false})).document;
 const spatial=record.inverse.some(command=>command.type==='object.set-patch'||command.type==='surface.set-stroke');let protectionAudit=null;
 if(spatial){if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorDocumentError('PROTECTION_POLICY_REQUIRED');const inspection=protectionPolicy.inspectFinalDelta({before:session.document,after:document,commands:record.inverse});protectionAudit=requireWalkMapProtectionAuthorization(protectionPolicy,inspection,authorizeProtected,{...clone(protectedOverride||{}),transactionId,documentId:document.documentId,operation:'undo',beforeRevision:session.revision,afterRevision:session.revision+1});}
 document.updatedAt=updatedAt;document.revision=session.revision+1;
 const audited={...record,protectionExecutions:[...(record.protectionExecutions||[]),...(protectionAudit?[protectionAudit]:[])]};
 return {document:normalizeWalkMapEditorDocument(document),undoStack,redoStack:[...session.redoStack,audited].slice(-MAX_HISTORY),revision:document.revision};
}

export function redoWalkMapEditorCommand(session,{expectedRevision=session.revision,updatedAt=new Date().toISOString(),protectionPolicy=null,authorizeProtected=null,protectedOverride=null,transactionId=`redo-${session.revision+1}`}={}){
 if(expectedRevision!==session.revision)throw new WalkMapEditorDocumentError(`Stale editor revision: expected ${expectedRevision}, current ${session.revision}`);
 if(!session.redoStack.length)return session;
 const redoStack=[...session.redoStack],record=redoStack.pop();let document=session.document;
 for(const command of record.forward)document=applyCanonical(document,canonicalCommand(command,document,{compose:false})).document;
 const spatial=record.forward.some(command=>command.type==='object.set-patch'||command.type==='surface.set-stroke');let protectionAudit=null;
 if(spatial){if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorDocumentError('PROTECTION_POLICY_REQUIRED');const inspection=protectionPolicy.inspectFinalDelta({before:session.document,after:document,commands:record.forward});protectionAudit=requireWalkMapProtectionAuthorization(protectionPolicy,inspection,authorizeProtected,{...clone(protectedOverride||{}),transactionId,documentId:document.documentId,operation:'redo',beforeRevision:session.revision,afterRevision:session.revision+1});}
 document.updatedAt=updatedAt;document.revision=session.revision+1;
 const audited={...record,protectionExecutions:[...(record.protectionExecutions||[]),...(protectionAudit?[protectionAudit]:[])]};
 return {document:normalizeWalkMapEditorDocument(document),undoStack:[...session.undoStack,audited].slice(-MAX_HISTORY),redoStack,revision:document.revision};
}

export function makeWalkMapObjectAddCommand({source,object,metadata={}}){
 const normalizedSource=normalizeSource(source);
 return {type:'object.set-patch',patch:{source:normalizedSource,action:'add',before:null,after:clone(object),metadata,derivedDirty:true}};
}

export function makeWalkMapObjectTransformCommand({source,before,after,metadata={}}){
 const normalizedSource=normalizeSource(source);
 return {type:'object.set-patch',patch:{source:normalizedSource,action:'modify',before:clone(before),after:clone(after),metadata,derivedDirty:true}};
}

export function makeWalkMapObjectDeleteCommand({source,before,metadata={}}){
 const normalizedSource=normalizeSource(source);
 return {type:'object.set-patch',patch:{source:normalizedSource,action:'delete',before:clone(before),after:null,metadata,derivedDirty:true}};
}

export function makeWalkMapSurfacePaintCommand(stroke){return {type:'surface.set-stroke',stroke};}

function stableValue(value){
 if(Array.isArray(value))return value.map(stableValue);
 if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stableValue(value[key])]));
 return value;
}

function sha256Text(text){
 const bytes=new TextEncoder().encode(text),bitLength=bytes.length*8,paddedLength=Math.ceil((bytes.length+9)/64)*64,data=new Uint8Array(paddedLength);data.set(bytes);data[bytes.length]=0x80;
 const view=new DataView(data.buffer);view.setUint32(paddedLength-8,Math.floor(bitLength/0x100000000));view.setUint32(paddedLength-4,bitLength>>>0);
 const k=new Uint32Array([0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]);
 const h=new Uint32Array([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]),w=new Uint32Array(64),rotr=(value,bits)=>(value>>>bits)|(value<<(32-bits));
 for(let offset=0;offset<paddedLength;offset+=64){
  for(let i=0;i<16;i++)w[i]=view.getUint32(offset+i*4);
  for(let i=16;i<64;i++){const s0=rotr(w[i-15],7)^rotr(w[i-15],18)^(w[i-15]>>>3),s1=rotr(w[i-2],17)^rotr(w[i-2],19)^(w[i-2]>>>10);w[i]=(w[i-16]+s0+w[i-7]+s1)>>>0;}
  let [a,b,c,d,e,f,g,z]=h;
  for(let i=0;i<64;i++){const s1=rotr(e,6)^rotr(e,11)^rotr(e,25),choice=(e&f)^(~e&g),t1=(z+s1+choice+k[i]+w[i])>>>0,s0=rotr(a,2)^rotr(a,13)^rotr(a,22),majority=(a&b)^(a&c)^(b&c),t2=(s0+majority)>>>0;z=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}
  h[0]=(h[0]+a)>>>0;h[1]=(h[1]+b)>>>0;h[2]=(h[2]+c)>>>0;h[3]=(h[3]+d)>>>0;h[4]=(h[4]+e)>>>0;h[5]=(h[5]+f)>>>0;h[6]=(h[6]+g)>>>0;h[7]=(h[7]+z)>>>0;
 }
 return [...h].map(value=>value.toString(16).padStart(8,'0')).join('');
}

function deepFreezeJson(value){if(Array.isArray(value))for(const item of value)deepFreezeJson(item);else if(isObject(value))for(const item of Object.values(value))deepFreezeJson(item);return Object.freeze(value);}

export function walkMapEditorCanonicalDigest(document){return sha256Text(JSON.stringify(stableValue(normalizeWalkMapEditorDocument(document))));}

export function createWalkMapEditorCompileReceipt(document,{protectionPolicy,sourceDigests={},compilerId,compiledAt=new Date().toISOString(),outputDigests={}}={}){
 const normalized=normalizeWalkMapEditorDocument(document);
 if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorDocumentError('PROTECTION_POLICY_REQUIRED');
 protectionPolicy.assertCompatible(normalized);
 const trustedSources={};for(const name of ['topology','buildings','decor']){const digest=sourceDigests[name];if(typeof digest!=='string'||!/^[a-f0-9]{64}$/i.test(digest))throw new WalkMapEditorDocumentError(`Invalid compile source SHA-256: ${name}`);trustedSources[name]=digest.toLowerCase();if(normalized.base[name]?.sha256?.toLowerCase()!==trustedSources[name])throw new WalkMapEditorDocumentError(`COMPILE_SOURCE_MISMATCH: ${name}`);}
 if(!isObject(outputDigests)||!Object.keys(outputDigests).length)throw new WalkMapEditorDocumentError('Compile receipt requires output SHA-256 digests');
 const trustedOutputs={};for(const [name,digest] of Object.entries(outputDigests)){const key=assertString(name,'output digest name');if(typeof digest!=='string'||!/^[a-f0-9]{64}$/i.test(digest))throw new WalkMapEditorDocumentError(`Invalid compile output SHA-256: ${key}`);trustedOutputs[key]=digest.toLowerCase();}
 const receipt=deepFreezeJson({schema:WALK_MAP_EDITOR_COMPILE_RECEIPT_SCHEMA,schemaVersion:1,documentId:normalized.documentId,revision:normalized.revision,documentDigest:walkMapEditorCanonicalDigest(normalized),sourceDigests:trustedSources,policyDigest:sha256Text(getWalkMapProtectionPolicyDigest(protectionPolicy)),compilerId:assertString(compilerId,'compilerId'),compiledAt:assertString(compiledAt,'compiledAt'),outputDigests:trustedOutputs});
 trustedCompileReceipts.set(receipt,receipt);return receipt;
}

export function isWalkMapEditorCompileReceipt(value){return trustedCompileReceipts.has(value);}

function checksum(text){
 let hash=0x811c9dc5;
 for(let i=0;i<text.length;i++){hash^=text.charCodeAt(i);hash=Math.imul(hash,0x01000193);}
 return (hash>>>0).toString(16).padStart(8,'0');
}

export function createWalkMapEditorRecoveryEnvelope(document,{savedAt=new Date().toISOString()}={}){
 const normalized=normalizeWalkMapEditorDocument(document);
 const payload=JSON.stringify(stableValue(normalized));
 return {schema:WALK_MAP_EDITOR_RECOVERY_SCHEMA,schemaVersion:1,savedAt,checksum:checksum(payload),document:normalized};
}

export function parseWalkMapEditorRecoveryEnvelope(value){
 if(!isObject(value)||value.schema!==WALK_MAP_EDITOR_RECOVERY_SCHEMA||value.schemaVersion!==1)throw new WalkMapEditorDocumentError('Unsupported recovery envelope');
 const normalized=normalizeWalkMapEditorDocument(value.document);
 const actual=checksum(JSON.stringify(stableValue(normalized)));
 if(value.checksum!==actual)throw new WalkMapEditorDocumentError('Recovery envelope checksum mismatch');
 return normalized;
}

export function assessWalkMapEditorPublishReady(document,{requireBaseRevisions=true,registeredObjectDatasets=[],registeredSurfaceMaterials=[],compileReceipt=null}={}){
 const validation=validateWalkMapEditorDocument(document);
 if(!validation.ok)return {ready:false,errors:validation.issues,warnings:[]};
 const normalized=validation.document,errors=[],warnings=[];
 if(requireBaseRevisions){
  for(const name of ['topology','buildings','decor']){const source=normalized.base[name];if(!isObject(source)||(!assertOptionalRevision(source)))errors.push(`Missing structured base revision: ${name}`);}
 }
 for(const patch of normalized.objectPatches){
  if(patch.derivedDirty)warnings.push(`Derived placement data must be rebuilt for ${patch.key}`);
  if(!patch.source.dataset||!patch.source.id)errors.push(`Incomplete source identity: ${patch.key}`);
  if(!registeredObjectDatasets.includes(patch.source.dataset))errors.push(`Publisher adapter required for object dataset: ${patch.source.dataset}`);
 }
 const known=new Set(WALK_MAP_EDITOR_SURFACES);
 for(const stroke of normalized.surfaceStrokes)if(!known.has(stroke.materialId)||!registeredSurfaceMaterials.includes(stroke.materialId))errors.push(`Publisher adapter required for surface material: ${stroke.materialId}`);
 if(normalized.objectPatches.length||normalized.surfaceStrokes.length){
  const receipt=trustedCompileReceipts.get(compileReceipt);
  if(!receipt)errors.push('Trusted compile receipt is required');
  else{
   if(receipt.documentId!==normalized.documentId||receipt.revision!==normalized.revision||receipt.documentDigest!==walkMapEditorCanonicalDigest(normalized))errors.push('Compile receipt does not match this document revision');
   for(const name of ['topology','buildings','decor'])if(receipt.sourceDigests[name]!==normalized.base[name]?.sha256?.toLowerCase())errors.push(`Compile receipt source mismatch: ${name}`);
  }
 }
 return {ready:errors.length===0,errors,warnings};
}

function assertOptionalRevision(source){return typeof source.sha256==='string'&&source.sha256.length>=8||typeof source.revision==='string'&&source.revision.length>0;}
