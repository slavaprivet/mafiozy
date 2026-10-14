// Preparation is CPU/read-only. Browser execution is gated by a fresh explicit
// Root GPU-window receipt. This is a coding/debugger test, not Windows UI input.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {repo,hash,worldSHA,sourceFunction} from './npc_startup_source_vm.mjs';
import {LIMITS,validateRootGo,createBudget,newFirstLedger,observeFirst,ownedProcessAlive,terminateOwnedPid} from './npc_capture_lifecycle.mjs';
const self=fileURLToPath(import.meta.url),out=path.join(repo,'outputs/astra21_npc_registered_capture_plan');
const WALK='assets/maps/city_rebuild_v1/walk_preview.mjs';
const sourcePaths=['tools/godot/capture_npc_registered_baseline.mjs','tools/godot/npc_capture_lifecycle.mjs','tools/godot/npc_startup_source_vm.mjs','world.html','world_walk_host.mjs','tools/city_rebuild_walk.html','tools/city_rebuild_monitor.py',WALK,'assets/maps/city_rebuild_v1/walk_entry.mjs','assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs','assets/maps/city_rebuild_v1/npc_native_navigation.mjs','assets/maps/city_rebuild_v1/exploration_railway_plan.mjs','assets/maps/city_rebuild_v1/exploration_railway.mjs','assets/maps/city_rebuild_v1/mercenary_world.js','tools/godot/export_npc_dynamic_frame.mjs','tools/godot/export_npc_mercenary_colliders.mjs'];
const sources=()=>sourcePaths.map(p=>{const b=fs.readFileSync(path.join(repo,p));return{path:p,bytes:b.length,sha256:hash(b)}});
const read=p=>fs.readFileSync(path.join(repo,p),'utf8');
const line=(p,needle)=>{const code=read(p),index=code.indexOf(needle);if(index<0)throw Error('Missing exact capture anchor:'+needle);return code.slice(0,index).split('\n').length-1;};
const column=(p,needle)=>{const code=read(p),index=code.indexOf(needle);if(index<0)throw Error('Missing exact capture column:'+needle);return index-code.lastIndexOf('\n',index)-1;};
const anchors=[
 {name:'registration_before_call',suffix:WALK,line:line(WALK,' npcBridge?.registerWalkNpcNavigationResolver?.(npcNativeNavigation.query);')},
 {name:'registration_after_call',suffix:WALK,line:line(WALK,' npcNativePerception=createNpcNativePerception(')},
 {name:'getter_entry',suffix:'world.html',line:line('world.html',' const rows=[];for(const car of CARS)if(car&&!car._nativeParkingPending')},
 {name:'getter_before_return',suffix:'world.html',line:line('world.html'," return {frame:typeof prevT==='number'?prevT:0,rows};")},
 {name:'rail_actual_blocks',suffix:'assets/maps/city_rebuild_v1/exploration_railway_plan.mjs',line:line('assets/maps/city_rebuild_v1/exploration_railway_plan.mjs',' function blocks(x,z,r=.36)')},
 {name:'logical_after_actual_ensure',suffix:'assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs',line:line('assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs','  blocks(x,z,body={}){ensure();const bucket='),column:column('assets/maps/city_rebuild_v1/npc_logical_vehicle_binding.mjs','const bucket=grid.get(Math.floor(x/cellSize)')},
 {name:'native_after_dynamic',suffix:'assets/maps/city_rebuild_v1/npc_native_navigation.mjs',line:line('assets/maps/city_rebuild_v1/npc_native_navigation.mjs','  counts.queries++;if(blocked)')}
];
export function urlCheck(value){const u=new URL(value);if(!['localhost','127.0.0.1'].includes(u.hostname)||u.protocol!=='http:'||u.port!=='18538'||u.pathname!=='/walk'||u.search||u.hash||u.username||u.password)throw Error('Require exact uncredentialed original loopback18538 /walk route without query/hash');return u;}
const rawSerializer=`function pack(value){const floats=[];const seen=new WeakSet();function v(x,p){if(typeof x==='number'){const a=new Uint8Array(8);new DataView(a.buffer).setFloat64(0,x,true);floats.push({path:p,bytes_le:Array.from(a)});return Number.isFinite(x)?x:null;}if(x===undefined)return undefined;if(x===null||typeof x==='string'||typeof x==='boolean')return x;if(typeof x==='function')throw Error('Uncaptured callable value');if(typeof x!=='object')throw Error('Unsupported source value');if(seen.has(x))throw Error('Cycle in source capture');seen.add(x);let z;if(Array.isArray(x))z=x.map((e,i)=>v(e,p.concat(i)));else{z={};for(const k of Object.keys(x)){const e=v(x[k],p.concat(k));if(e!==undefined)z[k]=e;}}seen.delete(x);return z;}return{data:v(value,[]),data_float64:floats};}`;
const registrationExpr=`(()=>{${rawSerializer}
 const fleetRows=fleet?.records?.map(record=>({id:record.id,car:{profile:record.car?.profile,object:record.car?.object?{position:{x:record.car.object.position.x,y:record.car.object.position.y,z:record.car.object.position.z},rotation:{y:record.car.object.rotation.y},scale:{x:record.car.object.scale.x,y:record.car.object.scale.y,z:record.car.object.scale.z},visible:record.car.object.visible}:null}}));
 const gate=window.MafioziMercenaries?.canUseLocalEffects;
 const gateResult=typeof gate==='function'?{known:true,status:'returned',value:gate.call(window.MafioziMercenaries),observation:'additional pure source gate read at registration'}:{known:true,status:'absent'};
 const readStorage=key=>{try{return{known:true,status:'returned',value:localStorage.getItem(key),observation:'read-only exact isolated profile API observation'}}catch(e){return{known:true,status:'threw',name:e.name,message:e.message}}};
 return pack({time:{performance_ms:performance.now(),date_ms:Date.now()},url:location.href,bridge_present:!!npcBridge,navigation_created:typeof npcNativeNavigation?.query==='function',physical_fleet:{known:true,present:!!fleet,records:fleetRows||[]},train:{known:true,present:!!explorationRailway,state:explorationRailway?.snapshot?.()},mercenary:{gate:gateResult,storage_reads:{fence:readStorage('mafiozi.mercenary-fences.v1'),power:readStorage('mafiozi.mercenary-yard-power.v1')},focus:{known:true,source:hero?.object.position?'hero_position':'controls_target',value:(hero?.object.position||controls.target).toArray()}},static_observed:{building_entry_ids:buildingEntries.map(e=>e.id),body_count:bodies.length,topology_dimensions:[topology?.grid?.length,topology?.grid?.[0]?.length]},limits:['Additional pure gate/storage observations; not a transcript of original storage calls','Outer explorationRailway.snapshot returns existing state; no motion snapshot resampling']});})()`;
