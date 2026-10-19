/** Source-only data publication. Integrity is not owner/gameplay authority. */
import fs from 'node:fs';
import path from 'node:path';
import {types} from 'node:util';
import {verifyClosure,pathFor,sha} from '../map_editor_publication_closure/closure.mjs';

const canonical=value=>JSON.stringify(value,(_key,item)=>item&&typeof item==='object'&&!Array.isArray(item)?Object.fromEntries(Object.entries(item).sort(([a],[b])=>a.localeCompare(b))):item);
const hash=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const within=(parent,child)=>{const relative=path.relative(parent,child);return relative!==''&&!relative.startsWith('..')&&!path.isAbsolute(relative);};
const mapEntries=Map.prototype.entries,setValues=Set.prototype.values;
const mapNext=Object.getPrototypeOf(new Map().entries()).next,setNext=Object.getPrototypeOf(new Set().values()).next;
function plainDescriptors(value){
 if(types.isProxy(value))throw Error('Executable Proxy refused before reflection');
 if(!value||typeof value!=='object'||![Object.prototype,null].includes(Object.getPrototypeOf(value)))throw Error('Plain host packet required');
 const descriptors=Object.getOwnPropertyDescriptors(value);
 for(const [key,item]of Object.entries(descriptors))if(!('value'in item)||['__proto__','constructor','prototype'].includes(key))throw Error('Host accessor/ambiguous property refused');
 return descriptors;
}
function collectionValues(value,kind){
 if(types.isProxy(value))throw Error('Collection Proxy refused before reflection');
 const proto=kind==='map'?Map.prototype:Set.prototype;
 if(!value||Object.getPrototypeOf(value)!==proto||Reflect.ownKeys(value).length)throw Error('Native collection without overrides required');
 const iterator=(kind==='map'?mapEntries:setValues).call(value),next=kind==='map'?mapNext:setNext,result=[];
 for(;;){const step=next.call(iterator);if(step.done)break;if(result.length>=20000)throw Error('Oversized host collection');result.push(step.value);}
 return result;
}
function admissionSnapshot(trusted){
 const properties=plainDescriptors(trusted),get=key=>properties[key]?.value;
 if(Object.keys(properties).some(key=>!['sourceManifests','familyManifests','runtimeGates','textureCaptures','validateMapBundle'].includes(key)))throw Error('Unknown host admission fields');
 const validator=get('validateMapBundle');
 if(types.isProxy(validator)||validator!==undefined&&typeof validator!=='function')throw Error('Explicit non-Proxy validator required');
 const strings=(value,kind)=>{const rows=collectionValues(value,kind);if(rows.some(row=>kind==='map'?typeof row[0]!=='string'||typeof row[1]!=='string':typeof row!=='string'))throw Error('Plain admission identity strings required');return rows;};
 const captureBudget={nodes:0};
 const captures=collectionValues(get('textureCaptures'),'map').map(([key,value])=>{if(typeof key!=='string')throw Error('Capture key must be a string');return [key,dataCopy(value,0,captureBudget)];});
 return {sourceManifests:new Set(strings(get('sourceManifests'),'set')),familyManifests:new Map(strings(get('familyManifests'),'map')),runtimeGates:new Set(strings(get('runtimeGates'),'set')),textureCaptures:new Map(captures),validateMapBundle:validator};
}
function admissionIdentity(packet){
 return canonical({sourceManifests:collectionValues(packet.sourceManifests,'set').sort(),familyManifests:collectionValues(packet.familyManifests,'map').sort(([a],[b])=>a.localeCompare(b)),runtimeGates:collectionValues(packet.runtimeGates,'set').sort(),textureCaptures:collectionValues(packet.textureCaptures,'map').sort(([a],[b])=>a.localeCompare(b))});
}
function dataCopy(value,depth=0,budget={nodes:0}){
 if(types.isProxy(value))throw Error('Executable Proxy refused before reflection');
 if(depth>64||++budget.nodes>500000)throw Error('Oversized publication data');
 if(typeof value==='string'&&value.length>4096)throw Error('Oversized publication string');
 if(value===null||typeof value==='string'||typeof value==='boolean')return value;
 if(typeof value==='number'&&Number.isFinite(value))return value;
 if(!value||typeof value!=='object'||(!Array.isArray(value)&&![Object.prototype,null].includes(Object.getPrototypeOf(value))))throw Error('Publication must be plain parsed data');
 const result=Array.isArray(value)?[]:{};
 for(const [key,descriptor]of Object.entries(Object.getOwnPropertyDescriptors(value))){
  if(Array.isArray(value)&&key==='length')continue;
  if(!('value'in descriptor)||key==='__proto__'||key==='constructor'||key==='prototype')throw Error('Accessor/executable/ambiguous data refused');
  result[key]=dataCopy(descriptor.value,depth+1,budget);
 }
 return result;
}

/** Host-only setup. None of these admissions are accepted from map JSON.
 * readBlob is an explicit source-whitelisted reader, not filesystem discovery.
 * trusted contains the ORIGINAL frozen-verifier source/family/runtime receipts
 * and actual installed MapBundle validator. All are required for a ready result.
 * userApprovedMapBundleSHA binds publication to the host's approved snapshot.
 * The host must own runtime/admission freshness for the complete synchronous call.
 */
