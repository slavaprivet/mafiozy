import assert from 'node:assert/strict';
import test from 'node:test';
import {createNpcBlastPresentation20} from './npc_blast_presentation20.mjs';
function setup(options={}){
 const actors=new Map(),jobs=[],shown=new Set();let admissions=0,reject=false;
 const parts={admit(input){admissions++;if(reject)return {ok:false};const ticket={status:'pending'};jobs.push({...input,ticket});return {ok:true,ticket};},update(now){const ready=[];for(const job of jobs){if(job.ticket.status==='pending'&&now-job.now>=.1){job.ticket.status='ready';shown.add(job.receipt.actorId);ready.push(job.ticket);}if(now-job.receipt.eventAt>=8){shown.delete(job.receipt.actorId);job.ticket.status='expired';}}return ready;},cull(id){shown.delete(id);for(const job of jobs)if(job.receipt.actorId===id)job.ticket.status='culled';},dispose(){shown.clear();}};
 const controller=createNpcBlastPresentation20({parts,getActor:id=>actors.get(id),groundHeight:()=>3,...options});
 const actor=id=>{const a={id,replaced:null,object:{visible:true},diagnostics:()=>({disposed:false}),markDeathVisualReplaced(key){this.replaced=key;return true;},isDeathVisualReplaced(key){return this.replaced===key;}};actors.set(id,a);return a;};
 return {controller,actors,actor,jobs,shown,admissions:()=>admissions,reject:()=>{reject=true;}};
}
function row(id='resident',deadAt=1000){return {id,dead:true,deathConfirmed:true,deadAt,deathRecord:{version:1,confirmed:true,fatal:true,targetId:id,eventId:'fatal:'+id+':'+deadAt,deathKey:String(deadAt),cause:'blast',blastPresentation:{version:1,originSource:{r:2,c:4},visualSpeed:5}}};}
test('whole corpse remains pending; complete fragments replace it in one host update',()=>{
 const h=setup(),a=h.actor('resident');h.controller.sync([row()],{now:1});h.controller.update(1);
 assert(a.object.visible);assert.equal(h.shown.size,0);assert.deepEqual(h.jobs[0].receipt.origin,{x:16.4,y:3,z:8.2});
 h.controller.update(1.2);assert(!a.object.visible);assert(h.shown.has(a.id));assert.equal(h.admissions(),1);
 a.object.visible=true;h.controller.update(2);assert(!a.object.visible,'population cannot restore intact body');
 h.controller.update(9);assert.equal(h.shown.size,0);a.object.visible=true;h.controller.update(10);assert(!a.object.visible,'expiry does not reassemble corpse');
 h.controller.dispose();
});
test('pending cull never hides the body, consumes decision and cannot restart',()=>{
 const h=setup(),a=h.actor('resident');h.controller.sync([row()],{now:1});h.controller.update(1);h.controller.sync([],{now:1.05});h.controller.update(1.2);
 assert(a.object.visible);assert.equal(h.shown.size,0);h.controller.sync([row()],{now:2});h.controller.update(2);assert.equal(h.admissions(),1);
});
test('presented cull/recreate stays suppressed; alive and new epoch remain independent',()=>{
 const h=setup();h.actor('resident');h.controller.sync([row()],{now:1});h.controller.update(1);h.controller.update(1.2);
 h.controller.sync([],{now:2});h.actors.delete('resident');const restored=h.actor('resident');restored.replaced='1000';h.controller.sync([row()],{now:3});h.controller.update(3);assert(!restored.object.visible);
 restored.object.visible=true;h.controller.sync([{id:'resident',dead:false}],{now:4});h.controller.update(4);assert(restored.object.visible);
 h.controller.sync([row('resident',5000)],{now:5});h.controller.update(5);assert(restored.object.visible);assert.equal(h.admissions(),2);
});
test('invalid or unsupported source evidence never creates parts',()=>{
 for(const mutate of [r=>{r.dead=false;r.deathConfirmed=false;},r=>r.deathConfirmed=false,r=>r.deadAt=0,r=>r.deathRecord.targetId='wrong',r=>r.deathRecord.deathKey='wrong',r=>r.deathRecord.cause='bullet',r=>r.deathRecord.fatal=false,r=>delete r.deathRecord.blastPresentation,r=>r.deathRecord.blastPresentation.originSource.r=NaN,r=>r.deathRecord.blastPresentation.visualSpeed=9]){
  const h=setup(),a=h.actor('resident'),r=row();mutate(r);h.controller.sync([r],{now:1});h.controller.update(1);assert.equal(h.admissions(),0);assert(a.object.visible);
 }
});
test('absolute source age, not receipt time, controls expiry; no replay after rejection',()=>{
 const h=setup(),a=h.actor('resident');h.controller.sync([row()],{now:200,sourceNowMs:10000});h.controller.update(200);assert.equal(h.admissions(),0);assert(a.object.visible);
 const k=setup();k.actor('resident');k.reject();k.controller.sync([row()],{now:1});k.controller.update(1);k.controller.sync([row()],{now:2});k.controller.update(2);assert.equal(k.admissions(),1);
});
test('bounded admission and ledger retain intact overflow victims',()=>{
 const h=setup({maxDeaths:2});for(const id of ['a','b','c'])h.actor(id);h.controller.sync(['a','b','c'].map(id=>row(id)),{now:1});h.controller.update(1);assert.equal(h.admissions(),1);h.controller.update(1.01);assert.equal(h.admissions(),2);assert(h.actors.get('c').object.visible);
 assert.equal(h.controller.diagnostics().deaths,2);
});
