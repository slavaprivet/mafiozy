import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {createMercenarySquad} from './mercenary_core.mjs';

test('single-record projection matches full roster and stays fresh and deeply isolated',()=>{
 let now=1000;
 const live={id:'specialist',hp:100,position:{x:0,y:0,z:0}};
 const squad=createMercenarySquad({now:()=>now,getMember:()=>live,performEffect:()=>true});
 const parity=id=>{const record=squad.getRecord(id);assert.deepEqual(record,squad.getRoster().find(r=>r.id===id));return record;};
 for(const id of [undefined,null,0,'missing','npc:specialist'])assert.equal(parity(id),undefined);
 assert(squad.recruit({id:live.id,profession:'safecracker',name:'Original name'}).ok);
 assert(squad.recruit({id:'other',profession:'bruiser'}).ok);
 parity(live.id);assert.equal(parity('npc:'+live.id),undefined);
 const weapon={id:'rifle',attachments:{optic:{zoom:2}},ammo:[8,9]};
 squad.setWeapon(live.id,weapon);weapon.attachments.optic.zoom=99;
 assert.equal(parity(live.id).weapon.attachments.optic.zoom,2);
 assert(squad.addXP(live.id,210));assert(squad.upgrade(live.id,'lockpicking').ok);
 const before=parity(live.id);
 before.name='Mutated';before.skills.lockpicking=99;before.cooldowns.unlock_safe=99999;
 before.weapon.attachments.optic.zoom=0;before.weapon.ammo.push(100);
 const fresh=parity(live.id);
 assert.equal(fresh.name,'Original name');assert.equal(fresh.skills.lockpicking,1);
 assert.equal(fresh.cooldowns.unlock_safe,undefined);assert.equal(fresh.weapon.attachments.optic.zoom,2);
 assert.deepEqual(fresh.weapon.ammo,[8,9]);assert.notEqual(fresh,before);
 assert.notEqual(fresh.skills,before.skills);assert.equal(parity('other').weapon,null);
 live.hp=0;squad.update();assert.equal(parity(live.id).status,'downed');
 now+=20;squad.update();const hospitalized=parity(live.id);
 assert.equal(hospitalized.status,'hospital');assert.equal(hospitalized.hospitalRemaining,300);
 now+=1.25;assert.equal(parity(live.id).hospitalRemaining,298.75);
 assert.equal(hospitalized.hospitalRemaining,300,'Previously returned copies remain isolated');
 now+=298.75;squad.update();assert.equal(parity(live.id).status,'returning');
 live.hp=80;live.followArrived=true;squad.update();assert.equal(parity(live.id).status,'active');
 squad.setWeapon(live.id,null);assert.equal(parity(live.id).weapon,null);
 assert(squad.dismiss(live.id).ok);assert.equal(parity(live.id),undefined);
 assert(squad.recruit({id:live.id,profession:'medic',name:'Replacement'}).ok);
 assert.equal(parity(live.id).profession,'medic');assert.equal(parity(live.id).xp,0);
});

const coreSource=fs.readFileSync(new URL('./mercenary_core.mjs',import.meta.url),'utf8');
const worldSource=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8');
const copyExpression='const copy=v=>JSON.parse(JSON.stringify(v));';
const recordExpression='const record=id=>core?.getRecord(id);';
let fixtureSequence=0;
const plain=value=>JSON.parse(JSON.stringify(value));

async function sourceFixture(legacy=false){
 assert(coreSource.includes(copyExpression),'Instrument actual core copy, not an imitation');
 assert(worldSource.includes(recordExpression),'Exercise actual production record helper');
 const audited=coreSource.replace(copyExpression,
  'const copy=v=>{copyAudit.push({fullRoster:Array.isArray(v),records:Array.isArray(v)?v.length:(v&&typeof v.id===\'string\'?1:0)});return JSON.parse(JSON.stringify(v));};');
 const module=await import('data:text/javascript;base64,'+Buffer.from(
  'export const copyAudit=[];\n'+audited+'\n// fixture '+fixtureSequence++).toString('base64'));
 let now=1000000,core;
 const injected={...module,createMercenarySquad(options){core=module.createMercenarySquad(options);return core;}};
 const script=(legacy?worldSource.replace(recordExpression,'const record=id=>core?.getRoster().find(m=>m.id===id);'):worldSource)
  .replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
 const storage=new Map();
 const ctx={module:injected,URL,Promise,console,Date:{now:()=>now*1000},performance:{now:()=>now*1000},
  document:{documentElement:{dataset:{}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},
  location:{origin:'http://localhost'},window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},
  localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},
  _LOCAL_PREVIEW:true,_serverAuthoritativeAmmo:false,_customGang:null,_myGang:[],
  NPCS:Array.from({length:8},(_,i)=>({id:'resident'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:'Resident '+i,look:{hair:i}})),
  player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:5,_hiredBotIds:new Set(),
  _inventoryItems:[{id:'pistol',type:'weapon',qty:2,name:'Pistol'},{id:'rifle',type:'weapon',qty:1,attachments:{optic:2}}],
  currentWeapon:'pistol',QP:{cash:500},_syncMyWeaponsFromInventory(){},_saveCurrentWeaponChoice(){},
  renderWeaponHud(){},_saveGang(){},_npcBodyPassable:()=>true,_npcPathPassable:()=>true,_hospitalDoor:()=>({r:10,c:11})};
 ctx._dismissGangMember=id=>{const index=ctx._myGang.findIndex(m=>m.id===id);if(index<0)return false;ctx._myGang.splice(index,1);return true;};
 vm.createContext(ctx);vm.runInContext(script,ctx);await new Promise(resolve=>setImmediate(resolve));
 const api=ctx.window.MafioziMercenaries;
 assert.equal(api.ready,true);
 for(const candidate of api.getRoster().candidates)assert(api.recruit(candidate.id).ok);
 const target={id:'traffic:car',kind:'vehicle',position:{x:41,y:0,z:41},locked:true};
 api.bindTargets({get:id=>id===target.id?target:null,performEffect:()=>true});
 return {api,ctx,core,target,audit:module.copyAudit,advance:seconds=>{now+=seconds;}};
}

