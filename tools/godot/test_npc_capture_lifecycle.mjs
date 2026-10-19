// Offline guards only. Never runs a server, Chrome, watchdog or actual process kill.
import assert from 'node:assert/strict';
import {prepareCapturePlan,urlCheck} from './capture_npc_registered_baseline.mjs';
import {hash} from './npc_startup_source_vm.mjs';
import {validateRootGo,createBudget,newFirstLedger,observeFirst,terminateOwnedPid,verifyOwnedIdentity} from './npc_capture_lifecycle.mjs';
let checks=0;const ok=(value,message)=>{assert.ok(value,message);checks++;};
const throws=(fn,match)=>{assert.throws(fn,match);checks++;};
const now=1790000000000,plan=prepareCapturePlan(),go={schema:'mafiozi.root-capture-go/v2',authorization:'ROOT_APPROVED_CAPTURE_GPU_WINDOW',coordinator_thread_id:'01a0eec3-2733-7130-9aea-c289c76574af',native_process_id:424242,native_stopped:true,native_stopped_at_ms:now-1000,native_build_receipt_sha256:'a'.repeat(64),plan_sha256:hash(JSON.stringify(plan)),expires_at_ms:now+30000,start_source_monitor:false};
ok(validateRootGo(plan,go,hash,now),'exact current GO');
for(const patch of [{schema:'mafiozi.root-capture-go/v1',native_43848_stopped:true},{coordinator_thread_id:'old-root21'},{native_stopped:false},{native_process_id:0},{native_process_id:1.2},{native_process_id:process.pid},{native_stopped_at_ms:now-180001},{native_stopped_at_ms:now+1},{native_build_receipt_sha256:'fake'},{expires_at_ms:now},{expires_at_ms:now+180001},{expires_at_ms:Infinity},{plan_sha256:'a'.repeat(64)},{start_source_monitor:undefined}])throws(()=>validateRootGo(plan,{...go,...patch},hash,now),/required|changed|overlong/);
throws(()=>validateRootGo({...plan,original_entry_url:'http://localhost:18538/walk'},go,hash,now),/plan_hash_changed/);
for(const url of ['http://user:pass@127.0.0.1:18538/walk','https://127.0.0.1:18538/walk','http://127.0.0.1:18539/walk','http://evil.example:18538/walk','http://localhost:18538/walk?standalone=0','http://localhost:18538/walk?account_uid=x','http://localhost:18538/walk#token','http://localhost:18538/world.html'])throws(()=>urlCheck(url),/exact uncredentialed/);
ok(urlCheck('http://localhost:18538/walk').port==='18538','valid loopback');
ok(plan.anchors.some(x=>x.name==='getter_entry')&&plan.anchors.some(x=>x.name==='registration_after_call'),'full boundary anchors');
ok(plan.registered_frame_claim===false&&plan.physical_admission===false,'diagnostic plan');
const stack=[{function_name:'_getWalkNpcVehicleTraffic',location:{scriptId:'world',lineNumber:10045}},{function_name:'ensure',location:{scriptId:'logical',lineNumber:19}},{function_name:'registerWalkNpcNavigationResolver',location:{scriptId:'world',lineNumber:70659}}];
const ev=(ordinal,s=stack)=>({ordinal,stack:structuredClone(s)});
let ledger=newFirstLedger();observeFirst(ledger,'registration_before_call',ev(1,[]));observeFirst(ledger,'getter_entry',ev(2));ok(!ledger.proven,'entry alone not FIRST receipt');observeFirst(ledger,'getter_before_return',ev(3));ok(ledger.proven,'matching first entry and return');
for(const run of [
 l=>{observeFirst(l,'getter_entry',ev(1));observeFirst(l,'getter_before_return',ev(2));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_before_return',ev(2));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_entry',ev(2));observeFirst(l,'registration_after_call',ev(3,[]));observeFirst(l,'getter_before_return',ev(4));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_entry',ev(2));observeFirst(l,'getter_entry',ev(3));observeFirst(l,'getter_before_return',ev(4));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_entry',ev(2,[stack[0],{function_name:'manual_test'}]));observeFirst(l,'getter_before_return',ev(3));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_entry',ev(3));observeFirst(l,'getter_before_return',ev(2));},
 l=>{observeFirst(l,'registration_before_call',ev(1,[]));observeFirst(l,'getter_entry',ev(2));const wrong=structuredClone(stack);wrong[1].location.lineNumber=99;observeFirst(l,'getter_before_return',ev(3,wrong));}
]){ledger=newFirstLedger();run(ledger);ok(!ledger.proven&&ledger.errors.length>0,'invalid FIRST sequence stays HOLD');}
const deadline=createBudget(25);const start=performance.now();await assert.rejects(deadline.run('hung_setup',()=>new Promise(()=>{}),1000),/capture_timeout/);checks++;ok(performance.now()-start<1500,'hung setup bounded');
let simulated=0;const shared=createBudget(10,()=>simulated);await shared.run('first',()=>{simulated=9;return 1;});simulated=11;await assert.rejects(shared.run('later',()=>assert.fail('expired work started')),/capture_deadline/);checks++;
let calls=[];const run=(exe,args)=>{calls.push({exe,args});return {status:0};};
throws(()=>terminateOwnedPid(process.pid,{run,verify:()=>true}),/invalid_owned_pid/);
const skipped=terminateOwnedPid(456789,{run,platform:'win32',verify:()=>false});ok(skipped.cleanup_unverified===true&&calls.length===0,'unverified/reused PID never killed');
const killed=terminateOwnedPid(456789,{run,platform:'win32',verify:()=>true});ok(killed.exit_code===0&&calls.length===1,'only verified own PID targeted');ok(JSON.stringify(calls[0].args)===JSON.stringify(['/PID','456789','/T','/F']),'exact owned process tree only');
const identity={parent_pid:123,spawn_started_ms:now,command_marker:'--user-data-dir=unique-owned-profile'};
const processRow={parent:123,born:new Date(now+100).toISOString(),command:'chrome --user-data-dir=unique-owned-profile'};
const identityRun=row=>()=>({status:0,stdout:JSON.stringify(row)});
ok(verifyOwnedIdentity(456789,identity,{run:identityRun(processRow),platform:'win32'}),'creation/parent/marker match');
for(const row of [{...processRow,parent:124},{...processRow,born:new Date(now-10000).toISOString()},{...processRow,born:new Date(now+10000).toISOString()},{...processRow,command:'chrome unrelated-profile'}])ok(!verifyOwnedIdentity(456789,identity,{run:identityRun(row),platform:'win32'}),'foreign/stale PID identity rejected');
ok(!verifyOwnedIdentity(456789,identity,{run:()=>({status:1,stdout:''}),platform:'win32'}),'unavailable inventory fails closed');
console.log(JSON.stringify({status:'PASS',checks,scope:'OFFLINE_GUARDS_ONLY_NO_BROWSER_SERVER_WATCHDOG_OR_KILL',capture_script_sha256:plan.source_receipts.find(x=>x.path.endsWith('/capture_npc_registered_baseline.mjs')).sha256,lifecycle_sha256:plan.source_receipts.find(x=>x.path.endsWith('/npc_capture_lifecycle.mjs')).sha256,registered_frame:false,physical_admission:false}));
