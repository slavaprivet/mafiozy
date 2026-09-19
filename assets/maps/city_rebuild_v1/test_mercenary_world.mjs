import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import * as module from './mercenary_core.mjs';
import {sourceFunction} from './test_civilian_native_fixture.mjs';
const script=fs.readFileSync(new URL('./mercenary_world.js',import.meta.url),'utf8').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');

test('five minute hospital returns physically, survives reload and stops owned movement on arrival',async()=>{
 const f=await fixture();f.ctx._hospitalDoor=()=>({r:30,c:10});const c=f.api.getRoster().candidates.find(c=>c.profession==='bruiser');f.api.recruit(c.id,'pistol');const m=f.ctx._myGang[0],id=m.id;
 m.hp=0;f.api.tick(.05);f.advance(20);f.api.tick(.05);assert.equal(f.api.getRoster().members[0].status,'hospital');
 f.advance(299);f.api.tick(.05);assert.equal(m.hp,0);assert.equal(f.api.getRoster().members[0].hospitalRemainingSeconds,1);
 f.advance(1);f.api.tick(.05);assert.equal(f.api.getRoster().members[0].status,'returning');assert(m.r>29.9,'Discharged at hospital, not player');assert.equal(m.id,id);assert.equal(m.weapon,'pistol');assert.equal(f.ctx._inventoryItems[0].qty,1);
 const loaded=await fixture({storage:f.storage});assert.equal(loaded.api.getRoster().members[0].status,'returning','Reload preserves return navigation ownership');assert.equal(loaded.ctx._myGang[0].id,id);
 for(let i=0;i<700;i++){f.advance(.05);f.api.tick(.05);}
 assert.equal(f.api.getRoster().members[0].status,'active');assert.equal(m._mercenaryReturnMove,false);assert.equal(f.api.ownsUpdate(m),true);const arrived=m.r;
 f.advance(.05);f.api.tick(.05);assert(Math.abs(m.r-arrived)*4.1<=.151,'Completed return uses one bounded source formation step');assert.equal(f.ctx._inventoryItems[0].qty,1);
});

test('falling during hospital return stops the body immediately and a blocked discharge retries',async()=>{
 const f=await fixture();f.ctx._hospitalDoor=()=>({r:30,c:10});f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='bruiser').id);
 const m=f.ctx._myGang[0];m.hp=0;f.api.tick(.05);f.advance(20);f.api.tick(.05);f.ctx._npcBodyPassable=()=>false;
 f.advance(300);f.api.tick(.05);assert.equal(m.hp,0);assert.equal(f.api.getRoster().members[0].status,'hospital');
 f.ctx._npcBodyPassable=()=>true;f.advance(1);f.api.tick(.05);assert(m.hp>0);const position=m.r;
 m.hp=0;f.advance(.05);f.api.tick(.05);assert.equal(m.r,position);assert.equal(m._mercenaryMove,null);f.advance(10);f.api.tick(.05);assert.equal(m.r,position,'Downed returner cannot walk during rescue grace');
});

test('medic cancels dispatched ambulance after in-place recovery through existing source helpers',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='medic').id);const patient={_medicalDowned:true,_ambulanceDispatched:true};
 f.ctx.myDead=true;f.ctx.myHp=0;f.ctx._playerEmergencyPatient=patient;const calls=[];f.ctx._setPlayerEmergencyTransport=value=>calls.push(['transport',value]);f.ctx._cancelAmbulanceCallForPatient=value=>calls.push(['cancel',value]);
 f.api.tick(.05);f.advance(1);f.api.tick(.05);f.advance(4);f.api.tick(.05);
 assert.equal(f.ctx.myDead,false);assert.equal(f.ctx.myHp,35);assert.equal(calls.length,2);assert.equal(calls[0][1],false);assert.equal(calls[1][1],patient);assert.equal(f.ctx._playerEmergencyPatient,null);assert.equal(f.ctx.player.r,10);
});

test('unavailable transported player does not monopolize medic while another crew member is downed',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='medic').id);f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='bruiser').id,'pistol');
 const [medic,ally]=f.ctx._myGang;ally.hp=0;f.ctx.myDead=true;f.ctx.myHp=0;f.ctx._playerEmergencyPatient={_ambulanceInTransit:true};
 assert.equal(f.api.getTarget('player').revivable,false);f.api.tick(.05);assert.equal(f.api.getAction(medic.id).targetId,ally.id);f.advance(1);f.api.tick(.05);f.advance(4);f.api.tick(.05);
 assert(ally.hp>0);assert.equal(f.ctx.myDead,true);assert.equal(f.ctx._inventoryItems[0].qty,1);assert.equal(ally.weapon,'pistol');assert.equal(f.ctx._myGang.length,2);
});
async function fixture({local=true,storage=new Map(),gang=[],blocked=false,gangMax=7,unnamed=false}={}){
 let clock=1000000;
 const ctx={module,URL,Promise,console,Date:{now:()=>clock*1000},performance:{now:()=>clock*1000},document:{documentElement:{dataset:{worldWalkReady:'first-populated-frame'}},currentScript:{src:'http://localhost/assets/maps/city_rebuild_v1/mercenary_world.js'}},location:{origin:'http://localhost'},window:{MAFIOZI_RENDERER_CONFIG:{worldScale:4.1}},localStorage:{getItem:k=>storage.get(k)||null,setItem:(k,v)=>storage.set(k,v)},_LOCAL_PREVIEW:local,_serverAuthoritativeAmmo:!local,_customGang:null,_myGang:gang,NPCS:Array.from({length:8},(_,i)=>({id:'civilian'+i,r:10,c:10+i*.1,hp:80,max_hp:80,name:unnamed?'':'NPC '+i,look:{hair:i}})),player:{r:10,c:10},myHp:100,myDead:false,GANG_MAX:gangMax,_hiredBotIds:new Set(),_inventoryItems:[{id:'pistol',type:'weapon',qty:2,name:'Пистолет'},{id:'rifle',type:'weapon',qty:1}],currentWeapon:'pistol',QP:{cash:500},_syncMyWeaponsFromInventory(){},_saveCurrentWeaponChoice(){},renderWeaponHud(){},_saveGang(){},_npcBodyPassable:()=>!blocked,_npcPathPassable:()=>!blocked,_hospitalDoor:()=>({r:10,c:11})};
 ctx._dismissGangMember=id=>{const i=ctx._myGang.findIndex(m=>m.id===id);if(i<0)return false;ctx._myGang.splice(i,1);return true;};
 vm.createContext(ctx);vm.runInContext(script,ctx);await new Promise(r=>setImmediate(r));return{ctx,api:ctx.window.MafioziMercenaries,storage,advance:n=>clock+=n};
}