const getterExpr=`(()=>{${rawSerializer}
 const refs=[],keys=new WeakMap(),add=o=>{if(!o||typeof o!=='object')throw Error('Source pool object invalid');if(!keys.has(o)){keys.set(o,'captured_reference_'+refs.length);refs.push(o);}return keys.get(o);};
 const pools={CARS:{known:true,present:true,object_keys:CARS.map(add)},questCars:typeof questCars==='undefined'?{known:true,present:false}:{known:true,present:true,object_keys:Array.from(questCars.values(),add)},serviceVehicles:typeof serviceVehicles==='undefined'?{known:true,present:false}:{known:true,present:true,object_keys:serviceVehicles.map(add)},BUS:typeof BUS==='undefined'?{known:true,present:false}:{known:true,present:true,object_key:add(BUS)}};
 const fields=['id','_id','_nativeParkingPending','_hidden','_towed','r','c','x','y','ang','dirDy','dirDx','model','modelName','kind','state','_nativeInitialReady','_nativeServiceVehicle'];
 const projection=o=>{const raw={};for(const k of fields)if(o[k]!==undefined)raw[k]=o[k];return raw;};
 const identity=refs.flatMap(o=>{const id=_threeVehicleIds.get(o);return id===undefined?[]:[{object_key:keys.get(o),id}]});
 return pack({source_frame:typeof prevT==='number'?prevT:0,player:{r:player.r,c:player.c},pools,objects:refs.map(o=>({object_key:keys.get(o),raw:projection(o)})),identity:{sequence:_threeVehicleIdSeq,entries:identity},catalogs:{QUEST_CAR_MODELS,CAR_MODELS,GANG_CAR_MODELS,POLICE_MODELS,_CAR_MODEL_BY_NAME},evaluated_rows:rows.map(row=>Object.fromEntries(Object.keys(row).map(k=>[k,row[k]]))),fresh_context:{MAP,NPCS,cityCops,worldCops},projection_scope:'Exact source dynamic getter property closure; reference keys are capture aliases, never vehicle IDs'});})()`;
