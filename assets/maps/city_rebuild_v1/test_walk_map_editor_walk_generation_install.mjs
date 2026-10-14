import assert from 'node:assert/strict';
import test from 'node:test';
import {readFile} from 'node:fs/promises';
import {auditWalkPreviewGenerationInstallSourceContract,createWalkMapEditorWalkGenerationInstall,WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS,WALK_MAP_EDITOR_WALK_GENERATION_INSTALL_SCHEMA} from './walk_map_editor_walk_generation_install.mjs';

const value=name=>({name}),state=label=>Object.fromEntries(WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS.map(key=>[key,['instances','bodies','carBodies','entries'].includes(key)?[value(`${label}:${key}`)]:value(`${label}:${key}`)]));
const generation=(label,nextState=state(label))=>{const generation={id:label,installState:nextState},stage={generation,groups:nextState.instances};return stage};
function harness({throwInstall=false,failRestore=false,verify=true}={}){
 let live=state('prior'),criticalDepth=0,criticalEnters=0,criticalLeaves=0,swaps=0,restores=0,disposals=0,verifies=0;const events=[];
 const bindings={captureState(){return live},async enterCriticalSection({label}){assert.equal(criticalDepth,0);criticalDepth++;criticalEnters++;events.push(`enter:${label}`);return async()=>{criticalDepth--;criticalLeaves++;events.push(`leave:${label}`)}},async swapState(next){assert.equal(criticalDepth,1);swaps++;events.push('swap');live=next;if(throwInstall)throw new Error('partial swap failed')},async verifyState(){verifies++;events.push('verify');return verify?{ok:true,sampleId:'live-proof'}:{ok:false,sampleId:'bad-live'}},async restoreState(previous){assert.equal(criticalDepth,1);restores++;events.push('restore');if(failRestore)throw new Error('restore failed');live=previous},async disposeState(previous){assert.notEqual(live,previous,'current live generation must never be disposed');disposals++;events.push('dispose-prior') }};
 const installer=createWalkMapEditorWalkGenerationInstall({bindings});return {installer,bindings,events,get live(){return live},get criticalDepth(){return criticalDepth},get criticalEnters(){return criticalEnters},get criticalLeaves(){return criticalLeaves},get swaps(){return swaps},get restores(){return restores},get disposals(){return disposals},get verifies(){return verifies}};
}

test('actual walk source exposes every state anchor but no atomic snapshot/swap/restore/release seam yet',async()=>{
 const source=await readFile(new URL('walk_preview.mjs',import.meta.url),'utf8'),audit=auditWalkPreviewGenerationInstallSourceContract({walkPreviewSource:source});assert.equal(audit.ready,false);assert.equal(Object.keys(audit.inventory).length,WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS.length);for(const [name,present] of Object.entries(audit.inventory))assert.equal(present,true,name);assert.equal(audit.checks.destructiveClear,true);assert.equal(audit.checks.directGlobalWrites,true);assert.equal(audit.checks.atomicSwapExported,false);assert.equal(audit.checks.snapshotExported,false);assert.equal(audit.checks.restoreExported,false);assert.equal(audit.checks.releaseAfterVerify,false);assert.equal(audit.gaps.length,5);
});

test('success swaps once, verifies exact references, then and only then releases prior generation',async()=>{
 const h=harness(),prior=h.live,snapshot=h.installer.snapshotGeneration({id:'success'}),stage=generation('next');assert.equal(snapshot.schema,WALK_MAP_EDITOR_WALK_GENERATION_INSTALL_SCHEMA);assert.equal(snapshot.state,prior);for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS)assert.equal(snapshot.state[key],prior[key],key);const installed=await h.installer.installGeneration(stage,{snapshot});assert.equal(installed.installed,true);assert.equal(installed.noop,false);assert.equal(h.live,stage.generation.installState);assert.equal(h.swaps,1);assert.equal(h.disposals,0);const verified=await h.installer.verifyInstalled({stage,expected:{signature:'signature-1'}});assert.deepEqual({ok:verified.ok,signature:verified.signature,sampleId:verified.sampleId},{ok:true,signature:'signature-1',sampleId:'live-proof'});assert.equal(h.live.instances,stage.groups);assert.equal(await h.installer.releaseGeneration(snapshot,{result:installed,verification:verified}),true,'atomic release context does not carry stage');assert.equal(h.disposals,1);assert.equal(snapshot.released,true);assert.equal(h.criticalEnters,1);assert.equal(h.criticalLeaves,1);assert.equal(h.criticalDepth,0);await h.installer.dispose();
});