test('safe money sync adds only ledger delta and loot requires a reachable same-floor bag',async()=>{
 const f=await fixture();assert.equal(f.api.syncSafeLootBalance(57),true);assert.equal(f.ctx.QP.cash,557);f.api.syncSafeLootBalance(57);assert.equal(f.ctx.QP.cash,557);assert.equal(f.api.syncSafeLootBalance(56),false);
 const target={id:'safe',valid:true,position:{x:41,y:0,z:41},lootPosition:{x:42,y:0,z:41}};
 f.api.bindTargets({get:()=>target,playerPosition:()=>({x:41,y:0,z:41}),canMove:()=>true});assert.equal(f.api.canCollectSafeLoot({id:'safe'}),true);
 target.lootPosition.y=5;assert.equal(f.api.canCollectSafeLoot({id:'safe'}),false);target.lootPosition.y=0;
 f.api.bindTargets({get:()=>target,canMove:()=>false});assert.equal(f.api.canCollectSafeLoot({id:'safe'}),false);
 const remote=await fixture({local:false});assert.equal(remote.api.syncSafeLootBalance(100),false);assert.equal(remote.ctx.QP.cash,500);
});

test('follow cancels unfinished specialist work without cancelling an armed charge',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='engineer').id);const m=f.ctx._myGang[0];
 const target={id:'fence',kind:'fence',position:f.api.getMember(m.id).position};f.api.bindTargets({get:()=>target});assert(f.api.command('cut_fence',target).ok);assert(f.api.getAction(m.id));f.api.follow();assert.equal(f.api.getAction(m.id),null);
});

test('adopts five existing residents, hires identity once, and dismissal restores ordinary city life',async()=>{
 const{api,ctx}=await fixture();assert.equal(api.ready,true);assert.equal(api.getRoster().candidates.length,5);assert.equal(ctx.NPCS.length,8);const c=api.getRoster().candidates[0];const source=ctx.NPCS.find(n=>n.id===c.id);assert.equal(api.recruit(c.id,'missing').ok,false);assert.equal(api.recruit(c.id,'pistol').ok,true);assert.equal(ctx.NPCS.length,7);const m=ctx._myGang[0];assert.equal(m.sourceBotId,source.id);assert.equal(m.look.hair,source.look.hair);assert.equal(ctx._inventoryItems[0].qty,1);assert.equal(api.recruit(c.id,'pistol').ok,false);assert.equal(api.equip(m.id,'rifle').ok,true);assert.equal(ctx._inventoryItems[0].qty,2);assert.equal(ctx._inventoryItems[1].qty,0);m.r=14;m.c=15;assert.equal(api.dismiss(m.id).ok,true);assert.equal(ctx._inventoryItems[1].qty,1);const released=ctx.NPCS.find(n=>n.id===source.id);assert.equal(released,source,'same source person returns');assert.deepEqual([released.r,released.c],[14,15]);assert.equal(released._civilianPlan.phase,'seek_shop');assert.equal(released.weapon,'pistol','personal sidearm stays with the former mercenary');assert.equal(released._formerMercenary,true);assert.equal(released._hostile,false);assert.equal(ctx._hiredBotIds.has(source.id),false);assert.equal(api.dismiss(m.id).ok,false);assert.equal(ctx._inventoryItems[1].qty,1);
});

test('dismissed mercenary holsters personal pistol while walking and retaliates against player attacks',async()=>{
 const f=await fixture(),candidate=f.api.getRoster().candidates[0],source=f.ctx.NPCS.find(n=>n.id===candidate.id);assert(f.api.recruit(candidate.id).ok);const member=f.ctx._myGang[0];assert(f.api.dismiss(member.id).ok);const n=f.ctx.NPCS.find(row=>row.id===source.id);
 const world=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');Object.assign(f.ctx,{NPC_LIFE_STATES:{ALERT:'alert'},_npcCancelHelping(){},_npcCancelSocial(){},_npcRememberEvent(){},_npcSetLifeState(){},_npcBeginPanic(){},_walkConfirmDamage(){},_markCombatBleeding(){},_npcPathPassable:()=>true,_npcRememberAggression(){},_npcSpreadRumor(){},_npcTrySurrenderAfterHit:()=>false,QP:{uid:'local'},_igniteLocalCharacter(){},_recordNpcEmpireStreetAttack(){},_queueNpcEmpireBossHit(){},_hitEmpireCombatant(){}});
 f.ctx._npcLifeEligible=()=>true;f.ctx._isRespawnableResident=()=>true;
 for(const name of ['npcCivilianUnarmed','npcVisibleWeapon','npcCarriedGun','_civilianPlanInterrupted','_civilianPlanEligible','_npcTriggerFight','hitNpc'])vm.runInContext(sourceFunction(world,name),f.ctx);
 assert.equal(f.ctx._civilianPlanEligible(n),true,'dismissed fighter is eligible for walking, visits and ambient driving');assert.equal(f.ctx.npcVisibleWeapon(n),'none','personal pistol remains holstered during ordinary city life');const before=n.hp;f.ctx.hitNpc(n,0,1,'pistol',5,{kind:'player'});assert.equal(n.hp,before-5);assert.equal(n._fighting,true);assert.equal(n._fightWeapon,'pistol');assert.equal(f.ctx.npcVisibleWeapon(n),'pistol');assert.equal(n.panicUntil,0);assert.equal(f.ctx._civilianPlanInterrupted(n,f.ctx.performance.now()),true,'combat temporarily owns the former fighter');
});

test('authoritative mode cannot mutate inventory or crew',async()=>{const{api,ctx}=await fixture({local:false});assert.equal(api.recruit('civilian0','pistol').ok,false);assert.equal(api.equip('x','pistol').ok,false);assert.equal(api.dismiss('x').ok,false);assert.equal(ctx._myGang.length,0);assert.equal(ctx._inventoryItems[0].qty,2);});

test('hospital preserves membership and epoch countdown through reload and discharges after five minutes',async()=>{
 const f=await fixture();const id=f.api.getRoster().candidates[1].id;f.api.recruit(id);const m=f.ctx._myGang[0];m.hp=0;f.api.tick(.05);assert.equal(f.api.ownsUpdate(m),true);f.advance(21);f.api.tick(.05);assert.equal(f.api.getRoster().members[0].status,'hospital');assert.equal(f.api.getRoster().members[0].hospitalRemainingSeconds,300);const savedGang=[{...m,id:'_gang_1'}];const reloaded=await fixture({storage:f.storage,gang:savedGang});assert.equal(reloaded.ctx._myGang.length,1);assert.equal(reloaded.ctx._myGang[0].id,m.id);assert.equal(reloaded.api.getRoster().members[0].status,'hospital');reloaded.advance(322);reloaded.api.tick(.05);assert.equal(reloaded.api.getRoster().members[0].status,'returning');assert.ok(reloaded.ctx._myGang[0].hp>0);
});