test('actual source getActions preserves results while full-roster deep copies become single-record copies',async t=>{
 const before=await sourceFixture(true),after=await sourceFixture();
 const sample=f=>{f.audit.length=0;const actions=plain(f.api.getActions(f.target));return {actions,copies:f.audit.length,fullRosterCopies:f.audit.filter(v=>v.fullRoster).length,recordsCopied:f.audit.reduce((n,v)=>n+v.records,0)};};
 const a=sample(before),b=sample(after);
 assert.deepEqual(b.actions,a.actions);assert.equal(a.actions.length,2);
 assert.deepEqual({copies:a.copies,fullRosterCopies:a.fullRosterCopies,recordsCopied:a.recordsCopied},{copies:2,fullRosterCopies:2,recordsCopied:10});
 assert.deepEqual({copies:b.copies,fullRosterCopies:b.fullRosterCopies,recordsCopied:b.recordsCopied},{copies:2,fullRosterCopies:0,recordsCopied:2});
 t.diagnostic('Five-member locked-car getActions: copy calls 2 -> 2; full roster copies 2 -> 0; member records copied 10 -> 2. Structural counts, not a timing/FPS benchmark.');
 const observe=f=>plain({roster:f.api.getRoster(),actions:f.api.getActions(f.target),inventory:f.ctx._inventoryItems,
  members:f.ctx._myGang.map(m=>f.api.getMember(m.id)),gang:f.ctx._myGang.map(m=>({id:m.id,sourceBotId:m.sourceBotId,name:m.name,look:m.look,hp:m.hp,weapon:m.weapon}))});
 const parity=()=>assert.deepEqual(observe(after),observe(before));parity();
 for(const f of [before,after]){
  const specialist=f.api.getRoster().members.find(m=>m.profession==='safecracker'),id=specialist.id;
  assert.equal(f.api.isMercenary('npc:'+id),false,'Exact membership helper semantics stay unchanged');
  assert.equal(f.api.isMercenary('unknown'),false);assert.equal(f.api.getMember('unknown'),null);
  for(const alias of [id,'crew_'+id,'npc_crew_'+id,'npc:npc_crew_'+id])assert.equal(f.api.getMember(alias).id,id);
  assert(f.api.equip(id,'rifle').ok);f.core.addXP(id,210);assert(f.api.upgrade(id,'lockpicking').ok);
 }
 parity();
 for(const f of [before,after]){
  const id=f.api.getRoster().members.find(m=>m.profession==='safecracker').id;
  f.ctx._myGang.find(m=>m.id===id).hp=0;
  assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,false,'Raw HP is read immediately without tick/cache');
  f.ctx._myGang.find(m=>m.id===id).hp=80;
  assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,true);
  assert(f.api.command('unlock_door',f.target).ok);
  assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,false,'Command mutation is visible immediately');
  assert(f.api.cancelCommand(id).ok);
  assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,true);
  assert(f.api.command('unlock_door',f.target).ok);f.api.tick(.05);f.advance(6);f.api.tick(.05);
  assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,false,'Completed action cooldown stays authoritative');
  f.advance(2);assert.equal(f.api.getActions(f.target).find(a=>a.id==='unlock_door').enabled,true,'Cooldown expiry is fresh without tick');
  for(const m of f.ctx._myGang)m.hp=0;
  f.api.tick(.05);f.advance(21);f.api.tick(.05);
 }
 parity();
 for(const f of [before,after]){
  assert(f.api.getRoster().members.every(m=>m.status==='hospital'));
  assert(f.api.getActions(f.target).every(a=>!a.enabled));
  f.advance(1.5);assert.equal(f.api.getRoster().members[0].hospitalRemainingSeconds,298.5);
 }
 parity();
 for(const f of [before,after]){
  const id=f.api.getRoster().members.find(m=>m.profession==='safecracker').id;
  assert(f.api.dismiss(id).ok);assert.equal(f.api.isMercenary(id),false);assert.equal(f.api.getMember(id),null);
  assert.equal(f.ctx._inventoryItems.find(w=>w.id==='rifle').qty,1);
 }
 parity();
});
