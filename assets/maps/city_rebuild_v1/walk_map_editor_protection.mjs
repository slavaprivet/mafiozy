const trustedPolicies=new WeakSet();
const trustedReports=new WeakMap();
const trustedPolicyDigests=new WeakMap();
const trustedAuditReceipts=new WeakSet();
const MASK_NAMES=['protectedMask','policeMask','bridgeDeckMask'];

class WalkMapProtectionError extends Error{constructor(message){super(message);this.name='WalkMapProtectionError';}}
export function walkMapEditorEntityKey(source){if(!source||typeof source.dataset!=='string'||typeof source.id!=='string')throw new WalkMapProtectionError('Invalid entity source');return `${encodeURIComponent(source.dataset)}:${encodeURIComponent(source.id)}`;}

function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function clone(value){return structuredClone(value);}
function stable(value){if(Array.isArray(value))return value.map(stable);if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value;}
function equal(a,b){return JSON.stringify(stable(a))===JSON.stringify(stable(b));}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(isObject(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value);}

function normalizeMask(mask,name,rows,cols){
 if(!Array.isArray(mask)||mask.length!==rows)throw new WalkMapProtectionError(`${name} row count mismatch`);
 const copy=mask.map((row,r)=>{if(!Array.isArray(row)||row.length!==cols)throw new WalkMapProtectionError(`${name}[${r}] column count mismatch`);return row.map(value=>{if(value!==0&&value!==1&&value!==false&&value!==true)throw new WalkMapProtectionError(`${name} must contain booleans or 0/1`);return !!value})});
 for(const row of copy)Object.freeze(row);return Object.freeze(copy);
}

function rasterize(shape,rows,cols,limit){
 const cells=[],seen=new Set();
 const add=(r,c)=>{if(r<0||c<0||r>=rows||c>=cols)return;const key=`${r}:${c}`;if(seen.has(key))return;seen.add(key);if(cells.length>=limit)throw new WalkMapProtectionError('SURFACE_RASTER_LIMIT');cells.push([r,c])};
 if(shape?.type==='cells')for(const [r,c] of shape.cells)add(r,c);
 else if(shape?.type==='rect')for(let r=Math.floor(shape.minR);r<Math.ceil(shape.maxR);r++)for(let c=Math.floor(shape.minC);c<Math.ceil(shape.maxC);c++)add(r,c);
 else if(shape?.type==='polygon'){
  const points=shape.points,minR=Math.max(0,Math.floor(Math.min(...points.map(p=>p[0])))),maxR=Math.min(rows-1,Math.floor(Math.max(...points.map(p=>p[0])))),minC=Math.max(0,Math.floor(Math.min(...points.map(p=>p[1])))),maxC=Math.min(cols-1,Math.floor(Math.max(...points.map(p=>p[1]))));
  for(let r=minR;r<=maxR;r++)for(let c=minC;c<=maxC;c++){let inside=false;const y=r+.5,x=c+.5;for(let i=0,j=points.length-1;i<points.length;j=i++){const [yi,xi]=points[i],[yj,xj]=points[j];if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)inside=!inside}if(inside)add(r,c)}
 }
 return cells;
}

function effectiveEntity(patch,base){if(!patch)return base??null;if(patch.action==='delete')return null;return patch.after;}