test('blocked vehicle pursuit never crosses walls and waits for explicit cancellation',async()=>{
 const f=await fixture({blocked:true});const candidate=f.api.getRoster().candidates.find(c=>c.profession==='demolitions');f.api.recruit(candidate.id);const m=f.ctx._myGang[0],start={r:m.r,c:m.c};let applied=0;const target={id:'traffic:car',kind:'vehicle',position:{x:60,y:0,z:41}};f.api.bindTargets({get:()=>target,performEffect:()=>{applied++;return true;}});assert.equal(f.api.command('plant_bomb',target).ok,true);f.api.tick(.05);assert.equal(m.r,start.r);assert.equal(m.c,start.c);f.advance(120);f.api.tick(.05);assert.equal(f.api.getAction(m.id).phase,'approach');assert.equal(applied,0);assert(f.api.follow().ok);assert.equal(f.api.getAction(m.id),null);
});

test('inventory reload reserves issued guns once, hospital entities filtered and candidates keep source identity',async()=>{
 const{api,ctx}=await fixture();const candidate=api.getRoster().candidates[0];api.recruit(candidate.id,'pistol');api.reconcileInventory(ctx._inventoryItems);assert.equal(ctx._inventoryItems[0].qty,1);const refreshed=[{id:'pistol',type:'weapon',qty:2}];api.reconcileInventory(refreshed);api.reconcileInventory(refreshed);assert.equal(refreshed[0].qty,1);const out=api.decorateEntities({npcs:[{id:'civilian1'},{id:'crew_'+ctx._myGang[0].id}]});assert.ok(out.npcs[0].mercenary);assert.equal(out.npcs[1].id,'civilian1');
});

test('fresh duplicate inventory rows reserve each issued gun only once',async()=>{
 const {api}=await fixture();assert(api.recruit(api.getRoster().candidates[0].id,'pistol').ok);
 const rows=[{id:'pistol',type:'weapon',qty:1,count:1},{id:'pistol',type:'weapon',qty:1,count:1},{id:'rifle',type:'weapon',qty:1}];
 api.reconcileInventory(rows);assert.deepEqual(rows.map(r=>r.qty),[0,1,1]);assert.deepEqual(rows.slice(0,2).map(r=>r.count),[0,1]);
 api.reconcileInventory(rows);assert.deepEqual(rows.map(r=>r.qty),[0,1,1],'same reconciled objects are idempotent');
 const fresh=[{item_id:'pistol',type:'weapon',quantity:0},{item_id:'pistol',type:'weapon',quantity:2}];
 api.reconcileInventory(fresh);assert.deepEqual(fresh.map(r=>r.quantity),[0,1],'zero row consumes no reserve and source item_id works');
});

test('duplicate inventory rows retain total after hospital and dismissal',async()=>{
 const {api,ctx,advance}=await fixture();
 const candidates=api.getRoster().candidates;assert(api.recruit(candidates[0].id,'pistol').ok);assert(api.recruit(candidates[1].id,'pistol').ok);
 const rows=[{id:'pistol',type:'weapon',qty:1},{id:'pistol',type:'weapon',qty:2}];ctx._inventoryItems=rows;
 ctx._myGang[0].hp=0;api.tick(.05);advance(20);api.tick(.05);
 api.reconcileInventory(rows);assert.deepEqual(rows.map(r=>r.qty),[0,1],'hospital member still reserves its issued gun');
 assert(api.dismiss(ctx._myGang[0].id).ok);api.reconcileInventory(rows);assert.equal(rows.reduce((n,r)=>n+r.qty,0),2,'dismissal returns one gun exactly once');
});

test('attached bomb remains valid after operator dismissal, explosion delegates once',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates.find(c=>c.profession==='demolitions');f.api.recruit(candidate.id);const m=f.ctx._myGang[0];const target={id:'traffic:car',kind:'vehicle',position:{...f.api.getMember(m.id).position}};let applied=0;f.api.bindTargets({get:()=>target,performEffect:()=>{applied++;return true;}});f.api.command('plant_bomb',target);f.api.tick(.05);f.advance(5);f.api.tick(.05);assert.equal(f.api.getAction(m.id).armed,true);f.api.dismiss(m.id);f.advance(7);f.api.tick(.05);f.api.tick(.05);assert.equal(applied,1);
});

test('source blast uses live traffic and service coordinates and rejects repeated or fabricated action',async()=>{
 for(const service of [false,true]){const f=await fixture();const candidate=f.api.getRoster().candidates.find(c=>c.profession==='demolitions');f.api.recruit(candidate.id);const m=f.ctx._myGang[0];const car=service?{id:'ambulance',x:m.c,y:m.r}:{id:'car',c:m.c,r:m.r};f.ctx.CARS=service?[]:[car];f.ctx.serviceVehicles=service?[car]:[];f.ctx._threeVehicleEntityId=v=>'vehicle_'+v.id;const sourceId=service?'service_ambulance':'vehicle_car';let hit;f.ctx._startCarGunDestruction=(p,v)=>{hit=p;v._destroySequenceAt=1;};const target={id:'traffic:'+sourceId,kind:'vehicle',position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,performEffect:e=>f.api.blastVehicle(sourceId,e)});assert.equal(f.api.blastVehicle(sourceId,{kind:'plant_bomb',actionId:1,memberId:m.id,targetId:target.id}),false);f.api.command('plant_bomb',target);f.api.tick(.05);f.advance(5);f.api.tick(.05);if(service){car.x=23;car.y=24;}else{car.c=23;car.r=24;}target.position={x:23*4.1,y:0,z:24*4.1};target.center={...target.position};f.advance(7);f.api.tick(.05);assert.equal(hit.r,24);assert.equal(hit.c,23);assert.equal(car._ballisticHp,0);assert.equal(car.speed,0);}
});

test('automatic medic revives player in place without clearing gang, and intimidation changes real resident',async()=>{
 const f=await fixture();let candidate=f.api.getRoster().candidates.find(c=>c.profession==='medic');f.api.recruit(candidate.id);f.ctx.myDead=true;f.ctx.myHp=0;f.ctx._localDeath=true;f.ctx.myDeathBy='test';f.ctx.myDeathLeft=9;f.ctx._playerEmergencyPatient={_medicalDowned:true};f.api.tick(.05);f.advance(1);f.api.tick(.05);f.advance(5);f.api.tick(.05);assert.equal(f.ctx.myDead,false);assert.equal(f.ctx._localDeath,false);assert.equal(f.ctx.myHp,35);assert.equal(f.ctx.player.r,10);assert.equal(f.ctx._myGang.length,1);assert.equal(f.ctx._playerEmergencyPatient,null);
 candidate=f.api.getRoster().candidates.find(c=>c.profession==='bruiser');f.api.recruit(candidate.id);const victim=f.ctx.NPCS[0];const target=f.api.getTarget(victim.id);const action=f.api.getActions(target).find(a=>a.id==='intimidate');assert.equal(action.enabled,true);assert.equal(action.label,'Запугать');f.api.command('intimidate',target);f.api.tick(.05);f.advance(4);f.api.tick(.05);assert.ok(victim.panicUntil>0);assert.equal(victim.cryText,'Не трогай меня!');
});

