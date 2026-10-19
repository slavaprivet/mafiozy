/** Native import supplements can be extracted from embedded GLB images.
 * This records the source bytes without modifying the model or import cache.
 */
import {createHash} from 'node:crypto';
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {inspectGlb} from './install_map_editor_assets.mjs';
export function inspectEmbeddedImages(raw){
 inspectGlb(raw);
 let offset=12, json=null, binary=null;
 while(offset<raw.length){
  if(offset+8>raw.length)throw new Error('Truncated GLB chunk header');
  const length=raw.readUInt32LE(offset),type=raw.readUInt32LE(offset+4),end=offset+8+length;
  if(end>raw.length||length%4)throw new Error('Invalid GLB chunk bounds');
  if(type===0x4e4f534a){if(json)throw new Error('Duplicate JSON chunk');json=JSON.parse(raw.subarray(offset+8,end).toString('utf8'));}
  if(type===0x004e4942){if(binary)throw new Error('Duplicate BIN chunk');binary=raw.subarray(offset+8,end);}
  offset=end;
 }
 return (json.images||[]).map((image,index)=>{
  if(image.uri){
   // inspectGlb refuses external URIs. Embedded data-URIs are source-complete,
   // but a native extraction receipt requires explicit decoding admission.
   return {index,name:image.name||'',mimeType:image.mimeType||'',encoding:'data-uri',nativeExtractionReceiptRequired:true};
  }
  const view=json.bufferViews?.[image.bufferView];
  if(!view||view.buffer!==0||!binary)throw new Error('Image has no embedded BIN view');
  const start=view.byteOffset||0,length=view.byteLength;
  if(!Number.isSafeInteger(start)||!Number.isSafeInteger(length)||start<0||length<1||start+length>binary.length)throw new Error('Invalid embedded image bounds');
  const bytes=binary.subarray(start,start+length);
  return {index,name:image.name||'',mimeType:image.mimeType||'',encoding:'buffer-view',bufferView:image.bufferView,bytes:length,sha256:createHash('sha256').update(bytes).digest('hex')};
 });
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(!process.argv[2])throw new Error('Pass an admitted local GLB path');
 console.log(JSON.stringify(inspectEmbeddedImages(await readFile(resolve(process.argv[2])))));
}
