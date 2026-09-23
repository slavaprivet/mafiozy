import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import * as module from './mercenary_core.mjs';

const read=name=>fs.readFileSync(new URL(name,import.meta.url),'utf8');
const source=read('./mercenary_world.js').replace("import(new URL('./mercenary_core.mjs',scriptUrl).href)",'Promise.resolve(module)');
const text=read('./test_mercenary_rally_actions.mjs');
const fixture=Function('vm','module','script','assert',text.slice(text.indexOf('async function fixture('),text.indexOf('\nfor(const [profession'))+';return fixture;')(vm,module,source,assert);
const world=read('../../../world.html');
let checks=0;const check=(condition,message)=>{assert(condition,message);checks++;};
async function setup(){
 const f=await fixture(),m=f.recruit('engineer'),enemy={id:'attacker',hp:100,r:10,c:8};
 let vehicleId='fleet:test',seated=true;
 const descriptor=()=>({id:vehicleId,source:false,r:10,c:10,ang:Math.PI/2,speed:0,seats:['front_right','rear_left','rear_right'],occupied:['front_left'],blocked:false});
 const transport={getVehicle:descriptor,getPlayerVehicle:()=>seated?descriptor():null};
 f.api.bindTargets({squadTransport:transport,groundHeight:()=>0,canMove:()=>true});
 Object.assign(m,{weapon:'tt_pistol',_mercenaryVehicleId:vehicleId,_mercenaryVehicleSeat:'front_right',_mercenaryVehiclePhase:'drive',_mercenaryVehicleProgress:1});
 Object.assign(f.ctx,{cityCops:[],_bankInt:null,_buildingInt:null,_majorInteriorObjectId:null,_threeNpcEntityId:n=>'npc_'+n.id});f.ctx.NPCS.push(enemy);
 return {...f,m,enemy,transport,intent:()=>f.api.getVehicleFireIntent(m.id),attack:(ref=enemy,extra={})=>f.api.noteVehicleAttack({kind:'street_npc',ref,victimKind:'player',victimId:'player',...extra}),vehicle:id=>vehicleId=id,seated:value=>seated=value};
}
{
 const f=await setup(),before=JSON.stringify({r:f.m.r,c:f.m.c,order:f.m._mercenaryOrder,queue:f.api.getQueue(f.m.id)});
 check(!f.api.getVehicleDefenseFireState().enabled,'fresh host starts off');
 f.api.command('eliminate',{id:f.enemy.id});check(!f.intent(),'hovered/focused civilian is not car defense authority');
 f.m._threatRef=f.enemy;f.m._threatUntil=f.ctx.performance.now()+6000;
 check(f.api.toggleVehicleDefenseFire().ok&&!f.intent(),'X arms without generic alert or focused-target authority');
 const snapshot=f.api.decorateEntities([{id:'npc_crew_'+f.m.id}])[0];check(snapshot.mercenaryVehicleReady&&!snapshot.mercenaryVehicleFire,'presentation ready has no damage target');
 check(!('targetRef' in snapshot.mercenaryVehicleReady)&&snapshot.weapon==='tt_pistol','ready packet carries actual gun, no source identity');
 check(f.attack()&&f.intent()?.targetRef===f.enemy,'real incoming source permits defensive selection');
 f.api.toggleVehicleDefenseFire();check(!f.intent(),'off suppresses fire immediately');
 check(JSON.stringify({r:f.m.r,c:f.m.c,order:f.m._mercenaryOrder,queue:f.api.getQueue(f.m.id)})===before,'toggling never moves or changes normal order/queue');
}
for(const [name,mutate]of [
 ['downed',f=>f.enemy.downed=true],['dead',f=>f.enemy.hp=0],['friendly',f=>f.enemy._friendly=true],['allied',f=>f.enemy._allied=true],
 ['despawn',f=>f.ctx.NPCS.splice(f.ctx.NPCS.indexOf(f.enemy),1)],['identity replacement',f=>{const i=f.ctx.NPCS.indexOf(f.enemy);f.ctx.NPCS[i]={...f.enemy};}],
 ['expired',f=>{const stamp=f.ctx.performance.now();f.ctx.performance.now=()=>stamp+6001;}],['clock reversal',f=>{const stamp=f.ctx.performance.now();f.ctx.performance.now=()=>stamp-1;}],
 ['range',f=>f.enemy.c=-10],['opposite window',f=>f.enemy.c=12],['online',f=>f.ctx._serverAuthoritativeAmmo=true]
]){
 const f=await setup();f.api.toggleVehicleDefenseFire();check(f.attack()&&!!f.intent(),name+' baseline');mutate(f);check(!f.intent(),name+' cancels actual source intent');
}
{
 const f=await setup();f.api.toggleVehicleDefenseFire();
 for(const extra of [{kind:'city_cop'},{victimKind:'player',victimId:'other'},{victimKind:'member',victimId:'unknown'},{victimKind:'vehicle',victimId:'fleet:other'},{victimKind:'building'}])check(!f.attack(f.enemy,extra),'unproven victim/kind rejected');
 check(!f.attack({...f.enemy}),'unregistered same-id source rejected');check(!f.intent(),'invalid receipts have no intent');
 check(f.attack(f.enemy,{victimKind:'member',victimId:f.m.id}),'actual owned crew attack accepted');
 const old=f.intent();check(f.api.validateVehicleFireIntent(old),'current receipt validates');f.attack();check(!f.api.validateVehicleFireIntent(old),'new incoming receipt invalidates previously prepared identity');
 check(f.attack(f.enemy,{victimKind:'vehicle',victimId:'fleet:test'}),'current owned vehicle attack accepted');
}
for(const weapon of ['nagan','tt_pistol','revolver','deagle','golden_colt','uzi','golden_uzi','tommy_gun','sawn_off','shotgun','ak74','m16','sniper','pistol','pistol_heavy','smg','rifle','golden_ak','golden_pistol','pistol_gold','golden_tommy']){
 const f=await setup();f.m.weapon=weapon;check(f.api.toggleVehicleDefenseFire().ok,'held family can enable '+weapon);f.attack();check(f.intent()?.weaponId===weapon,'no TT substitution '+weapon);
}
{
 const f=await setup();f.api.toggleVehicleDefenseFire();f.m.weapon='rpg';
 check(f.api.canIssueVehicleFireCommand(),'off remains available after last eligible gun becomes unsupported');
 const state=f.api.getVehicleDefenseFireState();check(state.enabled&&state.eligible===0&&state.unsupportedWeapons[0].reason.includes('РПГ'),'RPG projectile-authority limitation is truthful');
 check(f.api.toggleVehicleDefenseFire().ok&&!f.api.getVehicleDefenseFireState().enabled,'X can disable zero-eligible mode');
 check(!f.api.toggleVehicleDefenseFire().ok,'unsupported-only crew cannot re-enable');
 f.m.weapon='tt_pistol';f.api.toggleVehicleDefenseFire();f.m.hp=0;check(f.api.canIssueVehicleFireCommand()&&f.api.toggleVehicleDefenseFire().ok,'off works after last shooter wounded');
}
for(const [name,mutate]of [['exit',f=>f.seated(false)],['vehicle switch',f=>f.vehicle('fleet:next')],['hero dead',f=>f.ctx.myDead=true],['dispose',f=>f.api.bindTargets(null)]]){
 const f=await setup();f.api.toggleVehicleDefenseFire();f.attack();mutate(f);check(!f.api.getVehicleDefenseFireState().enabled&&!f.intent(),name+' resets enabled and intent');
}