test('render target aliases resolve live source HP and crew kind before visual target fallback',async()=>{
 const f=await fixture();const c=f.api.getRoster().candidates[0];f.api.recruit(c.id);const m=f.ctx._myGang[0];m.hp=0;f.api.bindTargets({get:id=>({id,kind:'npc'})});for(const id of [m.id,'crew_'+m.id,'npc_crew_'+m.id,'npc:npc_crew_'+m.id]){const target=f.api.getTarget(id);assert.equal(target.kind,'npc');assert.equal(target.hp,0);assert.equal(target.downed,true);assert.equal(target.id,m.id);assert.ok(f.api.stats(id));}const n=f.ctx.NPCS[0];for(const id of [n.id,'npc_'+n.id,'npc:npc_'+n.id])assert.equal(f.api.getTarget(id).hp,80);
});

test('external disband removes metadata and returns issued inventory only once',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates[0];f.api.recruit(candidate.id,'pistol');assert.equal(f.ctx._inventoryItems[0].qty,1);f.ctx._myGang.length=0;f.api.tick(.05);assert.equal(f.api.getRoster().members.length,0);assert.equal(f.ctx._inventoryItems[0].qty,2);f.api.tick(.05);assert.equal(f.ctx._inventoryItems[0].qty,2);const saved=JSON.parse(f.storage.get('mafiozi.mercenaries.v1'));assert.equal(saved.core.members.length,0);
});

test('full source gang on restore cannot leave phantom mercenary or duplicate returned gun',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates[0];f.api.recruit(candidate.id,'pistol');const existing=Array.from({length:7},(_,i)=>({id:'unrelated'+i,sourceBotId:'other'+i,hp:80}));const loaded=await fixture({storage:f.storage,gang:existing});assert.equal(loaded.ctx._myGang.length,7);assert.equal(loaded.api.getRoster().members.length,0);assert.equal(loaded.ctx._inventoryItems[0].qty,2);loaded.api.tick(.05);assert.equal(loaded.ctx._inventoryItems[0].qty,2);
});

test('armed countdown decreases and charge remains visible after dismissal',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates.find(c=>c.profession==='demolitions');f.api.recruit(candidate.id);const m=f.ctx._myGang[0],target={id:'traffic:car',kind:'vehicle',position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,performEffect:()=>true});f.api.command('plant_bomb',target);f.api.tick(.05);f.advance(5);f.api.tick(.05);let row=f.api.getRoster().members[0];assert.equal(row.countdownRemainingSeconds,6);assert.match(row.phaseLabel,/взрыв через 6 с/i);f.advance(2);row=f.api.getRoster().members[0];assert.equal(row.countdownRemainingSeconds,4);assert.equal(f.api.getCharges().length,1);f.api.dismiss(m.id);assert.equal(f.api.getRoster().members.length,0);assert.equal(f.api.getCharges().length,1);assert.equal(f.api.getCharges()[0].targetId,target.id);f.advance(5);f.api.tick(.05);assert.equal(f.api.getCharges().length,0);
});

test('civilian mafia capacity zero allows five specialists and restores them without changing rank capacity',async()=>{
 const f=await fixture({gangMax:0});for(const candidate of f.api.getRoster().candidates)assert.equal(f.api.recruit(candidate.id).ok,true);assert.equal(f.ctx._myGang.length,5);assert.equal(f.ctx.GANG_MAX,0);assert.equal(f.api.getRoster().capacity,5);const loaded=await fixture({gangMax:0,storage:f.storage});assert.equal(loaded.api.getRoster().members.length,5);assert.equal(loaded.ctx._myGang.length,5);assert.equal(loaded.ctx.GANG_MAX,0);
});

test('source downed crew normalizes to nonfatal fall and clears after recovery',async()=>{
 const {registerHooks}=await import('node:module');const {pathToFileURL}=await import('node:url');const vendor=process.env.THREE_VENDOR_ROOT||'D:/codex_release/artist13_hero_first_DEV_20260907/demo/vendor';const hook=registerHooks({resolve(s,c,next){return next(s==='three'?pathToFileURL(vendor+'/build/three.module.js').href:s,c);}});
 try{const{normalizeNpcSnapshot}=await import('./npc_population.mjs');const f=await fixture();f.api.recruit(f.api.getRoster().candidates[0].id);const m=f.ctx._myGang[0];m.hp=0;f.api.tick(.05);const snapshot={id:'crew_'+m.id,r:m.r,c:m.c,hp:0,dead:true,deathConfirmed:false};const decorated=f.api.decorateEntities([snapshot])[0];assert.equal(decorated.downed,true);assert.equal(decorated.lifeState,'downed');assert.equal(decorated.deathConfirmed,false);assert.ok(decorated.downedAt>0);let normalized=normalizeNpcSnapshot(decorated,{time:1000000,sourceNowMs:1000000000});assert.equal(normalized.stun.active,true);assert.equal(normalized.lifecycle.dead,false);f.advance(1);f.api.tick(.05);assert.equal(m._mercenaryDownAt,decorated.downedAt);m.hp=40;f.api.tick(.05);assert.equal(m._mercenaryDownAt,0);normalized=normalizeNpcSnapshot(f.api.decorateEntities([{...snapshot,hp:40,dead:false}])[0],{time:1000001,sourceNowMs:1000001000});assert.equal(normalized.stun.active,false);assert.equal(normalized.lifecycle.dead,false);
 }finally{hook.deregister();}
});

test('protected residents are neither adopted nor hired after a role change',async()=>{
 const f=await fixture();f.ctx.NPCS[0]._cashier=true;f.ctx.NPCS[1]._guard=true;f.ctx.NPCS[2]._specialistId='story_npc';f.ctx.NPCS[3]._insideBuilding=true;f.ctx._isRespawnableResident=n=>n.id!=='civilian4';f.advance(3);const candidates=f.api.getRoster().candidates;assert.ok(candidates.every(c=>!['civilian0','civilian1','civilian2','civilian3','civilian4'].includes(c.id)));assert.ok(candidates.length>0);const selected=candidates[0],source=f.ctx.NPCS.find(n=>n.id===selected.id);source._cashier=true;assert.equal(f.api.recruit(selected.id,'pistol').ok,false);assert.ok(f.ctx.NPCS.includes(source));assert.equal(f.ctx._myGang.length,0);assert.equal(f.ctx._inventoryItems[0].qty,2);
});

test('restored pending transaction is not resent and explicit rejection releases member',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='safecracker').id);const m=f.ctx._myGang[0],target={id:'object:safe',kind:'safe',locked:true,position:{...f.api.getMember(m.id).position}};f.api.bindTargets({get:()=>target,performEffect:()=>new Promise(()=>{})});f.api.command('unlock_safe',target);f.api.tick(.05);f.advance(10);f.api.tick(.05);const transaction=f.api.getPendingTransactions()[0];assert.ok(transaction);const loaded=await fixture({storage:f.storage});let resent=0;loaded.api.bindTargets({get:()=>target,performEffect:()=>{resent++;return true;}});loaded.advance(12);loaded.api.tick(.05);assert.equal(resent,0);assert.equal(loaded.api.getPendingTransactions().length,1);loaded.api.resolvePending(transaction.requestId,{ok:false,reason:'rejected'});assert.equal(loaded.api.getPendingTransactions().length,0);assert.equal(loaded.api.getAction(m.id),null);assert.equal(loaded.api.getRoster().members[0].xp,0);assert.equal(JSON.parse(loaded.storage.get('mafiozi.mercenaries.v1')).core.pendingTransactions.length,0);
});

