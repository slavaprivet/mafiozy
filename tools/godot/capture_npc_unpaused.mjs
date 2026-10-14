// Unpaused instrumentation profile. Preparation imports no application code.
// Browser execution always requires a fresh exact-plan Root22 GO.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {spawn} from 'node:child_process';
import {createRequire} from 'node:module';
import {fileURLToPath} from 'node:url';
import {bootstrapSource} from './npc_observer_collector.mjs';
import {SOURCE_PINS,transformNpcObserverResponse} from './npc_observer_transform.mjs';
import {readObservedRoster} from './read_npc_observed_roster.mjs';
import {validateRootGo,createBudget,ownedProcessAlive,terminateOwnedPid,LIMITS} from './npc_capture_lifecycle.mjs';

export const REPO=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
export const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
export const CONFIG=Object.freeze({capacity:32768,maxScopes:64,maxStringLength:4096,maxStringUnits:1048576});
const SELF=fileURLToPath(import.meta.url);
const PRODUCERS=['tools/godot/capture_npc_unpaused.mjs','tools/godot/npc_observer_collector.mjs','tools/godot/npc_observer_transform.mjs','tools/godot/npc_capture_lifecycle.mjs','tools/godot/read_npc_observed_roster.mjs'];
const CONTEXT_SOURCES=['tools/city_rebuild_walk.html','world_walk_host.mjs','assets/maps/city_rebuild_v1/walk_entry.mjs','assets/maps/city_rebuild_v1/npc_native_navigation.mjs','assets/maps/city_rebuild_v1/world_traffic_presentation.mjs','assets/maps/city_rebuild_v1/exploration_railway_plan.mjs','assets/maps/city_rebuild_v1/exploration_railway.mjs'];
export function responsePath(url){const name=decodeURIComponent(new URL(url).pathname.slice(1));return name==='walk'?'tools/city_rebuild_walk.html':name;}
export function expectedSourceDocument(entry){
 const u=new URL(canonicalEntry(entry));u.pathname='/world.html';u.search='?direct=1&previewcity=1&render=3d&renderer=walk';
 return u.href;
}
export function validateNavigationTrace(trace,entry,finalUrl){
 const expected=expectedSourceDocument(entry);
 if(!Array.isArray(trace)||trace.length!==2||trace[0]!==canonicalEntry(entry)||trace[1]!==expected||finalUrl!==expected)throw Error('unexpected_source_document_transition');
 return expected;
}
export function storageBootstrapSource(entry){return `if(location.origin===${JSON.stringify(new URL(canonicalEntry(entry)).origin)}){try{globalThis.__npcObserverFreshStorage22={url:location.href,local:localStorage.length,session:sessionStorage.length};}catch(e){globalThis.__npcObserverFreshStorage22={error:'storage_receipt_failed'};}}`;}