export function createMaterializer(configuration){
 const initial=plainDescriptors(configuration),readBlob=initial.readBlob?.value,trusted=initial.trusted?.value,userApprovedMapBundleSHA=initial.userApprovedMapBundleSHA?.value,outputRoot=initial.outputRoot?.value;
 if(types.isProxy(readBlob)||typeof readBlob!=='function'||types.isProxy(trusted)||!trusted||typeof outputRoot!=='string'||!path.isAbsolute(outputRoot))throw Error('Explicit non-Proxy trusted reader/admissions and absolute host output root required');
 let busy=false;
 return Object.freeze({publish(input){
  if(busy)return {ok:false,wrote:false,error:'Reentrant publication refused'};
  busy=true;let destination=null;
  try{
   const closure=dataCopy(input),snapshots=new Map();
   const admitted=admissionSnapshot(trusted);
   const snapshotReader=portable=>{
    // No arbitrary user paths reach even the explicitly whitelisted host reader.
    const row=closure.blobs?.find(blob=>blob.path===portable);
    if(!row||portable!==pathFor(row.kind,row.sha256))throw Error('Undeclared noncanonical source blob');
    if(!snapshots.has(portable)){
     const raw=readBlob(portable);
     if(!Buffer.isBuffer(raw))throw Error('Original source bytes required');
     snapshots.set(portable,Buffer.from(raw));
    }
    return snapshots.get(portable);
   };
   // CRITICAL: all native owner/importer/texture/MapBundle holds are enforced by
   // the frozen verifier BEFORE any directory or file is created.
   const verification=verifyClosure(closure,snapshotReader,admitted,{requireReady:true});
   if(!verification.ok)return {ok:false,wrote:false,verification};
   if(!hash(userApprovedMapBundleSHA)||closure.mapBundle_sha256!==userApprovedMapBundleSHA||typeof admitted.validateMapBundle!=='function')return {ok:false,wrote:false,error:'Exact host user-approved MapBundle admission required',verification};
   // Snapshot ALL current descriptors/values before ANY equality comparisons.
   // This pass has no source callback/getter/custom collection invocation.
   const currentConfiguration=plainDescriptors(configuration);
   for(const [key,expected]of [['readBlob',readBlob],['trusted',trusted],['userApprovedMapBundleSHA',userApprovedMapBundleSHA],['outputRoot',outputRoot]])if(currentConfiguration[key]?.value!==expected)throw Error('Configured host capability changed');
   const current=admissionSnapshot(trusted);
   if(current.validateMapBundle!==admitted.validateMapBundle||admissionIdentity(current)!==admissionIdentity(admitted))throw Error('Host admissions changed during publication validation');
   // A validator/reader cannot substitute mutable bytes after validation. Cached
   // originals and receipts are checked again without another external reader.
   for(const row of closure.blobs){const raw=snapshots.get(row.path);if(!raw||raw.length!==row.bytes||sha(raw)!==row.sha256)throw Error('Verified source snapshot changed');}
   const base=path.resolve(outputRoot);
   if(fs.realpathSync(base)!==base||!fs.lstatSync(base).isDirectory()||fs.lstatSync(base).isSymbolicLink())throw Error('Output root must be an existing nonredirected host directory');
   destination=fs.mkdtempSync(path.join(base,'map-publication-'));
   if(!within(base,destination)||fs.realpathSync(destination)!==destination)throw Error('Output escaped trusted root');
   fs.mkdirSync(path.join(destination,'blobs'));
   for(const row of closure.blobs){
    const target=path.join(destination,row.path);
    if(row.path!==pathFor(row.kind,row.sha256)||!within(path.join(destination,'blobs'),target))throw Error('Invalid declared output path');
    const descriptor=fs.openSync(target,'wx',0o600);
    try{fs.writeFileSync(descriptor,snapshots.get(row.path));fs.fsyncSync(descriptor);}finally{fs.closeSync(descriptor);}
    const readback=fs.readFileSync(target);
    if(readback.length!==row.bytes||sha(readback)!==row.sha256)throw Error('Exclusive output hash readback failed');
   }
   const text=canonical(closure)+'\n',manifest=path.join(destination,'manifest.json');
   const descriptor=fs.openSync(manifest,'wx',0o600);
   try{fs.writeFileSync(descriptor,text,'utf8');fs.fsyncSync(descriptor);}finally{fs.closeSync(descriptor);}
   if(fs.readFileSync(manifest,'utf8')!==text)throw Error('Canonical manifest readback failed');
   return {ok:true,wrote:true,destination,manifest_sha256:sha(Buffer.from(text)),verification};
  }catch(error){return {ok:false,wrote:destination!==null,destination,error:String(error.message),partial_retained:destination!==null};}
  finally{busy=false;}
 }});
}

/** Optional host reader for a source-owned, configure-time Map. Never admit
 * filesystem paths from publication JSON. Each declared source is exact bytes.
 */
export function sourceWhitelistReader(admittedFiles){
 const files=new Map();
 for(const [portable,supplied]of collectionValues(admittedFiles,'map')){
  const row=dataCopy(supplied);
  if(!row||portable!==pathFor(row.kind,row.sha256)||!path.isAbsolute(row.source)||!Number.isSafeInteger(row.bytes)||row.bytes<=0)throw Error('Invalid configured source receipt');
  const absolute=path.resolve(row.source);
  if(fs.realpathSync(absolute)!==absolute||!fs.lstatSync(absolute).isFile()||fs.lstatSync(absolute).isSymbolicLink())throw Error('Source must be an admitted regular nonredirected file');
  files.set(portable,Object.freeze({...row,source:absolute}));
 }
 return portable=>{
  const row=files.get(portable);
  if(!row)throw Error('Source is not whitelisted');
  if(fs.realpathSync(row.source)!==row.source||!fs.lstatSync(row.source).isFile()||fs.lstatSync(row.source).isSymbolicLink())throw Error('Admitted source lifetime changed');
  const raw=fs.readFileSync(row.source);
  if(raw.length!==row.bytes||sha(raw)!==row.sha256)throw Error('Admitted source bytes changed');
  return raw;
 };
}