test('partial install throw restores every exact prior reference inside the same critical section',async()=>{
 const h=harness({throwInstall:true}),prior=h.live,snapshot=h.installer.snapshotGeneration(),stage=generation('broken');await assert.rejects(()=>h.installer.installGeneration(stage,{snapshot}),/partial swap failed/);assert.equal(h.live,prior);for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS)assert.equal(h.live[key],prior[key],key);assert.equal(h.swaps,1);assert.equal(h.restores,1);assert.equal(h.disposals,0);assert.deepEqual(h.events,['enter:walk-generation-install','swap','restore','leave:walk-generation-install']);assert.equal(h.criticalDepth,0);await h.installer.dispose();
});

test('install plus failed verification keeps prior alive and exact restore recovers arrays/controllers/listeners',async()=>{
 const h=harness({verify:false}),prior=h.live,snapshot=h.installer.snapshotGeneration(),stage=generation('unverified');await h.installer.installGeneration(stage,{snapshot});const verdict=await h.installer.verifyInstalled({stage,expected:{signature:'sig'}});assert.equal(verdict.ok,false);assert.equal(h.disposals,0);await h.installer.restoreGeneration(snapshot,{stage,error:new Error('verify failed')});assert.equal(h.live,prior);for(const key of WALK_MAP_EDITOR_WALK_INSTALL_STATE_KEYS)assert.equal(h.live[key],prior[key],key);assert.equal(snapshot.restored,true);assert.equal(h.restores,1);await assert.rejects(()=>h.installer.releaseGeneration(snapshot,{stage}),error=>error.code==='WALK_INSTALL_RELEASE_INVALID');assert.equal(h.disposals,0);await h.installer.dispose();
});

test('repeated installation of the same verified generation is a no-op without a second swap',async()=>{
 const h=harness(),snapshot=h.installer.snapshotGeneration(),stage=generation('stable'),first=await h.installer.installGeneration(stage,{snapshot});assert.equal(first.noop,false);await h.installer.verifyInstalled({stage,expected:{signature:'sig'}});const second=await h.installer.installGeneration(stage,{snapshot});assert.equal(second.noop,true);assert.equal(second.receipt.generation,stage.generation);assert.equal(h.swaps,1);assert.equal(h.criticalEnters,1);await h.installer.releaseGeneration(snapshot,{});assert.equal(h.disposals,1);await h.installer.dispose();
});

test('restore failure is aggregated with the install error and never releases either generation',async()=>{
 const h=harness({throwInstall:true,failRestore:true}),snapshot=h.installer.snapshotGeneration(),stage=generation('double-failure');await assert.rejects(()=>h.installer.installGeneration(stage,{snapshot}),error=>error instanceof AggregateError&&error.errors.length===2);assert.equal(h.disposals,0);assert.equal(h.criticalDepth,0);assert.equal(h.criticalLeaves,1);await h.installer.dispose();
});

test('dispose is idempotent and never disposes the live or captured state',async()=>{
 const h=harness(),prior=h.live,snapshot=h.installer.snapshotGeneration(),one=h.installer.dispose(),two=h.installer.dispose();assert.equal(one,two);await one;assert.equal(h.live,prior);assert.equal(h.disposals,0);await assert.rejects(()=>h.installer.installGeneration(generation('late'),{snapshot}),error=>error.code==='WALK_INSTALL_DISPOSED');assert.throws(()=>h.installer.snapshotGeneration(),error=>error.code==='WALK_INSTALL_DISPOSED');
});
