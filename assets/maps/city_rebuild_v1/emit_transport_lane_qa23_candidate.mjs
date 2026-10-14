// Write a reviewable patch/manifest only; never apply it to the shared runtime.
import fs from 'node:fs';
import crypto from 'node:crypto';
import {spawnSync,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {patchCivilian,patchNavigation,patchExport,patchInspection,patchWorld} from './transport_lane_qa23_candidate.mjs';
const root=new URL('../../../',import.meta.url),prefix='assets/maps/city_rebuild_v1/';
const edits=[[prefix+'civilian_parking_trip_source.js',patchCivilian],[prefix+'city_road_navigation.mjs',patchNavigation],[prefix+'npc_inspection_export.mjs',patchExport],[prefix+'npc_runtime_inspection.mjs',patchInspection],['world.html',patchWorld]].map(([path,patch])=>{const before=fs.readFileSync(new URL(path,root),'utf8').replace(/\r\n/g,'\n');return {path,before,after:patch(before)};});
const python='import sys,json,difflib\nfor e in json.load(sys.stdin):\n sys.stdout.write("".join(difflib.unified_diff(e["before"].splitlines(True),e["after"].splitlines(True),fromfile="a/"+e["path"],tofile="b/"+e["path"])))';
const diff=spawnSync('py',['-3','-c',python],{input:JSON.stringify(edits),encoding:'utf8',maxBuffer:20*1024*1024,env:{...process.env,PYTHONIOENCODING:'utf-8'}});if(diff.status!==0)throw Error(diff.stderr);
const patchText=diff.stdout.replace(/\r\n/g,'\n'),hash=s=>crypto.createHash('sha256').update(s).digest('hex');
const manifest={status:'CANDIDATE_ONLY_DO_NOT_APPLY_BEFORE_ROOT_SHA',head:execFileSync('git',['rev-parse','HEAD'],{cwd:fileURLToPath(root),encoding:'utf8'}).trim(),files:edits.map(e=>({path:e.path,beforeNormalizedSha256:hash(e.before),afterNormalizedSha256:hash(e.after)})),runtimeWritten:false};
fs.writeFileSync(new URL('outputs/transport_lane_qa23_candidate.patch',root),patchText);
fs.writeFileSync(new URL('outputs/transport_lane_qa23_candidate_manifest.json',root),JSON.stringify(manifest,null,2));
console.log({status:manifest.status,files:manifest.files.length,patchBytes:Buffer.byteLength(patchText),head:manifest.head});