export function canonicalEntry(value){
 const u=new URL(value);
 if(u.protocol!=='http:'||!['127.0.0.1','localhost'].includes(u.hostname)||u.port!=='18538'||u.pathname!=='/walk'||u.search||u.hash||u.username||u.password)throw Error('exact_uncredentialed_source_route_required');
 return u.href;
}
export function outputPath(value){
 const result=path.resolve(REPO,value),root=path.resolve(REPO,'outputs');
 if(!result.startsWith(root+path.sep))throw Error('output_outside_workspace_outputs');
 return result;
}
export function prepareProfile(config=CONFIG,entry='http://127.0.0.1:18538/walk'){
 const original_entry_url=canonicalEntry(entry),bootstrap=bootstrapSource(config),storageBootstrap=storageBootstrapSource(entry),responses=[];
 for(const name of Object.keys(SOURCE_PINS).sort()){
  const original=fs.readFileSync(path.join(REPO,name)),changed=transformNpcObserverResponse(name,original);
  responses.push({path:name,original,changed,mode:'instrumented'});
 }
 for(const name of CONTEXT_SOURCES){const original=fs.readFileSync(path.join(REPO,name));responses.push({path:name,original,changed:{bytes:original,edits:[]},mode:'unchanged_context'});}
 const plan={schema:'mafiozi.npc-unpaused-profile/v1',kind:'UNPAUSED_INSTRUMENTED_SOURCE_OBSERVATION',
  original_entry_url,config:{...config},bootstrap_sha256:sha(bootstrap),storage_bootstrap_sha256:sha(storageBootstrap),
  producer_receipts:PRODUCERS.map(name=>({path:name,sha256:sha(fs.readFileSync(path.join(REPO,name)))})),
  response_receipts:responses.map(({path:name,original,changed,mode})=>({path:name,mode,original_sha256:sha(original),instrumented_sha256:sha(changed.bytes),edits:changed.edits})),
  runtime:{chrome:'C:/Program Files/Google/Chrome/Application/chrome.exe',python:path.join(os.homedir(),'AppData/Local/Programs/Python/Python314/python.exe'),playwright_dependencies:path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules'),monitor:'tools/city_rebuild_monitor.py',monitor_sha256:sha(fs.readFileSync(path.join(REPO,'tools/city_rebuild_monitor.py')))},
  limits:LIMITS,registered_frame:false,physical_admission:false,root_restore_allowed:false,
  missing_policy:'Naturally unvisited values stay ABSENT. No full exporter admission, no clock/RNG/storage override, no debugger pauses.'};
 return {plan,bootstrap,storageBootstrap,responses,plan_sha256:sha(JSON.stringify(plan))};
}
export function writePreparedProfile(profile,destination){
 const out=outputPath(destination);fs.mkdirSync(out,{recursive:true});
 function writeOnce(name,bytes){const target=path.join(out,name);fs.mkdirSync(path.dirname(target),{recursive:true});if(fs.existsSync(target)){if(sha(fs.readFileSync(target))!==sha(bytes))throw Error('frozen_profile_path_changed:'+name);return;}fs.writeFileSync(target,bytes);}
 writeOnce('PLAN.json',JSON.stringify(profile.plan,null,2)+'\n');writeOnce('BOOTSTRAP.js',profile.bootstrap);
 writeOnce('STORAGE_BOOTSTRAP.js',profile.storageBootstrap);
 for(const row of profile.responses){writeOnce('original/'+row.path,row.original);writeOnce('instrumented/'+row.path,row.changed.bytes);}
 writeOnce('PLAN_SHA256.txt',profile.plan_sha256+'\n');
 return {output:out,plan_sha256:profile.plan_sha256,responses:profile.responses.length,browser_started:false,server_started:false};
}
// Unit-testable response guard. It never fetches or fulfils a browser response.
export function approvedResponse(profile,url,status,bytes){
 const u=new URL(url),origin=new URL(profile.plan.original_entry_url).origin;
 if(u.origin!==origin)return null;
 const name=responsePath(url),row=profile.responses.find(x=>x.path===name);
 if(!row)return null;
 if(status!==200||sha(bytes)!==sha(row.original))throw Error('original_HTTP_mismatch:'+name);
 return row;
}
export function originalResponseHeaders(headers){
 const result={};for(const [key,value]of Object.entries(headers))if(!['content-length','content-encoding','transfer-encoding','etag','last-modified'].includes(key.toLowerCase()))result[key]=value;
 result['cache-control']='no-store';return result;
}
async function probeOriginal(profile,cancelled=()=>false){
 const rows=[];
 for(const {path:name,original}of profile.responses){
  if(cancelled())throw Error('probe_cancelled');
  try{const response=await fetch(new URL('/'+name,profile.plan.original_entry_url),{signal:AbortSignal.timeout(4000),redirect:'error'}),bytes=Buffer.from(await response.arrayBuffer());rows.push({path:name,status:response.status,sha256:sha(bytes),exact:response.status===200&&sha(bytes)===sha(original)});}
  catch(error){rows.push({path:name,exact:false,error:error.message,cause:error.cause?.code});break;}
 }
 return {known:rows.length===profile.responses.length&&rows.every(r=>r.exact),rows};
}

export async function cleanupOwnedProcesses(owned,record,cleanup=createBudget(LIMITS.cleanup_ms)){
 for(const item of owned.slice().reverse()){
  if(!item.exited&&item.pid)try{record.cleanup.push({role:item.role,...terminateOwnedPid(item.pid,{identity:item.identity})});}catch(e){record.errors.push({event:'terminate_owned',message:e.message||String(e)});}
  try{await cleanup.run('wait_exit',async()=>{while(!item.exited&&!item.spawn_error){if(cleanup.remaining()<=0)throw Error('cleanup_deadline');await new Promise(r=>setTimeout(r,20));}},2500);}catch(e){record.errors.push({event:'exit_unconfirmed',message:e.message||String(e)});}
  record.cleanup.push({role:item.role,pid:item.pid,exit_confirmed:item.exited,spawn_error:item.spawn_error??null});
 }
 return owned.every(p=>p.exited||p.spawn_error&&!p.pid);
}

export async function executeProfile(profile,go,destination){
 validateRootGo(profile.plan,go,sha);
 if(ownedProcessAlive(go.native_process_id))throw Error('native_game_still_running');
 // Recompute immediately before acquiring any process/network resources.
 const current=prepareProfile(profile.plan.config,profile.plan.original_entry_url);
 if(sha(JSON.stringify(profile.plan))!==profile.plan_sha256||current.plan_sha256!==profile.plan_sha256)throw Error('profile_changed_after_review');
 // Never execute caller-owned buffers: GO covers fresh bytes and their exact closure.
 profile=current;
 const out=outputPath(destination);if(fs.existsSync(out))throw Error('new_run_directory_required');fs.mkdirSync(out,{recursive:true});
 const runId=crypto.randomUUID(),budget=createBudget(),owned=[],pending=new Set();
 const record={schema:'mafiozi.npc-unpaused-run/v1',run_id:runId,kind:profile.plan.kind,status:'CAPTURE_INCOMPLETE_HOLD',plan_sha256:profile.plan_sha256,root_go:go,bootstrap_sha256:profile.plan.bootstrap_sha256,source_responses:[],errors:[],cleanup:[],profile:{user_profile_used:false},registered_frame:false,physical_admission:false,root_restore_allowed:false,debugger_enabled:false,full_source_capture:false};
 let watchdog,browser,context,page,tmp,stopping=false;const save=()=>fs.writeFileSync(path.join(out,'RUN.json'),JSON.stringify(record,null,2)+'\n');
 const error=(event,e)=>record.errors.push({event,message:e.message||String(e)});
 const ipc=(message)=>{if(watchdog?.connected)watchdog.send(message,e=>{if(e&&!stopping)error('watchdog_ipc',e);});};
 async function spawnOwned(role,executable,args,marker){
  const identity={parent_pid:process.pid,spawn_started_ms:Date.now(),command_marker:marker};
  const stdout=fs.openSync(path.join(out,role+'.stdout.log'),'wx'),stderr=fs.openSync(path.join(out,role+'.stderr.log'),'wx');let child;
  try{child=spawn(executable,args,{cwd:REPO,windowsHide:true,stdio:['ignore',stdout,stderr]});}finally{fs.closeSync(stdout);fs.closeSync(stderr);}
  const item={role,child,pid:child.pid??null,identity,exited:false};owned.push(item);
  child.on('error',e=>{item.spawn_error=e.message;error(role,e);});
  child.once('exit',(code,signal)=>{item.exited=true;item.exit_code=code;item.signal=signal;ipc({type:'exited',pid:item.pid});});
  await budget.run(role+'_spawn',()=>new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);}));
  if(item.exited)throw Error(role+'_exited_before_ownership');
  await budget.run(role+'_watchdog',()=>new Promise((resolve,reject)=>{
   const listener=m=>{if(m?.type==='owned'&&m.pid===item.pid){watchdog.off('message',listener);resolve();}};watchdog.on('message',listener);
   watchdog.send({type:'own',pid:item.pid,role,identity},e=>{if(e){watchdog.off('message',listener);reject(e);}});
  }));
  if(item.exited){ipc({type:'exited',pid:item.pid});throw Error(role+'_exited_during_ownership');}
  return item;
 }
 try{
  save();
  const parentIdentity={parent_pid:process.ppid,spawn_started_ms:Date.now()-process.uptime()*1000,command_marker:path.basename(SELF)};
  watchdog=spawn(process.execPath,[path.join(REPO,'tools/godot/npc_capture_lifecycle.mjs'),'--watchdog',path.join(out,'WATCHDOG.json'),String(process.pid),String(Math.ceil(budget.remaining()+LIMITS.cleanup_ms)),JSON.stringify(parentIdentity)],{windowsHide:true,stdio:['ignore','ignore','ignore','ipc']});
  watchdog.on('error',e=>error('watchdog',e));await budget.run('watchdog_spawn',()=>new Promise((resolve,reject)=>{watchdog.once('spawn',resolve);watchdog.once('error',reject);}));
  let probe=await budget.run('original_probe',()=>probeOriginal(profile,()=>stopping||budget.remaining()<=0),60000);record.probe=probe;
  if(!probe.known&&go.start_source_monitor){
   if(!probe.rows.length||!probe.rows.every(r=>r.cause==='ECONNREFUSED'))throw Error('existing_or_mismatched_source_endpoint');
   const monitor=path.join(REPO,profile.plan.runtime.monitor);await spawnOwned('source_server',profile.plan.runtime.python,[monitor,'--port','18538'],'city_rebuild_monitor.py --port 18538');
   for(let i=0;i<20&&!probe.known;i++){if(stopping||budget.remaining()<=0)throw Error('capture_deadline');await budget.run('server_wait',()=>new Promise(r=>setTimeout(r,250)));probe=await budget.run('original_probe_retry',()=>probeOriginal(profile,()=>stopping||budget.remaining()<=0),60000);}
   record.probe=probe;
  }
  if(!probe.known)throw Error('original_source_not_ready');
  const require=createRequire(import.meta.url),{chromium}=require(require.resolve('playwright',{paths:[profile.plan.runtime.playwright_dependencies]}));
  tmp=fs.mkdtempSync(path.join(os.tmpdir(),'mafiozi-unpaused-'));fs.writeFileSync(path.join(tmp,'OWNED_CAPTURE_PROFILE'),runId);record.profile.path=tmp;record.profile.created_empty=true;
  const chrome=await spawnOwned('browser',profile.plan.runtime.chrome,['--headless=new','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1','--user-data-dir='+tmp,'--no-first-run','--no-default-browser-check','about:blank'],'--user-data-dir='+tmp);record.profile.pid=chrome.pid;
  const portFile=path.join(tmp,'DevToolsActivePort');await budget.run('debug_transport_endpoint',async()=>{while(!fs.existsSync(portFile)){if(stopping||budget.remaining()<=0)throw Error('capture_deadline');if(chrome.exited)throw Error('browser_exited');await new Promise(r=>setTimeout(r,50));}},20000);
  const [port,endpoint]=fs.readFileSync(portFile,'utf8').trim().split(/\r?\n/);if(!/^\d+$/.test(port)||!endpoint.startsWith('/devtools/browser/'))throw Error('invalid_own_browser_endpoint');
  // CDP transport only. No Debugger.enable/pause/breakpoint/step calls exist here.
  browser=await budget.run('connect_browser',()=>chromium.connectOverCDP('ws://127.0.0.1:'+port+endpoint,{timeout:15000}),16000);
  if(browser.contexts().length!==1)throw Error('unexpected_contexts');context=browser.contexts()[0];if(context.pages().length!==1)throw Error('unexpected_pages');page=context.pages()[0];
  await budget.run('bootstrap_install',()=>context.addInitScript({content:profile.bootstrap}));
  await budget.run('storage_receipt_install',()=>context.addInitScript({content:profile.storageBootstrap}));
  page.on('pageerror',e=>error('pageerror',e));
  record.navigation=[];
  const expectedDocument=expectedSourceDocument(profile.plan.original_entry_url);
  page.on('framenavigated',frame=>{if(frame!==page.mainFrame())return;const url=frame.url();record.navigation.push(url);if(url!==profile.plan.original_entry_url&&url!==expectedDocument)error('navigation',Error('unexpected_main_document:'+url));});
  await budget.run('route_install',()=>context.route('**/*',route=>{
   if(stopping)return route.abort();
   const task=budget.run('source_response',async()=>{
    const request=route.request(),u=new URL(request.url()),name=responsePath(request.url());
    if(u.origin!==new URL(profile.plan.original_entry_url).origin||!profile.responses.some(r=>r.path===name)){await route.continue();return;}
    if(request.method()!=='GET')throw Error('source_method');
    const response=await route.fetch({timeout:4500,maxRedirects:0}),bytes=await response.body(),row=approvedResponse(profile,response.url(),response.status(),bytes);
    if(!row||response.url()!==request.url())throw Error('unexpected_source_redirect');
    const receipt={path:name,url:request.url(),original_http_sha256:sha(bytes),instrumented_response_sha256:sha(row.changed.bytes),status:response.status(),fulfill_status:'pending'};
    await route.fulfill({response,headers:originalResponseHeaders(response.headers()),body:row.changed.bytes});
    receipt.fulfill_status='fulfilled';record.source_responses.push(receipt);
   }).catch(async e=>{error('source_response',e);await route.abort().catch(()=>{});}).finally(()=>pending.delete(task));pending.add(task);return task;
  }));
  await budget.run('navigate',()=>page.goto(profile.plan.original_entry_url,{waitUntil:'commit',timeout:20000}),21000);
  // The original /walk module deliberately location.replace()s to the source
  // world document. Its first commit is not the registration context.
  await budget.run('source_document',()=>page.waitForURL(expectedDocument,{waitUntil:'domcontentloaded',timeout:30000}),31000);
  validateNavigationTrace(record.navigation,profile.plan.original_entry_url,page.url());
  if(record.source_responses.filter(r=>r.path==='world.html'&&r.url===expectedDocument&&r.fulfill_status==='fulfilled').length!==1)throw Error('source_world_response_not_fulfilled_once');
  if(record.errors.length)throw Error('source_boot_errors');
  record.source_boot={entry_url:profile.plan.original_entry_url,final_url:page.url(),world_response_sha256:SOURCE_PINS['world.html'],instrumented_world_sha256:profile.responses.find(r=>r.path==='world.html').changed.instrumentedSha256,initial_status:await budget.run('source_boot_status',()=>page.evaluate(()=>globalThis.__mafioziNpcObserver22?.status()??null))};
  if(record.source_boot.initial_status?.schema!=='mafiozi.scalar-observer-status/v1'||record.source_boot.initial_status.fault||record.source_boot.initial_status.sealed)throw Error('source_world_bootstrap_missing_or_held');
  await budget.run('natural_registration',async()=>{
   for(;;){if(stopping||budget.remaining()<=0)throw Error('capture_deadline');validateNavigationTrace(record.navigation,profile.plan.original_entry_url,page.url());if(record.errors.length)throw Error('capture_errors');const status=await budget.run('collector_status',()=>page.evaluate(()=>globalThis.__mafioziNpcObserver22?.status()??null));
    if(status){record.collector_status=status;if(status.fault)throw Error('collector_hold:'+status.fault);if(status.registration_end_count>=1&&status.openScopes===0)break;}
    await new Promise(r=>setTimeout(r,100));
   }
  },60000);
  const observed=await budget.run('sealed_snapshot',()=>page.evaluate(()=>({snapshot:globalThis.__mafioziNpcObserver22.snapshot(),storage:globalThis.__npcObserverFreshStorage22,url:location.href})));
  record.final_url=observed.url;record.fresh_storage=observed.storage;
  validateNavigationTrace(record.navigation,profile.plan.original_entry_url,observed.url);
  if(!observed.storage||observed.storage.error||observed.storage.local!==0||observed.storage.session!==0)throw Error('fresh_storage_unproved');
  if(observed.snapshot?.schema!=='mafiozi.scalar-observer-packet/v1'||observed.snapshot.status?.state!=='SEALED'||observed.snapshot.status?.fault||observed.snapshot.status?.openScopes!==0||observed.snapshot.status?.registration_end_count<1)throw Error('sealed_packet_incomplete');
  fs.writeFileSync(path.join(out,'OBSERVED_SCALARS.json'),JSON.stringify(observed.snapshot,null,2)+'\n');record.scalar_packet_sha256=sha(fs.readFileSync(path.join(out,'OBSERVED_SCALARS.json')));
  await budget.run('pending_responses',()=>Promise.all([...pending]),10000);
  for(const name of ['world.html','assets/maps/city_rebuild_v1/walk_preview.mjs'])if(!record.source_responses.some(r=>r.path===name))throw Error('registration_source_response_missing:'+name);
  const producer=name=>profile.plan.producer_receipts.find(r=>r.path==='tools/godot/'+name).sha256;
  const roster=readObservedRoster(fs.readFileSync(path.join(out,'OBSERVED_SCALARS.json')),{data_sha256:record.scalar_packet_sha256,run_id:runId,world_source_sha256:SOURCE_PINS['world.html'],collector_sha256:producer('npc_observer_collector.mjs'),transformer_sha256:producer('npc_observer_transform.mjs'),runner_sha256:producer('capture_npc_unpaused.mjs'),test_only:false});
  fs.writeFileSync(path.join(out,'OBSERVED_ROSTER.json'),JSON.stringify(roster,null,2)+'\n');record.roster={status:roster.status,rows:roster.rows.length,reasons:roster.reasons,sha256:sha(fs.readFileSync(path.join(out,'OBSERVED_ROSTER.json')))};
  if(!record.errors.length){record.status='OBSERVED_SCALARS_REQUIRES_PROVIDER_VALIDATION';record.source_context_sha256=sha(JSON.stringify({run_id:runId,plan_sha256:profile.plan_sha256,scalar_packet_sha256:record.scalar_packet_sha256,source_responses:record.source_responses}));}
 }catch(e){error('capture',e);}
 finally{
  stopping=true;save();const cleanup=createBudget(LIMITS.cleanup_ms);
  if(browser)try{await cleanup.run('close_browser',()=>browser.close(),2000);}catch(e){error('close_browser',e);}
  const allExited=await cleanupOwnedProcesses(owned,record,cleanup);record.profile.parents_exited=allExited;
  if(allExited&&tmp)try{if(path.dirname(path.resolve(tmp))!==path.resolve(os.tmpdir())||!path.basename(tmp).startsWith('mafiozi-unpaused-')||fs.readFileSync(path.join(tmp,'OWNED_CAPTURE_PROFILE'),'utf8')!==runId)throw Error('profile_identity_unproved');fs.rmSync(tmp,{recursive:true,force:false});record.profile.removed=true;}catch(e){error('profile_cleanup',e);}
  if(record.errors.length||!allExited)record.status='CAPTURE_INCOMPLETE_HOLD';
  record.root_restore_requirement='Root independently verifies browser descendants and source server; parent exits are not whole-tree proof.';save();
  if(watchdog?.connected){if(allExited)ipc({type:'complete'});else watchdog.disconnect();}
 }
 return {status:record.status,output:out,errors:record.errors.length,registered_frame:false,physical_admission:false,root_restore_allowed:false};
}
if(process.argv[1]&&path.resolve(process.argv[1])===SELF){
 const args=process.argv.slice(2),arg=(key,otherwise)=>args.includes(key)?args[args.indexOf(key)+1]:otherwise;
 if(args.includes('--root-go')){
  const expected=JSON.parse(fs.readFileSync(arg('--plan'))),profile=prepareProfile(expected.config,expected.original_entry_url);
  if(sha(JSON.stringify(expected))!==profile.plan_sha256)throw Error('reviewed_plan_changed');
  const result=await executeProfile(profile,JSON.parse(fs.readFileSync(arg('--root-go'))),arg('--out','outputs/artist22_unpaused_run-'+Date.now()));console.log(JSON.stringify(result));if(result.errors)process.exitCode=2;
 }else console.log(JSON.stringify(writePreparedProfile(prepareProfile(),arg('--out','outputs/artist22_unpaused_profile'))));
}