test('real damage awards specialist XP and a skill point, zero and invalid damage award nothing',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates[0].id);const m=f.ctx._myGang[0];for(const value of [0,-1,NaN,Infinity])assert.equal(f.api.awardCombatXp(m.id,value,true,99),false);assert.equal(f.api.getRoster().members[0].xp,0);assert.equal(f.api.awardCombatXp(m.id,140,true,25),true);const row=f.api.getRoster().members[0];assert.equal(row.xp,100);assert.equal(row.level,2);assert.equal(row.skillPoints,1);assert.equal(m.fighterXp,100);assert.equal(m.level,2);assert.equal(f.api.upgrade(m.id,'medicine').ok,true);assert.equal(f.api.getRoster().members[0].skillPoints,0);assert.equal(f.api.awardCombatXp('not_member',140,true,25),false);
});

test('completed specialist action level is synchronized to ordinary source fighter',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates.find(c=>c.profession==='bruiser');f.api.recruit(candidate.id);const m=f.ctx._myGang[0];f.api.awardCombatXp(m.id,525,false,1);assert.equal(m.fighterXp,75);const victim=f.ctx.NPCS[0],target=f.api.getTarget(victim.id);f.api.command('intimidate',target);f.api.tick(.05);f.advance(4);f.api.tick(.05);assert.equal(f.api.getRoster().members[0].xp,100);assert.equal(m.level,2);assert.equal(m.fighterXp,100);
});

test('explicit loopback QA invites existing specialist near player without granting membership or weapon',async()=>{
 const f=await fixture();assert.equal(f.api.qaInvite('medic').ok,false);f.ctx.location.hostname='127.0.0.1';f.ctx.location.href='http://127.0.0.1/world.html?mercenaryqa=1';const timers=[];f.ctx.setTimeout=fn=>timers.push(fn);const candidate=f.api.getRoster().candidates.find(c=>c.profession==='medic'),npc=f.ctx.NPCS.find(n=>n.id===candidate.id);npc.r=40;npc.c=40;npc.speed=2;const count=f.ctx.NPCS.length;let nativeChecked=false;f.api.bindTargets({canMove:()=>{nativeChecked=true;return true;}});assert.equal(f.api.qaInvite('medic').ok,true);assert.ok(nativeChecked);assert.ok(Math.abs(Math.hypot(npc.r-f.ctx.player.r,npc.c-f.ctx.player.c)*4.1-2.4)<1e-6);assert.equal(f.ctx.NPCS.length,count);assert.equal(f.ctx._myGang.length,0);assert.equal(f.ctx._inventoryItems[0].qty,2);assert.equal(npc.speed,0);timers[0]();assert.equal(npc.speed,2);f.ctx.location.hostname='example.com';assert.equal(f.api.qaInvite('medic').ok,false);
});

test('personal starter pistol never reserves or refunds player inventory across swap and reload',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates[0].id);const m=f.ctx._myGang[0];assert.equal(m.weapon,'pistol');assert.equal(f.api.getRoster().members[0].weaponId,'pistol');assert.equal(f.api.getRoster().members[0].weaponOrigin,'personal');assert.equal(f.ctx._inventoryItems[0].qty,2);
 const loaded=await fixture({storage:f.storage});assert.equal(loaded.ctx._myGang[0].weapon,'pistol');assert.equal(loaded.ctx._inventoryItems[0].qty,2);loaded.api.dismiss(m.id);assert.equal(loaded.ctx._inventoryItems[0].qty,2,'Personal gun is never refunded');
 assert(f.api.equip(m.id,'rifle').ok);assert.equal(f.ctx._inventoryItems[0].qty,2,'Replacing personal gun does not mint pistol');assert.equal(f.ctx._inventoryItems[1].qty,0);
 const equipped=await fixture({storage:f.storage});assert.equal(equipped.ctx._myGang[0].weapon,'rifle');assert.equal(equipped.ctx._inventoryItems[1].qty,0);equipped.api.dismiss(m.id);assert.equal(equipped.ctx._inventoryItems[1].qty,1);assert.equal(equipped.ctx._inventoryItems[0].qty,2);
});

test('demo lineup shows all five ahead, validates placement, remains stable and never bypasses hire range',async()=>{
 const f=await fixture();assert.equal(f.api.qaLineup().ok,false);f.ctx.location.hostname='127.0.0.1';f.ctx.location.href='http://127.0.0.1/world.html?mercenarydemo=1';assert(f.api.demoSupported());assert(f.api.qaSupported());
 let nativeChecks=0;f.api.bindTargets({canMove:()=>{nativeChecks++;return true;}});const ids=f.ctx.NPCS.map(n=>n.id);const reply=f.api.qaLineup();assert.equal(reply.count,5);assert.equal(reply.placed,5);assert(nativeChecks>=5);
 const candidates=f.api.getRoster().candidates;const points=candidates.map(c=>f.ctx.NPCS.find(n=>n.id===c.id));assert.deepEqual(f.ctx.NPCS.map(n=>n.id),ids);
 for(const n of points){assert(n.c>f.ctx.player.c,'Ahead of zero heading');assert(Math.hypot(n.r-10,n.c-10)*4.1<=10);assert.equal(n._playerConversationOpen,true);assert.equal(f.api.recruit(n.id).ok,false,'Normal 3m hiring remains enforced');for(const other of points)if(other!==n)assert(Math.hypot(n.r-other.r,n.c-other.c)*4.1>=2);}
 const positions=points.map(n=>[n.r,n.c]);assert.equal(f.api.qaLineup().placed,0);assert.deepEqual(points.map(n=>[n.r,n.c]),positions);
 const decorated=f.api.decorateEntities(points.map(n=>({id:n.id,weapon:''})));assert(decorated.every(n=>n.weapon==='none'));assert(candidates.every(c=>c.weaponId==='pistol'));
 f.ctx.player.r=points[0].r;f.ctx.player.c=points[0].c;assert(f.api.recruit(points[0].id).ok);const hired=f.ctx._myGang[0];hired.r+=4;const hiredPosition=hired.r;f.api.qaLineup();assert.equal(hired.r,hiredPosition);assert.equal(hired.weapon,'pistol');assert.equal(f.ctx._inventoryItems[0].qty,2);
 f.ctx.location.hostname='example.com';assert.equal(f.api.qaLineup().ok,false);const remote=await fixture({local:false});remote.ctx.location.hostname='localhost';remote.ctx.location.href='http://localhost/world.html?mercenarydemo=1';assert.equal(remote.api.qaLineup().ok,false);
});

