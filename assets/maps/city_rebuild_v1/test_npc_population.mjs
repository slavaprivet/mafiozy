import fs from 'node:fs';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {pathToFileURL} from 'node:url';
import {normalizeNpcSnapshot,npcAppearanceFromWorld,npcWeaponId,createNpcPopulation} from './npc_population.mjs';
const failures=[],checks=[];
async function check(name,fn){try{await fn();checks.push(name);}catch(e){failures.push({name,error:e.message});}}
const base={id:'npc_resident_42',r:7,c:11,ang:0,weapon:'fists'};
await check('native4.1 and floating origins',()=>{const s=normalizeNpcSnapshot(base,{time:10,groundHeight:()=>2});assert.deepEqual(s.position,{x:45.099999999999994,y:2,z:28.699999999999996});const t=normalizeNpcSnapshot(base,{time:10,originR:2,originC:3});assert(Math.abs(t.position.x-32.8)<1e-8);assert(Math.abs(t.position.z-20.5)<1e-8);});
await check('source atan2(dR,dC) maps actor +Z to native displacement',()=>{for(const angle of [0,Math.PI/2,Math.PI,-Math.PI/2,.73]){const s=normalizeNpcSnapshot({...base,ang:angle},{time:10});assert(Math.abs(Math.sin(s.yaw)-Math.cos(angle))<1e-8);assert(Math.abs(Math.cos(s.yaw)-Math.sin(angle))<1e-8);}});
await check('all source roles preserve existing ids and role appearance',()=>{for(const role of ['civilian','said','unique_npc','empire_crew','empire_guard','police','prison_police','gang','medic','bank_guard','junkyard_worker','owner']){const src={...base,id:'npc_'+role+'_same-server-id',role};const snap=normalizeNpcSnapshot(src,{time:100});assert.equal(snap.life.id,src.id);const descriptor=npcAppearanceFromWorld(src);assert.equal(descriptor.id,src.id);assert.equal(descriptor.role,role);}});
await check('world weapons map to canonical meshes',()=>{for(const [source,target]of Object.entries({pistol:'tt_pistol',pistol_heavy:'deagle',rifle:'ak74',smg:'uzi',pistol_gold:'golden_colt',golden_tommy:'tommy_gun',nagan:'nagan',fists:'none'}))assert.equal(npcWeaponId(source),target,source);});
await check('idle melee does not block life gesture',()=>{const s=normalizeNpcSnapshot({...base,_shotAt:0,talking:true},{time:40});assert(!s.action||s.action.type==='none');});
await check('independent iframe shot clock',()=>{const s=normalizeNpcSnapshot({...base,_shotAt:120000,meleeType:'kick'},{time:4,sourceNowMs:120200});assert.equal(s.action?.type,'kick');assert(Math.abs(s.action.progress-.2/.62)<1e-8);});
await check('missing id/invalid coordinates rejected',()=>{assert.throws(()=>normalizeNpcSnapshot({...base,id:''},{time:1}));assert.throws(()=>normalizeNpcSnapshot({...base,r:NaN},{time:1}));});
const deps='D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';
registerHooks({resolve(specifier,context,nextResolve){return nextResolve(specifier==='three'?pathToFileURL(deps+'/build/three.module.js').href:specifier,context);}});
const THREE=await import(pathToFileURL(deps+'/build/three.module.js'));
const {GLTFLoader}=await import(pathToFileURL(deps+'/addons/loaders/GLTFLoader.js'));
const skeletonSource=await (await fetch('https://cdn.jsdelivr.net/npm/three@0.180.0/examples/jsm/utils/SkeletonUtils.js')).text();
const {clone}=await import('data:text/javascript;base64,'+Buffer.from(skeletonSource.replace("from 'three'","from '"+pathToFileURL(deps+'/build/three.module.js').href+"'")).toString('base64'));
const originalFetch=globalThis.fetch;
globalThis.fetch=async(url,options)=>String(url).startsWith('file:')?{ok:true,arrayBuffer:async()=>{const bytes=fs.readFileSync(new URL(url));return bytes.buffer.slice(bytes.byteOffset,bytes.byteOffset+bytes.byteLength);}}:originalFetch(url,options);
const scene=new THREE.Scene(),population=await createNpcPopulation({THREE,scene,loader:new GLTFLoader(),cloneSkeleton:clone,maxActors:4});
globalThis.fetch=originalFetch;
const row={...base,id:'npc_police_server_9',role:'police',weapon:'pistol',look:{gender:0}};
population.sync([row],1);population.update(.1,1);const actor=population.getActor(row.id);
await check('actual actor stable id, duplicate rows and weapon',()=>{assert.equal(actor.id,row.id);assert.equal(actor.weapon.userData.weaponId,'tt_pistol');population.sync([row,{...row}],2);assert.equal(population.getActors().length,1);assert.equal(population.getActor(row.id),actor);});
await check('confirmed injury stays attached through culling',()=>{const ctx=actor.walker.artistContext();actor.object.updateMatrixWorld(true);const point=ctx.bones.head.getWorldPosition(new THREE.Vector3());assert(population.receive(row.id,{id:'bruise-1',confirmed:true,point,zone:'head'}));const rayStart=ctx.offset.localToWorld(new THREE.Vector3(0,2.8,2)),direction=new THREE.Vector3(0,0,-1).applyQuaternion(ctx.offset.getWorldQuaternion(new THREE.Quaternion())),meshes=[];ctx.scene.traverse(o=>{if(o.isSkinnedMesh){o.skeleton.update();o.computeBoundingSphere();meshes.push(o);}});const hit=new THREE.Raycaster(rayStart,direction,0,4).intersectObjects(meshes,false)[0];assert(hit);assert(population.receive(row.id,{id:'tear-1',confirmed:true,kind:'bullet',point:hit.point,normal:direction.clone().negate(),clothing:true}));assert(ctx.scene.getObjectByName('PersistentBulletWounds').children.length>0);population.update(.1,2.1);population.sync([],3);assert.notEqual(actor.surface.state.kind,'dead');assert.equal(actor.object.visible,false);assert.equal(population.getActor(row.id),actor);});
await check('culling also hides sibling particle pool',()=>{assert.equal(actor.surface.particles.visible,false);});
await check('8second GPU eviction restores persistent CPU state on reentry',()=>{population.sync([],12);assert(!population.getActor(row.id),'hidden GPU actor must be disposed after8s');assert(population.diagnostics().serialized>0);population.sync([row],101);const restored=population.getActor(row.id);assert(restored&&restored!==actor,'must recreate GPU actor');const marks=[];restored.walker.artistContext().scene.traverse(o=>{if(o.name==='Artist14EyeBruise')marks.push(o)});assert(marks.some(o=>o.visible));assert(restored.walker.artistContext().scene.getObjectByName('PersistentBulletWounds').children.length>0);});
await check('temporary knockout not permanent death, actual death receipt yes',()=>{population.sync([{...row,dead:true,meleeStunned:true,deadAt:101000}],102);assert.notEqual(population.getActor(row.id).surface.state.kind,'dead');population.sync([{...row,dead:true,meleeStunned:false,deadAt:103000}],103);assert.equal(population.getActor(row.id).surface.state.kind,'dead');population.sync([],104);assert.equal(population.getActor(row.id).surface.state.kind,'dead');});
await check('low HP cannot synthesize death',()=>{const alive={...base,id:'npc_low-hp',hp:0,dead:false};population.sync([alive],105);assert.notEqual(population.getActor(alive.id).surface.state.kind,'dead');});
await check('10Hz visual interpolation and short yaw arc without AI mutation',()=>{
 const from={...base,id:'npc_interp',r:0,c:0,ang:Math.PI/2-(Math.PI-.05)},to={...from,c:1/4.1,ang:Math.PI/2-(-Math.PI+.05)};
 population.sync([from],200);population.update(0,200);const visual=population.getActor(from.id);population.sync([to],200.1);population.update(.05,200.15);
 assert(Math.abs(visual.object.position.x-.5)<1e-6,'between snapshots half distance');assert(Math.abs(Math.abs(visual.object.rotation.y)-Math.PI)<1e-6,'shortest arc across pi');assert.equal(to.c,1/4.1,'source AI row immutable');
 population.update(.05,200.2);assert(Math.abs(visual.object.position.x-1)<1e-6);
 population.sync([{...to,c:11/4.1}],200.3);assert(Math.abs(visual.object.position.x-11)<1e-6,'teleport >8m immediate');
});
await check('slow snapshot frames do not double presentation speed',()=>{
 const start={...base,id:'npc_longframe',r:0,c:0};population.sync([start],200.4);population.update(0,200.4);const actor=population.getActor(start.id);
 population.sync([{...start,c:.92/4.1}],200.6);population.update(.1,200.7);
 assert(Math.abs(actor.object.position.x-.46)<1e-6,'200ms source movement takes200ms, not100ms');
 const motion=population.diagnostics().motion.samples.find(s=>s.id===start.id);assert(Math.abs(motion.speed-4.6)<1e-6);assert(Math.abs(motion.dt-.2)<1e-6);
 population.sync([{...start,c:1.38/4.1}],200.7);const before=actor.object.position.x;population.update(.05,200.75);assert(actor.object.position.x-before<=4.6*.05+1e-6,'pending distance does not produce catch-up sprint');
});
await check('actual GLB legs animate at1.5m/s despite false walking and600ms snapshots',()=>{
 const start={...base,id:'npc_gait_slowframe',r:0,c:0,walking:false};population.sync([start],201);population.update(.04,201);const actor=population.getActor(start.id),bones=actor.walker.artistContext().bones,rest=bones.thigh_l.matrix.clone(),poses=[];
 for(let i=1;i<=5;i++){const time=201+i*.6;population.sync([{...start,c:(1.5*i*.6)/4.1}],time);population.update(.04,time);poses.push(bones.thigh_l.matrix.clone());assert.equal(population.diagnostics().motion.samples.find(s=>s.id===start.id).speed,1.5);}
 assert(poses.some(matrix=>!matrix.equals(rest)),'moving GLB must leave idle legs');assert(!poses[0].equals(poses.at(-1)),'legs continue stepping between samples');
});
await check('distance-driven gait phase equal at60FPS15FPS600ms and stationary feet stop',()=>{
 const actor=population.getActor('npc_gait_slowframe'),phases=[];
 for(const frames of [180,45,5]){actor.walker.reset();for(let frame=0;frame<frames;frame++)actor.update(Math.min(.04,3/frames),{time:210+frame*3/frames,position:{x:4.5*(frame+1)/frames,y:0,z:0},moving:true,motionSpeed:1.5,gaitDistance:4.5/frames,life:{},posture:{target:'stand',value:0}});phases.push(actor.walker.diagnostics().phase)}
 for(const phase of phases)assert(Math.abs(phase-4.5*2.3)<1e-8);
 actor.walker.reset();actor.update(.04,{time:214,position:{x:4.5,y:0,z:0},moving:true,motionSpeed:1.5,gaitDistance:0,life:{}});assert.equal(actor.walker.diagnostics().phase,0,'zero actual distance cannot advance a retained moving-speed phase');
});
await check('GPU hard cap under rapid roster churn',()=>{for(let wave=0;wave<3;wave++){const rows=Array.from({length:4},(_,i)=>({...base,id:'npc_churn_'+wave+'_'+i}));population.sync(rows,215+wave*.1);assert(population.diagnostics().cached<=population.diagnostics().maxCachedActors);}assert(population.diagnostics().serialized>=4);});
await check('death survives serialized eviction and only explicit respawn clears it',()=>{
 const dead={...row,dead:true,deadAt:300000};population.sync([dead],300);population.update(.1,300.1);population.sync([],301);population.update(.1,310);assert(!population.getActor(row.id));population.sync([dead],311);assert.equal(population.getActor(row.id).surface.state.kind,'dead');
 population.sync([{...row}],312);assert.equal(population.getActor(row.id).surface.state.kind,'dead','omitted lifecycle is not respawn');population.sync([{...row,dead:true,meleeStunned:true}],313);assert.equal(population.getActor(row.id).surface.state.kind,'dead','stun cannot heal saved death');
 population.sync([{...row,dead:false}],314);assert.equal(population.getActor(row.id).surface.state.kind,'idle','explicit authoritative respawn resets lifecycle');
});
await check('actual bridge clock object uses performance now, not epoch or renderer time',()=>{
 let clock={now:120200,epochNow:1790000000000,renderer:'walk'};const source={...base,id:'npc_clock_object',_shotAt:120000,meleeType:'kick'};
 population.attach({getWorldClock:()=>clock,getDynamicEntities:()=>({npcs:[source]})});population.update(.1,315);
 const actor=population.getActor(source.id);assert.equal(actor.walker.meleePresentation().type,'kick');assert(Math.abs(actor.walker.meleePresentation().age-.2)<1e-8);
 clock={...clock,now:120400};population.update(.05,315.05);assert(Math.abs(actor.walker.meleePresentation().age-.4)<1e-8);
 clock=120300;population.update(.01,315.06);assert(Math.abs(actor.walker.meleePresentation().age-.3)<1e-8,'numeric bridge backwards compatibility');
 clock={now:NaN,epochNow:1790000000000};population.update(.1,316);assert(!actor.walker.meleePresentation()?.active,'invalid source now falls back to finite render time');population.attach(null);
});
await check('population disposal removes actor and pools',()=>{population.dispose();population.dispose();assert.equal(scene.children.length,0);});
console.log(JSON.stringify({passed:checks.length,checks,failures},null,2));if(failures.length)process.exitCode=1;
