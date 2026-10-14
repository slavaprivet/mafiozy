// CPU-testable capture guards. No process/browser is started on import.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

export const LIMITS=Object.freeze({total_ms:180000,operation_ms:5000,cleanup_ms:10000});
export function validateRootGo(plan,go,hash,now=Date.now()){
 if(!go||go.schema!=='mafiozi.root-capture-go/v2'||go.authorization!=='ROOT_APPROVED_CAPTURE_GPU_WINDOW'||go.coordinator_thread_id!=='01a0eec3-2733-7130-9aea-c289c76574af')throw Error('fresh_root22_go_required');
 if(go.native_stopped!==true||!Number.isSafeInteger(go.native_process_id)||go.native_process_id<=0||go.native_process_id===process.pid)throw Error('current_native_lifecycle_required');
 if(!Number.isFinite(go.native_stopped_at_ms)||go.native_stopped_at_ms>now||go.native_stopped_at_ms<now-180000)throw Error('fresh_native_stop_required');
 if(typeof go.native_build_receipt_sha256!=='string'||!/^[0-9a-f]{64}$/.test(go.native_build_receipt_sha256))throw Error('native_build_receipt_required');
 if(go.plan_sha256!==hash(JSON.stringify(plan)))throw Error('plan_hash_changed');
 if(!Number.isFinite(go.expires_at_ms)||go.expires_at_ms<=now||go.expires_at_ms>now+180000)throw Error('go_expired_or_overlong');
 if(typeof go.start_source_monitor!=='boolean')throw Error('explicit_monitor_policy_required');
 return true;
}
export function createBudget(totalMs=LIMITS.total_ms,clock=()=>performance.now()){
 const start=clock(),deadline=start+totalMs;
 return {remaining:()=>Math.max(0,deadline-clock()),async run(label,fn,cap=LIMITS.operation_ms){
  const left=Math.min(cap,deadline-clock());if(left<=0)throw Error('capture_deadline:'+label);
  let timer;try{return await Promise.race([Promise.resolve().then(fn),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('capture_timeout:'+label)),left);})]);}finally{clearTimeout(timer);}
 }};
}
export function newFirstLedger(){return {entries:0,returns:0,registration_before:null,registration_after:null,first_entry:null,first_return:null,errors:[],proven:false};}
export function observeFirst(ledger,name,event){
 if(name==='registration_before_call'){if(ledger.registration_before)ledger.errors.push('duplicate_registration');ledger.registration_before=event;}
 if(name==='registration_after_call')ledger.registration_after=event;
 if(name==='getter_entry'){
  ledger.entries++;
  if(ledger.entries===1){ledger.first_entry=event;const stack=event.stack.map(f=>f.function_name);
   if(!ledger.registration_before||ledger.registration_after)ledger.errors.push('first_getter_outside_registration');
   if(!stack.includes('ensure')||!stack.includes('registerWalkNpcNavigationResolver'))ledger.errors.push('first_getter_not_actual_lazy_registration_stack');
  }
 }
 if(name==='getter_before_return'){
  ledger.returns++;
  if(ledger.returns===1){ledger.first_return=event;if(ledger.entries!==1||!ledger.first_entry||ledger.first_entry.ordinal>=event.ordinal)ledger.errors.push('first_entry_return_order');
   if(ledger.registration_after)ledger.errors.push('getter_return_after_registration');
   if(event.stack[0]?.function_name!=='_getWalkNpcVehicleTraffic')ledger.errors.push('wrong_getter_return_frame');
   if(ledger.first_entry&&JSON.stringify(ledger.first_entry.stack.slice(1))!==JSON.stringify(event.stack.slice(1)))ledger.errors.push('first_entry_return_caller_mismatch');
  }
 }
 ledger.proven=!!ledger.first_entry&&!!ledger.first_return&&ledger.errors.length===0;
 return ledger;
}
export function ownedProcessAlive(pid){try{process.kill(pid,0);return true;}catch(error){if(error.code==='ESRCH')return false;throw error;}}
export function verifyOwnedIdentity(pid,identity,{run=spawnSync,platform=process.platform}={}){
 if(platform!=='win32'||!identity||!Number.isSafeInteger(identity.parent_pid)||!Number.isFinite(identity.spawn_started_ms)||typeof identity.command_marker!=='string'||!identity.command_marker)return false;
 const command=`$captureProc = Get-CimInstance Win32_Process -Filter 'ProcessId = ${pid}'; if ($captureProc) { [pscustomobject]@{ parent = $captureProc.ParentProcessId; born = $captureProc.CreationDate.ToUniversalTime().ToString('o'); command = $captureProc.CommandLine } | ConvertTo-Json -Compress }`;
 const r=run('powershell.exe',['-NoProfile','-NonInteractive','-Command',command],{windowsHide:true,timeout:1000,encoding:'utf8'});
 if(r.error||r.status!==0)return false;
 try{const p=JSON.parse(r.stdout),born=Date.parse(p.born);return p.parent===identity.parent_pid&&Number.isFinite(born)&&born>=identity.spawn_started_ms-2000&&born<=identity.spawn_started_ms+5000&&typeof p.command==='string'&&p.command.includes(identity.command_marker);}catch{return false;}
}
export function terminateOwnedPid(pid,{kill=process.kill.bind(process),run=spawnSync,platform=process.platform,identity,verify=verifyOwnedIdentity}={}){
 if(!Number.isSafeInteger(pid)||pid<=0||pid===process.pid)throw Error('invalid_owned_pid');
 if(!verify(pid,identity,{run,platform}))return {pid,method:'SKIPPED_IDENTITY_UNVERIFIED',cleanup_unverified:true};
 if(platform==='win32'){
  const r=run('taskkill.exe',['/PID',String(pid),'/T','/F'],{windowsHide:true,timeout:1000,encoding:'utf8'});
  return {pid,method:'taskkill-owned-tree',exit_code:r.status,error:r.error?.message??null};
 }
 try{kill(-pid,'SIGKILL');return {pid,method:'owned-process-group'};}catch(error){if(error.code!=='ESRCH')throw error;return {pid,method:'already_exited'};}
}