const railExpr=`(()=>{${rawSerializer}return pack({current_cars:currentCars,query:{x,z,r}})})()`;
// A column breakpoint targets const bucket AFTER actual ensure on the same
// source line. Stepping over that whole line would leave the private scope.
const logicalExpr=`(()=>{${rawSerializer}const aliases=new Map();records.forEach((r,i)=>{if(!aliases.has(r.actor))aliases.set(r.actor,i)});return pack({query:{x,z,body},records:records.map(r=>({id:r.id,actor_alias_ordinal:aliases.get(r.actor),source_row:r.actor.sourceRow,profile:r.actor.profile,profile_known:r.actor.profileKnown,position:{x:r.actor.object.position.x,z:r.actor.object.position.z},scale:r.actor.object.scale})),grid:Array.from(grid,([key,bucket])=>({key,entries:bucket.map(r=>({id:r.id,actor_alias_ordinal:aliases.get(r.actor)}))})),diagnostics_ground_not_sampled:true});})()`;
const nativeExpr=`(()=>{${rawSerializer}return pack({query:{r,c,ignoreVehicleId,x,z,dynamicBody},blocked,depth,floor})})()`;

export function prepareCapturePlan(origin='http://127.0.0.1:18538/walk'){
 const u=urlCheck(origin);const dependencyRoot=path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules');
 return {schema:'mafiozi.npc-registered-capture-plan/v1',status:'PREPARED_NOT_RUN_REQUIRES_ROOT_GO',original_entry_url:u.href,expected_redirect:'/world.html?direct=1&previewcity=1&render=3d&renderer=walk (actual source18538 rule)',source_world_sha256:worldSHA,source_receipts:sources(),anchors,expressions:{registrationExpr,getterExpr,railExpr,logicalExpr,nativeExpr},browser:{executable:'C:/Program Files/Google/Chrome/Application/chrome.exe',executable_exists:fs.existsSync('C:/Program Files/Google/Chrome/Application/chrome.exe'),dependency_root:dependencyRoot,profile:'new fs.mkdtemp under OS temp; no existing profile/session/cookies/storage imported',headless:true,gpu:'REAL WebGL original constructor; only after Root22 stops the actual native_process_id and grants a fresh window'},limits:LIMITS,evidence_kind:'DEBUGGER_PAUSED_SOURCE_CAPTURE_DIAGNOSTIC_ONLY',scope:'No source response interception/rewriting; CDP observational breakpoints and private reads only',remaining_blocks:['Complete current frame may require more than first logical query; no invented absent pools','Fresh context serializer can fail on circular/function values -> HOLD with exact source position','Ground samples for all records are not provided by initial capture; separate explicit source diagnostic sampling needs Root review','Debugger pauses advance performance.now; placement slice timing is not pristine','Mercenary storage reads here are additional source API observations, not original-read transcript'],registered_frame_claim:false,physical_admission:false,source_functions:['_getWalkNpcVehicleTraffic','_npcLogicalVehicleRow','_threeVehicleEntityId','resolveCarModel'].map(sourceFunction)};
}

