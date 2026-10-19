import {
 createWalkMapEditorCompileReceipt,
 normalizeWalkMapEditorDocument
} from './walk_map_editor_document.mjs';
import {isWalkMapProtectionPolicy} from './walk_map_editor_protection.mjs';

const trustedSources=new WeakSet(),trustedDatasetAdapters=new WeakSet(),trustedTopologyAdapters=new WeakSet(),trustedSurfaceAdapters=new WeakSet(),trustedCompileResults=new WeakSet();
const REQUIRED_SOURCES=['topology','buildings','decor','custom'];

export class WalkMapEditorCompileError extends Error{constructor(message){super(message);this.name='WalkMapEditorCompileError';}}

function isObject(value){return value!==null&&typeof value==='object'&&!Array.isArray(value);}
function stable(value){if(Array.isArray(value))return value.map(stable);if(isObject(value))return Object.fromEntries(Object.keys(value).sort().map(key=>[key,stable(value[key])]));return value;}
function canonicalJson(value){return JSON.stringify(stable(value));}
function equal(a,b){return canonicalJson(a)===canonicalJson(b);}
function clone(value){return structuredClone(value);}
function deepFreeze(value){if(Array.isArray(value))for(const item of value)deepFreeze(item);else if(isObject(value))for(const item of Object.values(value))deepFreeze(item);return Object.freeze(value);}
function assertSafeJson(value,label='JSON'){const seen=new WeakSet();let nodes=0;function visit(item,depth){if(++nodes>1500000||depth>64)throw new WalkMapEditorCompileError(`${label} exceeds JSON complexity limits`);if(item===null||typeof item==='boolean'||typeof item==='number'&&Number.isFinite(item))return;if(typeof item==='string'){if(item.length>4*1024*1024)throw new WalkMapEditorCompileError(`${label} contains an oversized string`);return;}if(typeof item!=='object'||seen.has(item))throw new WalkMapEditorCompileError(`${label} is not safe JSON`);seen.add(item);if(Array.isArray(item))for(const child of item)visit(child,depth+1);else{if(Object.getPrototypeOf(item)!==Object.prototype&&Object.getPrototypeOf(item)!==null)throw new WalkMapEditorCompileError(`${label} contains a non-plain object`);for(const [key,child] of Object.entries(item)){if(['__proto__','prototype','constructor'].includes(key))throw new WalkMapEditorCompileError(`${label} contains a dangerous key`);visit(child,depth+1);}}seen.delete(item);}visit(value,0);return value;}

function sha256Text(text){
 const bytes=new TextEncoder().encode(text),bitLength=bytes.length*8,paddedLength=Math.ceil((bytes.length+9)/64)*64,data=new Uint8Array(paddedLength);data.set(bytes);data[bytes.length]=0x80;const view=new DataView(data.buffer);view.setUint32(paddedLength-8,Math.floor(bitLength/0x100000000));view.setUint32(paddedLength-4,bitLength>>>0);
 const k=new Uint32Array([0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2]),h=new Uint32Array([0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19]),w=new Uint32Array(64),rotr=(value,bits)=>(value>>>bits)|(value<<(32-bits));
 for(let offset=0;offset<paddedLength;offset+=64){for(let i=0;i<16;i++)w[i]=view.getUint32(offset+i*4);for(let i=16;i<64;i++){const s0=rotr(w[i-15],7)^rotr(w[i-15],18)^(w[i-15]>>>3),s1=rotr(w[i-2],17)^rotr(w[i-2],19)^(w[i-2]>>>10);w[i]=(w[i-16]+s0+w[i-7]+s1)>>>0;}let [a,b,c,d,e,f,g,z]=h;for(let i=0;i<64;i++){const s1=rotr(e,6)^rotr(e,11)^rotr(e,25),choice=(e&f)^(~e&g),t1=(z+s1+choice+k[i]+w[i])>>>0,s0=rotr(a,2)^rotr(a,13)^rotr(a,22),majority=(a&b)^(a&c)^(b&c),t2=(s0+majority)>>>0;z=g;g=f;f=e;e=(d+t1)>>>0;d=c;c=b;b=a;a=(t1+t2)>>>0;}h[0]=(h[0]+a)>>>0;h[1]=(h[1]+b)>>>0;h[2]=(h[2]+c)>>>0;h[3]=(h[3]+d)>>>0;h[4]=(h[4]+e)>>>0;h[5]=(h[5]+f)>>>0;h[6]=(h[6]+g)>>>0;h[7]=(h[7]+z)>>>0;}
 return [...h].map(value=>value.toString(16).padStart(8,'0')).join('');
}

