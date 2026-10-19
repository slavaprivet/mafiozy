import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {createHash} from 'node:crypto';
import {ROOT} from '../export_map_editor_catalog.mjs';

const base=resolve(ROOT);
const original=await readFile(resolve(base,'tools/godot/map_editor_candidate/scripts/map_editor/map_document.gd'),'utf8');
const candidate=await readFile(resolve(base,'tools/godot/map_editor_incremental_prepare_candidate/incremental_prepare.gd'),'utf8');
const digest=createHash('sha256').update(original).digest('hex');
if(digest!=='09b32b7623dd66aa623fd0fc469fa3feee3d84f6de60ca26d6553f8954b1911e')throw Error('MapDocument source changed; re-review exact header rule');
function body(text,name){
 const lines=text.replaceAll('\r','').split('\n');
 const index=lines.findIndex(line=>line.startsWith('static func '+name+'('));
 if(index<0)throw Error('Missing function '+name);
 const result=[];
 for(let i=index+1;i<lines.length;i++){
  if(lines[i]&&!lines[i].startsWith('\t'))break;
  if(lines[i])result.push(lines[i]);
 }
 return result.join('\n');
}
if(body(original,'_copy_header')!==body(candidate,'_copy_header_exact'))throw Error('Header copy semantics drifted from frozen MapDocument');
if(candidate.includes('Document._copy_header('))throw Error('Candidate still calls an external private helper');
const calls=candidate.match(/_copy_header_exact\(/g)||[];
if(calls.length!==4)throw Error('Expected declaration plus source/candidate header uses');
console.log(JSON.stringify({suite:'incremental-header-source-pin',checks:4,sourceSha256:digest,privateExternalCalls:0}));
