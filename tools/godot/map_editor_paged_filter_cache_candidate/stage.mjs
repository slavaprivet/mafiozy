/** Optional source-only fixture; never changes the frozen assembly or live project. */
import {readFile,writeFile,lstat,realpath} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {dirname,join,resolve} from 'node:path';
import {fileURLToPath} from 'node:url';
import {stageAssembly} from '../stage_map_editor_assembly.mjs';

const here=dirname(fileURLToPath(import.meta.url));
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const entries=[
 ['paged_filter_panel.gd','paged_filter_panel.gd'],
 ['paged_setup_once_controller.gd','paged_setup_once_controller.gd'],
 ['test_paged_filter_cache.gd','test_paged_filter_cache.gd'],
 ['test_paged_setup_once.gd','test_paged_setup_once.gd'],
];
const args=process.argv.slice(2);
if(args.length>1||args.some(x=>!['--check','--stage'].includes(x)))throw Error('Use --check or --stage');
const stage=args.includes('--stage');
const own=[];
for(const [name,target] of entries){
 const path=resolve(here,name), stat=await lstat(path);
 if(!stat.isFile()||stat.isSymbolicLink()||await realpath(path)!==path)throw Error('Candidate file changed type: '+name);
 const bytes=await readFile(path);
 own.push({name,target,bytes,sha256:sha(bytes)});
}
const assembled=await stageAssembly({stage,procedural:true,transport:true,registryPerf:true,authoredPerf:true,pagedEditor:true});
if(stage){
 for(const file of own){
  const path=join(assembled.destination,file.target);
  await writeFile(path,file.bytes,{flag:'wx'});
  if(sha(await readFile(path))!==file.sha256)throw Error('Candidate readback changed: '+file.name);
 }
 const sourceReceipt=await readFile(join(assembled.destination,'source_receipt.json'));
 await writeFile(join(assembled.destination,'filter_cache_receipt.json'),JSON.stringify({schema:'mafiozi.map-editor.paged-filter-optional/v1',sourceReceiptSha256:sha(sourceReceipt),files:own.map(({target,bytes,sha256})=>({path:target,bytes:bytes.length,sha256})),productionWired:false,gpu:false},null,2)+'\n',{flag:'wx'});
}
console.log(JSON.stringify({mode:stage?'stage':'check',destination:assembled.destination,fullSourceIds:9901,baseFiles:assembled.files.length,candidateFiles:own.map(({target,bytes,sha256})=>({path:target,bytes:bytes.length,sha256})),gpu:false,productionWired:false}));