function assertName(value,label){if(typeof value!=='string'||!value.trim()||value.length>512)throw new WalkMapEditorCompileError(`${label} must be a non-empty string`);return value;}

export function createWalkMapEditorCompileSource(name,jsonText,{revision}={}){
 assertName(name,'source name');assertName(revision,'source revision');if(typeof jsonText!=='string')throw new WalkMapEditorCompileError('Compile source must be JSON text');if(new TextEncoder().encode(jsonText).byteLength>64*1024*1024)throw new WalkMapEditorCompileError('Compile source exceeds 64 MiB');
 let snapshot;try{snapshot=JSON.parse(jsonText);}catch(error){throw new WalkMapEditorCompileError(`Compile source JSON is invalid: ${error.message}`);}assertSafeJson(snapshot,`${name} source`);
 const source=deepFreeze({name,revision,sha256:sha256Text(jsonText),snapshot:clone(snapshot)});trustedSources.add(source);return source;
}
export function isWalkMapEditorCompileSource(value){return trustedSources.has(value);}
export function isWalkMapEditorCompileResult(value){return trustedCompileResults.has(value);}
export function walkMapEditorArtifactSha256(text){if(typeof text!=='string')throw new WalkMapEditorCompileError('SHA-256 input must be text');return sha256Text(text);}

export function createWalkMapEditorDatasetAdapter({dataset,id=dataset,version=1,readEntities,writeEntities,getId=entity=>entity?.id}={}){
 assertName(dataset,'dataset');assertName(id,'dataset adapter id');if(!Number.isSafeInteger(version)||version<1||typeof readEntities!=='function'||typeof writeEntities!=='function'||typeof getId!=='function')throw new WalkMapEditorCompileError(`Invalid dataset adapter: ${dataset}`);
 const adapter=Object.freeze({dataset,id,version,readEntities,writeEntities,getId});trustedDatasetAdapters.add(adapter);return adapter;
}

export function createWalkMapEditorTopologyAdapter({id,version=1,dimensions,readCell,writeCell,eraseCell}={}){
 assertName(id,'topology adapter id');if(!Number.isSafeInteger(version)||version<1||![dimensions,readCell,writeCell,eraseCell].every(fn=>typeof fn==='function'))throw new WalkMapEditorCompileError('Invalid topology adapter');
 const adapter=Object.freeze({id,version,dimensions,readCell,writeCell,eraseCell});trustedTopologyAdapters.add(adapter);return adapter;
}

export function createWalkMapEditorSurfaceAdapter({materialId,id=materialId,version=1,paintValue}={}){
 assertName(materialId,'surface material');assertName(id,'surface adapter id');if(!Number.isSafeInteger(version)||version<1)throw new WalkMapEditorCompileError(`Invalid surface adapter: ${materialId}`);assertSafeJson(paintValue,'surface paint value');
 const adapter=deepFreeze({materialId,id,version,paintValue:clone(paintValue)});trustedSurfaceAdapters.add(adapter);return adapter;
}

