import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {clone} from './test_npc_death_offline_setup.mjs';
import {createNpcActor,NPC_ASSETS} from './npc_actor.mjs';
import {normalizeNpcSnapshot,createNpcPopulation} from './npc_population.mjs';
import {normalizeNpcLifecycle} from './npc_source_lifecycle.mjs';
import {NPC_DISPLAY_CATALOGUE,NPC_SOURCE_CATALOGUE} from './npc_role_catalogue.mjs';
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,next){return next(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js')),{GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const sources={};for(const [sex,asset]of Object.entries(NPC_ASSETS)){const b=fs.readFileSync(new URL(asset.url));sources[sex]=(await new GLTFLoader().parseAsync(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength),'')).scene;}
const base={id:'existing-server-id',r:2,c:3},clock={time:12,sourceNowMs:900000};
// Execute the actual world helper, including its persistent timestamp map.
// This catches regressions in source classification rather than merely
// asserting that the renderer accepts our hand-authored normalized rows.
const worldSource=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),worldStart=worldSource.indexOf('function _threeNpcDeathState('),worldEnd=worldSource.indexOf('\nfunction _threeTrackCombatBleed(',worldStart),sandbox={_threeNpcDeathTimes:new Map()};
assert(worldStart>=0&&worldEnd>worldStart);vm.runInNewContext(worldSource.slice(worldStart,worldEnd)+'\nthis.classify=_threeNpcDeathState;',sandbox);
const families=['resident','said','unique_npc','empire_crew','empire_guard','gang_fighter','police_backup','city_cop','world_cop','convoy_boss','convoy_guard','aggro','gang_nest','business_guard','beach','michael','bus_passenger','race_staff','medic','junkyard_worker','building_interior','bank_interior','raid_guard','custody'];
for(const [i,family]of families.entries()){
 const id='existing:'+family,raw={hp:0,...(i%2?{alive:false}:{dead:true}),deadAt:899000},original=JSON.stringify(raw),death=sandbox.classify(raw,id,900000);
 assert.equal(death.dead,true,family+' legacy dead');assert.equal(death.deathConfirmed,true,family+' confirmed fatal');assert.equal(death.deadAt,899000);assert.equal(JSON.stringify(raw),original);
 assert.equal(normalizeNpcSnapshot({...base,id,...death},{time:12,sourceNowMs:900000}).lifecycle.age,1);
}
for(const hp of [undefined,null,'',false,NaN,Infinity]){const d=sandbox.classify({hp},'invalid-hp',900000);assert.equal(d.dead,false,'unusable hp is not zero');assert.equal(d.deathConfirmed,false);}
const sourceCases=[
 [{hp:0},true,false],
 [{hp:0,dead:true,_meleeStunnedUntil:901000},true,true],
 [{hp:25,dead:true,_meleeStunnedUntil:901000},true,false],
 [{hp:1,_medicalDowned:true},false,false],
 [{hp:0,dead:true,_medicalDowned:true},true,false],
 [{hp:0,dead:true,_empireDownUntil:901000},true,false],
 [{hp:0,dead:true,downed:true},true,false],
 [{hp:100,cuffed:true,_arrestPhase:'transport'},false,false],
 [{hp:0,dead:true,_medicalDowned:true,_deathConfirmed:true},true,true]
];for(const [raw,legacy,fatal]of sourceCases){const d=sandbox.classify(raw,'edge',900000);assert.equal(d.dead,legacy,JSON.stringify(raw));assert.equal(d.deathConfirmed,fatal,JSON.stringify(raw));}
const withoutTime={dead:true,hp:0};assert.equal(sandbox.classify(withoutTime,'stable-time',900000).deadAt,900000);assert.equal(sandbox.classify(withoutTime,'stable-time',901000).deadAt,900000);sandbox.classify({dead:false,hp:100},'stable-time',902000);assert.equal(sandbox.classify(withoutTime,'stable-time',903000).deadAt,903000);
for(const raw of [{hp:0},{hp:0,dead:false},{alive:false},{dead:true,deathConfirmed:false},{dead:true,meleeStunned:true},{dead:true,downed:true},{dead:true,lifeState:'downed'},{dead:true,meleeStunned:true,meleeStunnedUntil:1}])assert.equal(normalizeNpcLifecycle(raw,clock).dead,false,JSON.stringify(raw));
assert.equal(normalizeNpcLifecycle({dead:true,meleeStunned:true,deathConfirmed:true},clock).dead,true);
assert.equal(normalizeNpcLifecycle({dead:true,deadAt:899800},clock).age,.2,'iframe and render clocks are independent');
for(const row of [...NPC_DISPLAY_CATALOGUE,...NPC_SOURCE_CATALOGUE]){
 const src={...base,id:row.bridgeId||row.id,role:row.role||row.label,dead:true,deadAt:899000,deathConfirmed:true},before=JSON.stringify(src),snap=normalizeNpcSnapshot(src,clock);
 assert.equal(snap.life.id,src.id);assert.equal(snap.lifecycle.dead,true);assert.equal(snap.lifecycle.age,1);assert.equal(JSON.stringify(src),before);
}
const world=new THREE.Scene();let actors=0;
const roles=[...new Set(NPC_DISPLAY_CATALOGUE.map(x=>x.role)), 'empire_crew','empire_guard','bank_guard','gang','convoy_boss','convoy_guard','police_response'];
for(const [i,role]of roles.entries()){
 const sex=i%2?'female':'male',actor=createNpcActor({THREE,scene:world,source:sources[sex],cloneSkeleton:clone,id:'real:'+role,sex}),ctx=actor.walker.artistContext(),row={...base,id:actor.id,role,dead:true,deadAt:899000,deathConfirmed:true,forcedCrawl:true,cuffed:true,meleeStunned:true,downed:true,walking:true};
 const result=actor.update(0,normalizeNpcSnapshot(row,clock));assert.equal(result.reaction.kind,'dead');assert.equal(result.reaction.age,1);assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y<.7,role+' must already lie down on its first visible frame');assert.equal(actor.diagnostics().lifeGesture,null);
 const q=ctx.visualPivot.quaternion.clone();actor.update(.1,normalizeNpcSnapshot({...row,forcedCrawl:false,downed:false,meleeStunned:false},{time:12.1,sourceNowMs:900100}));assert(ctx.visualPivot.quaternion.angleTo(q)<1e-8,'death uses the same Artist14 neutral base, not double prone');
 const saved=actor.saveSurfaceState();assert(saved.surface.reaction.age>=1);actor.restoreSurfaceState(saved,{time:30,elapsedSeconds:17.9});actor.update(0,{time:30,life:{cuffed:true}});assert.equal(actor.surface.state.kind,'dead');assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y<.7,'corpse survives serialized cull');
 actor.update(.1,normalizeNpcSnapshot({...base,id:actor.id,dead:false,cuffed:true},{time:30.1}));assert.equal(actor.surface.state.kind,'idle');assert.equal(actor.diagnostics().lifeGesture,'cuffed');
 actor.update(0,normalizeNpcSnapshot({...base,id:actor.id,dead:true},{time:31}));assert.equal(actor.diagnostics().surface.reaction.age,0,'unknown timestamp fresh death starts now');assert(ctx.bones.head.getWorldPosition(new THREE.Vector3()).y>1,'fresh death is not snapped to an old corpse');
 actor.update(.1,normalizeNpcSnapshot({...base,id:actor.id,dead:true,deadAt:31000},{time:31.1,sourceNowMs:31100}));assert(actor.diagnostics().surface.reaction.age>=.1-1e-8,'timestamp hydration preserves death age');
 if(i<2){actor.update(.1,normalizeNpcSnapshot({...base,id:actor.id,dead:false},{time:32}));for(let j=0;j<10;j++)actor.update(.1,{time:32.1+j*.1,inWater:true,waterLevel:2,moving:true});assert(actor.diagnostics().surface.swim.blend>.8);actor.update(.1,normalizeNpcSnapshot({...base,id:actor.id,dead:true,deathConfirmed:true,deadAt:33000},{time:34,sourceNowMs:34000,waterAt:()=>({level:2,depth:2})}));assert(ctx.visualPivot.quaternion.angleTo(q)<1e-8,'residual swim does not compose a second tilt with authored death');}
 actor.dispose();actors++;
}
assert.equal(world.children.length,0);
const population=await createNpcPopulation({THREE,scene:world,loader:new GLTFLoader(),cloneSkeleton:clone,maxActors:2,creationBudget:1,cacheSeconds:.1});
const corpse={...base,dead:true,deathConfirmed:true,deadAt:40000};population.sync([corpse],1,45000);population.update(.1,1.1);let actor=population.getActor(base.id);assert(actor.walker.artistContext().bones.head.getWorldPosition(new THREE.Vector3()).y<.7,'creation budget cannot leave a fresh corpse standing');
population.sync([],1.2,45000);population.update(.2,1.4);assert(!population.getActor(base.id));population.sync([corpse],2,46000);population.update(.1,2.1);actor=population.getActor(base.id);assert.equal(actor.surface.state.kind,'dead');assert(actor.diagnostics().surface.reaction.age>=5,'serialized death does not replay');population.dispose();
console.log(JSON.stringify({passed:true,actualWorldFamilies:families.length,actualWorldEdgeCases:sourceCases.length,normalizedCatalogueEntries:NPC_DISPLAY_CATALOGUE.length+NPC_SOURCE_CATALOGUE.length,posedRoles:actors,checks:['source_clock_age','first_frame_corpse','fresh_death_animation','all_archetypes_shared_artist14_pose','no_double_prone','stun_medical_custody_preserved','fatal_over_stale_stun','eviction_reentry','explicit_respawn','timestamp_hydration','creation_budget']}));
