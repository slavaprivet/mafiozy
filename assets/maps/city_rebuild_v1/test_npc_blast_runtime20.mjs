import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {registerHooks} from 'node:module';import {pathToFileURL} from 'node:url';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot} from './npc_population.mjs';
import {createNpcBlastPartsPrototype20} from './npc_blast_parts_prototype20.mjs';
import {createNpcBlastPresentation20} from './npc_blast_presentation20.mjs';
const vendor='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';registerHooks({resolve(s,c,n){return n(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c)}});
const THREE=await import(pathToFileURL(vendor+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(vendor+'/addons/loaders/GLTFLoader.js')),{clone}=await import('./vendor/three_skeleton_utils.mjs');
const sourceApi=vm.createContext({});for(const file of ['npc_death_record20_source.js','npc_blast_record20_source.js'])vm.runInContext(fs.readFileSync(new URL(file,import.meta.url),'utf8'),sourceApi);
const reports=[],fps=Number(process.env.NPC_BLAST_FPS||60);assert([7,15,60].includes(fps));
for(const sex of ['male','female']){
 const bytes=fs.readFileSync(new URL(NPC_ASSETS[sex].url)),source=(await new GLTFLoader().parseAsync(bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength),'')).scene,scene=new THREE.Scene(),id='blast-runtime-'+sex;
 const make=()=>createNpcActor({THREE,scene,source,cloneSkeleton:clone,id,sex});let actor=make();
 const entity={id,dead:true,deadAt:1000};entity._deathRecord20=sourceApi.createNpcFatalRecord20({entity,targetId:id,weapon:'rpg',dirR:0,dirC:1,now:1000});entity._deathRecord20=sourceApi.enrichNpcBlastRecord20({entity,previousRecord:null,originSource:{r:0,c:0}});
 let row={id,r:0,c:1,ang:0,dead:true,deathConfirmed:true,deadAt:1000,deathRecord:entity._deathRecord20};
 const parts=createNpcBlastPartsPrototype20(THREE,scene,{groundHeight:()=>3}),host=createNpcBlastPresentation20({parts,getActor:()=>actor,groundHeight:()=>3});
 function tick(t){host.sync([row],{now:t});actor.update(1/fps,normalizeNpcSnapshot(row,{time:t,sourceNowMs:t*1000,groundHeight:()=>3}));host.update(t);}
 let frames=0;for(;frames<Math.ceil(fps*7.9);frames++){tick(1+frames/fps);const stat=parts.stats();if(!stat.activeVictims)assert(actor.object.visible,'body remains until complete geometry');else{assert(!actor.object.visible,'no whole body plus fragments');break;}}
 assert(frames<Math.ceil(fps*7.9),'bounded preparation reaches ready before TTL at '+fps+'Hz');assert.equal(parts.stats().parts,6);assert.equal(actor.surface.state.kind,'dead');assert(actor.isDeathVisualReplaced('1000'));
 const snapshot=JSON.parse(JSON.stringify(actor.saveSurfaceState()));assert.equal(snapshot.deathPresentation.visualReplaced,true);actor.dispose();actor=make();actor.restoreSurfaceState(snapshot);tick(2+frames/fps);assert(!actor.object.visible,'recreated actor stays replaced');
 tick(10);assert.equal(parts.stats().parts,0);assert.equal(host.diagnostics().deaths,0,'expired queue history retired');assert(!actor.object.visible,'saved replacement survives expired queue history');
 const invalid=structuredClone(snapshot);invalid.sourceDeathKey='wrong';const stable=JSON.stringify(actor.saveSurfaceState());assert.throws(()=>actor.restoreSurfaceState(invalid));assert.equal(JSON.stringify(actor.saveSurfaceState()),stable);
 row={id,r:0,c:1,dead:false};tick(11);assert(actor.object.visible,'explicit source respawn restored independently');assert(!actor.isDeathVisualReplaced('1000'));
 reports.push({sex,fps,framesToReady:frames,secondsToReady:frames/fps,maxSliceMs:parts.stats().maxSliceMs,geometryReleased:parts.stats().geometryBytes===0});host.dispose();actor.dispose();assert.equal(scene.children.length,0);
}
console.log(JSON.stringify({pass:true,reports,scope:'Actual source metadata helpers -> actor/source lifecycle -> bounded parts -> host atomic replacement -> saved actor recreation -> TTL -> explicit respawn. Browser/GPU pending.'}));
