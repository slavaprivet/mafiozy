import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const outputs=path.join(root,'outputs');
const closurePath=path.join(root,'tools/godot/map_editor_printshop_shadow_v2_stage_manifest.json');
const CLOSURE_SHA='d09ec7d7a85583fb8cffeeb0160297b45ae4b30d54ad038f376e50c732f34143';
const digest=buffer=>crypto.createHash('sha256').update(buffer).digest('hex');
const samePath=(a,b)=>process.platform==='win32'?a.toLowerCase()===b.toLowerCase():a===b;
function assertInside(base,target){const r=path.relative(base,target);if(r===''||r.startsWith('..'+path.sep)||r==='..'||path.isAbsolute(r))throw Error('Path escape/root target refused');}
function safeRelative(value){if(typeof value!=='string'||!value||!value.match(/^[a-zA-Z0-9_./-]+$/)||value.includes('..')||path.isAbsolute(value)||value.includes('//')||value.endsWith('/'))throw Error('Unsafe relative path');return value;}
function inspect(target,{missing=false,directory=false}={}){
 const abs=path.resolve(target),drive=path.parse(abs).root;let cursor=drive;
 for(const part of path.relative(drive,abs).split(path.sep).filter(Boolean)){
  cursor=path.join(cursor,part);
  let stat;try{stat=fs.lstatSync(cursor);}catch(error){if(missing&&error.code==='ENOENT')return null;throw error;}
  if(stat.isSymbolicLink())throw Error('Symlink/junction refused: '+cursor);
  if(!samePath(fs.realpathSync.native(cursor),cursor))throw Error('Resolved path mismatch: '+cursor);
  if(!samePath(cursor,abs)&&!stat.isDirectory())throw Error('Non-directory ancestor');
 }
 const stat=fs.lstatSync(abs);if(directory&&!stat.isDirectory())throw Error('Expected directory');return stat;
}
function readExact(file,expectedSha,expectedBytes){
 const before=inspect(file);if(!before.isFile())throw Error('Expected regular source file');
 const fd=fs.openSync(file,'r');let bytes;
 try{const opened=fs.fstatSync(fd);if(opened.ino!==before.ino||opened.dev!==before.dev)throw Error('Source changed during open');bytes=fs.readFileSync(fd);}finally{fs.closeSync(fd);}
 const after=inspect(file);if(before.ino!==after.ino||before.dev!==after.dev||before.size!==after.size||before.mtimeMs!==after.mtimeMs)throw Error('Source changed during read');
 if(digest(bytes)!==expectedSha||(expectedBytes!==undefined&&bytes.length!==expectedBytes))throw Error('Reviewed source hash/byte count mismatch: '+file);
 return bytes;
}
function createSubdirs(base,relative){let cursor=base;for(const part of relative.split('/').slice(0,-1)){cursor=path.join(cursor,part);assertInside(base,cursor);if(!inspect(cursor,{missing:true})){inspect(path.dirname(cursor),{directory:true});fs.mkdirSync(cursor);}inspect(cursor,{directory:true});}}
function writeExclusive(base,relative,bytes){safeRelative(relative);const target=path.resolve(base,relative);assertInside(base,target);createSubdirs(base,relative);inspect(base,{directory:true});inspect(path.dirname(target),{directory:true});if(inspect(target,{missing:true}))throw Error('Overwrite refused');fs.writeFileSync(target,bytes,{flag:'wx'});readExact(target,digest(bytes),bytes.length);return {path:relative,bytes:bytes.length,sha256:digest(bytes)};}
function run(){
 const args=process.argv.slice(2);if(args.length!==1||!['--check','--stage'].includes(args[0]))throw Error('Usage: node tools/godot/stage_printshop_shadow_v2.mjs --check|--stage');
 inspect(root,{directory:true});
 const closureBytes=readExact(closurePath,CLOSURE_SHA),closure=JSON.parse(closureBytes);
 if(closure.schema!=='printshop-shadow-v2-reviewed-source-closure-v1'||closure.files.length!==7)throw Error('Reviewed closure schema mismatch');
 const targets=new Set();const prepared=closure.files.map(record=>{safeRelative(record.source);safeRelative(record.target);if(targets.has(record.target))throw Error('Duplicate target');targets.add(record.target);const file=path.resolve(root,record.source);assertInside(root,file);return {record,bytes:readExact(file,record.sha256,record.bytes)};});
 const sourceReceipt=JSON.parse(prepared[0].bytes);
 if(sourceReceipt.builder_sha256!==closure.files[1].sha256||sourceReceipt.test_sha256!==closure.files[2].sha256||sourceReceipt.cpu_checks_passed!==546||sourceReceipt.actual_scene_admitted!==false||sourceReceipt.gpu!==false)throw Error('Frozen receipt closure mismatch');
 const outputStat=inspect(outputs,{missing:true,directory:true});
 if(args[0]==='--check'){console.log(JSON.stringify({ok:true,mode:'read-only',files:7,sourceBytes:prepared.reduce((s,x)=>s+x.bytes.length,0),closure_sha256:CLOSURE_SHA,outputs_exists:!!outputStat,cpu_only:true}));return;}
 if(!outputStat){inspect(root,{directory:true});fs.mkdirSync(outputs);}
 inspect(outputs,{directory:true});
 const candidate=fs.mkdtempSync(path.join(outputs,'printshop-shadow-v2-'));
 assertInside(outputs,candidate);inspect(candidate,{directory:true});
 const written=[];
 for(const{record,bytes}of prepared){inspect(outputs,{directory:true});written.push(writeExclusive(candidate,record.target,bytes));}
 const project=Buffer.from('config_version=5\n[application]\nconfig/name="Reviewed Printshop CPU Shadow V2"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n');
 written.push(writeExclusive(candidate,'project.godot',project));
 written.push(writeExclusive(candidate,'reviewed_source_closure.json',closureBytes));
 const receipt={schema:'printshop-shadow-v2-unique-stage-receipt-v1',closure_sha256:CLOSURE_SHA,files:written,cpu_source_checks:546,native_rerun:false,gpu:false,actual_scene_admitted:false,production_wired:false};
 writeExclusive(candidate,'stage_receipt.json',Buffer.from(JSON.stringify(receipt,null,2)+'\n'));
 const actual=[];function walk(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,entry.name);inspect(f);if(entry.isDirectory())walk(f);else actual.push(path.relative(candidate,f).replaceAll(path.sep,'/'));}}walk(candidate);
 if(actual.length!==10||actual.some(x=>x.split('/').includes('.godot')||x.endsWith('.uid')||x.endsWith('.import')))throw Error('Unexpected staged output');
 console.log(JSON.stringify({ok:true,stage:candidate,files:actual.length,closure_sha256:CLOSURE_SHA,native_rerun:false,gpu:false}));
}
try{run();}catch(error){console.error('STAGE REFUSED: '+error.message);process.exitCode=1;}
