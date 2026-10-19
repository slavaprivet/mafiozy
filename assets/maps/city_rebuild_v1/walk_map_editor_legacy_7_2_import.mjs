import {
 normalizeWalkMapEditorDocument,
 serializeWalkMapEditorDocument,
 walkMapEditorEntityKey
} from './walk_map_editor_document.mjs';
import {importWalkMapEditorText} from './walk_map_editor_storage.mjs';

export const WALK_MAP_LEGACY_7_2_SOURCES=Object.freeze(['/__studio_map','./map_overrides.json']);
export const WALK_MAP_LEGACY_7_2_FORMAT='mafiozi.legacy-map-editor-7.2/v20';

const MAX_INPUT_BYTES=16*1024*1024;
const MAX_NODES=500000;
const MAX_DEPTH=48;
const TOP_LEVEL=new Set(['version','districtStyleVersion','decorFull','decor','mapEdits','buildingMoves','deletedBuildings']);
const UNSAFE_FLAG=/^(?:unlock(?:ed)?|force|allowProtected|protectedOverride|bypassProtection|trusted)$/i;
const trustedPreviews=new WeakSet();

export class WalkMapLegacy72ImportError extends Error{
 constructor(code,message,details={}){super(message);this.name='WalkMapLegacy72ImportError';this.code=code;this.details=structuredClone(details)}
}

