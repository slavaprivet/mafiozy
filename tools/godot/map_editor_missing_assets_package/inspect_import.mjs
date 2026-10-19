/** Read-only inspection of one completed isolated 188-GLB Godot import. */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {ROOT} from '../export_map_editor_catalog.mjs';

const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function inside(base,target){const rel=path.relative(base,target);return !!rel&&!rel.startsWith('..')&&!path.isAbsolute(rel);}
async function read(file,base){
 if(!inside(base,file))throw Error(`Path escaped stage: ${file}`);
 const stat=await fs.lstat(file);
 if(!stat.isFile()||stat.isSymbolicLink()||!inside(base,await fs.realpath(file)))throw Error(`Missing/redirected import file: ${file}`);
 return fs.readFile(file);
}
export async function inspect(stage){
 const stageReal=await fs.realpath(stage);
 const outputReal=await fs.realpath(path.join(ROOT,'outputs'));
 if(!inside(outputReal,stageReal))throw Error('Import stage outside outputs');
 const snapshot=JSON.parse((await read(path.join(stageReal,'import_source_snapshot.json'),stageReal)).toString('utf8'));
 const manifest=JSON.parse((await read(path.join(stageReal,'test_import_manifest.json'),stageReal)).toString('utf8'));
 if(snapshot.checkedCatalogPaths!==196||snapshot.package.missing!==188||snapshot.retained.length!==5||snapshot.supplemental.length!==3||manifest.resources.length!==196)throw Error('Stage receipt/catalog scope mismatch');
 const log=await read(path.join(stageReal,'import.log'),stageReal);
 const verifyLog=await read(path.join(stageReal,'verify.log'),stageReal);
 const diagnostics=[...log.toString('utf8').split(/\r?\n/),...verifyLog.toString('utf8').split(/\r?\n/)].filter(line=>/\b(?:SCRIPT ERROR|ERROR|WARNING|FAILED|UNABLE)\b|ПРЕДУПРЕЖДЕНИЕ|ОШИБКА/i.test(line));
 const resultLine=verifyLog.toString('utf8').split(/\r?\n/).find(line=>line.startsWith('{"checks":'));
 if(!resultLine)throw Error('Native verification result missing');
 const native=JSON.parse(resultLine);
 if(native.failures.length||native.checks!==785||native.loaded!==196||native.missing!==188||native.present!==8)throw Error('Native resource verification failed');
 let missing=0,present=0,cacheBytes=0;
 const imports=[];
 for(const row of manifest.resources){
  const relative=row.proposedResPath.slice('res://'.length);
  const asset=await read(path.join(stageReal,relative),stageReal);
  if(asset.length!==row.bytes||sha(asset)!==row.sha256)throw Error(`Raw stage GLB drift: ${row.sha256}`);
  const sidecar=await read(path.join(stageReal,relative+'.import'),stageReal);
  const content=sidecar.toString('utf8');
  const source=`source_file="${row.proposedResPath}"`;
  const found=content.match(/^path="(res:\/\/\.godot\/imported\/[^"\r\n]+\.scn)"$/m);
  if(!content.includes('importer="scene"')||!content.includes('type="PackedScene"')||!content.includes(source)||!found||!content.includes(`dest_files=["${found[1]}"]`))throw Error(`Import sidecar mismatch: ${row.sha256}`);
  const generated=await read(path.join(stageReal,found[1].slice('res://'.length)),stageReal);
  if(generated.length===0)throw Error(`Empty generated scene: ${row.sha256}`);
  cacheBytes+=generated.length;
  imports.push({sha256:row.sha256,source:relative,sidecarSha256:sha(sidecar),cache:found[1],cacheSha256:sha(generated),cacheBytes:generated.length,group:row.packagePath?'missing-production':'preexisting-production'});
  if(row.packagePath)missing++;else present++;
 }
 if(missing!==188||present!==8)throw Error('Import group count mismatch');
 return {schema:'mafiozi.map-editor-188-import-verification/v1',stage:stageReal,sourceSnapshotSha256:sha(await read(path.join(stageReal,'import_source_snapshot.json'),stageReal)),packageManifestSha256:snapshot.package.manifestSha256,catalogSha256:snapshot.catalogSha256,counts:{importedGLB:imports.length,missingProduction:missing,presentProduction:present,checkpointSupplemental:3,checkpointRetained:5,generatedSceneBytes:cacheBytes,nativeChecks:native.checks,nativeLoaded:native.loaded},logs:{import:{sha256:sha(log),bytes:log.length},verify:{sha256:sha(verifyLog),bytes:verifyLog.length},diagnostics},imports};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 const args=process.argv.slice(2);
 if(args.length!==1)throw Error('Usage: inspect_import.mjs <absolute-stage-path>');
 const result=await inspect(args[0]);
 const receipt=path.join(result.stage,'import_verification.json');
 await fs.writeFile(receipt,JSON.stringify(result,null,2)+'\n',{flag:'wx'});
 console.log(JSON.stringify({stage:result.stage,receipt,receiptSha256:sha(await fs.readFile(receipt)),counts:result.counts,logs:result.logs}));
}