test('demo refuses blocked placements and normal residents retain appearance and ordinary movement',async()=>{
 const f=await fixture({blocked:true});f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenarydemo=1';const before=f.ctx.NPCS.map(n=>[n.r,n.c]);assert.equal(f.api.qaLineup().count,0);assert.deepEqual(f.ctx.NPCS.map(n=>[n.r,n.c]),before);
 const normal=await fixture({unnamed:true});const candidate=normal.api.getRoster().candidates[0],n=normal.ctx.NPCS.find(n=>n.id===candidate.id),look=n.look;n._hostile=true;normal.advance(3);normal.api.tick(.05);n._hostile=false;n.speed=1.5;normal.advance(3);normal.api.tick(.05);const personal=n.name;assert.match(personal,/\S+ \S+/);assert.equal(n.look,look);assert.equal(n.speed,1.5);assert.equal(n._mercenaryProfession,candidate.profession);assert.equal(n._mercenaryDemoLineup,undefined);
 normal.advance(3);normal.api.tick(.05);assert.equal(n.name,personal);
});

test('same resident retains profession name and appearance through normal indoor visit without indoor hiring',async()=>{
 const f=await fixture({unnamed:true});const candidate=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===candidate.id),look=n.look,name=n.name;
 f.ctx.RESIDENTS_INDOORS=[n];n._residentIndoors=true;f.ctx.NPCS.splice(f.ctx.NPCS.indexOf(n),1);f.advance(3);f.api.tick(.05);
 assert.equal(f.api.getRoster().candidates.some(c=>c.id===n.id),false);assert.equal(f.api.recruit(n.id).ok,false);assert.equal(f.api.getRoster().candidates.some(c=>c.profession===candidate.profession),false,'Indoor specialist slot is retained');
 f.ctx.RESIDENTS_INDOORS=[];n._residentIndoors=false;f.ctx.NPCS.push(n);f.advance(3);f.api.tick(.05);
 const returned=f.api.getRoster().candidates.find(c=>c.id===n.id);assert(returned);assert.equal(returned.profession,candidate.profession);assert.equal(returned.name,name);assert.equal(n.look,look);assert.equal(f.ctx._myGang.length,0);
});

test('demo waits for native population and completes partial lineup without moving earlier placements',async()=>{
 const f=await fixture();f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenarydemo=1';assert.equal(f.api.qaLineup().ok,false);
 let allowed=1;f.api.bindTargets({canMove:()=>allowed-->0});f.ctx.document.documentElement.dataset.worldWalkReady='loading';assert.equal(f.api.qaLineup().ok,false);
 f.ctx.document.documentElement.dataset.worldWalkReady='first-populated-frame';const partial=f.api.qaLineup();assert.equal(partial.count,1);assert.equal(partial.ok,false);
 const first=f.ctx.NPCS.find(n=>n._mercenaryDemoLineup),position=[first.r,first.c];f.api.bindTargets({canMove:()=>true});assert.equal(f.api.qaLineup().ok,true);assert.deepEqual([first.r,first.c],position);
});

test('unnamed female candidate receives stable female name without changing appearance',async()=>{
 const f=await fixture();const previous=f.api.getRoster().candidates[0];f.ctx.NPCS.find(n=>n.id===previous.id)._guard=true;
 const woman=f.ctx.NPCS[5];woman.name='';woman.look.gender=1;const look=woman.look;f.advance(3);f.api.tick(.05);
 assert.match(woman.name,/^(Лючия|Мария|Анна|Джулия|София|Кьяра|Франческа|Паола|Елена|Роза|Валентина|Изабелла|Карла|Джованна|Анджела|Сильвия) /);assert.equal(woman.look,look);const name=woman.name;f.advance(3);f.api.tick(.05);assert.equal(woman.name,name);
});

test('demo searches a free rear patch and road policy fallback still enforces native collision',async()=>{
 const f=await fixture();f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenarydemo=1';f.api.bindTargets({canMove:(_,p)=>p.x<31});
 const rear=f.api.qaLineup();assert(rear.ok);assert(rear.diagnostics.nativeRejected>0);assert(rear.diagnostics.positions.every(p=>p.x<31&&Math.hypot(p.x-41,p.z-41)<=20));
 const road=await fixture();road.ctx.location.hostname='localhost';road.ctx.location.href='http://localhost/world.html?mercenarydemo=1';road.ctx.npcPassableForSnitch=()=>true;road.ctx._npcBodyPassable=(r,c,predicate)=>predicate===road.ctx.npcPassableForSnitch;
 road.api.bindTargets({canMove:()=>false});assert.equal(road.api.qaLineup().count,0,'Road policy never bypasses native collision');
 const rejected=JSON.parse(road.ctx.document.documentElement.dataset.mercenaryDemoPlacement);assert(rejected.tested>0);assert(rejected.nativeRejected>0);assert.equal(rejected.origin.x,41);
 road.api.bindTargets({canMove:()=>true});const placed=road.api.qaLineup();assert(placed.ok);assert.equal(placed.diagnostics.roadPlacements,5);
});

test('demo and normal E conversations use source conversation guard, preserve speed and release on danger',async()=>{
 const f=await fixture();const source=fs.readFileSync(new URL('../../../world.html',import.meta.url),'utf8');
 const helperStart=source.indexOf('function _beginNpcPlayerConversation('),helperEnd=source.indexOf('function _npcActionSay(',helperStart);
 f.ctx._npcConversationPosition=n=>({r:n.r,c:n.c});f.ctx._clearNpcRoute=n=>{n._route=null;};vm.runInContext(source.slice(helperStart,helperEnd),f.ctx);
 const guardStart=source.indexOf('const playerConversationActive='),guardEnd=source.indexOf('if(n._npcHelpingTarget',guardStart);
 vm.runInContext('function runConversationGuard(n){const now=performance.now();for(const n0 of [n]){'+source.slice(guardStart,guardEnd)+'n.c+=1;return false;}return true;}',f.ctx);
 const candidate=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===candidate.id);n.speed=2;assert(f.api.beginConversation(n.id).ok);const original=n.c;assert(f.ctx.runConversationGuard(n));assert.equal(n.c,original);f.api.endConversation(n.id);assert.equal(n._playerConversationOpen,false);assert.equal(n.speed,2);
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenarydemo=1';f.api.bindTargets({canMove:()=>true});assert(f.api.qaLineup().ok);const staged=n.c;assert(f.ctx.runConversationGuard(n));assert.equal(n.c,staged);assert.equal(n.speed,2,'Danger retains original escape speed');n.panicUntil=f.ctx.performance.now()+1000;assert.equal(f.ctx.runConversationGuard(n),false);assert.equal(n._playerConversationOpen,false);
});