// Execute the actual QA provocation function, then the actual direct police
// shooting branch. Merely preparing aggro must not create a fire receipt.
const engage=world.slice(world.indexOf('function _cityCopEngagePlayerAfterHit('),world.indexOf('function hitCityCop('));
const note=world.slice(world.indexOf('function _noteVehicleIncomingAttack('),world.indexOf('// Автоспавн убран',world.indexOf('function _noteVehicleIncomingAttack(')));
const attackStart=world.indexOf('      if(perceivedTarget.visible&&_localHostileCanResolveHit()&&armedAggro&&distToPlayer>.7');
const attackBody=world.slice(attackStart,world.indexOf('      // Игрок в машине',attackStart));
check(attackBody.includes('_noteVehicleIncomingAttack(cop)'),'actual direct police shooting branch contains receipt hook');
{
 const f=await setup(),cop={id:'patrol',hp:100,alive:true,x:8,y:10},far={id:'far',hp:100,alive:true,x:1,y:10},before={hp:100,x:8,y:10};
 f.ctx.cityCops.push(cop,far);let los=true,bullets=0,damage=0;
 Object.assign(f.ctx,{serviceVehicles:[],_policeWorldLineClear:()=>los,_localHostileCanResolveHit:()=>true,_markPoliceShot(){},spawnBullet(){bullets++;},spawnMuzzle(){},spawnImpact(){},spawnFloatText(){},_hurtLocal(){damage++;},Math:Object.assign(Object.create(Math),{random:()=>.99})});
 vm.runInContext(engage+'\n'+note+'\nfunction actualPoliceAttack(cop,now){const perceivedTarget={visible:true},armedAggro=true,distToPlayer=Math.hypot(cop.y-player.r,cop.x-player.c);'+attackBody+'}',f.ctx);
 check(!f.api.qaVehicleDefenseAttack().ok&&!cop._pursuing,'QA absent denies provocation');
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/walk?carqa=1';
 f.api.toggleVehicleDefenseFire();los=false;check(f.api.qaVehicleDefenseAttack().ok&&!f.intent(),'QA may prepare ordinary pursuit without initial LOS, never a fire receipt');los=true;
 const response=f.api.qaVehicleDefenseAttack();check(response.ok&&response.copId==='patrol','QA chooses nearest existing living officer');
 check(JSON.stringify({hp:cop.hp,x:cop.x,y:cop.y})===JSON.stringify(before)&&f.ctx.cityCops.length===2,'QA does not alter HP/position or create officers');
 check(!f.intent()&&bullets===0&&damage===0&&cop._pursuing,'QA aggro alone never authors a receipt or shot');
 f.ctx.actualPoliceAttack(cop,f.ctx.performance.now());check(bullets===0&&!f.intent(),'real attack respects cadence before receipt');
 f.ctx.actualPoliceAttack(cop,f.ctx.performance.now()+1000);check(bullets===1&&f.intent()?.targetRef===cop,'real direct police emission establishes source defensive target');
 // A real miss also establishes hostile intent. At 12 source cells, .99
 // RNG exceeds the branch hit threshold; moving closer later is normal.
 f.api.bindTargets(null);f.api.bindTargets({squadTransport:f.transport,groundHeight:()=>0});f.api.toggleVehicleDefenseFire();cop.x=-2;cop._murderNextShootAt=0;
 f.ctx.actualPoliceAttack(cop,f.ctx.performance.now()+2000);const damageBefore=damage;f.ctx.actualPoliceAttack(cop,f.ctx.performance.now()+3000);
 check(bullets===2&&damage===damageBefore,'actual miss emits a bullet without HP hit');cop.x=8;check(f.intent()?.targetRef===cop,'miss provenance remains valid when real attacker moves into range');
 f.seated(false);check(!f.api.qaVehicleDefenseAttack().ok,'QA rejects player on foot');
}
{
 const f=await setup(),cop={id:'approach',hp:100,alive:true,x:30.5,y:10};f.ctx.cityCops.push(cop);
 Object.assign(f.ctx,{serviceVehicles:[],CITYCOP_PURSUE_R:12,_policeWorldLineClear:()=>false,_policeCanSeePoint:()=>false});
 f.ctx.location.hostname='localhost';f.ctx.location.href='http://localhost/walk?carqa=1';
 const pursuit=world.slice(world.indexOf('function _policePursuitTarget('),world.indexOf('function _alertNearbyCops('));vm.runInContext(engage+'\n'+pursuit,f.ctx);
 f.api.toggleVehicleDefenseFire();const before={x:cop.x,y:cop.y,hp:cop.hp},qa=f.api.qaVehicleDefenseAttack();check(qa.ok&&qa.distanceMeters===84,'QA admits actual 84m officer without LOS');
 const perceived=f.ctx._policePursuitTarget(cop,f.ctx.performance.now(),24,true);
 check(perceived&&!perceived.visible&&perceived.r===f.ctx.player.r&&perceived.c===f.ctx.player.c,'actual knownDirect perception remembers player behind occlusion for normal approach');
 check(Math.hypot(perceived.r-cop.y,perceived.c-cop.x)<24,'84m officer lies within unchanged real pursuit radius');
 check(JSON.stringify({x:cop.x,y:cop.y,hp:cop.hp})===JSON.stringify(before)&&!f.intent(),'QA preserves officer location/HP and does not fabricate incoming attack');
 cop.x=49;const far=f.api.qaVehicleDefenseAttack();check(far.ok&&far.message.includes('приблизьтесь'),'QA range beyond ordinary pursuit gives truthful approach instruction');
 cop.x=60.01;check(!f.api.qaVehicleDefenseAttack().ok,'50-cell QA bound is enforced');cop.x=30;cop.alive=false;check(!f.api.qaVehicleDefenseAttack().ok,'dead officer cannot be provoked');
}
console.log(JSON.stringify({status:'PASS',checks,coverage:'actual source defense host, current weapon families, life/authority/TTL, QA provocation and real direct-police firing branch; no browser claims'}));