function rasterize(shape,rows,cols){const cells=[],seen=new Set(),add=(r,c)=>{if(r<0||c<0||r>=rows||c>=cols)return;const key=`${r}:${c}`;if(!seen.has(key)){seen.add(key);cells.push([r,c]);}};if(shape.type==='cells')for(const [r,c] of shape.cells)add(r,c);else if(shape.type==='rect')for(let r=Math.floor(shape.minR);r<Math.ceil(shape.maxR);r++)for(let c=Math.floor(shape.minC);c<Math.ceil(shape.maxC);c++)add(r,c);else if(shape.type==='polygon'){const points=shape.points,minR=Math.max(0,Math.floor(Math.min(...points.map(p=>p[0])))),maxR=Math.min(rows-1,Math.floor(Math.max(...points.map(p=>p[0])))),minC=Math.max(0,Math.floor(Math.min(...points.map(p=>p[1])))),maxC=Math.min(cols-1,Math.floor(Math.max(...points.map(p=>p[1]))));for(let r=minR;r<=maxR;r++)for(let c=minC;c<=maxC;c++){let inside=false;const y=r+.5,x=c+.5;for(let i=0,j=points.length-1;i<points.length;j=i++){const [yi,xi]=points[i],[yj,xj]=points[j];if((yi>y)!==(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)inside=!inside;}if(inside)add(r,c);}}return cells;}

function requireSource(name,sources,document){
 const source=sources?.[name];if(!trustedSources.has(source)||source.name!==name)throw new WalkMapEditorCompileError(`TRUSTED_SOURCE_REQUIRED: ${name}`);
 const reference=name==='custom'?document.base.extensions?.custom:document.base[name];
 if(!isObject(reference)||typeof reference.sha256!=='string'||typeof reference.revision!=='string')throw new WalkMapEditorCompileError(`SOURCE_REVISION_REQUIRED: ${name}`);
 if(reference.sha256.toLowerCase()!==source.sha256||reference.revision!==source.revision)throw new WalkMapEditorCompileError(`COMPILE_SOURCE_MISMATCH: ${name}`);
 return source;
}

function compileDataset(source,adapter,patches){
 let entities;try{entities=[...adapter.readEntities(source.snapshot)].map(clone);}catch(error){throw new WalkMapEditorCompileError(`DATASET_READ_FAILED: ${adapter.dataset}: ${error.message}`);}
 const byId=new Map();for(const entity of entities){const id=adapter.getId(entity);if(typeof id!=='string'||!id||byId.has(id))throw new WalkMapEditorCompileError(`INVALID_BASE_ENTITY_ID: ${adapter.dataset}`);byId.set(id,entity);}
 for(const patch of [...patches].sort((a,b)=>a.key.localeCompare(b.key))){const id=patch.source.id,current=byId.get(id);if(patch.action==='add'){if(current)throw new WalkMapEditorCompileError(`ENTITY_EXISTS: ${patch.key}`);if(adapter.getId(patch.after)!==id)throw new WalkMapEditorCompileError(`ENTITY_ID_MISMATCH: ${patch.key}`);byId.set(id,clone(patch.after));entities.push(clone(patch.after));continue;}if(!current)throw new WalkMapEditorCompileError(`ENTITY_MISSING: ${patch.key}`);if(!equal(current,patch.before))throw new WalkMapEditorCompileError(`STALE_BEFORE: ${patch.key}`);if(patch.action==='delete'){byId.delete(id);entities=entities.filter(entity=>adapter.getId(entity)!==id);}else{if(adapter.getId(patch.after)!==id)throw new WalkMapEditorCompileError(`ENTITY_ID_MISMATCH: ${patch.key}`);const index=entities.findIndex(entity=>adapter.getId(entity)===id);entities[index]=clone(patch.after);byId.set(id,entities[index]);}}
 let output;try{output=adapter.writeEntities(clone(source.snapshot),entities.map(clone));}catch(error){throw new WalkMapEditorCompileError(`DATASET_WRITE_FAILED: ${adapter.dataset}: ${error.message}`);}assertSafeJson(output,`${adapter.dataset} artifact`);return output;
}

function artifact(value){const json=canonicalJson(value);return deepFreeze({json,sha256:sha256Text(json),value:clone(value)});}

export function compileWalkMapEditorDocument(document,{trustedSources:sourceSet,datasetAdapters=new Map(),topologyAdapter,surfaceAdapters=new Map(),protectionPolicy,compilerId='walk-map-editor-compiler-v1',compiledAt=new Date().toISOString()}={}){
 const normalized=normalizeWalkMapEditorDocument(document);if(!isWalkMapProtectionPolicy(protectionPolicy))throw new WalkMapEditorCompileError('PROTECTION_POLICY_REQUIRED');
 const sources=Object.fromEntries(REQUIRED_SOURCES.map(name=>[name,requireSource(name,sourceSet,normalized)]));protectionPolicy.assertCompatible(normalized);
 if(!trustedTopologyAdapters.has(topologyAdapter))throw new WalkMapEditorCompileError('TOPOLOGY_ADAPTER_REQUIRED');
 for(const adapter of datasetAdapters.values())if(!trustedDatasetAdapters.has(adapter))throw new WalkMapEditorCompileError('UNTRUSTED_DATASET_ADAPTER');
 for(const adapter of surfaceAdapters.values())if(!trustedSurfaceAdapters.has(adapter))throw new WalkMapEditorCompileError('UNTRUSTED_SURFACE_ADAPTER');
 const baseDocument={...clone(normalized),objectPatches:[],surfaceStrokes:[]},protectionReport=protectionPolicy.inspectFinalDelta({before:baseDocument,after:normalized});
 if(protectionReport.unresolved.length)throw new WalkMapEditorCompileError(`PROTECTION_UNRESOLVED: ${protectionReport.unresolved.map(item=>item.code).join(', ')}`);
 if(protectionReport.protectedTouches.length)throw new WalkMapEditorCompileError('PROTECTED_EDIT');
 const patchesByDataset=new Map();for(const patch of normalized.objectPatches){const dataset=patch.source.dataset;if(!REQUIRED_SOURCES.slice(1).includes(dataset))throw new WalkMapEditorCompileError(`UNKNOWN_OBJECT_DATASET: ${dataset}`);if(!patchesByDataset.has(dataset))patchesByDataset.set(dataset,[]);patchesByDataset.get(dataset).push(patch);}
 const outputs={};for(const dataset of REQUIRED_SOURCES.slice(1)){const adapter=datasetAdapters.get(dataset);if(!trustedDatasetAdapters.has(adapter)||adapter.dataset!==dataset)throw new WalkMapEditorCompileError(`DATASET_ADAPTER_MISSING: ${dataset}`);outputs[dataset]=compileDataset(sources[dataset],adapter,patchesByDataset.get(dataset)??[]);}
 let topology=clone(sources.topology.snapshot),dimensions;try{dimensions=topologyAdapter.dimensions(sources.topology.snapshot);}catch(error){throw new WalkMapEditorCompileError(`TOPOLOGY_READ_FAILED: ${error.message}`);}if(!isObject(dimensions)||dimensions.rows!==normalized.map.rows||dimensions.cols!==normalized.map.cols)throw new WalkMapEditorCompileError('TOPOLOGY_DIMENSION_MISMATCH');
 for(const stroke of normalized.surfaceStrokes){const surfaceAdapter=surfaceAdapters.get(stroke.materialId);if(!trustedSurfaceAdapters.has(surfaceAdapter)||surfaceAdapter.materialId!==stroke.materialId)throw new WalkMapEditorCompileError(`SURFACE_ADAPTER_MISSING: ${stroke.materialId}`);for(const [row,col] of rasterize(stroke.shape,dimensions.rows,dimensions.cols)){try{if(stroke.mode==='paint')topologyAdapter.writeCell(topology,row,col,clone(surfaceAdapter.paintValue));else if(stroke.mode==='erase')topologyAdapter.eraseCell(topology,row,col);else topologyAdapter.writeCell(topology,row,col,clone(topologyAdapter.readCell(sources.topology.snapshot,row,col)));}catch(error){throw new WalkMapEditorCompileError(`TOPOLOGY_WRITE_FAILED: ${stroke.id}: ${error.message}`);}}}
 assertSafeJson(topology,'topology artifact');outputs.topology=topology;
 const artifacts=deepFreeze(Object.fromEntries(REQUIRED_SOURCES.map(name=>[name,artifact(outputs[name])]))),outputDigests=Object.fromEntries(REQUIRED_SOURCES.map(name=>[name,artifacts[name].sha256]));
 const compileReceipt=createWalkMapEditorCompileReceipt(normalized,{protectionPolicy,sourceDigests:{topology:sources.topology.sha256,buildings:sources.buildings.sha256,decor:sources.decor.sha256},compilerId,compiledAt,outputDigests});
 const result=Object.freeze({document:deepFreeze(clone(normalized)),artifacts,compileReceipt,protectionReport});trustedCompileResults.add(result);return result;
}