test('pending placement and civilian trip preserve specialist slot without positioning an unfinished spawn',async()=>{
 const f=await fixture();const candidate=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===candidate.id);n._civilianTrip={};f.advance(3);f.api.tick(.05);assert(!f.api.getRoster().candidates.some(c=>c.profession===candidate.profession));delete n._civilianTrip;f.advance(3);f.api.tick(.05);assert.equal(f.api.getRoster().candidates.find(c=>c.id===n.id).profession,candidate.profession);
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/world.html?mercenarydemo=1';f.api.bindTargets({canMove:()=>true});n._npcInitialPlacementPending=true;const position=[n.r,n.c];const partial=f.api.qaLineup();assert.equal(partial.ok,false);assert.equal(partial.diagnostics.initialPlacementPending,1);assert.deepEqual([n.r,n.c],position);delete n._npcInitialPlacementPending;assert(f.api.qaLineup().ok);
});

test('ordinary candidate holsters an owned starter pistol before hire without becoming hostile or spending inventory',async()=>{
 const f=await fixture();assert.equal(f.api.demoSupported(),false);
 for(const c of f.api.getRoster().candidates){const n=f.ctx.NPCS.find(n=>n.id===c.id);assert.equal(n.weapon,'pistol');assert.equal(c.weaponId,'pistol');assert.equal(c.weaponLabel,'Пистолет');assert(!n._hostile);assert(!n._fighting);assert.equal(f.api.decorateEntities([{id:n.id,weapon:''}])[0].weapon,'none');}
 const c=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===c.id),look=n.look,name=n.name;assert(f.api.recruit(c.id).ok);const m=f.ctx._myGang[0];assert.equal(m.weapon,'pistol');assert.equal(m.look.hair,look.hair);assert.equal(m.name,name);assert.equal(f.ctx._inventoryItems[0].qty,2);
 assert(f.api.equip(m.id,'rifle').ok);f.advance(3);f.api.tick(.05);assert.equal(m.weapon,'rifle','Candidate adoption never replaces issued member gun');
});

test('three actual hired members restore names looks issued guns and IDs over legacy gang IDs',async()=>{
 const f=await fixture();for(const [i,c] of f.api.getRoster().candidates.slice(0,3).entries())assert(f.api.recruit(c.id,i===1?'rifle':undefined).ok);
 const original=f.ctx._myGang.map(m=>JSON.parse(JSON.stringify(m))),legacy=original.map((m,i)=>({...m,id:'_gang_'+(i+1)}));
 const loaded=await fixture({storage:f.storage,gang:legacy});assert.equal(loaded.ctx._myGang.length,3);
 for(const saved of original){const actual=loaded.ctx._myGang.find(m=>m.id===saved.id);assert(actual);assert.equal(actual.name,saved.name);assert.deepEqual(JSON.parse(JSON.stringify(actual.look)),saved.look);assert.equal(actual.weapon,saved.weapon);assert.equal(actual.sourceBotId,saved.sourceBotId);}
 loaded.advance(3);loaded.api.tick(.05);const diagnostics=JSON.parse(loaded.ctx.document.documentElement.dataset.mercenaryPersistence);assert.equal(diagnostics.restore.ids.length,3);assert.equal(diagnostics.save.ids.length,3);
 const renamed=loaded.ctx._myGang[0],id=renamed.id;renamed.id='_gang_after_async_load';loaded.api.tick(.05);assert.equal(renamed.id,id);assert.equal(loaded.api.getRoster().members.length,3);assert.equal(loaded.ctx._inventoryItems[1].qty,0,'Renaming never refunds issued rifle');
});

test('failed or unsupported restore preserves original bytes instead of overwriting with empty roster',async()=>{
 for(const bytes of ['{broken',JSON.stringify({core:{version:999,members:[]},rows:[]}),JSON.stringify({core:{version:1,members:[{id:'missing',profession:'medic'}]},rows:[]})]){
  const storage=new Map([['mafiozi.mercenaries.v1',bytes]]),warn=console.warn;console.warn=()=>{};let f;try{f=await fixture({storage});}finally{console.warn=warn;}
  f.advance(5);f.api.tick(.05);assert.equal(storage.get('mafiozi.mercenaries.v1'),bytes);const diagnostic=JSON.parse(f.ctx.document.documentElement.dataset.mercenaryPersistence);assert.equal(diagnostic.restore.ok,false);assert.equal(diagnostic.restore.preserved,true);
 }
});

test('late local host eligibility restores saved crew before first tick may persist an empty roster',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates[0].id,'rifle');const saved=f.ctx._myGang[0];
 const delayed=await fixture({local:false,storage:f.storage});assert.equal(delayed.api.getRoster().members.length,0);delayed.ctx._LOCAL_PREVIEW=true;delayed.ctx._serverAuthoritativeAmmo=false;
 delayed.api.tick(.05);assert.equal(delayed.api.getRoster().members.length,1);assert.equal(delayed.ctx._myGang[0].id,saved.id);assert.equal(delayed.ctx._myGang[0].weapon,'rifle');assert.equal(delayed.ctx._inventoryItems[1].qty,0);assert.equal(JSON.parse(delayed.storage.get('mafiozi.mercenaries.v1')).rows[0].id,saved.id);
});

test('rally uses separate live collision-checked slots, persists and follow releases rally',async()=>{
 const f=await fixture();for(const c of f.api.getRoster().candidates)assert(f.api.recruit(c.id).ok);let checks=0;
 f.api.bindTargets({groundHeight:()=>3,canMove:()=>{checks++;return true;}});const original=f.ctx._myGang.map(m=>[m.r,m.c]);
 const receipt=f.api.rally({x:48,y:999,z:46});assert.equal(receipt.count,5);assert.equal(receipt.positions.length,5);assert(checks>=5);assert.deepEqual(f.ctx._myGang.map(m=>[m.r,m.c]),original,'Order never teleports');
 for(const p of receipt.positions){assert.equal(p.y,3);for(const q of receipt.positions)if(p!==q)assert(Math.hypot(p.x-q.x,p.z-q.z)>=2.1);}
 for(let i=0;i<350;i++){f.advance(.05);f.api.tick(.05);}
 for(const m of f.ctx._myGang){assert(Math.hypot(m.c*4.1-m._mercenaryRally.x,m.r*4.1-m._mercenaryRally.z)<.4,JSON.stringify({id:m.id,r:m.r,c:m.c,goal:m._mercenaryRally,positions:f.ctx._myGang.map(m=>({r:m.r,c:m.c}))}));assert(f.api.ownsUpdate(m));}
 const loaded=await fixture({storage:f.storage});assert(loaded.api.getRoster().members.every(r=>r.order==='rally'));assert.equal(loaded.ctx._myGang.length,5);
 assert(f.api.follow().ok);f.api.tick(.05);assert(f.api.getRoster().members.every(r=>r.order==='follow'));assert.equal(f.api.rally({x:9999,z:9999}).ok,false);
});

