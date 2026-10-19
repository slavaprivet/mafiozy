/** Data-only portable resource inventory. SHA integrity never grants gameplay authority. */
import {createHash} from 'node:crypto';
export const SCHEMA='mafiozi.portable-map-resource-closure/v1';
export const sha=b=>createHash('sha256').update(b).digest('hex');
const hash=s=>typeof s==='string'&&/^[a-f0-9]{64}$/.test(s);
const canonical=o=>JSON.stringify(o,(k,v)=>v&&typeof v==='object'&&!Array.isArray(v)?Object.fromEntries(Object.entries(v).sort(([a],[b])=>a.localeCompare(b))):v);
export const identitySHA=o=>sha(canonical(o));
const familyNames=['catalog','ground-topology','ground-palette','procedural','transport','landmarks','landmark-textures','rail-caption-capture'];
const extension={json:'json',glb:'glb',buffer:'bin',rgba8:'rgba'};
export function pathFor(kind,hash){if(!extension[kind]||!hash?.match(/^[a-f0-9]{64}$/))throw Error('Unsafe content identity');return `blobs/${hash}.${extension[kind]}`;}
export function verifyClosure(closure,readBlob,trusted,{requireReady=true}={}){
 const errors=[],holds=[],decoded=new Map(),bytesBySHA=new Map();let checks=0;
 const reject=message=>errors.push(message);
 if(!closure||closure.schema!==SCHEMA||closure.engineContract!=='godot-native-map-importer/closure-v1'||!Array.isArray(closure.blobs)||!Array.isArray(closure.families))return {ok:false,integrity:false,ready:false,errors:['Unsupported portable closure schema']};
 if(closure.blobs.length>4096||closure.families.length!==8||closure.families.some(f=>!Array.isArray(f.semanticKeys)||f.semanticKeys.length>20000||f.semanticKeys.some(k=>typeof k!=='string'||k.length>512)))return {ok:false,integrity:false,ready:false,errors:['Oversized or malformed publication inventory']};
 if(Object.keys(closure).sort().join(',')!=='blobs,engineContract,families,mapBundle_sha256,schema')reject('Unexpected publication fields');
 if(closure.ready!==undefined||closure.authority!==undefined||closure.scripts!==undefined)reject('Publication cannot grant ready/authority or executable scripts');
 const bySHA=new Map(),paths=new Set();
 for(const receipt of closure.blobs){
  if(Object.keys(receipt).sort().join(',')!=='bytes,kind,path,sha256'){reject('Unexpected blob fields');continue;}
  if(!hash(receipt.sha256)||!Number.isSafeInteger(receipt.bytes)||receipt.bytes<=0||receipt.bytes>64*1024*1024||!extension[receipt.kind]){reject('Unsafe blob descriptor');continue;}
  if(receipt.path!==pathFor(receipt.kind,receipt.sha256)||bySHA.has(receipt.sha256)||paths.has(receipt.path)){reject('Nonportable/duplicate content path');continue;}
  bySHA.set(receipt.sha256,receipt);paths.add(receipt.path);
  let raw;try{raw=readBlob(receipt.path);}catch{reject('Missing portable blob '+receipt.sha256);continue;}
  if(!Buffer.isBuffer(raw)||raw.length!==receipt.bytes||sha(raw)!==receipt.sha256){reject('Corrupt portable blob '+receipt.sha256);continue;}
  checks++;bytesBySHA.set(receipt.sha256,raw);
  if(receipt.kind==='json'){try{decoded.set(receipt.sha256,JSON.parse(raw));}catch{reject('Corrupt JSON descriptor');}}
  if(receipt.kind==='glb'){
   if(raw.length<20||raw.readUInt32LE(0)!==0x46546c67||raw.readUInt32LE(4)!==2||raw.readUInt32LE(8)!==raw.length){reject('Invalid GLB bytes');continue;}
   let gltf;try{const len=raw.readUInt32LE(12);if(raw.readUInt32LE(16)!==0x4e4f534a||20+len>raw.length)throw Error();gltf=JSON.parse(raw.subarray(20,20+len).toString());}catch{reject('Invalid embedded GLB JSON');continue;}
   for(const resource of [...(gltf.images??[]),...(gltf.buffers??[])])if(resource.uri&&!resource.uri.startsWith('data:'))reject('External GLB URI is not portable '+resource.uri);
  }
 }
 const families=new Map();
 for(const family of closure.families){
  if(Object.keys(family).sort().join(',')!=='id,manifest_sha256,semanticKeys'||!familyNames.includes(family.id)||families.has(family.id)||!hash(family.manifest_sha256)||!decoded.has(family.manifest_sha256)||!trusted.sourceManifests?.has(family.manifest_sha256)||trusted.familyManifests?.get(family.id)!==family.manifest_sha256){reject('Untrusted/missing/duplicate family manifest');continue;}
  families.set(family.id,family);
 }
 for(const id of familyNames)if(!families.has(id))reject('Missing required full-map family '+id);
 const requiredBlobs=new Set([...families.values()].map(f=>f.manifest_sha256));
 const requireBlob=(id,bytes,kind)=>{requiredBlobs.add(id);const row=bySHA.get(id);if(!row||row.bytes!==bytes||(kind&&row.kind!==kind))reject('Incomplete dependency receipt '+id);else checks++;};
 for(const family of families.values()){
  const manifest=decoded.get(family.manifest_sha256);let keys=[];
  if(family.id==='catalog'){
   keys=manifest.objects?.map(o=>o.key)??[];
   if(keys.length!==9901||manifest.resources?.length!==196)reject('Source catalog census changed');
   for(const resource of manifest.resources??[])requireBlob(resource.sha256,resource.bytes,'glb');
  }else if(family.id==='procedural')keys=Object.keys(manifest.objectIndex??{});
  else if(family.id==='transport')keys=manifest.semanticObjects?.map(o=>o.key)??[];
  else if(family.id==='landmarks')keys=manifest.records?.map(o=>o.key)??[];
  else if(family.id==='landmark-textures')keys=manifest.textures?.map(o=>o.id)??[];
  else if(family.id==='rail-caption-capture')keys=manifest.captures?.map(o=>o.texture_id)??[];
  if(!Array.isArray(family.semanticKeys)||new Set(keys).size!==keys.length||canonical([...keys].sort())!==canonical([...family.semanticKeys].sort()))reject('Semantic identity loss/substitution '+family.id);
  for(const buffer of manifest.buffers??[]){if(buffer.file!==`buffers/${buffer.sha256}.bin`)reject('Unsafe source-buffer alias');requireBlob(buffer.sha256,buffer.bytes,'buffer');}
  if(family.id==='transport')requireBlob(manifest.railway.trainAsset.sha256,manifest.railway.trainAsset.bytes,'glb');
  if(family.id==='landmark-textures'){
   if(manifest.textures?.length!==38)reject('Landmark texture closure incomplete');
   for(const texture of manifest.textures??[])for(const image of texture.images??[]){
    const admitted=trusted.textureCaptures?.get(image.recipeKey);
    if(!admitted||!hash(admitted.pixel_sha256)||admitted.recipe_sha256!==image.sourceRecipeSha256||admitted.width!==image.width||admitted.height!==image.height||admitted.original_sampler_sha256!==identitySHA(texture.sampler))holds.push('Original caption/font/Canvas/sampler capture missing: '+texture.id+'/'+image.ordinal);
    else requireBlob(admitted.pixel_sha256,image.width*image.height*4,'rgba8');
   }
   if(!trusted.runtimeGates?.has('landmarks-original-PMREM-IBL'))holds.push('Native original environment PMREM/IBL parity pending');
  }
  if(family.id==='rail-caption-capture')for(const capture of manifest.captures??[])requireBlob(capture.rgba_sha256,capture.width*capture.height*4,'rgba8');
 }
 for(const id of ['native-importer-closure-v1','source-baseline-identity','ground-owner','procedural-owner','parking-rail-route-owner','protected-landmark-authority-collider-doors-nav','GLB-importer-material-parity','rail-caption-GPU-sampler-parity'])if(!trusted.runtimeGates?.has(id))holds.push('Trusted installed game gate pending: '+id);
 // No map/user-state snapshot is manufactured by an inventory audit.
 if(!hash(closure.mapBundle_sha256)||!decoded.has(closure.mapBundle_sha256))holds.push('User-approved MapBundle is absent');
 else{requiredBlobs.add(closure.mapBundle_sha256);if(!trusted.validateMapBundle||trusted.validateMapBundle(decoded.get(closure.mapBundle_sha256))!==true)holds.push('Trusted installed MapBundle baseline/ground validator did not admit publication');}
 for(const id of bySHA.keys())if(!requiredBlobs.has(id))reject('Unexpected/unreferenced publication blob '+id);
 const integrity=errors.length===0,ready=integrity&&holds.length===0;
 return {ok:integrity&&(!requireReady||ready),integrity,ready,checks,errors,holds,portableBlobCount:bySHA.size,portableBytes:[...bySHA.values()].reduce((n,r)=>n+r.bytes,0)};
}
