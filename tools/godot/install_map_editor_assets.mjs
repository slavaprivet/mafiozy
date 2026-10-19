/** Byte-preserving, shared-by-SHA asset admission. Dry run by default. */
import {readFile,mkdir,copyFile} from 'node:fs/promises';
import {constants} from 'node:fs';
import {resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {ROOT,sourceAssetPath} from './export_map_editor_catalog.mjs';
const hash=raw=>createHash('sha256').update(raw).digest('hex');
export function inspectGlb(raw){
 if(raw.length<20||raw.toString('ascii',0,4)!=='glTF'||raw.readUInt32LE(4)!==2||raw.readUInt32LE(8)!==raw.length||raw.readUInt32LE(16)!==0x4e4f534a)throw new Error('Invalid complete GLB2');
 const jsonSize=raw.readUInt32LE(12);if(20+jsonSize>raw.length)throw new Error('Truncated GLB JSON');
 const gltf=JSON.parse(raw.toString('utf8',20,20+jsonSize));
 const external=[...(gltf.buffers||[]),...(gltf.images||[])].filter(v=>v.uri&&!v.uri.startsWith('data:')).map(v=>v.uri);
 if(external.length)throw new Error(`External GLB dependencies require explicit resource admission: ${external.join(',')}`);
 return {materials:(gltf.materials||[]).length,meshes:(gltf.meshes||[]).length};
}
async function existing(path){try{return await readFile(path);}catch(error){if(error.code==='ENOENT')return null;throw error;}}
export async function installAssets({root=ROOT,catalog=null,install=false,limit=Infinity}={}){
 if(!(limit===Infinity||Number.isSafeInteger(limit)&&limit>=0))throw new Error('Invalid nonnegative installation limit');
 catalog??=JSON.parse(await readFile(resolve(root,'godot/mafiozi_walk/data/map_editor/catalog.json'),'utf8'));
 if(catalog.schema!=='mafiozi.godot.map-editor-catalog/v1')throw new Error('Unsupported catalog schema');
 // Stage outside res://: editor auto-scan must not import a work-in-progress batch.
 const destination=resolve(root,'outputs/map_editor_asset_stage');
 const checked=[],pending=[];let installed=0,totalBytes=0,pendingBytes=0;
 // Verify the complete admission set before writing even the first file.
 for(const entry of [...catalog.resources].sort((a,b)=>a.sha256.localeCompare(b.sha256))){
  if(!/^[a-f0-9]{64}$/.test(entry.sha256)||entry.id!==entry.sha256||!Number.isSafeInteger(entry.bytes)||entry.bytes<20)throw new Error('Invalid resource receipt');
  if(!entry.sourcePaths?.length)throw new Error('Missing source paths');
  const source=sourceAssetPath('/'+entry.sourcePaths[0],root),raw=await readFile(source);
  if(hash(raw)!==entry.sha256||raw.length!==entry.bytes)throw new Error(`Source SHA/size changed: ${entry.sourcePaths[0]}`);
  const gltf=inspectGlb(raw),target=resolve(destination,entry.sha256+'.glb'),targetRaw=await existing(target);
  if(targetRaw&&(hash(targetRaw)!==entry.sha256||targetRaw.length!==entry.bytes))throw new Error(`Refusing to overwrite nonidentical target: ${target}`);
  const item={id:entry.id,source,target,proposedResPath:`res://assets/map_editor/${entry.sha256}.glb`,bytes:entry.bytes,materials:gltf.materials,meshes:gltf.meshes,status:targetRaw?'staged-verified':'pending-stage'};
  checked.push(item);totalBytes+=entry.bytes;
  if(!targetRaw){pending.push(item);pendingBytes+=entry.bytes;}
 }
 if(install&&pending.length&&limit>0){await mkdir(destination,{recursive:true});for(const item of pending.slice(0,limit)){
  // Exclusive copy prevents a concurrent creator from being overwritten.
  try{await copyFile(item.source,item.target,constants.COPYFILE_EXCL);}catch(error){if(error.code!=='EEXIST')throw error;}
  const copied=await readFile(item.target);if(hash(copied)!==item.id||copied.length!==item.bytes)throw new Error(`Post-copy mismatch: ${item.target}`);
  item.status='staged-verified';installed++;
 }}
 return {mode:install?'stage':'check',destination,resources:checked.length,totalBytes,presentBefore:checked.length-pending.length,pendingBefore:pending.length,pendingBytes,installed,remaining:pending.length-installed,items:checked,limitations:['Byte copies preserve all original meshes/materials/images/LOD; Godot import and visual/collision/gameplay parity remain unverified.','Staging is outside res://. Coordinator admission is required before any project assets/catalog changes.']};
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2),index=args.indexOf('--limit');
 if(args.includes('--check')&&args.includes('--install'))throw new Error('Choose --check OR --install');
 const result=await installAssets({install:args.includes('--install'),limit:index<0?Infinity:Number(args[index+1])});
 const {items,...summary}=result;console.log(JSON.stringify(summary));
}