export async function probeSources(entry){
 const u=urlCheck(entry),receipts=[];for(const p of ['world.html','world_walk_host.mjs',WALK,'assets/maps/city_rebuild_v1/walk_entry.mjs','tools/city_rebuild_walk.html']){const url=new URL('/'+p,u);try{const r=await fetch(url,{signal:AbortSignal.timeout(5000)});const bytes=Buffer.from(await r.arrayBuffer());const expected=hash(fs.readFileSync(path.join(repo,p)));receipts.push({url:url.href,status:r.status,bytes:bytes.length,sha256:hash(bytes),expected_sha256:expected,exact_match:r.ok&&hash(bytes)===expected});}catch(error){receipts.push({url:url.href,exact_match:false,error:error.message,cause:error.cause?.code});break;}}return{known:receipts.length===5&&receipts.every(r=>r.exact_match),receipts,server_started:false,browser_started:false};
}

async function executeRootApproved(plan,go){
 validateRootGo(plan,go,hash);
 // Permission is a receipt, not evidence that a still-running native game stopped.
 if(ownedProcessAlive(go.native_process_id))throw Error('approved_native_pid_still_running');
 const budget=createBudget(),current=sources();if(JSON.stringify(current)!==JSON.stringify(plan.source_receipts))throw Error('Source changed after Root review');
 const evidence=path.join(out,'run-'+Date.now()+'-'+crypto.randomUUID());fs.mkdirSync(evidence,{recursive:true});
 const record={schema:'mafiozi.npc-debugger-capture-observation/v2',status:'CAPTURE_INCOMPLETE_HOLD',evidence_kind:'DEBUGGER_PAUSED_SOURCE_CAPTURE_DIAGNOSTIC_ONLY',created_at:new Date().toISOString(),root_go:go,profile:{created_empty:false,user_profile_used:false,closed:false,removed:false},source_server:{started_by_capture:false},plan_sha256:hash(JSON.stringify(plan)),observations:[],network:[],http_sources:[],scripts:[],breakpoints:[],events:[],storage_documents:[],errors:[],cleanup:[],first_lazy_getter:newFirstLedger(),debugger_clock_skew:true,original_source_unmodified:true,instrumented_source_sha256:null,registered_frame:false,physical_admission:false};
 const save=()=>fs.writeFileSync(path.join(evidence,'OBSERVATIONS.json'),JSON.stringify(record,null,2)+'\n');
 const pending=new Set(),owned=[],points=new Map(),scripts=new Map();let tmp,watchdog,browser,context,cdp,stopping=false,ordinal=0,finish;const ready=new Promise(resolve=>{finish=resolve});
 const error=(event,e)=>{record.errors.push({event,message:e.message||String(e)});finish();};
 const track=(label,fn)=>{if(stopping)return;const promise=budget.run(label,fn).catch(e=>error(label,e)).finally(()=>pending.delete(promise));pending.add(promise);};
 const send=(method,args)=>budget.run(method,()=>cdp.send(method,args));
 const delay=ms=>budget.run('poll',()=>new Promise(r=>setTimeout(r,ms)),ms+100);
 async function spawnOwned(role,executable,args){
  const spawnStarted=Date.now();
  const std=fs.openSync(path.join(evidence,role+'.stdout.log'),'wx');let err,child;
  try{err=fs.openSync(path.join(evidence,role+'.stderr.log'),'wx');child=spawn(executable,args,{cwd:repo,windowsHide:true,detached:process.platform!=='win32',stdio:['ignore',std,err]});}
  finally{fs.closeSync(std);if(err!==undefined)fs.closeSync(err);}
  const item={role,child,pid:child.pid??null,exited:false,identity:{parent_pid:process.pid,spawn_started_ms:spawnStarted,command_marker:role==='browser'?'--user-data-dir='+tmp:path.join(repo,'tools/city_rebuild_monitor.py')}};owned.push(item);
  child.once('exit',(code,signal)=>{item.exited=true;item.exit_code=code;item.signal=signal;if(watchdog?.connected)watchdog.send({type:'exited',pid:item.pid});});
  child.on('error',e=>{item.spawn_error=e.message;error(role+'_process',e);});
  await budget.run(role+'_spawn',()=>new Promise((resolve,reject)=>{child.once('spawn',resolve);child.once('error',reject);}));
  if(item.exited)throw Error(role+'_exited_before_ownership');
  await budget.run(role+'_watchdog_ownership',()=>new Promise((resolve,reject)=>{
   const onMessage=m=>{if(m?.type==='owned'&&m.pid===item.pid){watchdog.off('message',onMessage);resolve();}};watchdog.on('message',onMessage);
   watchdog.send({type:'own',pid:item.pid,role,identity:item.identity},e=>{if(e){watchdog.off('message',onMessage);reject(e);}});
  }));
  if(item.exited){watchdog.send({type:'exited',pid:item.pid});throw Error(role+'_exited_during_setup');}
  return item;
 }
 try{
  save();
  const parentIdentity={parent_pid:process.ppid,spawn_started_ms:Date.now()-process.uptime()*1000,command_marker:path.basename(self)};
  watchdog=spawn(process.execPath,[path.join(repo,'tools/godot/npc_capture_lifecycle.mjs'),'--watchdog',path.join(evidence,'WATCHDOG.json'),String(process.pid),String(Math.ceil(budget.remaining()+LIMITS.cleanup_ms)),JSON.stringify(parentIdentity)],{windowsHide:true,stdio:['ignore','ignore','ignore','ipc']});
  watchdog.on('error',e=>error('watchdog',e));await budget.run('watchdog_spawn',()=>new Promise((resolve,reject)=>{watchdog.once('spawn',resolve);watchdog.once('error',reject);}));
  let probe=await budget.run('source_probe',()=>probeSources(plan.original_entry_url),30000);record.probe=probe;save();
  if(!probe.known&&go.start_source_monitor){
   if(!probe.receipts.length||!probe.receipts.every(r=>r.cause==='ECONNREFUSED'))throw Error('Will not replace an existing/mismatched original endpoint');
   const server=await spawnOwned('source_server','python',[path.join(repo,'tools/city_rebuild_monitor.py'),'--port','18538']);record.source_server={started_by_capture:true,pid:server.pid};
   for(let i=0;i<20&&!probe.known;i++){await delay(250);probe=await budget.run('source_probe_retry',()=>probeSources(plan.original_entry_url),30000);record.probe=probe;}
  }
  if(!probe.known)throw Error('Original server/source readiness failed; no browser launched');
  const require=createRequire(import.meta.url),{chromium}=require(require.resolve('playwright',{paths:[plan.browser.dependency_root]}));
  tmp=fs.mkdtempSync(path.join(os.tmpdir(),'mafiozi-source-capture-'));fs.writeFileSync(path.join(tmp,'OWNED_CAPTURE_PROFILE'),crypto.randomUUID());record.profile={...record.profile,path:tmp,created_empty:true};save();
  const chrome=await spawnOwned('browser',plan.browser.executable,['--headless=new','--remote-debugging-port=0','--remote-debugging-address=127.0.0.1','--user-data-dir='+tmp,'--no-first-run','--no-default-browser-check','about:blank']);record.profile.browser_pid=chrome.pid;
  const portFile=path.join(tmp,'DevToolsActivePort');await budget.run('browser_debug_endpoint',async()=>{while(!fs.existsSync(portFile)){if(chrome.exited)throw Error('browser_exited_before_debug_endpoint');await delay(50);}},20000);
  const [port,endpoint]=fs.readFileSync(portFile,'utf8').trim().split(/\r?\n/);if(!/^\d+$/.test(port)||!endpoint.startsWith('/devtools/browser/'))throw Error('invalid_owned_debug_endpoint');
  browser=await budget.run('connect_owned_browser',()=>chromium.connectOverCDP('ws://127.0.0.1:'+port+endpoint,{timeout:15000}),16000);
  if(browser.contexts().length!==1)throw Error('Expected one owned profile context');context=browser.contexts()[0];if(context.pages().length!==1)throw Error('Expected exactly one own page');const page=context.pages()[0];
  page.on('requestfailed',r=>record.network.push({event:'requestfailed',url:r.url(),failure:r.failure()}));page.on('pageerror',e=>error('pageerror',e));
  page.on('response',r=>{record.network.push({event:'response',url:r.url(),status:r.status()});const u=new URL(r.url());if(!['document','script'].includes(r.request().resourceType()))return;
   track('http_source_body',async()=>{const bytes=await r.body(),rel=u.pathname==='/walk'?'tools/city_rebuild_walk.html':decodeURIComponent(u.pathname.slice(1)),local=path.resolve(repo,rel),sameOrigin=u.origin===new URL(plan.original_entry_url).origin;
    const inRepo=local.startsWith(path.resolve(repo)+path.sep),expected=sameOrigin&&inRepo&&fs.existsSync(local)?hash(fs.readFileSync(local)):null;
    const receipt={url:r.url(),status:r.status(),bytes:bytes.length,original_http_sha256:hash(bytes),instrumented_response_sha256:null,expected_local_sha256:expected,local_exact_match:expected?hash(bytes)===expected:null};record.http_sources.push(receipt);
    fs.writeFileSync(path.join(evidence,'HTTP-'+hash(bytes)+'.bin'),bytes);if(expected&&expected!==hash(bytes))throw Error('browser_HTTP_source_mismatch:'+r.url());
   });
  });
  cdp=await budget.run('new_CDP_session',()=>context.newCDPSession(page));
  cdp.on('Runtime.bindingCalled',e=>{if(e.name!=='__npcCaptureStorageReceipt')return;try{const v=JSON.parse(e.payload);record.storage_documents.push({...v,execution_context_id:e.executionContextId,ordinal:++ordinal});if(v.error||v.local_length!==0||v.session_length!==0)error('fresh_storage',Error('Origin document was not proved empty'));}catch(e){error('storage_receipt',e);}});
  cdp.on('Debugger.scriptParsed',e=>{scripts.set(e.scriptId,e);track('executed_script_source',async()=>{
   const {scriptSource}=await send('Debugger.getScriptSource',{scriptId:e.scriptId});let matches=null;
   if(e.url){const u=new URL(e.url);if(u.origin===new URL(plan.original_entry_url).origin){const rel=u.pathname==='/walk'?'tools/city_rebuild_walk.html':decodeURIComponent(u.pathname.slice(1)),local=path.resolve(repo,rel);if(local.startsWith(path.resolve(repo)+path.sep)&&fs.existsSync(local)){const bytes=fs.readFileSync(local,'utf8');matches=u.pathname.endsWith('.html')||u.pathname==='/walk'?bytes.includes(scriptSource):bytes===scriptSource;}}}
   record.scripts.push({script_id:e.scriptId,url:e.url,start_line:e.startLine,start_column:e.startColumn,end_line:e.endLine,end_column:e.endColumn,cdp_hash:e.hash,executed_script_sha256:hash(scriptSource),matches_original_local_source:matches});
   if(matches===false)throw Error('executed_source_mismatch:'+e.url);
  });});
  cdp.on('Debugger.breakpointResolved',e=>record.breakpoints.push({event:'resolved',...e,ordinal:++ordinal}));
  await send('Runtime.enable');await send('Runtime.addBinding',{name:'__npcCaptureStorageReceipt'});await send('Debugger.enable');
  // One immutable receipt per origin document; the bridge only reports storage
  // lengths. It does not clear/import/set storage or replace source functions.
  await send('Page.addScriptToEvaluateOnNewDocument',{source:`if(['127.0.0.1','localhost'].includes(location.hostname)){try{__npcCaptureStorageReceipt(JSON.stringify({url:location.href,origin:location.origin,local_length:localStorage.length,session_length:sessionStorage.length,user_data_imported:false}))}catch(e){__npcCaptureStorageReceipt(JSON.stringify({url:location.href,error:e.name,message:e.message}))}}`});
  for(const a of plan.anchors){const result=await send('Debugger.setBreakpointByUrl',{urlRegex:a.suffix.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')+'(?:\\?.*)?$',lineNumber:a.line,columnNumber:a.column||0});points.set(result.breakpointId,a);record.breakpoints.push({event:'requested',anchor:a,breakpoint_id:result.breakpointId,locations:result.locations,ordinal:++ordinal});}
  cdp.on('Debugger.paused',e=>{track('paused_handler',async()=>{
   try{
    const hit=e.hitBreakpoints.map(id=>points.get(id)).filter(Boolean);if(hit.length!==1)throw Error('unexpected_or_ambiguous_pause');const a=hit[0],frame=e.callFrames[0],source=scripts.get(frame.location.scriptId);
    if(frame.location.lineNumber!==a.line||a.column!==undefined&&frame.location.columnNumber!==a.column||!source?.url.endsWith(a.suffix)&&!source?.url.includes(a.suffix+'?'))throw Error('breakpoint_resolution_drift:'+a.name);
    const resolved=record.breakpoints.some(b=>b.event==='resolved'&&e.hitBreakpoints.includes(b.breakpointId)&&JSON.stringify(b.location)===JSON.stringify(frame.location))||record.breakpoints.some(b=>b.event==='requested'&&e.hitBreakpoints.includes(b.breakpoint_id)&&b.locations.some(l=>JSON.stringify(l)===JSON.stringify(frame.location)));
    if(!resolved)throw Error('missing_breakpoint_resolution_receipt:'+a.name);
    if(a.name==='getter_entry'){
     const possible=await send('Debugger.getPossibleBreakpoints',{start:{scriptId:frame.location.scriptId,lineNumber:a.line,columnNumber:0},end:{scriptId:frame.location.scriptId,lineNumber:a.line+1,columnNumber:0},restrictToFunction:false});
     record.breakpoints.push({event:'getter_first_possible',locations:possible.locations});
     if(!possible.locations.length||possible.locations[0].columnNumber!==frame.location.columnNumber)throw Error('getter_entry_not_first_executable_location');
    }
    const event={name:a.name,ordinal:++ordinal,at_ms:Date.now(),monotonic_ms:performance.now(),hit_breakpoints:e.hitBreakpoints,source_location:frame.location,stack:e.callFrames.map(f=>({function_name:f.functionName,url:f.url,location:f.location}))};record.events.push(event);observeFirst(record.first_lazy_getter,a.name,event);
    if(record.first_lazy_getter.errors.length)throw Error(record.first_lazy_getter.errors.join(','));
    const expression=a.name==='registration_before_call'?registrationExpr:a.name==='getter_entry'?`({source_frame:typeof prevT==='number'?prevT:0,identity_sequence:_threeVehicleIdSeq,performance_ms:performance.now(),date_ms:Date.now()})`:a.name==='getter_before_return'?getterExpr:a.name==='rail_actual_blocks'?railExpr:a.name==='logical_after_actual_ensure'?logicalExpr:a.name==='native_after_dynamic'?nativeExpr:null;
    if(expression&&(!record.observations.some(o=>o.name===a.name)||a.name==='rail_actual_blocks'||a.name==='native_after_dynamic')){const r=await send('Debugger.evaluateOnCallFrame',{callFrameId:frame.callFrameId,expression,returnByValue:true,silent:false});record.observations.push({...event,value:r.result.value,exception:r.exceptionDetails});if(r.exceptionDetails)throw Error('source_capture_expression_exception:'+a.name);}
    event.resumed_host_monotonic_ms=performance.now();save();
    if(record.events.length>500)throw Error('bounded_pause_count_exceeded');
    if(record.first_lazy_getter.proven&&a.name==='native_after_dynamic'){
     const logical=record.observations.find(o=>o.name==='logical_after_actual_ensure'&&o.ordinal>record.first_lazy_getter.first_return.ordinal),native=record.observations.at(-1);
     if(logical){const l=logical.value?.data?.query,n=native.value?.data?.query;
      if(!l||!n||l.x!==n.x||l.z!==n.z||JSON.stringify(l.body)!==JSON.stringify(n.dynamicBody))throw Error('first_lazy_consumer_query_mismatch');
      record.first_consumption={getter_entry_ordinal:record.first_lazy_getter.first_entry.ordinal,getter_return_ordinal:record.first_lazy_getter.first_return.ordinal,logical_ordinal:logical.ordinal,native_ordinal:native.ordinal,same_query_values:true};finish();
     }
    }
   }finally{if(!stopping)await send('Debugger.resume');}
  });});
  await budget.run('navigation_commit',()=>page.goto(plan.original_entry_url,{waitUntil:'commit',timeout:20000}),21000);
  await budget.run('first_getter_window',()=>ready,60000);record.final_url=page.url();
  await budget.run('pending_evidence',()=>Promise.all([...pending]),10000);
  if(!record.first_lazy_getter.proven)throw Error('FIRST_lazy_getter_not_proven');
  if(!record.storage_documents.some(r=>r.url.includes('/world.html')&&r.local_length===0&&r.session_length===0))throw Error('missing_world_storage_receipt');
  for(const event of record.events)if(!record.scripts.some(s=>s.script_id===event.source_location.scriptId&&s.matches_original_local_source===true))throw Error('missing_executed_source_receipt');
  record.first_capture_evidence_complete=!!record.first_consumption&&record.errors.length===0;
  // Deliberately no admission: original ground/static lease and mercenary
  // constructor-read transcript still require separate source evidence.
 }catch(e){error('capture_failure',e);}
 finally{
  stopping=true;save();const cleanupBudget=createBudget(LIMITS.cleanup_ms);
  if(cdp)try{await cleanupBudget.run('disable_debugger',()=>cdp.send('Debugger.disable'),1000);}catch(e){error('cleanup_debugger',e);}
  if(browser)try{await cleanupBudget.run('close_owned_browser',()=>browser.close(),2000);}catch(e){error('cleanup_browser',e);}
  for(const item of owned.slice().reverse()){
   if(!item.exited&&item.pid){try{record.cleanup.push({role:item.role,...terminateOwnedPid(item.pid,{identity:item.identity})});}catch(e){error('owned_terminate',e);}}
   try{await cleanupBudget.run('wait_owned_exit',async()=>{while(!item.exited&&!item.spawn_error)await new Promise(r=>setTimeout(r,20));},2500);}catch(e){error('owned_exit_not_confirmed',e);}
   record.cleanup.push({role:item.role,pid:item.pid,exit_confirmed:item.exited,exit_code:item.exit_code??null,signal:item.signal??null,spawn_error:item.spawn_error??null});
  }
  const allExited=owned.every(o=>o.exited||o.spawn_error&&!o.pid);record.profile.closed=allExited;
  if(allExited&&tmp){const resolved=path.resolve(tmp);if(path.dirname(resolved)===path.resolve(os.tmpdir())&&path.basename(resolved).startsWith('mafiozi-source-capture-')&&fs.existsSync(path.join(resolved,'OWNED_CAPTURE_PROFILE'))){try{fs.rmSync(resolved,{recursive:true,force:false});record.profile.removed=true;}catch(e){error('profile_cleanup',e);}}}
  record.root_restore_allowed=false;record.root_restore_requirement='Independent Root22 inventory of browser descendants and own server before restoring game; direct parent exits alone do not prove whole process tree exit.';save();
  if(watchdog?.connected){if(allExited)watchdog.send({type:'complete'});else watchdog.disconnect();}
 }
 return{status:record.status,output:evidence,observations:record.observations.length,errors:record.errors.length,closed:record.profile.closed,first_lazy_getter_proven:record.first_capture_evidence_complete===true,registered_frame:false,physical_admission:false};
}

if(process.argv[1]&&path.resolve(process.argv[1])===self){
 const args=process.argv.slice(2),arg=(key,fallback)=>args.includes(key)?args[args.indexOf(key)+1]:fallback;
 const plan=prepareCapturePlan(arg('--url','http://127.0.0.1:18538/walk'));fs.mkdirSync(out,{recursive:true});
 if(args.includes('--root-go')){const go=JSON.parse(fs.readFileSync(arg('--root-go')));console.log(JSON.stringify(await executeRootApproved(plan,go)));}
 else{fs.writeFileSync(path.join(out,'PLAN.json'),JSON.stringify({...plan,plan_sha256:hash(JSON.stringify(plan))},null,2)+'\n');if(args.includes('--probe'))fs.writeFileSync(path.join(out,'SERVER_READINESS.json'),JSON.stringify(await probeSources(plan.original_entry_url),null,2)+'\n');console.log(JSON.stringify({status:plan.status,plan_sha256:hash(JSON.stringify(plan)),browser_started:false,gpu_started:false,output:out}));}
}
