import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';
const source=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const fixtureText=fs.readFileSync(new URL('./test_mercenary_rally_actions.mjs',import.meta.url),'utf8');
const fixture=Function('vm','module','script','assert',fixtureText.slice(fixtureText.indexOf('async function fixture('),fixtureText.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,source,assert);
const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8'),loop=world.slice(world.indexOf('function _updateGang(dt) {'),world.indexOf('// Персистентность охраны банка:'));
async function combat(){const f=await fixture(),shots=[];f.recruit('medic');f.recruit('engineer');
 Object.assign(f.ctx,{_gangFormation:[],_gangFormationAng:0,_updateFormerGang(){},_tickGangChatter(){},_gangSay(){},_bankInt:null,_buildingInt:null,_majorInteriorObjectId:null,_majorRaidLocal:null,_businessInteriorMovementBlocked:()=>false,lockedTargets:new Set(),cityCops:[],_gangTargetPos:(k,r)=>({r:r.r??r.y,c:r.c??r.x}),GANG_ENGAGE_R:10,_interiorGuardWeaponAi:()=>({ideal:2,retreat:1}),GANG_SHOT_CD_MIN:1200,GANG_SHOT_CD_RANGE:600,GANG_SHOT_DMG_MIN:10,GANG_SHOT_DMG_RANGE:9,_npcMuzzleWorldPoint:(r,c)=>({r,c}),spawnBullet(){},spawnMuzzle(){},_mafiaDamageMultiplier:()=>1,_awardGangXp(){},_resolveGangAlertTarget:m=>m._threatUntil>f.ctx.performance.now()&&m._threatRef?.hp>0?{kind:'street_npc',ref:m._threatRef,id:m._threatRef.id}:null,
 hitNpc:(target,...args)=>shots.push({kind:'npc',target,args}),hitCityCop:(target,...args)=>shots.push({kind:'cop',target,args})});
 vm.runInContext(loop,f.ctx);const enemy={id:'enemy-focus',r:10,c:12,hp:100,dead:false};f.ctx.NPCS.push(enemy);f.api.bindTargets({canMove:()=>true});return {...f,shots,enemy,update:()=>f.ctx._updateGang(.05)};}
test('explicit focused target uses actual gang firing callbacks and death resumes independent threat',async()=>{
 const f=await combat(),other={id:'other-enemy',r:11,c:12,hp:100};f.ctx.NPCS.push(other);for(const m of f.ctx._myGang){m._threatRef=other;m._threatUntil=f.ctx.performance.now()+6000;}
 assert(f.api.getActions(f.api.getTarget(f.enemy.id)).some(a=>a.id==='eliminate'&&a.enabled));assert(f.api.command('eliminate',{id:f.enemy.id}).ok);assert.equal(f.enemy.hp,100,'order does not author damage');f.update();assert.equal(f.shots.length,2);assert(f.shots.every(s=>s.target===f.enemy));
 f.enemy.dead=true;for(const m of f.ctx._myGang)m._nextShootAt=0;f.update();assert.equal(f.shots.length,4);assert(f.shots.slice(2).every(s=>s.target===other));assert(f.ctx._myGang.every(m=>!m._mercenaryFocus&&m._threatRef===other));
});
test('neutral local police can be explicitly focused through existing cop hit authority',async()=>{
 const f=await combat(),cop={id:'cop1',x:12,y:10,hp:100,alive:true,_pursuing:false};f.ctx.cityCops.push(cop);assert(f.api.command('eliminate',{id:'npc:npc_city_cop_cop1'}).ok);f.update();assert.equal(f.shots.length,2);assert(f.shots.every(s=>s.kind==='cop'&&s.target===cop));assert.equal(cop.hp,100,'stub remains authoritative; order/loop adds no direct HP path');
});
test('focus outlasts ordinary alert timer and stops later shooters on same-frame kill',async()=>{
 const f=await combat();f.api.command('eliminate',{id:f.enemy.id});f.tick(8);assert(f.ctx._myGang.every(m=>f.api.getFocusedTarget(m.id)?.ref===f.enemy));let hits=0;f.ctx.hitNpc=target=>{hits++;target.hp=0;target.dead=true;};f.update();assert.equal(hits,1,'remaining shooter sees source death immediately');assert(f.ctx._myGang.every(m=>!f.api.getFocusedTarget(m.id)));
});
test('focus rejects own, downed, invulnerable, friendly, missing and unarmed-only orders',async()=>{
 const f=await combat();for(const id of [f.ctx._myGang[0].id,'missing'])assert.equal(f.api.command('eliminate',{id}).ok,false);
 for(const flag of ['dead','downed','_medicalDowned','_invulnerable','_allied','_friendly']){f.enemy[flag]=true;assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false,flag);delete f.enemy[flag];}
 for(const m of f.ctx._myGang)m.weapon=null;assert.equal(f.api.getActions(f.api.getTarget(f.enemy.id)).find(a=>a.id==='eliminate').enabled,false);assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false);
});
test('rally/follow cancel focus, despawn cancels identity without clearing other battle state',async()=>{
 const f=await combat();f.api.command('eliminate',{id:f.enemy.id});assert(f.api.rally({x:60,y:0,z:41}).ok);assert(f.ctx._myGang.every(m=>!m._mercenaryFocus));f.api.command('eliminate',{id:f.enemy.id});f.api.follow();assert(f.ctx._myGang.every(m=>!m._mercenaryFocus));
 f.api.command('eliminate',{id:f.enemy.id});f.ctx.NPCS.splice(f.ctx.NPCS.indexOf(f.enemy),1);f.ctx.NPCS.push({...f.enemy});f.update();assert.equal(f.shots.length,0);assert(f.ctx._myGang.every(m=>!m._mercenaryFocus));
});
test('downed source contact keeps root position and publishes actual chest point',async()=>{
 const f=await fixture(),medic=f.recruit('medic'),patient=f.recruit('bruiser');patient.hp=0;const root={x:patient.c*4.1,y:0,z:patient.r*4.1},t=f.api.getMember(patient.id);assert.deepEqual(JSON.parse(JSON.stringify(t.position)),root);assert.equal(t.workRange,.75);assert.equal(t.workPoint.y,.35);
 f.api.bindTargets({canMove:()=>true});f.api.command('revive',t);f.tick();assert.equal(medic._mercenaryAction.workPoint.y,.35);assert.deepEqual(JSON.parse(JSON.stringify(f.api.getAction(medic.id).workPoint)),JSON.parse(JSON.stringify(t.workPoint)));
});
test('moving contact metadata remains fresh, finite and isolated from published pose mutation',()=>{
 let time=0,last;const member={hp:100,position:{x:0,y:0,z:0}},target={id:'car',kind:'vehicle',position:{x:0,y:0,z:0},workPoint:{x:0,y:.7,z:1},workNormal:{x:0,y:0,z:1},supportPoint:{x:.1,y:.7,z:1}};
 const core=module.createMercenarySquad({now:()=>time,getMember:()=>member,getTarget:()=>target,onAction:(id,a)=>last=a});core.recruit({id:'demo',profession:'demolitions'});core.command('demo','plant_bomb','car');core.update();target.workPoint.x=2;time=1;core.update();assert.equal(last.workPoint.x,2);last.workPoint.x=999;assert.equal(core.getAction('demo').workPoint.x,2);assert.equal(target.workPoint.x,2);target.workNormal.x=NaN;core.update();assert.equal(last.workNormal,undefined);
});
test('focus assignment reaches 60m with LOS, physically approaches and preserves original firing range',async()=>{
 const f=await combat();f.enemy.c=10+55/4.1;let lineChecks=0;f.api.bindTargets({canMove:()=>true,hasLineOfSight:(from,to,id)=>{lineChecks++;assert.equal(id,f.enemy.id);assert(Math.hypot(to.x-from.x,to.z-from.z)>50);return true;}});
 assert(f.api.getActions(f.api.getTarget(f.enemy.id)).find(a=>a.id==='eliminate').enabled);assert(f.api.command('eliminate',{id:f.enemy.id}).ok);assert(lineChecks>=2);f.tick();f.update();assert.equal(f.shots.length,0);assert(f.ctx._myGang.some(m=>m._mercenaryMove?.phase==='focus_approach'));assert.equal(f.ctx.GANG_ENGAGE_R,10);
 for(let i=0;i<500&&!f.shots.length;i++){f.tick();f.update();}assert(f.shots.length>0);for(const shot of f.shots)assert.equal(shot.target,f.enemy);assert(f.ctx._myGang.some(m=>Math.hypot(m.r-f.enemy.r,m.c-f.enemy.c)<=10));assert.equal(f.ctx.GANG_ENGAGE_R,10);
 f.api.follow();f.api.bindTargets({canMove:()=>true,hasLineOfSight:()=>false});assert.equal(f.api.getActions(f.api.getTarget(f.enemy.id)).find(a=>a.id==='eliminate').enabled,false);assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false);
 f.api.bindTargets({canMove:()=>true,hasLineOfSight:()=>true});f.enemy.c=10+60.1/4.1;assert.equal(f.api.command('eliminate',{id:f.enemy.id}).ok,false);
});
