/** Source-only data publication. Integrity is not owner/gameplay authority. */
import fs from 'node:fs';
import path from 'node:path';
import {verifyClosure,pathFor,sha} from '../map_editor_publication_closure/closure.mjs';

const canonical=value=>JSON.stringify(value,(_key,item)=>item&&typeof item==='object'&&!Array.isArray(item)?Object.fromEntries(Object.entries(item).sort(([a],[b])=>a.localeCompare(b))):item);
const hash=value=>typeof value==='string'&&/^[a-f0-9]{64}$/.test(value);
const within=(parent,child)=>{const relative=path.relative(parent,child);return relative!==''&&!relative.startsWith('..')&&!path.isAbsolute(relative);};
const sameSet=(a,b)=>a instanceof Set&&a.size===b.size&&[...b].every(value=>a.has(value));
const sameMap=(a,b)=>a instanceof Map&&a.size===b.size&&[...b].every(([key,value])=>a.has(key)&&canonical(a.get(key))===canonical(value));
function dataCopy(value,depth=0,budget={nodes:0}){
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
export function createMaterializer({readBlob,trusted,userApprovedMapBundleSHA,outputRoot}){
 if(typeof readBlob!=='function'||!trusted||typeof outputRoot!=='string'||!path.isAbsolute(outputRoot))throw Error('Explicit trusted reader/admissions and absolute host output root required');
 let busy=false;
 return Object.freeze({publish(input){
  if(busy)return {ok:false,wrote:false,error:'Reentrant publication refused'};
  busy=true;let destination=null;
  try{
   const closure=dataCopy(input),snapshots=new Map();
   const admitted={...trusted,sourceManifests:new Set(trusted.sourceManifests??[]),familyManifests:new Map(trusted.familyManifests??[]),runtimeGates:new Set(trusted.runtimeGates??[]),textureCaptures:new Map([...trusted.textureCaptures??[]].map(([key,value])=>[key,dataCopy(value)]))};
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
   if(!hash(userApprovedMapBundleSHA)||closure.mapBundle_sha256!==userApprovedMapBundleSHA||typeof trusted.validateMapBundle!=='function')return {ok:false,wrote:false,error:'Exact host user-approved MapBundle admission required',verification};
   if(!sameSet(trusted.sourceManifests,admitted.sourceManifests)||!sameSet(trusted.runtimeGates,admitted.runtimeGates)||!sameMap(trusted.familyManifests,admitted.familyManifests)||!sameMap(trusted.textureCaptures,admitted.textureCaptures)||trusted.validateMapBundle!==admitted.validateMapBundle)throw Error('Host admissions changed during publication validation');
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
 if(!(admittedFiles instanceof Map))throw Error('Explicit trusted source Map required');
 const files=new Map();
 for(const [portable,row]of admittedFiles){
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
