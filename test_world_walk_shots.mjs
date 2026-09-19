import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source=fs.readFileSync(new URL('./world.html',import.meta.url),'utf8');
const fn=name=>{const start=source.indexOf('function '+name+'(');assert(start>=0,name);const end=source.indexOf('\nfunction ',start+10);return source.slice(start,end);};
for(const [,attrs,body] of source.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi))if(!/type=["'](?:module|importmap|application\/)/.test(attrs))new vm.Script(body);
const helpers=source.slice(source.indexOf('let _walkShotContext=null;'),source.indexOf('function _threeBridgeFireAccepted('));
const methods=source.slice(source.indexOf('  selectWalkWeapon(canonicalId){'),source.indexOf('  fire(angle, muzzleR, muzzleC) {',source.indexOf('  selectWalkWeapon(canonicalId){')));
function setup(){
 const victim={id:'civilian',r:0,c:2,hp:100},other={id:'other',r:0,c:2.15,hp:100};
 const emitted=[];let shots=0,reloads=0,equips=0;
 const c={NPCS:[victim,other],_buildingInt:null,_bankInt:null,cityCops:[],worldCops:[],michaelGuards:new Map(),beachgoers:new Map(),aggroZones:{},worldEvent:null,_busRiders:[],_busWaiters:[],_parkingNpcs:[],CARS:[],player:{r:0,c:0},currentWeapon:'pistol',WEAPON_ALIASES:{tt:'pistol'},performance:{now:()=>1000},
  _threeNpcActionRefs:new Map([['npc_civilian',{ref:victim}],['npc_other',{ref:other}]]),_threeNpcEntityId:n=>'npc_'+n.id,
  QP:{uid:'7'},_serverAuthoritativeAmmo:false,_walkRendererActive:()=>true,_isArmed:()=>!!c.currentWeapon,weaponsForPick:()=>[{id:null},{id:'pistol'}],_weaponPickEl:{children:[]},
  renderWeaponPick(){c._weaponPickEl.children=c.weaponsForPick().map(w=>({click(){equips++;c.currentWeapon=w.id;}}));},
  reloadCurrentWeapon(){reloads++;return true;},window:{dispatchEvent:e=>emitted.push(e.detail)},CustomEvent:class{constructor(type,{detail}){this.type=type;this.detail=detail;}}
 };vm.createContext(c);
 vm.runInContext(helpers+'\n'+fn('_raycastNpc')+'\n'+fn('_raycastBeachgoer')+'\n'+fn('_raycastDecorNpc')+'\n'+fn('_localBallisticTargets')+'\nthis.bridge={getPlayerState(){return {weapon:currentWeapon,magazine:this.magazine??4}},'+methods+'};'+`
 function _threeBridgeFireAccepted(angle){
  if(!bridge.magazine)return false;
  bridge.magazine--;
  const ctx=_walkShotContext;ctx.shotId='shot_'+(++bridge.seq);_walkPendingShots.set(ctx.shotId,ctx);
  _walkResolveShotContact(angle+.01,10,currentWeapon);
  const hit=_raycastNpc(0,0,0,1,10);
  if(hit){hit.npc.hp-=10;_walkConfirmDamage(hit.npc,10);}
  return true;
 }
 bridge.magazine=4;bridge.seq=0;
 this.setContext=value=>_walkShotContext=value;
 this.getContext=()=>_walkShotContext;
 `,c);return {c,victim,other,emitted,counts:()=>({shots,reloads,equips})};
}
const contact={npcId:'npc_civilian',point:{x:8.2,y:1.1,z:0},normal:{x:-3,y:0,z:0},zone:'chest'};
let {c,victim,other,emitted,counts}=setup();
// A miss over a prone body must still spend the real source round and must
// not let the old 0.95-tile cylinder damage this or a neighboring character.
let result=c.bridge.fireWalkShot({angle:0,resolveContact:()=>null});assert(result.accepted);assert.equal(result.state.magazine,3);assert.equal(victim.hp,100);assert.equal(other.hp,100);assert.equal(emitted.length,0);assert.equal(c.getContext(),null);
let observedAngle;
result=c.bridge.fireWalkShot({angle:0,resolveContact:q=>{observedAngle=q.angle;return contact;}});
assert.equal(observedAngle,.01);assert(result.accepted&&result.confirmed);assert.equal(victim.hp,90);assert.equal(other.hp,100);assert.equal(emitted.length,1);assert.equal(emitted[0].point.x,8.2);assert.equal(emitted[0].normal.x,-1);assert.equal(emitted[0].shotId,result.shotId);
assert.equal(c._walkConfirmDamage(victim,10,result.shotId),false,'repeat ack deduplicated');
c.bridge.magazine=0;result=c.bridge.fireWalkShot({angle:0,resolveContact:()=>contact});assert(!result.accepted);assert.equal(emitted.length,1);
c.bridge.magazine=1;result=c.bridge.fireWalkShot({angle:0,resolveContact:()=>({...contact,npcId:'npc_missing'})});assert(result.accepted&&!result.contactAccepted);assert.equal(victim.hp,90);
// Old renderer keeps its existing radius hits; no global AI/fire gate leaks.
assert.equal(c._raycastNpc(0,0,0,1,10).npc,victim);
assert(c.bridge.selectWalkWeapon('tt').accepted);assert.equal(counts().equips,1);assert(!c.bridge.selectWalkWeapon('sniper').accepted);assert.equal(counts().equips,1);assert(c.bridge.reloadWalkWeapon().accepted);assert.equal(counts().reloads,1);
c._walkRendererActive=()=>false;assert(!c.bridge.fireWalkShot({angle:0}).accepted);assert(!c.bridge.selectWalkWeapon('pistol').accepted);assert(!c.bridge.reloadWalkWeapon().accepted);
// Selected native actor is the sole NPC admitted across normal/penetrating
// target lists. Cars remain handled by the existing source ballistic code.
({c,victim,other}=setup());c.setContext({ref:victim});c._beachgoerWorldPos=b=>b;c.hitNpc=()=>{};c.hitCityCop=()=>{};c.hitGangCar=()=>{};let targets=c._localBallisticTargets();assert.equal(targets.length,1);assert.equal(targets[0].key,victim);c.setContext({ref:null});assert.equal(c._localBallisticTargets().length,0);
// Approved prone exception is only inside a live walk shot context.
const fire=fn('fire');assert(fire.includes("(!_walkShotContext&&_effectivePlayerStance()==='prone')"));assert(fire.includes('_spendWeaponRound()'));assert(fire.indexOf('_walkResolveShotContact(')>fire.indexOf('_applyWeaponSpread('));
for(const variable of ['t','c','bot','g','npc'])assert(fire.includes(`if(!_walkShotAllows(${variable}))continue;`));
assert(fire.includes('const pvpTarget = (!_walkShotContext && '));
// Remote contact is held until the server reports real successful damage.
({c,emitted}=setup());const cop={id:'cop1',x:2,y:0,alive:true};c.worldCops.push(cop);c._threeNpcActionRefs.set('npc_world_cop_cop1',{ref:cop});
result=c.bridge.fireWalkShot({angle:0,resolveContact:()=>({...contact,npcId:'npc_world_cop_cop1'})});assert(result.accepted&&!result.confirmed);assert.equal(emitted.length,0);
const receipt={kind:'cop_hit',shot_id:result.shotId,shooter_uid:'7',cop_id:'cop1',dmg:12};
for(const bad of [{...receipt,kind:'weapon_shot_reply'},{...receipt,shooter_uid:'8'},{...receipt,cop_id:'other'},{...receipt,shot_id:'old'},{...receipt,dmg:0}])assert(!c._walkConfirmServerHit(bad));
assert.equal(emitted.length,0);assert(c._walkConfirmServerHit(receipt));assert.equal(emitted.length,1);assert.equal(emitted[0].point.x,8.2);assert(!c._walkConfirmServerHit(receipt));
console.log('PASS world walk shots: source syntax, source-round forwarding, physical miss, final spread callback, native target identity, exact confirmed point/normal, ack dedupe, ownership/equip/reload, legacy isolation');