// Independent watchdog handles a stalled parent event loop/CDP and records what
// it actually terminated. It only receives PIDs spawned by this capture process.
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)&&process.argv[2]==='--watchdog'){
 const output=process.argv[3],parentPid=Number(process.argv[4]),delay=Number(process.argv[5]),parentIdentity=JSON.parse(process.argv[6]||'null');
 if(!Number.isSafeInteger(parentPid)||parentPid<=0||!Number.isFinite(delay)||delay<=0||delay>190000)throw Error('watchdog_arguments');
 const owned=new Map();let done=false;
 function stop(reason,killParent){if(done)return;done=true;const receipts=[];for(const [pid,ownedRow]of owned){try{receipts.push({role:ownedRow.role,...terminateOwnedPid(pid,{identity:ownedRow.identity})});}catch(error){receipts.push({pid,role:ownedRow.role,error:error.message});}}
  const parentVerified=killParent&&verifyOwnedIdentity(parentPid,parentIdentity);
  fs.writeFileSync(output,JSON.stringify({status:'WATCHDOG_ABORT_HOLD',reason,at:new Date().toISOString(),receipts,parent_termination_identity_verified:parentVerified,parent_termination_skipped:killParent&&!parentVerified},null,2)+'\n');
  if(parentVerified)try{process.kill(parentPid,'SIGTERM');}catch{}
  process.exit(2);
 }
 const timer=setTimeout(()=>stop('global_deadline',true),delay);
 process.on('message',m=>{if(m?.type==='own'&&Number.isSafeInteger(m.pid)&&m.pid>0&&m.pid!==parentPid&&m.pid!==process.pid){owned.set(m.pid,{role:m.role,identity:m.identity});process.send?.({type:'owned',pid:m.pid});}
  else if(m?.type==='exited'){owned.delete(m.pid);}
  else if(m?.type==='complete'&&owned.size===0){done=true;clearTimeout(timer);process.exit(0);}
 });
 process.on('disconnect',()=>stop('parent_disconnected',false));
}