function fail(code,message,details){throw new WalkMapLegacy72ImportError(code,message,details)}
function plain(value){return value!==null&&typeof value==='object'&&!Array.isArray(value)}
function finite(value){return typeof value==='number'&&Number.isFinite(value)}
function stable(value){if(Array.isArray(value))return value.map(stable);if(plain(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value}
function signature(value){return JSON.stringify(stable(value))}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(plain(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value)}
function cellKey(r,c){return `${r}:${c}`}
function entityKey(dataset,id){return walkMapEditorEntityKey({dataset,id:String(id)})}
function sourceFor(dataset,id){return {dataset,id:String(id)}}
function shortPath(path){return path.length>240?`${path.slice(0,237)}...`:path}
function fnv(text){let hash=0x811c9dc5;for(let i=0;i<text.length;i++){hash^=text.charCodeAt(i);hash=Math.imul(hash,0x01000193)}return (hash>>>0).toString(16).padStart(8,'0')}

function assertJsonTree(value){
 let nodes=0;
 function visit(item,path,depth){
  if(++nodes>MAX_NODES)fail('LEGACY_PAYLOAD_TOO_COMPLEX','Старое сохранение слишком большое');
  if(depth>MAX_DEPTH)fail('LEGACY_PAYLOAD_TOO_DEEP','Старое сохранение имеет недопустимую вложенность');
  if(item===null||typeof item==='string'||typeof item==='boolean')return;
  if(typeof item==='number'){if(!Number.isFinite(item))fail('LEGACY_NON_JSON_VALUE',`Недопустимое число в ${path}`);return}
  if(typeof item!=='object')fail('LEGACY_NON_JSON_VALUE',`Недопустимое значение в ${path}`);
  if(Array.isArray(item)){for(let i=0;i<item.length;i++)visit(item[i],`${path}[${i}]`,depth+1);return}
  if(Object.getPrototypeOf(item)!==Object.prototype&&Object.getPrototypeOf(item)!==null)fail('LEGACY_NON_PLAIN_OBJECT',`Недоверенный объект в ${path}`);
  for(const [key,next] of Object.entries(item)){
   if(key==='__proto__'||key==='prototype'||key==='constructor')fail('LEGACY_DANGEROUS_KEY',`Опасный ключ в ${path}`);
   visit(next,`${path}.${key}`,depth+1);
  }
 }
 visit(value,'$',0);return value;
}

function parsePayload(text,sourceKey){
 if(typeof text!=='string')fail('LEGACY_TEXT_REQUIRED','Старое сохранение принимается только как JSON-текст');
 if(new TextEncoder().encode(text).byteLength>MAX_INPUT_BYTES)fail('LEGACY_PAYLOAD_TOO_LARGE','Старое сохранение превышает безопасный размер');
 let value;try{value=JSON.parse(text)}catch(error){fail('LEGACY_JSON_INVALID',`Некорректный JSON старого редактора: ${error.message}`)}
 assertJsonTree(value);
 let actualSource=sourceKey??'./map_overrides.json';
 if(plain(value)&&('key' in value||'storageKey' in value||'sourceKey' in value)&&('value' in value||'payload' in value)){
  actualSource=String(value.storageKey??value.sourceKey??value.key);
  if(!WALK_MAP_LEGACY_7_2_SOURCES.includes(actualSource))fail('LEGACY_SOURCE_UNSUPPORTED',`Неизвестный ключ старого редактора: ${actualSource}`);
  const nested=value.payload??value.value;
  if(typeof nested==='string')return parsePayload(nested,actualSource);
  value=assertJsonTree(nested);
 }
 if(!WALK_MAP_LEGACY_7_2_SOURCES.includes(actualSource))fail('LEGACY_SOURCE_UNSUPPORTED',`Неизвестный источник старого редактора: ${actualSource}`);
 if(!plain(value))fail('LEGACY_SCHEMA_INVALID','Корень старого сохранения должен быть объектом');
 return {payload:value,sourceKey:actualSource};
}

function collectAuditOnlyPaths(payload,audit){
 for(const key of Object.keys(payload))if(!TOP_LEVEL.has(key))audit.unknown.push({path:shortPath(`$.${key}`),type:Array.isArray(payload[key])?'array':payload[key]===null?'null':typeof payload[key]});
 function scan(value,path,depth=0){
  if(depth>12||!value||typeof value!=='object')return;
  if(Array.isArray(value)){for(let i=0;i<Math.min(value.length,10000);i++)scan(value[i],`${path}[${i}]`,depth+1);return}
  for(const [key,next] of Object.entries(value)){const nextPath=`${path}.${key}`;if(UNSAFE_FLAG.test(key))audit.ignoredUnsafeFlags.push({path:shortPath(nextPath),reason:'Старые флаги разблокировки не являются авторизацией'});scan(next,nextPath,depth+1)}
 }
 scan(payload,'$');
}

function sameTrustedBase(documentBase,trustedSourceBase){
 if(!plain(trustedSourceBase))return false;
 const pick=value=>({topology:value?.topology??null,buildings:value?.buildings??null,decor:value?.decor??null});
 return signature(pick(documentBase))===signature(pick(trustedSourceBase));
}
function cellsEqualTranslation(from,to){
 if(!Array.isArray(from)||!Array.isArray(to)||!from.length||from.length!==to.length)return null;
 const a=from.map(q=>[q?.r,q?.c]),b=to.map(q=>[q?.r,q?.c]);if([...a,...b].some(q=>!q.every(Number.isInteger)))return null;
 const sorted=list=>list.slice().sort((x,y)=>x[0]-y[0]||x[1]-y[1]);const sa=sorted(a),sb=sorted(b),dr=sb[0][0]-sa[0][0],dc=sb[0][1]-sa[0][1];
 return sa.every((q,i)=>sb[i][0]-q[0]===dr&&sb[i][1]-q[1]===dc)?{dr,dc}:null;
}
function legacyRotationDegrees(item,current){
 const radians=finite(item?._studioRot)?item._studioRot:finite(item?.ang)?item.ang:finite(item?.angle)?item.angle:null;
 return radians===null?(current.transform?.yawDegrees??0):radians*180/Math.PI;
}
function addProposal(proposals,key,proposal,origin,audit){
 const previous=proposals.get(key);if(!previous){proposals.set(key,{proposal,origin,conflict:false});return}
 if(signature(previous.proposal)===signature(proposal)){audit.duplicates.push({target:key,sourcePaths:[previous.origin,origin],reason:'Повтор с тем же результатом объединён'});return}
 proposals.set(key,{proposal:null,origin:previous.origin,conflict:true});audit.ambiguous.push({target:key,sourcePaths:[previous.origin,origin],reason:'Конфликтующие записи одного объекта отброшены'});
}

export function previewWalkMapLegacy72Import({
 text,sourceKey='./map_overrides.json',document,topology=null,buildingRecords=[],decorRecords=[],trustedSourceBase=null,
 isProtectedCell=null,protectedEntityIds=[]
}={}){
 const current=normalizeWalkMapEditorDocument(document),parsed=parsePayload(text,sourceKey),payload=parsed.payload;
 const audit={schema:'mafiozi.walk-map-editor.legacy-7.2-audit/v1',format:WALK_MAP_LEGACY_7_2_FORMAT,sourceKey:parsed.sourceKey,version:payload.version??null,converted:[],dropped:[],ambiguous:[],protected:[],unsupported:[],duplicates:[],unknown:[],ignoredUnsafeFlags:[],blocking:[]};
 collectAuditOnlyPaths(payload,audit);
 if(payload.version!==undefined&&payload.version!==20)audit.blocking.push({code:'LEGACY_VERSION_UNSUPPORTED',reason:`Версия ${String(payload.version)} не подтверждена редактором 7.2`});
 if(!sameTrustedBase(current.base,trustedSourceBase))audit.blocking.push({code:'LEGACY_BASE_STALE_OR_UNVERIFIED',reason:'Не подтверждено совпадение исходных topology/buildings/decor'});
 const protectedIds=new Set([...protectedEntityIds].map(String)),buildings=new Map(buildingRecords.map(record=>[String(record.id),record])),decor=new Map(decorRecords.map(record=>[String(record.id),record]));
 const existingPatchKeys=new Set(current.objectPatches.map(patch=>patch.key)),proposals=new Map(),surface=new Map();
 const rows=current.map.rows,cols=current.map.cols,m=current.map.worldUnitsPerCell;
 const protectedCell=typeof isProtectedCell==='function'?isProtectedCell:null;
 if(!protectedCell&&Array.isArray(payload.mapEdits)&&payload.mapEdits.some(item=>item?.value===0||item?.value===8))audit.blocking.push({code:'LEGACY_PROTECTION_UNVERIFIED',reason:'Для переноса покрытий не передана доверенная проверка защищённых клеток'});

 for(let i=0;i<(Array.isArray(payload.mapEdits)?payload.mapEdits.length:0);i++){
  const item=payload.mapEdits[i],path=`$.mapEdits[${i}]`;if(!plain(item)||!Number.isInteger(item.r)||!Number.isInteger(item.c)||item.r<0||item.c<0||item.r>=rows||item.c>=cols){audit.dropped.push({path,reason:'Некорректная или выходящая за карту клетка'});continue}
  if(item.value!==0&&item.value!==8){const names={9:'tile 9 — тротуар/плитка, не земля',14:'tile 14 — песок, не земля',16:'tile 16 — вода',1:'tile 1 — старый безымянный дом'};audit.unsupported.push({path,cell:[item.r,item.c],tile:item.value,reason:names[item.value]??`Код tile ${String(item.value)} не доказан для нового редактора`});continue}
  const key=cellKey(item.r,item.c),previous=surface.get(key),next={r:item.r,c:item.c,value:item.value,path};
  if(previous&&previous.value!==item.value){surface.set(key,{conflict:true});audit.ambiguous.push({target:`topology:${key}`,sourcePaths:[previous.path,path],reason:'Конфликтующие значения клетки отброшены'});continue}
  if(previous){audit.duplicates.push({target:`topology:${key}`,sourcePaths:[previous.path,path],reason:'Повтор клетки объединён'});continue}
  if(protectedCell?.(item.r,item.c)===true)audit.protected.push({target:`topology:${key}`,path,reason:'Клетка защищена актуальной политикой карты'});
  surface.set(key,next);
 }

 function decorProposal(item,path){
  if(!plain(item)||typeof item.id!=='string'||!item.id){audit.ambiguous.push({target:null,sourcePaths:[path],reason:'У старого декора нет стабильного ID нового плана'});return}
  const base=decor.get(item.id);if(!base){audit.dropped.push({path,id:item.id,reason:'ID отсутствует в актуальном decor_placement'});return}
  if(item.added===true){audit.dropped.push({path,id:item.id,reason:'Старое добавление не имеет доказанной 3D binding-модели'});return}
  if(typeof item.kind==='string'&&item.kind!==base.assetId){audit.ambiguous.push({target:entityKey('decor',item.id),sourcePaths:[path],reason:'kind старого объекта не совпадает с актуальным assetId'});return}
  if(!finite(item.r)||!finite(item.c)){audit.dropped.push({path,id:item.id,reason:'У декора нет конечных r/c'});return}
  const after=structuredClone(base);after.r=item.r;after.c=item.c;after.transform={...structuredClone(base.transform||{}),positionM:[item.c*m,base.transform?.positionM?.[1]??0,item.r*m],yawDegrees:legacyRotationDegrees(item,base)};
  const key=entityKey('decor',item.id);if(existingPatchKeys.has(key)){audit.ambiguous.push({target:key,sourcePaths:[path],reason:'Объект уже изменён в текущем документе'});return}
  addProposal(proposals,key,{source:sourceFor('decor',item.id),action:'modify',before:structuredClone(base),after,derivedDirty:true,metadata:{adapter:'legacy-7.2-compat-v1'}},path,audit);
 }
 for(let i=0;i<(Array.isArray(payload.decorFull)?payload.decorFull.length:0);i++)decorProposal(payload.decorFull[i],`$.decorFull[${i}]`);
 for(let i=0;i<(Array.isArray(payload.decor)?payload.decor.length:0);i++){
  const item=payload.decor[i],path=`$.decor[${i}]`;if(item?.added===true){audit.dropped.push({path,id:item?.data?.id??null,reason:'Старое добавление не имеет доказанной 3D binding-модели'});continue}decorProposal(item?.data??item,path);
 }

 for(let i=0;i<(Array.isArray(payload.buildingMoves)?payload.buildingMoves.length:0);i++){
  const item=payload.buildingMoves[i],path=`$.buildingMoves[${i}]`;if(!plain(item)||typeof item.id!=='string'||!item.id){audit.ambiguous.push({target:null,sourcePaths:[path],reason:'Формат 7.2 хранит клетки дома без стабильного ID'});continue}
  const base=buildings.get(item.id),translation=cellsEqualTranslation(item.from,item.to);if(!base){audit.dropped.push({path,id:item.id,reason:'ID отсутствует в актуальном buildings_placement'});continue}if(!translation){audit.ambiguous.push({target:entityKey('buildings',item.id),sourcePaths:[path],reason:'from/to не доказывают простой перенос здания'});continue}
  const anchor=[Math.floor((base.transform?.positionM?.[2]??0)/m),Math.floor((base.transform?.positionM?.[0]??0)/m)];if(!item.from.some(q=>q?.r===anchor[0]&&q?.c===anchor[1])){audit.ambiguous.push({target:entityKey('buildings',item.id),sourcePaths:[path],reason:'from не содержит актуальный якорь здания'});continue}
  const after=structuredClone(base),position=[...(base.transform?.positionM||[0,0,0])];position[0]+=translation.dc*m;position[2]+=translation.dr*m;after.transform={...structuredClone(base.transform||{}),positionM:position};
  const key=entityKey('buildings',item.id);if(existingPatchKeys.has(key)){audit.ambiguous.push({target:key,sourcePaths:[path],reason:'Объект уже изменён в текущем документе'});continue}
  addProposal(proposals,key,{source:sourceFor('buildings',item.id),action:'modify',before:structuredClone(base),after,derivedDirty:true,metadata:{adapter:'legacy-7.2-compat-v1'}},path,audit);
 }
 for(let i=0;i<(Array.isArray(payload.deletedBuildings)?payload.deletedBuildings.length:0);i++){
  const item=payload.deletedBuildings[i],path=`$.deletedBuildings[${i}]`;if(!plain(item)||typeof item.id!=='string'||!item.id){audit.ambiguous.push({target:null,sourcePaths:[path],reason:'Удалённый дом не имеет стабильного ID'});continue}
  const base=buildings.get(item.id);if(!base){audit.dropped.push({path,id:item.id,reason:'ID отсутствует в актуальном buildings_placement'});continue}
  const key=entityKey('buildings',item.id);if(existingPatchKeys.has(key)){audit.ambiguous.push({target:key,sourcePaths:[path],reason:'Объект уже изменён в текущем документе'});continue}
  addProposal(proposals,key,{source:sourceFor('buildings',item.id),action:'delete',before:structuredClone(base),after:null,derivedDirty:true,metadata:{adapter:'legacy-7.2-compat-v1'}},path,audit);
 }

 const candidate=structuredClone(current);
 for(const [key,entry] of [...proposals].sort(([a],[b])=>a.localeCompare(b))){if(entry.conflict||!entry.proposal)continue;candidate.objectPatches.push(entry.proposal);audit.converted.push({sourcePath:entry.origin,target:key,kind:'object'});const id=entry.proposal.source.id;if(protectedIds.has(id)||protectedIds.has(key)||entry.proposal.before?.gameplayActive===true)audit.protected.push({target:key,path:entry.origin,reason:'Объект защищён актуальной политикой карты'})}
 const safeCells=[...surface.values()].filter(item=>item&&!item.conflict).sort((a,b)=>a.value-b.value||a.r-b.r||a.c-b.c);
 for(const value of [0,8]){const cells=safeCells.filter(item=>item.value===value).map(item=>[item.r,item.c]);if(!cells.length)continue;const materialId=value===0?'asphalt':'grass',id=`legacy72-${materialId}-${fnv(signature(cells))}`;if(candidate.surfaceStrokes.some(stroke=>stroke.id===id)){audit.ambiguous.push({target:`surface:${id}`,sourcePaths:[],reason:'Такой перенос уже есть в документе'});continue}candidate.surfaceStrokes.push({id,materialId,mode:'paint',shape:{type:'cells',cells}});audit.converted.push({sourcePath:'$.mapEdits',target:`surface:${id}`,kind:'surface',count:cells.length})}
 let normalized;try{normalized=normalizeWalkMapEditorDocument(candidate)}catch(error){fail('LEGACY_CANDIDATE_INVALID',`Конвертация не прошла проверку нового документа: ${error.message}`)}
 if(audit.protected.length)audit.blocking.push({code:'LEGACY_PROTECTED_ACTION',reason:'В старом сохранении есть действие над защищённой областью или объектом'});
 audit.counts={converted:audit.converted.length,dropped:audit.dropped.length,ambiguous:audit.ambiguous.length,protected:audit.protected.length,unsupported:audit.unsupported.length,duplicates:audit.duplicates.length,unknown:audit.unknown.length};
 const preview={format:WALK_MAP_LEGACY_7_2_FORMAT,dryRun:true,canApply:audit.blocking.length===0,sourceDocumentId:current.documentId,sourceRevision:current.revision,sourceFingerprint:fnv(serializeWalkMapEditorDocument(current,0)),candidateDocument:normalized,audit};
 trustedPreviews.add(preview);return deepFreeze(preview);
}

export function applyWalkMapLegacy72Import(session,preview,{dryRun=false,...options}={}){
 if(!trustedPreviews.has(preview))fail('LEGACY_PREVIEW_UNTRUSTED','Нужен результат текущего preview-конвертера');
 if(dryRun)return Object.freeze({applied:false,preview});
 if(!preview.canApply)fail('LEGACY_PREVIEW_BLOCKED','Старое сохранение заблокировано аудитом',{blocking:preview.audit.blocking});
 if(session?.document?.documentId!==preview.sourceDocumentId||session?.revision!==preview.sourceRevision||fnv(serializeWalkMapEditorDocument(session.document,0))!==preview.sourceFingerprint)fail('LEGACY_PREVIEW_STALE','Документ изменился после предварительной проверки');
 return importWalkMapEditorText(session,serializeWalkMapEditorDocument(preview.candidateDocument),{...options,expectedRevision:preview.sourceRevision});
}
