import assert from 'node:assert/strict';
import {createWalkMapEditorAutosave,WalkMapEditorAutosaveError} from './walk_map_editor_autosave.mjs';

function session(revision){return Object.freeze({revision,document:Object.freeze({revision})});}
function deferred(){let resolve,reject;const promise=new Promise((yes,no)=>{resolve=yes;reject=no;});return {promise,resolve,reject};}
function fakeScheduler(){
 let next=1;const delays=new Map(),idles=new Map();
 return {
  delay(callback){const id=next++;delays.set(id,callback);return id;},
  cancelDelay(id){delays.delete(id);},
  idle(callback){const id=next++;idles.set(id,callback);return id;},
  cancelIdle(id){idles.delete(id);},
  runDelays(){const work=[...delays.values()];delays.clear();for(const callback of work)callback();},
  runIdles(){const work=[...idles.values()];idles.clear();for(const callback of work)callback();},
  get delayCount(){return delays.size;},get idleCount(){return idles.size;}
 };
}
async function settle(){await Promise.resolve();await Promise.resolve();await Promise.resolve();}

let current=session(0),mode='success',pending=null,clearMode='success',clearPending=null;const saved=[],statuses=[],clears=[];const scheduler=fakeScheduler();
const autosave=createWalkMapEditorAutosave({
 getSession:()=>current,
 saveRecovery:async(active,options)=>{saved.push({revision:active.revision,options});if(mode==='deferred'){pending=deferred();await pending.promise;}if(mode==='quota'){const error=new Error('storage full');error.name='QuotaExceededError';throw error;}},
 clearRecovery:async options=>{clears.push(options);if(clearMode==='deferred'){clearPending=deferred();await clearPending.promise;}},
 onStatus:value=>statuses.push(value),
 debounceMs:25,
 scheduleDelay:callback=>scheduler.delay(callback),cancelDelay:id=>scheduler.cancelDelay(id),
 scheduleIdle:callback=>scheduler.idle(callback),cancelIdle:id=>scheduler.cancelIdle(id)
});

assert.equal(autosave.state.status,'saved');assert.equal(autosave.state.dirty,false);assert.equal(autosave.state.shouldWarnBeforeUnload,false);assert.ok(Object.isFrozen(autosave.state));
assert.equal(autosave.notifyPreview(),false);assert.equal(scheduler.delayCount,0,'preview must not schedule persistence');

current=session(1);assert.equal(autosave.notifyCommitted(current),true);
current=session(2);assert.equal(autosave.notifyCommitted(current),true);
assert.equal(scheduler.delayCount,1,'rapid commits must coalesce into one debounce timer');
assert.equal(autosave.state.latestRevision,2);assert.equal(autosave.state.dirty,true);assert.equal(autosave.shouldWarnBeforeUnload(),true);
scheduler.runDelays();assert.equal(scheduler.idleCount,1);scheduler.runIdles();await autosave.flush();
assert.deepEqual(saved.map(entry=>entry.revision),[2]);assert.equal(autosave.state.savedRevision,2);assert.equal(autosave.shouldWarnBeforeUnload(),false);

mode='deferred';current=session(3);autosave.notifyCommitted(current);scheduler.runDelays();scheduler.runIdles();await settle();
assert.equal(autosave.state.inFlightRevision,3);assert.equal(autosave.state.saving,true);
current=session(4);autosave.notifyCommitted(current);assert.equal(autosave.state.latestRevision,4);assert.equal(autosave.state.savedRevision,2);
pending.resolve();await settle();
assert.equal(autosave.state.savedRevision,3,'stale completion may only acknowledge its captured revision');assert.equal(autosave.state.dirty,true,'newer revision must stay dirty');
mode='success';scheduler.runDelays();scheduler.runIdles();await autosave.flush();
assert.deepEqual(saved.map(entry=>entry.revision),[2,3,4]);assert.equal(autosave.state.savedRevision,4);

current=session(5);autosave.notifyCommitted(current);assert.equal(await autosave.onEditorClose(),true);assert.equal(scheduler.delayCount,0,'close must cancel pending debounce');assert.equal(autosave.state.savedRevision,5);
current=session(6);autosave.notifyCommitted(current);assert.equal(await autosave.onPageHide(),true);assert.equal(autosave.state.savedRevision,6);

mode='quota';current=session(7);autosave.notifyCommitted(current);assert.equal(await autosave.flush(),false,'storage failures are non-fatal results');
assert.equal(autosave.state.status,'error');assert.equal(autosave.state.dirty,true);assert.match(autosave.state.message,/хранилище браузера заполнено/i);assert.equal(autosave.shouldWarnBeforeUnload(),true);
mode='success';assert.equal(await autosave.flush(),true);assert.equal(autosave.state.savedRevision,7);assert.equal(autosave.shouldWarnBeforeUnload(),false);

current=session(8);autosave.notifyCommitted(current);assert.equal(await autosave.clearRecovery(),true);assert.equal(clears.length,1);assert.equal(autosave.state.savedRevision,8);assert.equal(autosave.shouldWarnBeforeUnload(),false);
assert.ok(statuses.some(value=>value.status==='dirty'&&value.message));assert.ok(statuses.some(value=>value.status==='saving'&&value.saving));assert.ok(statuses.some(value=>value.status==='error'&&value.lastError));

clearMode='deferred';current=session(9);autosave.notifyCommitted(current);const clearing=autosave.clearRecovery();await settle();current=session(10);autosave.notifyCommitted(current);clearPending.resolve();assert.equal(await clearing,true);assert.equal(autosave.state.savedRevision,9,'clear may only acknowledge the revision captured before its async call');assert.equal(autosave.state.dirty,true);clearMode='success';await autosave.flush();assert.equal(autosave.state.savedRevision,10);

mode='deferred';current=session(11);autosave.notifyCommitted(current);scheduler.runDelays();scheduler.runIdles();await settle();const oldPending=pending;
autosave.dispose();autosave.dispose();assert.equal(autosave.state.status,'disposed');assert.equal(autosave.state.dirty,true);assert.equal(autosave.shouldWarnBeforeUnload(),false);oldPending.resolve();await settle();
assert.equal(autosave.state.savedRevision,10,'completion after dispose must not update saved revision');assert.throws(()=>autosave.notifyPreview(),WalkMapEditorAutosaveError);

assert.throws(()=>createWalkMapEditorAutosave({getSession:()=>({}),saveRecovery(){}}),WalkMapEditorAutosaveError);
console.log('walk_map_editor_autosave PASS');