export function createWalkMapProtectionPolicy({rows,cols,worldUnitsPerCell,sourceDigests={},masks={},protectedEntityIds=[],trustedBaseEntities=new Map(),footprintAdapters=new Map(),rasterLimit=250000}={}){
 if(!Number.isSafeInteger(rows)||rows<=0||!Number.isSafeInteger(cols)||cols<=0||!Number.isFinite(worldUnitsPerCell)||worldUnitsPerCell<=0)throw new WalkMapProtectionError('Invalid protection map descriptor');
 const digests={};for(const name of ['topology','buildings','decor']){const digest=sourceDigests[name];if(typeof digest!=='string'||!/^[a-f0-9]{64}$/i.test(digest))throw new WalkMapProtectionError(`Invalid SHA-256 digest for ${name}`);digests[name]=digest.toLowerCase()}
 const frozenMasks={};for(const name of MASK_NAMES){if(!(name in masks))throw new WalkMapProtectionError(`Missing protection mask: ${name}`);frozenMasks[name]=normalizeMask(masks[name],name,rows,cols)}
 const protectedIds=new Set([...protectedEntityIds].map(String));
 const bases=new Map();for(const [key,value] of trustedBaseEntities){if(!isObject(value))throw new WalkMapProtectionError(`Invalid trusted base entity: ${key}`);bases.set(String(key),clone(value))}
 const adapters=new Map();for(const [name,adapter] of footprintAdapters){if(typeof adapter?.cellsFor!=='function')throw new WalkMapProtectionError(`Invalid footprint adapter: ${name}`);adapters.set(name,Object.freeze({id:adapter.id??name,version:adapter.version??1,cellsFor:adapter.cellsFor}))}
 const policyDigest=JSON.stringify(stable({rows,cols,worldUnitsPerCell,digests,masks:frozenMasks,protectedIds:[...protectedIds].sort(),bases:[...bases].map(([key,value])=>[key,value]).sort(),adapters:[...adapters].map(([key,value])=>[key,value.id,value.version]).sort()}));
 const policy={
  isProtectionPolicy:true,
  assertCompatible(document){
   if(document.map.rows!==rows||document.map.cols!==cols||document.map.worldUnitsPerCell!==worldUnitsPerCell)throw new WalkMapProtectionError('PROTECTION_MAP_MISMATCH');
   for(const [name,digest] of Object.entries(digests))if(document.base?.[name]?.sha256?.toLowerCase()!==digest)throw new WalkMapProtectionError(`PROTECTION_BASE_MISMATCH: ${name}`);
  },
  inspectFinalDelta({before,after}){
   this.assertCompatible(after);const protectedTouches=[],unresolved=[];let affectedCellCount=0;
   const beforeStrokes=new Map(before.surfaceStrokes.map(stroke=>[stroke.id,stroke])),afterStrokes=new Map(after.surfaceStrokes.map(stroke=>[stroke.id,stroke])),orderChanged=!equal(before.surfaceStrokes.map(s=>s.id),after.surfaceStrokes.map(s=>s.id));
   for(const id of new Set([...beforeStrokes.keys(),...afterStrokes.keys()])){
    const oldStroke=beforeStrokes.get(id),newStroke=afterStrokes.get(id);if(equal(oldStroke,newStroke))continue;
    let cells;try{cells=[...rasterize(oldStroke?.shape,rows,cols,rasterLimit),...rasterize(newStroke?.shape,rows,cols,rasterLimit)]}catch(error){unresolved.push({code:'SURFACE_RASTER_LIMIT',key:id,reason:error.message});continue}
    const unique=new Set();for(const [r,c] of cells){const cellKey=`${r}:${c}`;if(unique.has(cellKey))continue;unique.add(cellKey);affectedCellCount++;const hit=MASK_NAMES.filter(name=>frozenMasks[name][r][c]);if(hit.length)protectedTouches.push({code:'PROTECTED_CELL',commandType:'surface',key:id,source:null,cell:[r,c],masks:hit,reason:'Защищённая клетка карты'});}
   }
   if(orderChanged)for(const stroke of [...before.surfaceStrokes,...after.surfaceStrokes]){let cells;try{cells=rasterize(stroke.shape,rows,cols,rasterLimit)}catch(error){unresolved.push({code:'SURFACE_RASTER_LIMIT',key:stroke.id,reason:error.message});continue}for(const [r,c] of cells){const hit=MASK_NAMES.filter(name=>frozenMasks[name][r][c]);if(hit.length)protectedTouches.push({code:'PROTECTED_CELL',commandType:'surface',key:stroke.id,source:null,cell:[r,c],masks:hit,reason:'Изменён порядок покрытий защищённой клетки'});}}
   const beforePatches=new Map(before.objectPatches.map(patch=>[patch.key,patch])),afterPatches=new Map(after.objectPatches.map(patch=>[patch.key,patch]));
   for(const key of new Set([...beforePatches.keys(),...afterPatches.keys()])){
    const oldPatch=beforePatches.get(key),newPatch=afterPatches.get(key);if(equal(oldPatch,newPatch))continue;const source=newPatch?.source??oldPatch?.source,hasBase=bases.has(key),base=bases.get(key);
    const patches=[oldPatch,newPatch].filter(Boolean);
    if(hasBase&&patches.some(patch=>patch.action==='add')){unresolved.push({code:'BASE_ENTITY_EXISTS',key,source});continue}
    if(!hasBase&&patches.some(patch=>patch.action!=='add')){unresolved.push({code:'BASE_ENTITY_MISSING',key,source});continue}
    if(hasBase&&patches.some(patch=>patch.action!=='add'&&!equal(patch.before,base))){unresolved.push({code:'BASE_ENTITY_MISMATCH',key,source});continue}
    const oldEntity=effectiveEntity(oldPatch,base),newEntity=effectiveEntity(newPatch,base);
    if(equal(oldEntity,newEntity))continue;
    if(protectedIds.has(key))protectedTouches.push({code:'PROTECTED_ENTITY',commandType:'entity',key,source,cell:null,masks:[],reason:'Объект защищён владельцем карты'});
    if(base?.gameplayActive===true)protectedTouches.push({code:'GAMEPLAY_ACTIVE_ENTITY',commandType:'entity',key,source,cell:null,masks:[],reason:'Здание участвует в игровых механиках'});
    const adapter=adapters.get(source?.dataset);
    if(!adapter?.cellsFor){unresolved.push({code:'FOOTPRINT_ADAPTER_MISSING',key,source});continue}
    for(const [phase,snapshot] of [['before',oldEntity],['after',newEntity]])if(snapshot){let cells;try{cells=[...adapter.cellsFor({source,snapshot,trustedBase:base,map:{rows,cols,worldUnitsPerCell},phase})]}catch(error){unresolved.push({code:'INVALID_TRUSTED_FOOTPRINT',key,source,reason:error.message});continue}if(!cells.length){unresolved.push({code:'EMPTY_TRUSTED_FOOTPRINT',key,source,phase});continue}for(const cell of cells){if(!Array.isArray(cell)||cell.length!==2||!cell.every(Number.isInteger)){unresolved.push({code:'INVALID_TRUSTED_FOOTPRINT',key,source});break}const [r,c]=cell;if(r<0||c<0||r>=rows||c>=cols){unresolved.push({code:'INVALID_TRUSTED_FOOTPRINT',key,source});break}affectedCellCount++;const hit=MASK_NAMES.filter(name=>frozenMasks[name][r][c]);if(hit.length)protectedTouches.push({code:'PROTECTED_CELL',commandType:'entity',key,source,cell:[r,c],masks:hit,phase,reason:'Объект пересекает защищённую область'});}}
   }
   protectedTouches.sort((a,b)=>`${a.commandType}:${a.key}:${a.cell||''}:${a.phase||''}`.localeCompare(`${b.commandType}:${b.key}:${b.cell||''}:${b.phase||''}`));unresolved.sort((a,b)=>`${a.code}:${a.key}`.localeCompare(`${b.code}:${b.key}`));
   const report=deepFreeze({allowed:!protectedTouches.length&&!unresolved.length,protectedTouches:clone(protectedTouches),unresolved:clone(unresolved),affectedCellCount,policyDigest});
   trustedReports.set(report,policy);return report;
  }
 };
 trustedPolicies.add(policy);trustedPolicyDigests.set(policy,policyDigest);return Object.freeze(policy);
}