test('follow formation turns gradually once per frame and follows the shortest angle',async()=>{
 const f=await fixture();f.ctx.player.ang=0;for(const c of f.api.getRoster().candidates)assert(f.api.recruit(c.id).ok);
 f.api.bindTargets({canMove:()=>true});f.api.tick(.05);
 const before=f.ctx._myGang.map(m=>({...m._mercenaryFollowGoal.position}));f.ctx.player.ang=Math.PI;
 f.advance(.25);f.api.tick(.05);
 const after=f.ctx._myGang.map(m=>({...m._mercenaryFollowGoal.position}));
 for(let i=0;i<after.length;i++)assert(Math.hypot(after[i].x-before[i].x,after[i].z-before[i].z)<.5,'a sharp hero turn must not move a formation slot across the hero');
 const rotations=after.map((p,i)=>{const x=p.x-f.ctx.player.c*4.1,z=p.z-f.ctx.player.r*4.1,bx=before[i].x-f.ctx.player.c*4.1,bz=before[i].z-f.ctx.player.r*4.1;return Math.atan2(z,x)-Math.atan2(bz,bx);});
 for(const turn of rotations)assert(Math.abs(Math.atan2(Math.sin(turn),Math.cos(turn)))<=1.45*.05+.00001,'five fighters must not advance the heading five times');
 for(let i=0;i<60;i++){f.advance(.05);f.api.tick(.05);}
 const first=f.ctx._myGang[0]._mercenaryFollowGoal.position;assert(first.x>f.ctx.player.c*4.1+2,'formation eventually turns behind the new heading');
 const g=await fixture();g.ctx.player.ang=Math.PI-.01;assert(g.api.recruit(g.api.getRoster().candidates[0].id).ok);g.api.tick(.05);
 const previous={...g.ctx._myGang[0]._mercenaryFollowGoal.position};g.ctx.player.ang=-Math.PI+.01;g.advance(.25);g.api.tick(.05);
 const next=g.ctx._myGang[0]._mercenaryFollowGoal.position;assert(Math.hypot(next.x-previous.x,next.z-previous.z)<.07,'angle wrap takes the short path');
});

test('combat movement facade preserves source and rendered collision guards',async()=>{
 const f=await fixture();assert(f.api.recruit(f.api.getRoster().candidates[0].id).ok);const m=f.ctx._myGang[0],from={r:m.r,c:m.c},to={r:m.r,c:m.c+.01};
 let nativeChecks=0;f.api.bindTargets({canMove:(a,b,id)=>{nativeChecks++;assert.equal(id,m.id);assert.equal(a.x,from.c*4.1);return false;}});
 assert.equal(f.api.canMoveMember(m.id,from,to),false,'native car/building collision blocks combat');assert.equal(nativeChecks,1);
 f.api.bindTargets({canMove:()=>true});f.ctx._npcPathPassable=()=>false;
 assert.equal(f.api.canMoveMember(m.id,from,to),false,'source wall blocks combat');f.ctx._npcPathPassable=()=>true;
 assert.equal(f.api.canMoveMember(m.id,from,to),true);assert.equal(f.api.canMoveMember(m.id,from,{r:NaN,c:0}),false);
 m.hp=0;assert.equal(f.api.canMoveMember(m.id,from,to),false,'downed fighter cannot move');
});

test('defense hands existing threat to combat and resumes rally after target dies or threat expires',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates[1].id);const m=f.ctx._myGang[0],enemy={id:'attacker',r:11,c:11,hp:80};
 f.api.bindTargets({canMove:()=>true});f.api.rally({x:46,z:46});f.ctx._resolveGangAlertTarget=()=>({kind:'street_npc',ref:enemy,id:enemy.id});m._threatRef=enemy;m._threatUntil=f.ctx.performance.now()+6000;
 f.api.tick(.05);assert(f.api.isDefending(m.id));assert.equal(f.api.ownsUpdate(m),false);assert.equal(m.targetRef,enemy);assert.equal(m._mercenaryMove,null);
 enemy.hp=0;f.api.tick(.05);assert.equal(f.api.isDefending(m.id),false);assert.equal(m.targetRef,null);assert.equal(m._mercenaryOrder,'rally');assert(f.api.ownsUpdate(m));
 enemy.hp=80;m._threatUntil=f.ctx.performance.now()+6000;f.api.tick(.05);f.advance(7);f.api.tick(.05);assert.equal(f.api.isDefending(m.id),false);assert.equal(m.targetKind,null);
});

test('cancelCommand cancels work but preserves attached charges and blocked rally cannot move fighters',async()=>{
 const f=await fixture();f.api.recruit(f.api.getRoster().candidates.find(c=>c.profession==='demolitions').id);const m=f.ctx._myGang[0],target={id:'car',kind:'vehicle',position:{...f.api.getMember(m.id).position}};
 f.api.bindTargets({get:()=>target,performEffect:()=>true,canMove:()=>true});f.api.command('plant_bomb',target);f.api.tick(.05);assert(f.api.cancelCommand(m.id).ok);assert.equal(f.api.getAction(m.id),null);
 f.api.command('plant_bomb',target);f.api.tick(.05);f.advance(4);f.api.tick(.05);assert.equal(f.api.cancelCommand(m.id).blocked[0].reason,'bomb_armed');
 const g=await fixture({blocked:true});g.api.recruit(g.api.getRoster().candidates[1].id);g.api.bindTargets({canMove:()=>true});assert.equal(g.api.rally({x:45,z:45}).count,0);const before=g.ctx._myGang.map(m=>[m.r,m.c]);for(let i=0;i<20;i++)g.api.tick(.05);assert.deepEqual(g.ctx._myGang.map(m=>[m.r,m.c]),before);
});

test('carry and draw preserve source inventory, retain combat candidate identity and holster after combat',async()=>{
 const f=await fixture(),c=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===c.id);
 const view=()=>f.api.decorateEntities([{id:n.id,weapon:n.weapon}])[0];
 assert.equal(view().weapon,'none');n._fighting=true;f.advance(3);f.api.tick(.05);assert.equal(view().weapon,'pistol');assert.equal(view().mercenary.profession,c.profession);
 n._fighting=false;assert.equal(view().weapon,'none');assert(f.api.recruit(c.id).ok);const m=f.ctx._myGang[0];
 const crew=()=>f.api.decorateEntities([{id:'crew_'+m.id,weapon:m.weapon}])[0];
 assert.equal(crew().weapon,'none');m._mercenaryDefending=true;assert.equal(crew().weapon,'pistol');m._mercenaryDefending=false;assert.equal(crew().weapon,'none');
 assert.equal(m.weapon,'pistol');assert.equal(f.ctx._inventoryItems[0].qty,2);
 const ordinary={id:'civilian7',weapon:null},guard={id:'guard',weapon:'rifle',police:true};assert.equal(f.api.decorateEntities([ordinary,guard])[0].weapon,null);assert.equal(f.api.decorateEntities([ordinary,guard])[1].weapon,'rifle');
});

test('retired candidate does not leak assigned pistol into an ordinary civilian',async()=>{
 const f=await fixture(),c=f.api.getRoster().candidates[0],n=f.ctx.NPCS.find(n=>n.id===c.id);assert.equal(n.weapon,'pistol');
 n._clientOfBiz='shop';f.advance(3);f.api.tick(.05);assert.equal(n.weapon,null);assert(!f.api.decorateEntities([{id:n.id,weapon:n.weapon}])[0].mercenaryCandidate);
});
