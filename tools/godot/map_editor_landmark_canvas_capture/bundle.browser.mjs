// Pure browser/Node byte packaging. Never imports or executes source factories.
export const SOURCE_PIN='4e459bda9cf6a9ab752667bc8a55fe36a6a6c4d7350a7d5ddc64e08c6a8c490c';
export const CLOSURE_PIN='0c905c26584b0916777973fb7b28e12bfe7aa1e759134e0ec1ad188501897b81';
export const MAX_BUNDLE_BYTES=80*1024*1024;
export const BUNDLE_FILENAME='original-landmark-canvas43.tar';
const encoder=new TextEncoder(),decoder=new TextDecoder('utf-8',{fatal:true});
const assert=(condition,message)=>{if(!condition)throw Error(message);};
export async function sha256(bytes){return Array.from(new Uint8Array(await globalThis.crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');}
function sorted(value){
 if(Array.isArray(value))return value.map(sorted);
 if(value&&typeof value==='object')return Object.fromEntries(Object.keys(value).sort().map(k=>[k,sorted(value[k])]));
 return value;
}
export const canonical=value=>JSON.stringify(sorted(value));
const safeName=name=>name==='receipt.json'||/^images\/texture-(?:0|[1-9]\d?)-image-[0-5]\.(?:rgba|png)$/.test(name);
const equalBytes=(a,b)=>a.length===b.length&&a.every((v,i)=>v===b[i]);
function bytes(value){assert(value instanceof Uint8Array,'Unsigned native byte array required');return value;}
function text(header,offset,length,value){const b=encoder.encode(value);assert(b.length<length,'USTAR field too long');header.set(b,offset);}
function octal(header,offset,length,value){assert(Number.isSafeInteger(value)&&value>=0,'Invalid TAR integer');text(header,offset,length,value.toString(8).padStart(length-1,'0'));}
function headerFor(name,size){
 assert(safeName(name),'Unsafe/noncanonical artifact filename');
 const header=new Uint8Array(512);
 text(header,0,100,name);octal(header,100,8,0o644);octal(header,108,8,0);octal(header,116,8,0);octal(header,124,12,size);octal(header,136,12,0);
 header.fill(32,148,156);header[156]=48;text(header,257,6,'ustar');header[263]=48;header[264]=48;
 const sum=header.reduce((n,v)=>n+v,0);const checksum=encoder.encode(sum.toString(8).padStart(6,'0')+'\0 ');header.set(checksum,148);
 return header;
}
function field(header,offset,length){const b=header.subarray(offset,offset+length),end=b.indexOf(0);return decoder.decode(end<0?b:b.subarray(0,end));}
// Strict shared receiver parser: no filesystem interpretation or writes.
export function parserTar(input){
 const data=bytes(input);assert(data.length<=MAX_BUNDLE_BYTES&&data.length>=1024&&data.length%512===0,'TAR size refused');
 const entries=new Map();let offset=0,terminated=false;
 while(offset<data.length){
  const header=data.subarray(offset,offset+512);
  if(header.every(v=>v===0)){
   assert(offset+1024===data.length&&data.subarray(offset).every(v=>v===0),'Exactly two terminal zero blocks required');terminated=true;break;
  }
  const name=field(header,0,100),sizeText=field(header,124,12);
  assert(safeName(name)&&!entries.has(name),'Unsafe/duplicate TAR name');assert(/^[0-7]{11}$/.test(sizeText),'Canonical TAR size required');
  const size=Number.parseInt(sizeText,8);assert(size<=MAX_BUNDLE_BYTES&&equalBytes(header,headerFor(name,size)),'Header metadata/checksum mismatch');
  offset+=512;const padded=Math.ceil(size/512)*512;
  assert(offset+padded<=data.length-1024,'Truncated TAR entry');
  assert(data.subarray(offset+size,offset+padded).every(v=>v===0),'Nonzero TAR padding');
  entries.set(name,data.subarray(offset,offset+size));offset+=padded;
 }
 assert(terminated&&entries.size===87&&entries.keys().next().value==='receipt.json','Exactly receipt +43 RGBA +43 PNG required');
 return entries;
}
async function admitted(receipt,closureBytes){
 assert(await sha256(bytes(closureBytes))===CLOSURE_PIN,'Reviewed original closure bytes changed');
 const closure=JSON.parse(decoder.decode(closureBytes));
 assert(receipt&&receipt.schema==='original-landmark-canvas-browser-capture-v1'&&receipt.ready===false,'Original HOLD capture receipt required');
 assert(receipt.sourceManifestSha256===SOURCE_PIN&&receipt.sourceClosureSha256===CLOSURE_PIN&&receipt.threeRevision==='180','Capture source pins changed');
 assert(receipt.zeroWebGL===true&&receipt.webglAttempts===0,'Zero WebGL receipt required');
 const opaque={...receipt};delete opaque.canonicalSha256;
 assert(await sha256(encoder.encode(canonical(opaque)))===receipt.canonicalSha256,'Original canonical receipt hash mismatch');
 const expected=closure.textures.flatMap(texture=>texture.images.map((image,ordinal)=>({texture,image,ordinal,id:texture.id+'-image-'+ordinal})));
 assert(expected.length===43&&receipt.slots.length===43,'Original43 image slots required');
 for(let i=0;i<43;i++){
  const e=expected[i],s=receipt.slots[i];
  assert(s.id===e.id&&s.textureId===e.texture.id&&s.ordinal===e.ordinal&&s.cubeFaceOrdinal===(e.texture.type==='CubeTexture'?e.ordinal:null),'Original slot/face order changed');
  assert(s.width===e.image.width&&s.height===e.image.height&&s.rgbaBytes===s.width*s.height*4,'Original native dimensions/bytes changed');
  assert(s.sourceRecipeSha256===e.image.sourceRecipeSha256&&s.sourceRecipeKey===e.image.recipeKey&&canonical(s.sourceSampler)===canonical(e.texture.sampler),'Source recipe/sampler changed');
  assert(/^[a-f0-9]{64}$/.test(s.rgbaSha256)&&/^[a-f0-9]{64}$/.test(s.pngSha256)&&Number.isSafeInteger(s.pngBytes)&&s.pngBytes>=33&&s.pngBytes<=MAX_BUNDLE_BYTES,'Invalid artifact hashes/PNG size');
 }
 return receipt;
}
function checkPng(png,slot){
 assert(equalBytes(png.subarray(0,8),new Uint8Array([137,80,78,71,13,10,26,10])),'Native PNG signature required');
 const view=new DataView(png.buffer,png.byteOffset,png.byteLength);
 assert(view.getUint32(8)===13&&decoder.decode(png.subarray(12,16))==='IHDR'&&view.getUint32(16)===slot.width&&view.getUint32(20)===slot.height,'Original PNG IHDR dimensions changed');
}
export async function validateBundle(input,closureBytes){
 const entries=parserTar(input),receiptBytes=entries.get('receipt.json');
 assert(receiptBytes.length<=2*1024*1024,'Receipt size limit');
 const receipt=JSON.parse(decoder.decode(receiptBytes));
 assert(equalBytes(receiptBytes,encoder.encode(canonical(receipt)+'\n')),'Canonical receipt bytes required');
 await admitted(receipt,closureBytes);
 for(const slot of receipt.slots)for(const kind of ['rgba','png']){
  const name='images/'+slot.id+'.'+kind,data=entries.get(name);
  assert(data&&data.length===slot[kind+'Bytes']&&await sha256(data)===slot[kind+'Sha256'],'Artifact byte/hash mismatch: '+name);
  if(kind==='png')checkPng(data,slot);
 }
 return {receipt,entries,ready:false};
}
export async function buildTarBundle(capture,closureBytes){
 assert(capture&&typeof capture.receipt==='function'&&typeof capture.artifact==='function','Original capture API required');
 // Snapshot metadata and use artifact's defensive copies, never mutate originals.
 const receipt=JSON.parse(canonical(capture.receipt()));await admitted(receipt,closureBytes);
 const files=[{name:'receipt.json',data:encoder.encode(canonical(receipt)+'\n')}];
 for(const slot of receipt.slots)for(const kind of ['rgba','png']){
  const data=bytes(capture.artifact(slot.id,kind)).slice();
  assert(data.length===slot[kind+'Bytes']&&await sha256(data)===slot[kind+'Sha256'],'Capture changed/mismatched artifact: '+slot.id+'.'+kind);
  if(kind==='png')checkPng(data,slot);
  files.push({name:'images/'+slot.id+'.'+kind,data});
 }
 files.splice(1,files.length-1,...files.slice(1).sort((a,b)=>a.name<b.name?-1:a.name>b.name?1:0));
 const size=1024+files.reduce((n,f)=>n+512+Math.ceil(f.data.length/512)*512,0);
 assert(size<=MAX_BUNDLE_BYTES,'Bundle exceeds80MiB hard limit');
 const archive=new Uint8Array(size);let offset=0;
 for(const file of files){archive.set(headerFor(file.name,file.data.length),offset);offset+=512;archive.set(file.data,offset);offset+=Math.ceil(file.data.length/512)*512;}
 return {bytes:archive,filename:BUNDLE_FILENAME,entries:87,ready:false,receiptSha256:receipt.canonicalSha256,bundleSha256:await sha256(archive)};
}
export function downloadBundle(bundle){
 const url=URL.createObjectURL(new Blob([bundle.bytes],{type:'application/x-tar'})),link=document.createElement('a');
 link.href=url;link.download=BUNDLE_FILENAME;link.click();setTimeout(()=>URL.revokeObjectURL(url),30000);
}