export function isWalkMapProtectionPolicy(value){return trustedPolicies.has(value);}
export function getWalkMapProtectionPolicyDigest(policy){if(!isWalkMapProtectionPolicy(policy))throw new WalkMapProtectionError('PROTECTION_POLICY_REQUIRED');return trustedPolicyDigests.get(policy);}
export function isWalkMapProtectionAuditReceipt(value){return trustedAuditReceipts.has(value);}

function normalizeAuditScope(request){
 if(!isObject(request))throw new WalkMapProtectionError('PROTECTION_AUDIT_SCOPE_REQUIRED');
 const {transactionId,documentId,beforeRevision,afterRevision}=request,operation=request.operation??'commit';
 if(typeof transactionId!=='string'||!transactionId||typeof documentId!=='string'||!documentId||!['commit','undo','redo'].includes(operation)||!Number.isSafeInteger(beforeRevision)||beforeRevision<0||!Number.isSafeInteger(afterRevision)||afterRevision!==beforeRevision+1)throw new WalkMapProtectionError('PROTECTION_AUDIT_SCOPE_INVALID');
 if(request.reason!==undefined&&typeof request.reason!=='string')throw new WalkMapProtectionError('PROTECTION_AUDIT_SCOPE_INVALID');
 return {transactionId,documentId,operation,beforeRevision,afterRevision};
}

function createAuditReceipt(report,request,authorization=null){
 const scope=normalizeAuditScope(request),receipt=deepFreeze({schema:'mafiozi.walk-map-protection-audit',schemaVersion:1,decision:authorization?'approved':'clear',policyDigest:report.policyDigest,approvalId:authorization?.approvalId??null,actor:authorization?.actor??(authorization?'host':'policy'),reason:request.reason??'',scope,touches:clone(report.protectedTouches),affectedCellCount:report.affectedCellCount});
 trustedAuditReceipts.add(receipt);return receipt;
}

export function requireWalkMapProtectionAuthorization(policy,report,authorizeProtected,request){
 if(!isWalkMapProtectionPolicy(policy))throw new WalkMapProtectionError('PROTECTION_POLICY_REQUIRED');
 if(trustedReports.get(report)!==policy)throw new WalkMapProtectionError('PROTECTION_REPORT_UNTRUSTED');
 if(report.unresolved.length)throw new WalkMapProtectionError(`PROTECTION_UNRESOLVED: ${report.unresolved.map(item=>item.code).join(', ')}`);
 normalizeAuditScope(request);
 if(!report.protectedTouches.length)return createAuditReceipt(report,request);
 const authorization=typeof authorizeProtected==='function'?authorizeProtected(deepFreeze({policyDigest:report.policyDigest,touches:clone(report.protectedTouches),request:clone(request)})):null;
 if(!authorization||authorization.allowed!==true||typeof authorization.approvalId!=='string'||!authorization.approvalId.trim()||authorization.approvalId.length>512||(authorization.actor!==undefined&&(typeof authorization.actor!=='string'||!authorization.actor.trim()||authorization.actor.length>512)))throw new WalkMapProtectionError('PROTECTED_EDIT');
 return createAuditReceipt(report,request,authorization);
}
